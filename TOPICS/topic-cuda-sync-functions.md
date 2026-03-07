---
id: KB-20260307-004
title: CUDA 同步与内存屏障函数
category: cuda.sync
level: 2
tags: [cuda, synchronization, barrier, fence, atomic]
summary: "CUDA 同步原语：syncthreads、内存屏障、原子操作与协作组"
contributor: main
created: 2026-03-07
updated: 2026-03-07
status: done
---

# CUDA 同步与内存屏障函数

## 同步层级

```
┌─────────────────────────────────────────────────────────────┐
│                      Grid 层级                               │
│  • cudaDeviceSynchronize() [Host 端]                         │
│  • Cooperative Groups: grid.sync()                           │
├─────────────────────────────────────────────────────────────┤
│                      Block 层级                              │
│  • __syncthreads()                                           │
│  • __syncthreads_and(), __syncthreads_or(), __syncthreads_count()│
│  • Cooperative Groups: block.sync()                          │
├─────────────────────────────────────────────────────────────┤
│                      Warp 层级                               │
│  • __syncwarp()                                              │
│  • __ballot_sync(), __all_sync(), __any_sync()              │
│  • __shfl_sync() 系列                                        │
├─────────────────────────────────────────────────────────────┤
│                      Thread 层级                             │
│  • __threadfence()                                           │
│  • __threadfence_block()                                     │
│  • __threadfence_system()                                    │
└─────────────────────────────────────────────────────────────┘
```

## 1. Block 同步：`__syncthreads()`

### 基本用法
```cpp
__global__ void kernel(float* data) {
    int idx = threadIdx.x;
    __shared__ float cache[256];
    
    // 阶段 1：写入共享内存
    cache[idx] = data[idx];
    __syncthreads();  // 等待所有 thread 完成
    
    // 阶段 2：读取其他 thread 的数据
    data[idx] = cache[255 - idx];
}
```

### 注意事项
- **必须条件执行**：所有 thread 都必须执行，否则死锁

```cpp
// ❌ 危险：可能死锁
if (threadIdx.x < 128) {
    __syncthreads();  // 只有部分 thread 执行
}

// ✅ 安全：所有 thread 都执行
__syncthreads();
if (threadIdx.x < 128) {
    // ...
}
```

### 变体函数
```cpp
// 带条件返回
int __syncthreads_and(int predicate);  // 所有 thread predicate 为真 → 返回非零
int __syncthreads_or(int predicate);   // 任一 thread predicate 为真 → 返回非零
int __syncthreads_count(int predicate);// 返回 predicate 为真的 thread 数
```

## 2. Warp 同步：`__syncwarp()`

### 基本用法（CUDA 9.0+）
```cpp
__global__ void kernel() {
    int lane = threadIdx.x & 31;
    
    // Warp 内同步
    __syncwarp();
    
    // 指定 mask 同步
    unsigned mask = 0xffffffff;  // 所有 32 个 lane
    __syncwarp(mask);
}
```

### Warp Vote 函数
```cpp
int lane = threadIdx.x % 32;
int val = (lane < 16) ? 1 : 0;

// 所有 lane 都为真？
int all_true = __all_sync(0xffffffff, val);

// 任一 lane 为真？
int any_true = __any_sync(0xffffffff, val);

// 返回 bitmask
unsigned ballot = __ballot_sync(0xffffffff, val);
// ballot = 0x0000ffff (低 16 位为 1)
```

### Warp Shuffle 函数
```cpp
int lane = threadIdx.x % 32;
int val = lane * 10;

// 广播：从 lane 0 获取值
int broadcast = __shfl_sync(0xffffffff, val, 0);

// 上移：从 lane+1 获取值
int up_val = __shfl_up_sync(0xffffffff, val, 1);

// 下移：从 lane-1 获取值
int down_val = __shfl_down_sync(0xffffffff, val, 1);

// 异或：从 lane^mask 获取值
int xor_val = __shfl_xor_sync(0xffffffff, val, 16);
```

**Shuffle 示例：Warp 内求和**
```cpp
__device__ int warp_sum(int val) {
    for (int offset = 16; offset > 0; offset /= 2) {
        val += __shfl_down_sync(0xffffffff, val, offset);
    }
    return val;  // 仅 lane 0 包含完整和
}
```

## 3. 内存屏障：`__threadfence()`

### 三种屏障
```cpp
// 1. Block 屏障：保证 block 内可见
__threadfence_block();

// 2. Device 屏障：保证整个 device 可见
__threadfence();

// 3. System 屏障：跨 device 和 host 可见
__threadfence_system();
```

### 典型用法：生产者-消费者
```cpp
__device__ int data = 0;
__device__ int flag = 0;

__global__ void producer() {
    data = 42;
    __threadfence();      // 保证 data 写入在 flag 之前
    flag = 1;
}

__global__ void consumer() {
    while (flag == 0);    // 等待 flag
    // 此时 data 必定可见
    printf("%d\n", data);
}
```

## 4. 原子操作

### 基本原子函数
```cpp
// 算术操作
int atomicAdd(int* addr, int val);
int atomicSub(int* addr, int val);
int atomicExch(int* addr, int val);
int atomicMin(int* addr, int val);
int atomicMax(int* addr, int val);
int atomicInc(int* addr, int val);
int atomicDec(int* addr, int val);

// 位操作
int atomicAnd(int* addr, int val);
int atomicOr(int* addr, int val);
int atomicXor(int* addr, int val);

// 比较交换
int atomicCAS(int* addr, int compare, int val);
```

### 示例：并行求和
```cpp
__global__ void reduce_atomic(int* input, int* sum, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        atomicAdd(sum, input[idx]);
    }
}
```

### 高效原子操作模式
```cpp
// ❌ 低效：每个 thread 原子操作
__global__ void bad(int* counter) {
    atomicAdd(counter, 1);  // 争用严重
}

// ✅ 高效：warp 聚合 + block 聚合
__global__ void good(int* counter) {
    // Warp 聚合
    int warp_sum = /* warp 内 reduce */;
    if (lane_id() == 0) {
        atomicAdd(counter, warp_sum);  // 争用减少 32 倍
    }
}
```

## 5. Cooperative Groups（CUDA 9.0+）

### 线程组抽象
```cpp
#include <cooperative_groups.h>
namespace cg = cooperative_groups;

__global__ void kernel() {
    // 获取不同层级的组
    cg::thread_block block = cg::this_thread_block();
    cg::thread_block_tile<32> warp = cg::tiled_partition<32>(block);
    cg::grid_group grid = cg::this_grid();
    
    // 组内同步
    block.sync();  // 等同于 __syncthreads()
    warp.sync();   // 等同于 __syncwarp()
    grid.sync();   // Grid 级同步（需要特殊启动方式）
}
```

### Grid 同步启动
```cpp
int main() {
    int threads = 256;
    int blocks = 1024;
    
    // 计算 shared memory 需求
    size_t shared_mem = /* ... */;
    
    // 必须使用 cudaLaunchCooperativeKernel
    void* args[] = { /* ... */ };
    cudaLaunchCooperativeKernel(
        (void*)kernel,
        blocks, threads,
        args,
        shared_mem,
        0  // stream
    );
}
```

## 性能建议

| 操作 | 开销（cycles）| 建议 |
|------|---------------|------|
| `__syncthreads()` | ~100-200 | 最小化使用次数 |
| `__syncwarp()` | ~20-30 | Warp 内同步首选 |
| `atomicAdd` | ~100-1000+ | 减少 block 间争用 |
| `__threadfence()` | ~100+ | 仅必要时使用 |

## 关联知识点

- [[KB-20260307-003]] - CUDA 内存空间限定符详解
- [[KB-20260307-001]] - CUDA C++ Device Code 语法约束
