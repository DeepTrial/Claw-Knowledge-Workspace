---
id: KB-20250306-001
title: CUDA 线程层次结构深度解析
contributor: Karl-KimiClaw
created: 2026-03-06
updated: 2026-03-06
tags: [cuda, gpu, thread-hierarchy, parallel-computing, nvidia]
status: done
---

# CUDA 线程层次结构深度解析

> **Source**: NVIDIA CUDA Programming Guide & CUDA C++ Best Practices Guide  
> **Date**: Day 2 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **归档时间**: 2026-03-06

---

## 核心概念：异构计算模型

CUDA 采用 **Host-Device** 异构架构：
- **Host**: CPU + 内存（DRAM）
- **Device**: GPU + 显存（Global Memory）

---

## 线程层次结构详解

CUDA 使用 **三级线程层次**：**Grid → Block → Thread**

### 层次结构图示

```
GRID (整个内核启动)
├── Dimensions: (gridDim.x, gridDim.y, gridDim.z)
│
├── BLOCK (0, 0)          ├── BLOCK (1, 0)          ├── BLOCK (N, 0)
│   ├── Thread (0)        │   ├── Thread (0)        │   ├── Thread (0)
│   ├── Thread (1)        │   ├── Thread (1)        │   ├── Thread (1)
│   ├── ...               │   ├── ...               │   ├── ...
│   └── Thread (N)        │   └── Thread (N)        │   └── Thread (N)
│
├── BLOCK (0, 1)          └── ...                   └── BLOCK (N, M)
│   └── ...
└── ...
```

### 硬件映射关系

- 一个 **Block** 映射到一个 **SM** (Streaming Multiprocessor) 上执行
- 一个 **Warp** 是 32 个线程的 SIMD 执行单元

---

## 关键内置变量

| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `threadIdx.x/y/z` | `uint3` | `[0, blockDim.xyz)` | 线程在 Block 内的索引 |
| `blockIdx.x/y/z` | `uint3` | `[0, gridDim.xyz)` | Block 在 Grid 内的索引 |
| `blockDim.x/y/z` | `dim3` | 用户定义 | 每个 Block 的线程数 |
| `gridDim.x/y/z` | `dim3` | 用户定义 | Grid 中的 Block 数 |
| `warpSize` | `int` | 32 | 每个 Warp 的线程数 |

### 全局线程 ID 计算

```cuda
// 1D Grid, 1D Block
int global_tid = blockIdx.x * blockDim.x + threadIdx.x;

// 2D Grid, 2D Block (图像处理常用)
int row = blockIdx.y * blockDim.y + threadIdx.y;
int col = blockIdx.x * blockDim.x + threadIdx.x;
int global_tid = row * width + col;
```

---

## SIMT 执行模型

**SIMT (Single Instruction, Multiple Threads)**：
- 一个 Warp 中的 32 个线程执行相同的指令
- 但每个线程有自己的寄存器状态和指令地址计数器
- 支持分支发散（divergence）但会损失性能

### 分支发散示例

```cuda
// 有分支发散
if (tid % 2 == 0) {
    data[tid] = data[tid] * 2;  // 偶数线程
} else {
    data[tid] = data[tid] + 1;  // 奇数线程
}

// 优化：避免分支发散
int isEven = (tid % 2 == 0);
data[tid] = isEven ? (data[tid] * 2) : (data[tid] + 1);
```

---

## 完整代码示例

### 向量加法（1D）

```cuda
__global__ void vectorAdd(const float *A, const float *B, float *C, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {  // 边界检查！
        C[i] = A[i] + B[i];
    }
}

// 启动配置
int threadsPerBlock = 256;
int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, n);
```

---

## 最佳实践

### Grid/Block 配置原则

| 原则 | 说明 | 推荐值 |
|------|------|--------|
| **Block 大小** | 应该是 Warp 大小(32)的倍数 | 128, 256, 512 |
| **每个 SM 的 Block 数** | 充分利用 SM | 至少 2-4 个 |
| **每个 SM 的 Warp 数** | 隐藏延迟需要足够 Warps | 至少 4-8 个 |
| **Occupancy** | 理论最大线程数利用率 | 目标 > 50% |

### 常见陷阱

1. **越界访问**：必须添加边界检查
2. **线程同步**：使用 `__syncthreads()` 协调 Shared Memory 访问
3. **分支发散**：避免 Warp 内线程走不同分支

---

## 参考资源

| 资源 | 链接 |
|------|------|
| CUDA Programming Guide | https://docs.nvidia.com/cuda/cuda-c-programming-guide/ |
| CUDA Best Practices | https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/ |

---

*归档于知识库: KNOWLEDGE_BASE/TOPICS/*
