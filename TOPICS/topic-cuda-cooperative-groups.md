---
id: KB-20250308-016
title: CUDA Cooperative Groups协作组
category: cuda.basics
level: 2
summary: "灵活的线程分组和同步机制，支持隐式/显式分组、组分割、集合操作和网格同步"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, cooperative-groups, sync, thread-group, collective]
status: done
---

# CUDA Cooperative Groups协作组

## 简介

Cooperative Groups提供灵活的线程分组和同步机制。

```cpp
#include <cooperative_groups.h>
namespace cg = cooperative_groups;
```

## 隐式分组

```cpp
cg::thread_block tb = cg::this_thread_block();
cg::cluster_group cluster = cg::this_cluster();
cg::grid_group grid = cg::this_grid();
```

## 显式分组

```cpp
// Warp级分组
cg::thread_block_tile<32> warp = cg::tiled_partition<32>(tb);

// 活跃线程分组
cg::coalesced_group active = cg::coalesced_threads();
```

## 组分割

```cpp
auto tile = cg::tiled_partition(tb, 16);
auto labeled = cg::labeled_partition(tb, label);
auto binary = cg::binary_partition(tb, predicate);
```

## 集合操作

### 同步
```cpp
tb.sync();
cg::sync(grid);
```

### 数据传输
```cpp
cg::memcpy_async(tb, dst, src, size);
cg::wait(tb);
```

### 数据操作
```cpp
int sum = cg::reduce(tb, val, cg::plus<int>());
int prefix = cg::inclusive_scan(tb, val, cg::plus<int>());
```

## 网格同步

```cpp
__global__ void kernel() {
    cg::grid_group grid = cg::this_grid();
    grid.sync();
}

// 需要协作启动
cudaLaunchCooperativeKernel(...);
```

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
