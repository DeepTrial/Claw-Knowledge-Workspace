---
id: KB-20250308-015
title: CUDA性能优化指南
category: cuda.optimization
level: 2
summary: "三大优化方向：最大化利用率、最大化内存吞吐量、最大化指令吞吐量"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, optimization, performance, memory, throughput, occupancy]
status: done
---

# CUDA性能优化指南

## 三大优化方向

1. **最大化利用率** - 保持GPU忙碌
2. **最大化内存吞吐量** - 减少内存瓶颈
3. **最大化指令吞吐量** - 减少计算瓶颈

## 最大化利用率

### 应用级别
- 足够的并行度
- 异步执行
- 重叠计算和传输

### 设备级别
- 同时运行多个Kernel
- 使用多个Stream

### SM级别

```cpp
// 使用launch bounds限制
__launch_bounds__(256, 4)  // 256线程, 至少4 blocks/SM
__global__ void kernel() { }
```

## 最大化内存吞吐量

### Host-Device传输优化
- 使用Pinned Memory
- 异步传输
- 使用CUDA Graphs

### 设备内存访问优化

**合并访问模式** ✅
```cpp
// 好：连续线程访问连续地址
out[idx] = in[idx];
```

**分散访问** ❌
```cpp
// 坏：分散访问
out[idx * stride] = in[idx * stride];
```

**使用Shared Memory**
```cpp
__shared__ float smem[256];
smem[tid] = in[idx];
__syncthreads();
out[idx] = smem[tid] * 2;
```

## 最大化指令吞吐量

- 避免分支发散
- 使用快速数学函数
- 循环展开

```cpp
// 避免分支
float result = fmaxf(val, 0.0f);  // ReLU

// 而不是if-else
```

## 避免内存抖动

- 合理设置缓存策略
- 使用L2持久化访问
- 控制内存分配粒度

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
