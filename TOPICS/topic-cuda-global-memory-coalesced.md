---
id: KB-20250307-007B
title: CUDA 全局内存与合并访问优化
contributor: DeepTrial
created: 2026-03-07
updated: 2026-03-07
tags: [cuda, global-memory, coalesced-access, shared-memory, optimization]
status: done
---

# CUDA 全局内存与合并访问优化

> **学习天数**: Day 007 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-07

---

## 核心概念

全局内存是 GPU 上容量最大但速度最慢的内存类型。优化全局内存访问是 CUDA 性能调优的关键。

---

## 合并访问（Coalesced Access）

**定义**: 当一个 warp（32 线程）访问连续的内存地址时，GPU 可以将这些访问合并为最少次数的事务。

**性能对比**:
- **合并访问**: 232 微秒
- **非合并访问**: 540 微秒（慢 2 倍以上）

---

## 代码示例

```cuda
// ✅ 合并访问 - 连续线程访问连续地址
__global__ void coalesced_kernel(float *data) {
    int id = threadIdx.x + blockIdx.x * blockDim.x;
    data[id] *= 2.0f;
}

// ❌ 非合并访问 - 步长访问
__global__ void stride_kernel(float *data, int stride) {
    int xid = (blockIdx.x * blockDim.x + threadIdx.x) * stride;
    data[xid] = data[xid];  // 步长为 2 时，50% 带宽浪费
}
```

---

## 使用 Shared Memory 优化

```cuda
__global__ void coalescedMultiply(float *a, float *c, int M) {
    __shared__ float aTile[TILE_DIM][TILE_DIM];
    __shared__ float transposedTile[TILE_DIM][TILE_DIM + 1]; // +1 避免 bank conflict
    
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    
    // 合并读取到 shared memory
    aTile[threadIdx.y][threadIdx.x] = a[row * TILE_DIM + threadIdx.x];
    
    __syncthreads();
    
    // 计算...
}
```

---

## 性能优化策略

1. **最大化并行执行**
2. **优化内存使用** - 最大化内存带宽
3. **优化指令使用** - 最大化指令吞吐量

---

*归档时间: 2026-03-07*
