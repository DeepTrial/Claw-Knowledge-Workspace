---
id: KB-20250309-004
title: CUTLASS 架构设计详解
category: cuda.optimization
level: 3
summary: "CUTLASS分层架构：Kernel层全局协调、Block层CTA管理、Warp级MMA抽象、Thread级寄存器操作，以及TileIterator和Epilogue设计"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cutlass, cuda, gemm, architecture, tensor-core, mma, epilogue]
status: done
---

# CUTLASS 架构设计详解

## CUTLASS 的设计哲学

CUTLASS 遵循**分层抽象**原则，每一层只关心当前层的问题：

```
┌─────────────────────────────────────────────────────────────┐
│  Kernel Level (Grid)                                        │
│  - 全局分块 (Tiling)                                         │
│  - 多阶段流水线 (Multi-stage Pipeline)                        │
│  - Grid 同步                                                 │
├─────────────────────────────────────────────────────────────┤
│  Block Level (CTA)                                          │
│  - Shared Memory 管理                                        │
│  - Warp 调度                                                 │
│  - 消费者-生产者同步                                         │
├─────────────────────────────────────────────────────────────┤
│  Warp Level                                                 │
│  - Tensor Core MMA 调用                                      │
│  - Warp 级数据分块                                           │
│  - 寄存器文件布局                                            │
├─────────────────────────────────────────────────────────────┤
│  Thread Level                                               │
│  - 寄存器操作                                                │
│  - 数据移动 (Global -> Shared -> Register)                  │
│  - 指令级并行                                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Gemm 问题的层次划分

### 问题定义

```cpp
C = alpha * A * B + beta * C
// A: M x K
// B: K x N  
// C: M x N
```

### 分层策略

```cpp
// 全局划分 (Device Level)
M: [M0, M1, M2]  // 每个 CTA 处理 M1
N: [N0, N1, N2]  // 每个 CTA 处理 N1
K: [K0, K1, K2]  // K 维度循环，每个 tile 处理 K1

// CTA 内划分 (Block Level)
M1: [M2, M3, M4]  // Warp 级分块
N1: [N2, N3, N4]

// Warp 内划分 (Warp Level)
M3: 每个线程的寄存器分块
N3: 每个线程的寄存器分块
```

### CUTLASS 术语对照

| 术语 | 含义 | 典型值 |
|------|------|--------|
| Tile Shape | CTA 处理的 MNK 块 | 128x128x8, 256x128x32 |
| Warp Shape | Warp 处理的 MNK 块 | 64x64x8, 32x32x32 |
| Instruction Shape | Tensor Core 指令粒度 | 16x8x8 (FP16), 8x8x4 (FP64) |
| Stages | 软件流水线级数 | 2-5 |

---

## 核心组件详解

### 1. GemmUniversal

```cpp
// include/cutlass/gemm/kernel/gemm_universal.hpp
template <
  typename Mma,           // 核心 MMA 算法
  typename Epilogue,      // 输出融合
  typename ThreadblockSwizzle  // Grid 级调度策略
>
class GemmUniversal {
public:
  void operator()(Params const& params, cudaStream_t stream) {
    // 1. 计算 Grid 尺寸
    // 2. 启动 Kernel
  }
};
```

### 2. MmaMultistage (核心计算)

```cpp
// include/cutlass/gemm/threadblock/mma_multistage.h
template <
  typename Shape_,           // CTA Tile Shape (M, N, K)
  typename IteratorA_,       // A 矩阵加载器
  typename SmemIteratorA_,   // A 的 Shared Memory 迭代器
  typename IteratorB_,
  typename SmemIteratorB_,
  typename ElementC_,
  typename LayoutC_,
  typename Policy_           // Warp-level MMA 策略
>
class MmaMultistage {
  // 核心循环:
  // for k in 0..K stages:
  //   Load A, B from Gmem to Smem (async)
  //   Compute on previous stage data
  //   Sync
};
```

### 3. Epilogue

```cpp
// include/cutlass/epilogue/threadblock/epilogue.h
// 处理 C 矩阵输出：缩放、加 bias、activation

template <...\n>
class Epilogue {
  // 1. 从 Accumulator 加载数据
  // 2. 应用 EpilogueOp (bias, relu, etc)
  // 3. 写回 Global Memory
};
```

---

## 数据加载模式

### Global Memory → Shared Memory

```cpp
// 使用 cp.async 指令 (Ampere+)
// include/cutlass/gemm/threadblock/default_mma_core_sm80.h

// 关键参数:
// - ThreadMap: 每个线程负责哪些元素
// - AccessSize: 128-bit 或 256-bit 向量加载
// - Stages: 双缓冲/多缓冲

using GmemIteratorA = cutlass::transform::threadblock::
  PredicatedTileIterator<
    cutlass::MatrixShape<128, 8>,  // 每次加载的 tile
    half_t,                          // 数据类型
    layout::RowMajor,                // A 布局
    0,                               // Advance rank
    ThreadMapA                       // 线程映射
  >;
```

### Shared Memory → Register (for Tensor Core)

```cpp
// LDSM 指令: 从 Shared Memory 加载到寄存器
// 用于 WMMA/MMA 指令的输入

// include/cutlass/arch/mma_sm80.h
using MmaOp = cutlass::arch::OpClassTensorCore;
using SmemIteratorA = cutlass::transform::threadblock::
  RegularTileIterator<...>;
```

---

## Warp 级 MMA 抽象

### 问题背景

Tensor Core 指令以 warp 为单位执行：
- `mma.sync.aligned.m16n8k16.row.col.f16.f16.f16.f16`
- 64 线程协作完成 16x8x16 矩阵乘

### CUTLASS 封装

```cpp
// include/cute/atom/mma_atom.hpp

// 定义 MMA 操作的原子描述
template <class MMA_Op, class ElementA, class ElementB, class ElementC>
struct MMA_Atom {
  using Shape_MNK = typename MMA_Op::Shape;  // 如 (16, 8, 16)
  
  // 描述数据如何在 warp 内分布
  using ThrLayoutVMNK = ...;  // (Value, M, N, K) -> thread
  using ValLayoutA = ...;     // A 数据布局
  using ValLayoutB = ...;     // B 数据布局
  using ValLayoutC = ...;     // C 数据布局
};

// 使用示例
using MMA_Atom_OP = MMA_Atom<
  SM80_16x8x16_F16F16F16F16_TN,
  half_t, half_t, half_t
>;
```

### ThrVal 分解

```cpp
// 将问题分解为 Thread 和 Value 两个维度

// ThrLayout: 哪些线程参与
// ValLayout: 每个线程持有哪些数据

// 对于 m16n8k16:
// - 32 threads 参与 (实际 64，但成对)
// - 每个线程持有 4 个 FP16 值
```

---

## 软件流水线原理

### 为什么需要流水线？

```
没有流水线:
  Load A0, B0 → Wait → MMA(A0,B0) → Load A1, B1 → Wait → MMA(A1,B1)...
  
双缓冲流水线:
  Stream 0: Load A0,B0 ──────────────────────────────────────────────
  Stream 1: ─────────── MMA(A0,B0) ─────────────────────────────────
  Stream 0: ───────────────────────── Load A1,B1 ───────────────────
  Stream 1: ─────────────────────────────────────── MMA(A1,B1) ─────
  
关键: Load 和 Compute 重叠，隐藏内存延迟
```

### CUTLASS 实现

```cpp
// include/cutlass/pipeline/pipeline_v2.hpp

template <int Stages>
class PipelineAsync {
public:
  // 生产者 (数据加载)
  __device__ void producer_acquire(int stage);
  __device__ void producer_commit(int stage);
  
  // 消费者 (计算)
  __device__ void consumer_wait(int stage);
  __device__ void consumer_release(int stage);
};

// 使用 cp.async 的 arrive/wait 机制实现同步
```

### 多级流水线

```cpp
// Gemm 中的三级流水线
Level 0: Global Memory → Shared Memory (cp.async)
Level 1: Shared Memory → Register (LDS)
Level 2: Register → Tensor Core (MMA)

CUTLASS 3 使用更细粒度的同步原语实现高效重叠
```

---

## 配置参数全解析

### 一个完整的 CUTLASS Gemm 配置

```cpp
using Gemm = cutlass::gemm::device::GemmUniversalAdapter<
  cutlass::gemm::kernel::GemmUniversal<
    cutlass::gemm::GemmShape<128, 128, 32>,    // CTA Tile
    cutlass::gemm::GemmShape<64, 64, 32>,      // Warp Tile
    cutlass::gemm::GemmShape<16, 8, 16>,       // MMA Tile (Tensor Core)
    
    half_t,                                      // A 类型
    cutlass::layout::RowMajor,                   // A 布局
    half_t,                                      // B 类型
    cutlass::layout::ColumnMajor,                // B 布局
    float,                                       // C 类型
    cutlass::layout::RowMajor,                   // C 布局
    
    float,                                       // Accumulator 类型
    cutlass::arch::OpClassTensorCore,            // 使用 Tensor Core
    cutlass::arch::Sm80,                         // 目标架构
    
    3,                                           // Stages (Ampere 可用 3-5)
    cutlass::gemm::kernel::GemmIdentityThreadblockSwizzle<8>
  >
>;
```

### 参数选择指南

| 参数 | 影响 | 调优建议 |
|------|------|----------|
| CTA Tile | Occupancy, 寄存器压力 | 128x128 或 256x128 是甜点 |
| Warp Tile | 每个 Warp 的工作量 | 通常是 CTA Tile / 4 |
| Stages | 延迟隐藏 vs SMEM | Ampere: 3-5, Hopper: 可更高 |
| SplitK | K 维并行 | 大 K 时使用，增加 Occupancy |

---

## 参考

- [[KB-20250309-001]] CUTLASS CuTe 系统性学习计划
- [[KB-20250309-003]] CuTe 核心抽象详解
- [[KB-20250309-005]] Gemm 实现原理与优化
