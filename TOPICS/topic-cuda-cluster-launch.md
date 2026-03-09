---
id: KB-20250308-022
title: CUDA Cluster Launch Control
category: cuda.basics
level: 2
summary: "Hopper+动态Block调度，Thread Block取消机制，cudaLaunchKernelEx API"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, cluster, hopper, launch-control, block-cancellation]
status: done
---

# CUDA Cluster Launch Control

## 简介

Hopper+架构支持动态Block调度。

## Thread Block取消

```cpp
__global__ void kernel() {
    int idx = blockIdx.x;
    
    // 动态取消Block
    if (idx >= validBlocks) {
        cg::this_grid().cancel();
        return;
    }
    
    // 正常计算
}
```

## 启动示例

```cpp
cudaLaunchConfig_t config = {};
config.gridDim = dim3(100);
config.blockDim = dim3(256);

cudaLaunchAttribute attr = {};
attr.id = cudaLaunchAttributeClusterDimension;
attr.val.clusterDim = {2, 2, 1};

config.numAttrs = 1;
config.attrs = &attr;

cudaLaunchKernelEx(&config, kernel, args);
```

## 约束条件

- 只能在Kernel开始时取消
- 取消后Block不再执行
- 需要Hopper+架构

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
