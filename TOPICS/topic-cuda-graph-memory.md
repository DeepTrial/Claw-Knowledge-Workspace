---
id: KB-20250308-019
title: CUDA Graph内存节点
category: cuda.basics
level: 2
summary: "CUDA Graph中管理内存生命周期，支持内存分配/释放节点、自动释放、内存复用优化"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, graph, memory-node, cuda-graph, memory-management]
status: done
---

# CUDA Graph内存节点

## 简介

CUDA Graph支持内存分配节点，在Graph中管理内存生命周期。

需要CUDA 11.4+。

## API基础

### Graph节点API

```cpp
cudaGraphAddMemAllocNode(&allocNode, graph, 
    dependencies, numDependencies, &allocParams);

cudaGraphAddMemFreeNode(&freeNode, graph,
    dependencies, numDependencies, d_ptr);
```

### Stream Capture

```cpp
cudaStreamBeginCapture(stream);

void* d_ptr = cudaMallocAsync(size, stream);
// 使用d_ptr...
cudaFreeAsync(d_ptr, stream);

cudaStreamEndCapture(stream, &graph);
```

### 自动释放

```cpp
// 启动时自动释放内存
cudaGraphInstantiateWithFlags(
    &graphExec, graph,
    cudaGraphInstantiateFlagAutoFreeOnLaunch
);
```

## 内存复用优化

### 地址复用
Graph内内存地址复用。

### 物理内存管理
物理内存共享和复用。

## 性能考虑

- 首次启动需要上传
- 后续启动更快

## 多GPU支持

- 物理内存占用控制
- Peer访问支持
- 子图支持内存节点

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
