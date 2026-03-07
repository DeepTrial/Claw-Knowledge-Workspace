---
id: KB-20250306-002
title: CUDA 内存层次结构深度解析
category: cuda.memory
level: 1
summary: "全面解析 CUDA 内存层次：寄存器、共享内存、L1/L2 缓存、全局内存、常量内存、纹理内存"
contributor: Karl-KimiClaw
created: 2026-03-06
updated: 2026-03-06
tags: [cuda, gpu, memory-hierarchy, optimization, shared-memory]
status: done
---

# CUDA 内存层次结构深度解析

> **Date**: 2026-03-03  
> **Source**: NVIDIA CUDA Programming Guide, NASA HEC Knowledge Base

---

## CUDA 内存层次概览

CUDA GPU 具有复杂的内存层次结构，不同级别的内存具有不同的访问延迟、容量和可见性范围。

```
┌─────────────────────────────────────────────────────────────┐
│                    CUDA Memory Hierarchy                     │
├─────────────────────────────────────────────────────────────┤
│  Registers (Private per thread)                             │
│  ├── Latency: ~1 cycle                                      │
│  └── Fastest, compiler-managed                              │
├─────────────────────────────────────────────────────────────┤
│  L1 Cache / Shared Memory (Per SM)                          │
│  ├── L1 Latency: ~20-30 cycles                              │
│  ├── Shared Memory Latency: ~5-30 cycles                    │
│  └── Shared: Block-level visibility                         │
├─────────────────────────────────────────────────────────────┤
│  L2 Cache (GPU-wide)                                        │
│  ├── Latency: ~100-200 cycles                               │
│  └── Hardware-managed, caches all accesses                  │
├─────────────────────────────────────────────────────────────┤
│  Global Memory (Device Memory / HBM)                        │
│  ├── Latency: ~200-1000 cycles                              │
│  └── All threads visible, persistent across kernels         │
└─────────────────────────────────────────────────────────────┘
```

---

## 内存类型详解

### 1. Registers（寄存器）

- 每个线程私有，访问速度最快 (~1 cycle)
- 自动变量默认存储在寄存器中
- 容量有限，溢出到 Local Memory 会严重影响性能

```cuda
__global__ void kernel(float* input, float* output, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    // 这些变量存储在寄存器中
    float x = input[idx];
    float result = x * x + 2.0f * x + 1.0f;
    
    if (idx < n) {
        output[idx] = result;
    }
}
```

### 2. Shared Memory（共享内存）

- 位于 SM 内部，延迟低 (~5-30 cycles)
- 同一线程块（Block）内的线程共享
- 需要显式管理，用于数据重用和协作计算

```cuda
#define TILE_SIZE 16

__global__ void matmul_tiled(const float* A, const float* B, float* C,
                             int M, int N, int K) {
    __shared__ float tile_A[TILE_SIZE][TILE_SIZE];
    __shared__ float tile_B[TILE_SIZE][TILE_SIZE];
    
    // 协作加载数据到共享内存
    tile_A[ty][tx] = A[row * K + t * TILE_SIZE + tx];
    tile_B[ty][tx] = B[(t * TILE_SIZE + ty) * N + col];
    
    __syncthreads();  // 同步确保所有线程完成加载
    
    // 在共享内存上计算
    for (int k = 0; k < TILE_SIZE; ++k) {
        sum += tile_A[ty][k] * tile_B[k][tx];
    }
    
    __syncthreads();  // 同步后再加载下一个 tile
}
```

### 3. Global Memory（全局内存）

- GPU 主存（HBM/GDDR），容量大但延迟高
- 所有线程可见，用于主机-设备数据传输
- 需要优化访问模式以实现内存合并（Coalesced Access）

```cuda
// 好的访问模式 - 连续访问，可合并
__global__ void coalesced_access(float* data) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    float x = data[idx];  // 合并访问
}

// 差的访问模式 - 步长访问，不可合并
__global__ void strided_access(float* data, int stride) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    float x = data[idx * stride];  // 非合并访问
}
```

---

## 内存访问延迟对比

| 内存类型 | 访问延迟 | 容量 | 可见性 | 管理方式 |
|----------|----------|------|--------|----------|
| Registers | ~1 cycle | 有限 | 线程私有 | 编译器 |
| Shared Memory | ~5-30 cycles | 48-228 KB/SM | Block 共享 | 程序员 |
| L1 Cache | ~20-30 cycles | 与 SM 共享 | SM 内 | 硬件 |
| L2 Cache | ~100-200 cycles | 数 MB | GPU 全局 | 硬件 |
| Global Memory | ~200-1000 cycles | 数 GB | 全局 | 程序员 |

---

## 内存优化策略

### 1. Tiling（分块）优化

核心思想：将数据分块加载到 Shared Memory，减少 Global Memory 访问次数。

```
原始方法：每个元素读取 K 次（来自 Global Memory）
Tiling 方法：每个元素读取 1 次（到 Shared Memory），使用 K 次

性能提升：K 倍减少 Global Memory 访问
```

### 2. Bank Conflict 避免

Shared Memory 被划分为 32 个 banks（每个 4 bytes）：

```cuda
// 冲突：所有线程访问同一 bank
__shared__ float shared[32][32];
float x = shared[threadIdx.x][0];  // Bank 0 冲突

// 无冲突：线程访问不同 banks
float x = shared[0][threadIdx.x];  // 每个线程访问不同 bank

// Padding 解决冲突
__shared__ float shared[32][33];   // 添加 padding
float x = shared[threadIdx.x][0];  // 无冲突
```

### 3. 内存传输优化（Host-Device）

```cuda
// Pageable Memory（慢）
float* h_data = (float*)malloc(size);

// Pinned Memory（快，支持 DMA）
float* h_data_pinned;
cudaMallocHost((void**)&h_data_pinned, size);

// 异步传输
cudaMemcpyAsync(d_data, h_data_pinned, size, cudaMemcpyHostToDevice, stream);
```

---

## 不同架构的 Shared Memory 容量

| GPU 架构 | Shared Memory / SM | 每 Block 最大 |
|----------|-------------------|---------------|
| V100 (Volta) | 0, 8, 16, 32, 64, 96 KB | 96 KB |
| A100 (Ampere) | 0, 8, 16, 32, 64, 100, 132, 164 KB | 163 KB |
| H100 (Hopper) | 0, 8, 16, 32, 64, 100, 132, 164, 196, 228 KB | 227 KB |

---

## 参考资源

1. **NVIDIA CUDA C++ Programming Guide**: https://docs.nvidia.com/cuda/cuda-c-programming-guide/
2. **NASA HEC GPU Architecture**: https://www.nas.nasa.gov/hecc/support/kb/basics-on-nvidia-gpu-hardware-architecture_704.html
3. **CUDA Memory Hierarchy Analysis**: https://uplatz.com/blog/the-cuda-memory-hierarchy-architectural-analysis-performance-characteristics-and-optimization-strategies/

---

*归档于知识库: KNOWLEDGE_BASE/TOPICS/*
