---
id: KB-20250309-005
title: Gemm 实现原理与优化
category: cuda.optimization
level: 3
summary: "从v0到v4的Gemm实现演进：基础实现、Shared Memory分块、寄存器分块、Tensor Core使用、异步拷贝与多阶段流水线优化"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cuda, gemm, implementation, optimization, tensor-core, pipeline]
status: done
---

# Gemm 实现原理与优化

本节从零开始，逐步构建一个高性能 Gemm Kernel，理解每一层优化的原理。

---

## 版本 0: 基础实现 (Global Memory 直接访问)

```cpp
// 最简单版本：每个线程计算 C 的一个元素
// 无 Shared Memory，无优化

template <typename T>
__global__ void gemm_v0(
    const T* A, const T* B, T* C,
    int M, int N, int K) {
    
    int m = blockIdx.y * blockDim.y + threadIdx.y;
    int n = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (m >= M || n >= N) return;
    
    T sum = 0;
    for (int k = 0; k < K; ++k) {
        sum += A[m * K + k] * B[k * N + n];
    }
    C[m * N + n] = sum;
}

// 问题分析:
// 1. 每个线程访问分散的 Global Memory (A 的行，B 的列)
// 2. 内存访问不合并
// 3. 无数据复用
// 性能: ~1-2% 峰值 (约 100 GFLOPS on A100)
```

---

## 版本 1: Shared Memory 分块

```cpp
// 引入 Tile，数据加载到 Shared Memory 后复用
// TILE_M = TILE_N = TILE_K = 32

template <int BM, int BN, int BK, typename T>
__global__ void gemm_v1(
    const T* A, const T* B, T* C,
    int M, int N, int K) {
    
    // 当前 CTA 负责的输出 tile 坐标
    int tile_m = blockIdx.y * BM;
    int tile_n = blockIdx.x * BN;
    
    // Shared Memory 分配
    __shared__ T sA[BM * BK];
    __shared__ T sB[BK * BN];
    
    // 当前线程在 tile 内的坐标
    int tid = threadIdx.y * blockDim.x + threadIdx.x;
    
    // Accumulator 寄存器
    T acc[BM * BN / (blockDim.x * blockDim.y)] = {0};
    
    // 遍历 K 维度
    for (int k = 0; k < K; k += BK) {
        // 协作加载 A tile 到 Shared Memory
        for (int i = tid; i < BM * BK; i += blockDim.x * blockDim.y) {
            int sm = i / BK;
            int sk = i % BK;
            sA[sm * BK + sk] = A[(tile_m + sm) * K + k + sk];
        }
        
        // 协作加载 B tile
        for (int i = tid; i < BK * BN; i += blockDim.x * blockDim.y) {
            int sk = i / BN;
            int sn = i % BN;
            sB[sk * BN + sn] = B[(k + sk) * N + tile_n + sn];
        }
        
        __syncthreads();
        
        // 计算: 从 Shared Memory 读取
        for (int kk = 0; kk < BK; ++kk) {
            // 计算逻辑...
        }
        
        __syncthreads();
    }
}

// 性能提升: ~5-10x
// 原理: Shared Memory 访问速度是 Global Memory 的 ~20-30 倍
// 每个元素从 Gmem 加载 1 次，在 Smem 中复用 BM 或 BN 次
```

---

## 版本 2: 寄存器分块 + 向量化加载

```cpp
// 每个线程计算 TM x TN 输出，使用寄存器累加
// 向量加载 (float4) 提高带宽利用率

template <int BM, int BN, int BK, int TM, int TN, typename T>
__global__ void gemm_v2(...) {
    
    T rA[TM];
    T rB[TN];
    T acc[TM][TN] = {0};
    
    int thread_row = threadIdx.y * TM;
    int thread_col = threadIdx.x * TN;
    
    for (int k = 0; k < K; k += BK) {
        // 加载数据到 Shared Memory
        // ...
        
        __syncthreads();
        
        // 内积计算
        for (int kk = 0; kk < BK; ++kk) {
            // 广播加载到寄存器
            for (int i = 0; i < TM; ++i) rA[i] = sA[kk][thread_row + i];
            for (int j = 0; j < TN; ++j) rB[j] = sB[kk][thread_col + j];
            
            // 外积累加
            for (int i = 0; i < TM; ++i)
                for (int j = 0; j < TN; ++j)
                    acc[i][j] += rA[i] * rB[j];
        }
        
        __syncthreads();
    }
}

// 性能: ~30-40% 峰值
// 关键优化:
// 1. 寄存器累加避免重复访问 Shared Memory
// 2. TM x TN 分块提高指令级并行 (ILP)
// 3. 减少 Shared Memory 访问次数
```

---

## 版本 3: Warp 级优化 + Tensor Core

```cpp
// 使用 WMMA API 调用 Tensor Core
// Warp 内 32 线程协作完成矩阵乘

#include <mma.h>
using namespace nvcuda::wmma;

template <int WMMA_M, int WMMA_N, int WMMA_K, typename T>
__global__ void gemm_v3_tensor_core(...) {
    
    int warp_id = threadIdx.x / 32;
    int lane_id = threadIdx.x % 32;
    
    // WMMA fragment 声明
    fragment<matrix_a, WMMA_M, WMMA_N, WMMA_K, half_t, row_major> fragA;
    fragment<matrix_b, WMMA_M, WMMA_N, WMMA_K, half_t, col_major> fragB;
    fragment<accumulator, WMMA_M, WMMA_N, WMMA_K, float> fragC;
    
    fill_fragment(fragC, 0.0f);
    
    int warp_row = blockIdx.y * WMMA_M + warp_id / 4 * WMMA_M;
    int warp_col = blockIdx.x * WMMA_N + warp_id % 4 * WMMA_N;
    
    for (int k = 0; k < K; k += WMMA_K) {
        load_matrix_sync(fragA, A + warp_row * K + k, K);
        load_matrix_sync(fragB, B + k * N + warp_col, N);
        mma_sync(fragC, fragA, fragB, fragC);
    }
    
    store_matrix_sync(C + warp_row * N + warp_col, fragC, N, mem_row_major);
}

// 性能: ~60-80% 峰值 (FP16 on A100)
// 关键点:
// 1. Tensor Core 提供 ~2x 峰值性能 vs CUDA Core
// 2. WMMA 抽象了硬件细节
// 3. 需要特定的 memory layout
```

---

## 版本 4: 异步拷贝 + 多阶段流水线

```cpp
// Ampere+ 架构使用 cp.async 实现 Global -> Shared 异步加载
// 多阶段流水线隐藏延迟

template <int BM, int BN, int BK, int STAGES>
__global__ void gemm_v4_pipeline(...) {
    
    extern __shared__ half_t smem[];
    half_t* sA = smem;
    half_t* sB = smem + STAGES * BM * BK;
    
    int write_stage = 0;
    int read_stage = 0;
    
    // 预加载前 STAGES-1 个 K tile
    for (int s = 0; s < STAGES - 1; ++s) {
        // cp.async: 异步加载 A,B tiles
        cp_async_commit_group();
        write_stage = (write_stage + 1) % STAGES;
    }
    
    // 主循环
    for (int k = (STAGES - 1) * BK; k < K; k += BK) {
        cp_async_wait_group<STAGES - 1>();
        __syncthreads();
        
        // 启动下一批异步加载
        if (k + STAGES * BK < K) {
            cp_async_commit_group();
        }
        
        // 计算
        compute_from_smem(sA + read_stage * BM * BK, 
                         sB + read_stage * BK * BN);
        
        __syncthreads();
        read_stage = (read_stage + 1) % STAGES;
        write_stage = (write_stage + 1) % STAGES;
    }
}

// 性能: ~80-95% 峰值
// 关键点:
// 1. cp.async 重叠内存加载与计算
// 2. 多缓冲避免读写冲突
// 3. 精确的同步控制 (arrive/wait)
```

---

## 性能演进总结

| 版本 | 优化点 | 峰值性能 | 复杂度 |
|------|--------|----------|--------|
| v0 | 基础实现 | ~2% | 低 |
| v1 | Shared Memory 分块 | ~10% | 中 |
| v2 | 寄存器分块 + 向量化 | ~35% | 中 |
| v3 | Tensor Core | ~70% | 高 |
| v4 | 异步拷贝 + 流水线 | ~90% | 很高 |
| CUTLASS | 全套优化 | ~95% | 专业 |

---

## 参考

- [[KB-20250309-001]] CUTLASS CuTe 系统性学习计划
- [[KB-20250309-004]] CUTLASS 架构设计详解
- [[KB-20250309-006]] CUTLASS 性能调优实战
