---
id: KB-20250308-018
title: CUDA流有序内存分配器
category: cuda.basics
level: 2
summary: "cudaMallocAsync/cudaFreeAsync流有序内存分配，内存池管理，多GPU和IPC支持"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, memory-allocator, stream-ordered, mempool, async]
status: done
---

# CUDA流有序内存分配器

## 简介

CUDA 11.2+引入的流有序内存分配器，比传统`cudaMalloc`性能更好。

## API基础

```cpp
// 流有序分配
cudaMallocAsync(&d_ptr, size, stream);
cudaFreeAsync(d_ptr, stream);

// 比cudaMalloc/cudaFree快
// 因为使用内存池避免系统调用
```

## 内存池管理

### 默认内存池

```cpp
cudaMemPool_t memPool;
cudaDeviceGetMemPool(&memPool, device);

// 配置内存池
uint64_t threshold = UINT64_MAX;  // 不释放回OS
cudaMemPoolSetAttribute(
    memPool, 
    cudaMemPoolAttrReleaseThreshold, 
    &threshold
);
```

### 显式内存池

```cpp
cudaMemPoolProps props = {};
props.allocType = cudaMemAllocationTypePinned;
props.location.type = cudaMemLocationTypeDevice;
props.location.id = device;

cudaMemPoolCreate(&memPool, &props);

// 使用指定内存池
cudaMallocFromPoolAsync(&d_ptr, size, memPool, stream);

cudaMemPoolDestroy(memPool);
```

## 内存复用策略

- `cudaMemPoolReuseFollowEventDependencies`
- `cudaMemPoolReuseAllowOpportunistic`
- `cudaMemPoolReuseAllowInternalDependencies`

## 资源统计

```cpp
cudaMemPoolGetAttribute(
    memPool, 
    cudaMemPoolAttrUsedMemCurrent, 
    &usedBytes
);
```

## 多GPU与IPC支持

- 多设备访问内存池
- 进程间共享内存池

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
