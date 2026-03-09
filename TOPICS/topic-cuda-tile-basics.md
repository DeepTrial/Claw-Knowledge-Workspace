---
id: KB-20250309-002
title: CUDA Tile 基础概念与编程模型
category: cuda.optimization
level: 2
summary: "Tile-based programming核心概念，包含Tile分块原理、计算强度、CTA/Warp/Thread三级分块、bank conflict与Swizzle技术"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cuda, tile, gemm, shared-memory, bank-conflict, swizzle, optimization]
status: done
---

# CUDA Tile 基础概念与编程模型

Tile-based programming 是高性能 GPU 计算的核心范式。理解 Tile 概念是学习 CuTe 和 CUTLASS 的必要基础。

## 什么是 Tile？

### 直观理解

想象矩阵是一个巨大的棋盘，Tile 就是棋盘上的一个方块：

```
┌─────────────────────────────────────┐
│  Tile(0,0)  │  Tile(0,1)  │  Tile(0,2)  │
│   64x64     │   64x64     │   64x64     │
├─────────────┼─────────────┼─────────────┤
│  Tile(1,0)  │  Tile(1,1)  │  Tile(1,2)  │
│   64x64     │   64x64     │   64x64     │
├─────────────┼─────────────┼─────────────┤
│  Tile(2,0)  │  Tile(2,1)  │  Tile(2,2)  │
│   64x64     │   64x64     │   64x64     │
└─────────────┴─────────────┴─────────────┘
           256x256 矩阵被划分为 3x3 个 64x64 Tiles
```

### 为什么需要 Tile？

**问题**: GPU 的 Global Memory 延迟 ~400 周期，而计算单元在 1 周期内可以完成多次运算。

**解决方案**: 将数据分块 (Tile) 加载到更快的内存层次：

```
┌─────────────────────────────────────────────┐
│  Global Memory (HBM)  ~400 周期             │
│     ↓                                       │
│  L2 Cache            ~200 周期              │
│     ↓                                       │
│  Shared Memory       ~20 周期               │
│     ↓                                       │
│  Registers           ~1 周期                │
│     ↓                                       │
│  Tensor Core/CUDA Core  计算                │
└─────────────────────────────────────────────┘

Tile 策略: 一次性加载大块数据到 Shared Memory/Registers，
          在 fast memory 中重复利用，隐藏慢速内存延迟
```

## Tile 的核心参数

### Tile Shape

Tile Shape 定义了分块的尺寸，通常用 (M, N, K) 表示：

```cpp
// Gemm 中的三层 Tile
template <int CTA_M, int CTA_N, int CTA_K,  // CTA (Block) 级 Tile
          int WARP_M, int WARP_N, int WARP_K,  // Warp 级 Tile
          int THREAD_M, int THREAD_N>  // Thread 级 Tile
struct GemmTiling {
    // CTA Tile: 一个 Block 处理的输出大小
    static constexpr int cta_m = CTA_M;  // 如 128
    static constexpr int cta_n = CTA_N;  // 如 128
    static constexpr int cta_k = CTA_K;  // 如 32 (K 维循环)
    
    // Warp Tile: 一个 Warp 处理的输出大小
    static constexpr int warp_m = WARP_M;  // 如 64
    static constexpr int warp_n = WARP_N;  // 如 64
    
    // Thread Tile: 一个 Thread 处理的输出大小
    static constexpr int thread_m = THREAD_M;  // 如 4
    static constexpr int thread_n = THREAD_N;  // 如 4
};
```

### 典型 Tile 配置

```
┌─────────────────────────────────────────────────────────────┐
│                     CTA Tile (128x128)                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Warp Tile (64x64)  │  Warp Tile (64x64)            │   │
│  │  ┌───────┬───────┐  │  ┌───────┬───────┐            │   │
│  │  │Thread │Thread │  │  │Thread │Thread │            │   │
│  │  │ 4x4   │ 4x4   │  │  │ 4x4   │ 4x4   │            │   │
│  │  ├───────┼───────┤  │  ├───────┼───────┤            │   │
│  │  │Thread │Thread │  │  │Thread │Thread │            │   │
│  │  │ 4x4   │ 4x4   │  │  │ 4x4   │ 4x4   │            │   │
│  │  └───────┴───────┘  │  └───────┴───────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Warp Tile (64x64)  │  Warp Tile (64x64)            │   │
│  │  (同上结构)                                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

一个 128x128 CTA Tile:
- 包含 4 个 64x64 Warp Tiles (2x2 排列)
- 每个 Warp 包含 256 threads (通常 8x8 Thread Tile 排列)
- 每个 Thread 计算 4x4 = 16 个输出元素
```

## Tile 中的数据复用

### 计算强度 (Arithmetic Intensity)

```cpp
// 对于 C = A * B (M,N,K)
// 每个输出元素需要 K 次乘加

// 总计算量: 2 * M * N * K (FLOPs)
// 总数据量: M*K + K*N + M*N (元素)

// 计算强度 = FLOPs / Bytes
//          = (2*M*N*K) / ((M*K + K*N + M*N) * sizeof(T))

// 对于 Tile:
// - 从 Global Memory 加载: CTA_M * CTA_K + CTA_K * CTA_N
// - 计算: 2 * CTA_M * CTA_N * CTA_K
// - 每个元素从 Gmem 加载后，在 Smem 中复用 CTA_M 或 CTA_N 次
```

### 具体示例

```cpp
// Tile Size: 64x64x32
// 数据类型: FP16 (2 bytes)

// 每个 CTA 从 Gmem 加载:
// A Tile: 64 * 32 * 2 = 4 KB
// B Tile: 32 * 64 * 2 = 4 KB
// 总计: 8 KB

// 每个 CTA 计算:
// 64 * 64 * 32 * 2 = 262,144 FLOPs

// 数据复用:
// A 的每个元素被复用 64 次 (N 维)
// B 的每个元素被复用 64 次 (M 维)

// 计算强度:
// 262,144 FLOPs / 8,192 Bytes = 32 FLOPs/Byte
```

## Tile 的内存布局与 Bank Conflict

### Global Memory → Shared Memory 的映射

```cpp
// 问题: Global Memory 是行优先，如何高效加载到 Shared Memory？

// 方案 1: 直接转置 (bank conflict 风险)
// Gmem A[row, col] -> Smem A[col, row]

// 方案 2: 保持行优先，使用 Swizzle 避免 bank conflict
// Gmem A[row, col] -> Smem A[row, swizzled_col]

// Swizzle 公式 (避免 bank conflict):
// swizzled_col = col ^ (row & 0b11)  // 2-bit XOR

__device__ int swizzle(int row, int col, int swizzle_bits = 2) {
    int mask = (1 << swizzle_bits) - 1;
    return col ^ (row & mask);
}
```

### 典型 Shared Memory 布局

```cpp
// 64x64 Tile 的 Shared Memory 布局

// 基础布局 (有 bank conflict)
__shared__ float tile[64][64];  // tile[row][col]
// 访问 tile[row][0:3] 时，4 个线程访问同 4 个 bank，无冲突 ✓
// 但访问 tile[row][0:31] 时，32 线程访问 32 bank，如果 stride 不当会冲突

// Swizzle 布局 (bank conflict free)
__shared__ float tile[64][64 + 4];  // 64+4 填充，通常 +1 即可
// 或更复杂的 swizzle 索引计算
```

## Tile 的计算模式

### Outer Product (外积)

```cpp
// 最基础的 Tile 计算: A 列 × B 行 = C 外积

for (int k = 0; k < TILE_K; ++k) {
    // 加载 A 的一列到寄存器
    float a[TM];
    for (int m = 0; m < TM; ++m) {
        a[m] = smem_A[(thread_m * TM + m) * TILE_K + k];
    }
    
    // 加载 B 的一行到寄存器
    float b[TN];
    for (int n = 0; n < TN; ++n) {
        b[n] = smem_B[k * TILE_N + thread_n * TN + n];
    }
    
    // 外积累加
    for (int m = 0; m < TM; ++m) {
        for (int n = 0; n < TN; ++n) {
            acc[m][n] += a[m] * b[n];
        }
    }
}
```

### 计算强度对比

```
模式            内存访问次数    计算量        计算强度
─────────────────────────────────────────────────────────
Naive (无 Tile)  M*N*K*2       2*M*N*K      ~1 (内存 bound)
Tile (Smem)      M*N*K/Tile    2*M*N*K      Tile 大小
Tile (Registers) M*N*K/Tile    2*M*N*K      Tile 大小 * 复用
```

## Tile 大小选择

### 考虑因素

```cpp
// 1. Shared Memory 容量限制 (A100: 164KB/SM)
// Smem_needed = (CTA_M * CTA_K + CTA_K * CTA_N) * sizeof(T) * Stages

// 2. 寄存器压力
// 每个线程: TM * TN (acc) + TM (a) + TN (b) + ...
// 总寄存器: threads_per_cta * registers_per_thread

// 3. Occupancy 目标
// 每个 SM 至少 4 warps (128 threads) 才能隐藏延迟
// 考虑寄存器和 Smem 限制，计算最大 block 数

// 4. 数据复用
// 更大的 Tile = 更高的数据复用
// 但受限于硬件资源
```

### 不同架构的甜点配置

| 架构 | 推荐 CTA Tile | 推荐 Warp Tile | Stages | 说明 |
|------|---------------|----------------|--------|------|
| Turing | 128x128 | 64x64 | 2 | 无 cp.async |
| Ampere | 256x128 | 64x64 | 3-5 | 有 cp.async |
| Hopper | 256x128 | 64x64 | 3-5+ | TMA 加速 |

## 参考

- [[KB-20250309-001]] CUTLASS CuTe 系统性学习计划
- [[KB-20250309-003]] CuTe 核心抽象详解
- [[KB-20250306-002]] CUDA 内存层次结构深度解析
