---
id: KB-20250309-003
title: CuTe 核心抽象详解
category: cuda.optimization
level: 3
summary: "CuTe库的核心概念：Shape多维形状、Layout内存布局映射、Tensor数据封装，以及布局代数Composition和Tiled Division"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cute, cutlass, cuda, layout, tensor, shape, abstraction]
status: done
---

# CuTe 核心抽象详解

CuTe (CUDA Template Extension) 是 CUTLASS 3.x 引入的核心抽象层，用声明式编程替代手动偏移计算。

## 为什么需要 CuTe？

传统 CUDA 编程中，我们手动计算偏移量：
```cpp
// 传统方式: 容易出错，难以泛化
int offset = (blockIdx.y * TILE_M + threadIdx.y) * ldA + 
             (blockIdx.x * TILE_N + threadIdx.x);
float val = A[offset];
```

CuTe 提供**声明式**的布局抽象：
```cpp
// CuTe 方式: 描述意图，而非计算细节
auto layout = make_layout(make_shape(M, N), make_stride(N, 1));
Tensor A = make_tensor(data, layout);
float val = A(m, n);  // 编译期确定偏移计算
```

---

## 核心概念 1: Shape

Shape 描述多维尺寸，是**编译期常量**（也可用动态值）：

```cpp
#include <cute/layout.hpp>
using namespace cute;

// 静态 Shape（编译期确定）
auto s1 = make_shape(Int<64>{}, Int<128>{});  // (64, 128)
auto s2 = make_shape(64, 128);                 // 动态 Shape
auto s3 = make_shape(Int<8>{}, Int<8>{}, Int<4>{});  // 3D

// Shape 操作
auto s4 = flatten(s1);           // 展平: (8192,)
auto s5 = append(s1, Int<8>{});  // 追加维度: (64, 128, 8)
auto s6 = prepend(Int<2>{}, s1); // 前置维度: (2, 64, 128)
```

### Shape 的核心性质

```cpp
// rank: 维度数
static_assert(rank(s1) == 2);

// size: 总元素数
static_assert(size(s1) == 64 * 128);

// get<I>(shape): 获取第 I 维
static_assert(get<0>(s1) == 64);
```

---

## 核心概念 2: Layout

Layout = Shape + Stride，定义**逻辑坐标到物理偏移的映射**。

```cpp
// 列优先布局 (Column Major)
auto layout_col = make_layout(
    make_shape(Int<64>{}, Int<128>{}),    // Shape: (M, N)
    make_stride(Int<1>{}, Int<64>{})      // Stride: (1, M)
);
// 偏移 = m * 1 + n * 64

// 行优先布局 (Row Major)
auto layout_row = make_layout(
    make_shape(Int<64>{}, Int<128>{}),    // Shape: (M, N)
    make_stride(Int<128>{}, Int<1>{})     // Stride: (N, 1)
);
// 偏移 = m * 128 + n * 1
```

### 理解 Layout 的本质

```cpp
// 手动计算偏移
int offset = layout(m, n);

// Layout 是函数对象
static_assert(layout_col(10, 20) == 10 + 20 * 64);  // 1290
static_assert(layout_row(10, 20) == 10 * 128 + 20); // 1300
```

### 特殊 Layout 类型

```cpp
// 紧凑布局 (Compact)
auto layout_compact = make_layout(make_shape(4, 8));
// 默认行优先，stride 自动计算为 (8, 1)

// 转置布局
auto layout_t = transposed(layout_row);
// Shape: (128, 64), Stride: (1, 128)

// 分块布局 (Tiled)
auto tiled_layout = tiled_divide(layout, make_tile(Int<32>{}, Int<32>{}));
// 将大矩阵划分为 32x32 的 tiles
```

---

## 核心概念 3: Tensor

Tensor = 数据指针 + Layout，是 CuTe 的核心数据结构。

```cpp
#include <cute/tensor.hpp>

float* data = ...;  // 假设指向 64x128 矩阵
auto layout = make_layout(make_shape(64, 128), 
                          make_stride(128, 1));  // 行优先

// 创建 Tensor
Tensor A = make_tensor(data, layout);

// 访问元素
float val = A(10, 20);  // 访问逻辑坐标 (10, 20)

// 获取形状和布局
auto shape = A.shape();
auto layout = A.layout();
```

### Tensor 的切片与视图

```cpp
// 局部切片 (Local Tile)
auto tile = local_tile(A, make_tile(Int<32>{}, Int<32>{}), 
                       make_coord(1, 2));  // 第(1,2)个32x32 tile

// 扁平化视图
auto flat = flatten(A);
// Shape: (8192,), 连续访问

// 分区 (Partition) - 按线程分发
auto tA = make_tensor(make_smem_ptr(smem), make_shape(Int<32>{}, Int<32>{}));
auto thr_layout = make_layout(make_shape(Int<8>{}, Int<4>{}));  // 32 threads
auto partitioned = partition(tA, thr_layout, threadIdx.x);
// 每个线程获得其负责的数据子集
```

---

## 布局代数 (Layout Algebra)

CuTe 的强大之处在于可以对 Layout 进行**代数运算**。

### 1. 组合 (Composition)

```cpp
auto outer = make_layout(make_shape(4, 8), make_stride(8, 1));    // (4, 8) -> 32
auto inner = make_layout(make_shape(2, 4), make_stride(4, 1));    // (2, 4) -> 8

auto composed = composition(outer, inner);
// 结果 Shape: (2, 4, 8)
// 描述 32 个元素如何被 (2,4) 模式重复 8 次
```

### 2. 除法 (Division)

```cpp
auto layout = make_layout(make_shape(64, 128));
auto tile = make_tile(Int<32>{}, Int<32>{});

auto divided = tiled_divide(layout, tile);
// 结果: ((2, 4), (32, 32))
// 表示 64x128 矩阵被划分为 2x4 个 32x32 tiles
```

### 3. 拼接与交错

```cpp
// 拼接两个 layout
auto concat_layout = make_layout(make_shape(4, 8), 
                                  LayoutLeft{});  // 列优先

// 交错布局 (用于 bank conflict 避免)
auto swizzled = swizzle<2, 0, 2>(layout);  // 2-bit swizzle
```

---

## 实践示例: 理解 Shared Memory 布局

```cpp
// 目标: 在 Shared Memory 中存储 64x64 float 矩阵
// 要求: 避免 bank conflict，支持向量加载

constexpr int SMEM_M = 64;
constexpr int SMEM_N = 64;

// 基础布局
auto smem_layout = make_layout(make_shape(Int<SMEM_M>{}, Int<SMEM_N>{}), 
                               make_stride(Int<SMEM_N>{}, Int<1>{}));

// 问题: 如果每个线程加载 4 个 float (128-bit)，如何避免 bank conflict？
// 方案: Swizzle 布局

// 32 banks * 4 bytes = 128 bytes per row
// 需要让同一行的连续 128-bit 访问分布在不同 bank

auto swizzled_layout = composition(
    smem_layout,
    make_layout(make_shape(Int<4>{}, Int<16>{}),  // 4 rows x 16 floats per swizzle
                make_stride(Int<16>{}, Int<1>{}))
);

// 更简洁的方式: 使用内置 swizzle
auto swizzled = Swizzle<2, 0, 4>{};  // 2-bit XOR swizzle
```

---

## 关键概念总结

| 概念 | 作用 | 典型用法 |
|------|------|----------|
| Shape | 描述多维尺寸 | `make_shape(M, N, K)` |
| Layout | 映射逻辑坐标到物理偏移 | `make_layout(shape, stride)` |
| Tensor | 数据 + 布局的封装 | `make_tensor(ptr, layout)` |
| Composition | 布局组合 | `composition(outer, inner)` |
| Tiled Division | 分块划分 | `tiled_divide(layout, tile)` |
| Partition | 按线程分发 | `partition(tensor, thr_layout, tid)` |

---

## 参考

- [[KB-20250309-001]] CUTLASS CuTe 系统性学习计划
- [[KB-20250309-002]] CUDA Tile 基础概念
- [[KB-20250309-004]] CUTLASS 架构设计
