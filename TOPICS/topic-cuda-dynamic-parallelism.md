---
id: KB-20250308-023
title: CUDA动态并行CDP
category: cuda.basics
level: 2
summary: "设备端启动Kernel，递归和嵌套并行，CDP2改进，内存模型和同步"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, cdp, dynamic-parallelism, device-launch, nested]
status: done
---

# CUDA动态并行CDP

## 简介

设备端代码启动Kernel，支持递归和嵌套并行。

## 执行环境和内存模型

### 父子网格
- 父网格：启动者
- 子网格：被启动的Kernel

### 同步
```cpp
cudaDeviceSynchronize();  // 等待所有子网格完成
```

### 内存一致性
- 父网格的global内存修改对子网格可见
- 子网格完成后，修改对父网格可见

## 设备端Kernel启动

```cpp
#include <cuda_device_runtime_api.h>

__global__ void childKernel(int* data) {
    data[threadIdx.x] = threadIdx.x;
}

__global__ void parentKernel(int* data) {
    childKernel<<<1, 256>>>(data);
    cudaDeviceSynchronize();
}
```

## Stream和Event

```cpp
__global__ void withStream() {
    cudaStream_t s;
    cudaStreamCreateWithFlags(&s, cudaStreamNonBlocking);
    
    kernel<<<grid, block, 0, s>>>();
    
    cudaEvent_t e;
    cudaEventCreate(&e);
    cudaEventRecord(e, s);
    cudaStreamWaitEvent(0, e, 0);
    
    cudaEventDestroy(e);
    cudaStreamDestroy(s);
}
```

## CDP2 vs CDP1

CDP2 (CUDA 11.6+)改进：
- 更深的嵌套深度 (256 vs 24)
- 更低的启动开销
- 更好的内存管理

## 编程指南

- 最大嵌套深度256
- 子网格启动是异步的
- 启动有开销，批量启动减少开销
- 需要额外的设备内存

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
