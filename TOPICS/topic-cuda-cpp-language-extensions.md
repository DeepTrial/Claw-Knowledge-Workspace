---
id: KB-20260307-006
title: CUDA C++ 语言扩展完整框架
category: cuda.syntax
level: 1
tags: [cuda, cpp, language-extensions, nvcc, reference]
summary: "基于 NVIDIA 官方文档的 CUDA C++ 语言扩展完整框架，涵盖函数/变量限定符、内建类型、同步原语等"
contributor: main
created: 2026-03-07
updated: 2026-03-07
status: done
references:
  - https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#c-language-support
---

# CUDA C++ 语言扩展完整框架

> 基于 NVIDIA CUDA C++ Programming Guide 第 10 章 C++ Language Extensions

## 一、框架总览

```
CUDA C++ Language Extensions
├── 10.1  函数执行空间限定符
├── 10.2  变量内存空间限定符
├── 10.3  内建向量类型
├── 10.4  内建变量
├── 10.5  内存屏障函数
├── 10.6  同步函数
├── 10.7  数学函数
├── 10.8  纹理函数
├── 10.9  表面函数
├── 10.10-10.12 带缓存提示的加载/存储
├── 10.13 时间函数
├── 10.14 原子函数
├── 10.15 地址空间谓词函数
├── 10.16 地址空间转换函数
├── 10.17 Alloca 函数
├── 10.18 编译器优化提示函数
├── 10.19-10.22 Warp 操作函数
├── 10.23 Nanosleep 函数
├── 10.24 Warp 矩阵函数 (WMMA)
├── 10.25 DPX 指令
├── 10.26-10.28 异步屏障与数据拷贝
├── 10.29-10.30 TMA 与 Tensor Map
├── 10.31-10.35 调试与输出
├── 10.36 动态全局内存分配
├── 10.37-10.40 执行配置与优化
├── 10.41 SIMD 视频指令
├── 10.42-10.43 Pragma 指令
└── 10.44-10.45 内存/执行模型
```

---

## 二、函数执行空间限定符 (10.1)

### 限定符列表

| 限定符 | 执行位置 | 可调用者 | 返回值 | 备注 |
|--------|----------|----------|--------|------|
| `__global__` | Device | Host, Device (SM 3.5+) | void | Kernel 入口 |
| `__device__` | Device | Device | 任意 | Device 函数 |
| `__host__` | Host | Host | 任意 | Host 函数（默认）|

### 组合规则

```cpp
// ✅ 允许：同时编译 host 和 device 版本
__host__ __device__ void func() { }

// ❌ 禁止：__global__ 不能与其他组合
// __global__ __device__ void kernel();  // 编译错误
```

### 内联控制

```cpp
__noinline__      // 禁止内联
__forceinline__   // 强制内联
__inline_hint__   // 建议内联（编译器可忽略）
```

---

## 三、变量内存空间限定符 (10.2)

| 限定符 | 内存位置 | 生命周期 | 可见性 | 容量 |
|--------|----------|----------|--------|------|
| `__device__` | 全局内存 | 程序全程 | 所有 grid | GB 级 |
| `__constant__` | 常量内存 | 程序全程 | 所有 grid | 64KB |
| `__shared__` | 共享内存 | Block | Block 内 | 48KB+/SM |
| `__grid_constant__` | 常量缓存 | Kernel | Kernel 内 | 参数 |
| `__managed__` | 统一内存 | 程序全程 | Host+Device | GB 级 |
| `__restrict__` | 指针提示 | - | - | 优化提示 |

---

## 四、内建向量类型 (10.3)

### 基本向量类型

```cpp
// 1/2/4 分量向量
char1, char2, char4
short1, short2, short4
int1, int2, int4
long1, long2, long4
longlong1, longlong2, longlong4

float1, float2, float4
double1, double2

// 访问分量
int4 v = make_int4(1, 2, 3, 4);
v.x, v.y, v.z, v.w  // 分量访问
```

### dim3 类型

```cpp
dim3 gridDim(16, 16, 1);   // Grid 维度
dim3 blockDim(256, 1, 1);  // Block 维度
kernel<<<gridDim, blockDim>>>();
```

---

## 五、内建变量 (10.4)

| 变量 | 类型 | 说明 |
|------|------|------|
| `gridDim` | dim3 | Grid 维度 |
| `blockIdx` | uint3 | Block 在 Grid 中的索引 |
| `blockDim` | dim3 | Block 维度 |
| `threadIdx` | uint3 | Thread 在 Block 中的索引 |
| `warpSize` | int | Warp 大小（通常为 32）|

### 全局索引计算

```cpp
// 1D
int idx = blockIdx.x * blockDim.x + threadIdx.x;

// 2D
int x = blockIdx.x * blockDim.x + threadIdx.x;
int y = blockIdx.y * blockDim.y + threadIdx.y;
int idx = y * gridDim.x * blockDim.x + x;

// 3D
int z = blockIdx.z * blockDim.z + threadIdx.z;
int idx = z * gridDim.x * blockDim.x * gridDim.y * blockDim.y 
        + y * gridDim.x * blockDim.x + x;
```

---

## 六、同步与内存屏障 (10.5-10.6)

### 内存屏障函数

```cpp
void __threadfence_block();  // Block 内可见
void __threadfence();        // Device 内可见
void __threadfence_system(); // System 内可见（跨 GPU）
```

### 同步函数

```cpp
void __syncthreads();                        // Block 同步
int __syncthreads_and(int predicate);        // 条件 AND
int __syncthreads_or(int predicate);         // 条件 OR
int __syncthreads_count(int predicate);      // 计数
void __syncwarp(unsigned mask = 0xffffffff); // Warp 同步
```

---

## 七、Warp 操作函数 (10.19-10.22)

### Vote 函数

```cpp
int __all_sync(unsigned mask, int predicate);
int __any_sync(unsigned mask, int predicate);
unsigned __ballot_sync(unsigned mask, int predicate);
```

### Shuffle 函数

```cpp
T __shfl_sync(unsigned mask, T var, int srcLane);
T __shfl_up_sync(unsigned mask, T var, unsigned delta);
T __shfl_down_sync(unsigned mask, T var, unsigned delta);
T __shfl_xor_sync(unsigned mask, T var, int laneMask);
```

### Match/Reduce 函数

```cpp
unsigned __match_any_sync(unsigned mask, T value);
unsigned __match_all_sync(unsigned mask, T value, int *pred);
T __reduce_sync(unsigned mask, T value, ReduceOp op);
```

---

## 八、原子函数 (10.14)

### 算术原子操作

```cpp
int atomicAdd(int* address, int val);
int atomicSub(int* address, int val);
int atomicExch(int* address, int val);
int atomicMin(int* address, int val);
int atomicMax(int* address, int val);
int atomicInc(int* address, int val);
int atomicDec(int* address, int val);
int atomicCAS(int* address, int compare, int val);
```

### 位运算原子操作

```cpp
int atomicAnd(int* address, int val);
int atomicOr(int* address, int val);
int atomicXor(int* address, int val);
```

---

## 九、执行配置 (10.37-10.40)

### 启动边界

```cpp
__global__ void __launch_bounds__(MAX_THREADS_PER_BLOCK, MIN_BLOCKS_PER_SM)
kernel() { }

// 示例
__global__ void __launch_bounds__(256, 2)
kernel(float* data) { }
```

### 执行配置语法

```cpp
kernel<<<gridDim, blockDim, sharedMem, stream>>>(args);
kernel<<<gridDim, blockDim>>>(args);  // 简化形式
```

### #pragma unroll

```cpp
#pragma unroll 4
for (int i = 0; i < 16; i++) {
    // 完全展开 4 次迭代
}

#pragma unroll
for (int i = 0; i < 4; i++) {
    // 完全展开
}

#pragma unroll 1
for (int i = 0; i < N; i++) {
    // 禁止展开
}
```

---

## 十、高级特性索引

| 特性 | 章节 | 计算能力 | 说明 |
|------|------|----------|------|
| Warp Matrix Functions | 10.24 | 7.0+ | Tensor Core 操作 |
| DPX | 10.25 | 9.0+ | 精度加速指令 |
| Asynchronous Barrier | 10.26 | 9.0+ | 异步同步原语 |
| memcpy_async | 10.27 | 8.0+ | 异步内存拷贝 |
| TMA | 10.29 | 9.0+ | Tensor Memory Accelerator |
| Dynamic Parallelism | 10.36 | 3.5+ | Device 端 kernel 启动 |
| Cooperative Groups | 11 | 9.0+ | 线程组抽象 |

---

## 十一、知识点关联

| 知识点 ID | 主题 |
|-----------|------|
| KB-20260307-001 | CUDA C++ Device Code 语法约束 |
| KB-20260307-002 | NVCC 编译流程与分离编译 |
| KB-20260307-003 | CUDA 内存空间限定符详解 |
| KB-20260307-004 | CUDA 同步与内存屏障函数 |
| KB-20260307-005 | CUDA 内建变量与函数速查 |

---

## 参考

- NVIDIA CUDA C++ Programming Guide: https://docs.nvidia.com/cuda/cuda-c-programming-guide/
- CUDA Compiler Driver NVCC: https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/
