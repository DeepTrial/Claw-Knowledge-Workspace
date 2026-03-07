---
id: KB-20260307-005
title: CUDA 内建变量与函数速查
category: cuda.builtin
level: 1
tags: [cuda, builtin, functions, variables, reference]
summary: "CUDA 内建变量（threadIdx, blockIdx 等）与常用内建函数速查表"
contributor: main
created: 2026-03-07
updated: 2026-03-07
status: done
---

# CUDA 内建变量与函数速查

## 内建变量

### 线程索引变量

| 变量 | 类型 | 说明 | 范围 |
|------|------|------|------|
| `threadIdx` | uint3 | Block 内 thread 索引 | 0 - (blockDim-1) |
| `blockIdx` | uint3 | Grid 内 block 索引 | 0 - (gridDim-1) |
| `blockDim` | dim3 | Block 维度 | 启动时指定 |
| `gridDim` | dim3 | Grid 维度 | 启动时指定 |
| `warpSize` | int | Warp 大小 | 32（通常）|

### 计算全局索引
```cpp
// 1D Grid, 1D Block
int idx = blockIdx.x * blockDim.x + threadIdx.x;

// 2D Grid, 2D Block
int idx_x = blockIdx.x * blockDim.x + threadIdx.x;
int idx_y = blockIdx.y * blockDim.y + threadIdx.y;
int idx = idx_y * gridDim.x * blockDim.x + idx_x;

// 通用宏
#define IDX ((blockIdx.x * blockDim.x) + threadIdx.x)
```

## 数学函数

### 快速近似函数（无保证精度）
```cpp
__device__ float __sinf(float x);    // 比 sinf() 快
__device__ float __cosf(float x);
__device__ float __expf(float x);
__device__ float __logf(float x);
__device__ float __powf(float x, float y);
```

### 标准数学函数
```cpp
// 三角函数
__device__ float sinf(float x);
__device__ float cosf(float x);
__device__ float tanf(float x);
__device__ float sincosf(float x, float* sptr, float* cptr);

// 指数对数
__device__ float expf(float x);
__device__ float logf(float x);
__device__ float log10f(float x);
__device__ float powf(float x, float y);

// 取整
__device__ float ceilf(float x);
__device__ float floorf(float x);
__device__ float roundf(float x);
__device__ float truncf(float x);

// 其他
__device__ float sqrtf(float x);
__device__ float rsqrtf(float x);  // 1/sqrt(x)
__device__ float fabsf(float x);
__device__ float fmodf(float x, float y);
```

## 位操作函数

```cpp
// 位计数
__device__ int __popc(unsigned int x);      // 1 的位数
__device__ int __popcll(unsigned long long x);

// 前导零
__device__ int __clz(unsigned int x);       // 前导零数
__device__ int __clzll(unsigned long long x);

// 字节反转
__device__ unsigned int __brev(unsigned int x);
__device__ unsigned long long __brevll(unsigned long long x);

// 位提取/插入
__device__ unsigned int __byte_perm(unsigned int x, unsigned int y, unsigned int s);
__device__ int __funnelshift_l(int low, int high, unsigned int shift);
__device__ int __funnelshift_r(int low, int high, unsigned int shift);
```

## 类型转换函数

```cpp
// 整数转浮点（带舍入模式）
__device__ float __int2float_rn(int x);  // 最近偶数
__device__ float __int2float_rz(int x);  // 向零
__device__ float __int2float_ru(int x);  // 向上
__device__ float __int2float_rd(int x);  // 向下

// 浮点转整数
__device__ int __float2int_rn(float x);
__device__ int __float2int_rz(float x);

// 半精度
__device__ half __float2half(float x);
__device__ float __half2float(half h);

// 类型重解释
__device__ float __int_as_float(int x);
__device__ int __float_as_int(float x);
```

## 地址空间谓词函数

```cpp
// 判断指针所在内存空间
__device__ unsigned int __isGlobal(const void* ptr);
__device__ unsigned int __isShared(const void* ptr);
__device__ unsigned int __isConstant(const void* ptr);
__device__ unsigned int __isLocal(const void* ptr);
__device__ unsigned int __isGridConstant(const void* ptr);
```

## 地址空间转换函数

```cpp
// 通用指针 ↔ 特定空间指针
__device__ size_t __cvta_generic_to_global(const void* ptr);
__device__ size_t __cvta_generic_to_shared(const void* ptr);
__device__ void* __cvta_global_to_generic(size_t ptr);
__device__ void* __cvta_shared_to_generic(size_t ptr);
```

## 时间函数

```cpp
// 高精度计时
__device__ long long clock();
__device__ long long clock64();

// 全局计时器（纳秒）
__device__ unsigned long long globaltimer();  // SM 7.0+
```

## 内存操作提示

```cpp
// 带 cache 提示的加载
__device__ float __ldg(const float* ptr);      // 通过只读 cache
__device__ float __ldcg(const float* ptr);     // 使用全局 cache
__device__ float __ldcs(const float* ptr);     // 流式加载
__device__ float __ldlu(const float* ptr);     // 最后使用

// 带 cache 提示的存储
__device__ void __stcg(float* ptr, float val); // 写入全局 cache
__device__ void __stcs(float* ptr, float val); // 流式存储
__device__ void __stwb(float* ptr, float val); // 写回
```

## 断言与陷阱

```cpp
// 断言（失败时终止 kernel）
__device__ void assert(int expression);

// 陷阱（无条件终止）
__device__ void trap();

// 断点（调试用）
__device__ void brkpt();
```

## 格式化输出（CUDA 11.0+）

```cpp
__global__ void kernel() {
    printf("Thread %d: value = %f\n", threadIdx.x, 3.14f);
}
```

**限制**：
- 输出缓冲区大小限制（默认 1MB）
- 仅 host 端可见
- 性能影响较大

## 常用宏定义

```cpp
// 获取 lane ID
#define LANE_ID() (threadIdx.x & 31)

// 获取 warp ID
#define WARP_ID() (threadIdx.x >> 5)

// 检查是否为 warp 第一个 lane
#define WARP_FIRST() (LANE_ID() == 0)

// 安全索引边界检查
#define IN_BOUNDS(idx, n) ((idx) < (n))

// 向上对齐
#define ALIGN_UP(x, align) (((x) + (align) - 1) & ~((align) - 1))
```

## 性能提示

| 函数类型 | 延迟（cycles）| 建议 |
|----------|---------------|------|
| 整数加法 | ~10 | 非常快 |
| 浮点乘法 | ~10-20 | 快 |
| 除法 | ~100-200 | 避免或预计算倒数 |
| `__sinf/__cosf` | ~20-30 | 近似计算，足够精确 |
| `sinf/cosf` | ~100-200 | 高精度，较慢 |

## 关联知识点

- [[KB-20260307-004]] - CUDA 同步与内存屏障函数
- [[KB-20260307-001]] - CUDA C++ Device Code 语法约束
