---
id: KB-20250308-013
title: CUDA编程接口详解
category: cuda.basics
level: 2
summary: "NVCC编译流程、CUDA Runtime API、设备内存管理、Stream和Event、CUDA Graphs"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, nvcc, runtime, api, memory, stream, graph]
status: done
---

# CUDA编程接口详解

## NVCC编译流程

```
CUDA Source (.cu)
       |
       v
[NVCC Frontend] --> 分离Host和Device代码
       |
       +--> Host Code --> [Host Compiler] --> Host Binary
       |
       +--> Device Code --> [NVCC] --> PTX / CUBIN
```

### 编译模式

```bash
# 离线编译 (生成特定架构二进制)
nvcc -arch=sm_80 kernel.cu -o program

# JIT编译 (生成PTX，运行时编译)
nvcc -arch=compute_80 -code=compute_80 kernel.cu
```

## CUDA Runtime核心API

### 设备内存管理

```cpp
cudaMalloc(&d_ptr, size);     // 分配设备内存
cudaFree(d_ptr);              // 释放
cudaMemcpy(dst, src, size, cudaMemcpyHostToDevice);  // 拷贝
```

### Page-Locked Host内存

```cpp
cudaMallocHost(&h_ptr, size);  // Pinned memory，加速H2D传输
cudaFreeHost(h_ptr);
```

### Stream和异步执行

```cpp
cudaStream_t stream;
cudaStreamCreate(&stream);

// 异步操作
kernel<<<grid, block, 0, stream>>>(args);
cudaMemcpyAsync(dst, src, size, H2D, stream);

cudaStreamSynchronize(stream);
cudaStreamDestroy(stream);
```

### CUDA Graphs

```cpp
cudaGraph_t graph;
cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);
// 记录操作
kernel<<<grid, block, 0, stream>>>(args);
cudaStreamEndCapture(stream, &graph);

// 实例化并执行
cudaGraphExec_t graphExec;
cudaGraphInstantiate(&graphExec, graph, NULL, NULL, 0);
cudaGraphLaunch(graphExec, stream);
```

## 计算模式

- **Default**: 多进程共享GPU
- **Exclusive Process**: 单进程独占
- **Prohibited**: 禁止计算模式

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
