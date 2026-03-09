---
id: KB-20250308-020
title: CUDA C++语言扩展
category: cuda.basics
level: 1
summary: "CUDA C++扩展：执行空间限定符、内存空间限定符、内置向量类型、内建变量、内存和同步函数"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, cpp, language-extension, specifier, builtin]
status: done
---

# CUDA C++语言扩展

## 函数执行空间限定符

```cpp
__global__ void kernel() { }   // Host调用，Device执行
__device__ float func() { }    // Device调用，Device执行
__host__ void hostFunc() { }   // Host调用，Host执行
__host__ __device__ void both() { }  // 两者都可用
```

## 变量内存空间限定符

```cpp
__device__ float devArray[256];     // 全局设备内存
__constant__ float constArray[256]; // 常量内存
__shared__ float sharedArray[256];  // 共享内存
__managed__ float managedVar;       // 统一内存
__grid_constant__ MyStruct params;  // 网格常量(Ampere+)
```

## 内置向量类型

```cpp
char4, short2, int4, uint3
float2, float4, double2
dim3  // 用于内核启动
```

## 内建变量

```cpp
gridDim, blockIdx, blockDim, threadIdx, warpSize
```

## 内存和同步函数

```cpp
__syncthreads();
__threadfence();
cuda::barrier
```

## 纹理/表面函数

```cpp
tex1D(), tex2D(), tex3D()
surf2Dread(), surf2Dwrite()
```

## 地址空间函数

```cpp
__isGlobal(), __isShared(), __isConstant(), __isLocal()
__cvta_generic_to_global()
```

## 高级特性

- Warp函数
- WMMA(Tensor Core)
- 异步拷贝
- TMA

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
