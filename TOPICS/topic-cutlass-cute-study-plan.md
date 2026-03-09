---
id: KB-20250309-001
title: CUTLASS CuTe 系统性学习计划
category: cuda.optimization
level: 2
summary: "CUTLASS和CuTe的完整学习路线，包含Tile基础、CuTe抽象、CUTLASS架构、Gemm实现原理和实战调优五个阶段"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cutlass, cute, cuda, gemm, tensor-core, optimization]
status: done
---

# CUTLASS / CuTe 系统性学习计划

## 学习定位

在已完成 CUDA 基础（包括 Shared Memory 矩阵乘法）之上，深入理解：
- **CUTLASS**: NVIDIA 高性能线性代数模板库的设计与实现
- **CuTe**: CUTLASS 3.x 核心布局抽象系统（Layout, Tensor, Shape）
- **CUTile**: Tile-based 编程模型的本质

## 学习资源分级

### 入门资源 (必看)
1. **CUTLASS 官方文档**
   - https://github.com/NVIDIA/cutlass/blob/main/README.md
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/quickstart.md
   
2. **CuTe 核心概念**
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/cute/00_quickstart.md
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/cute/01_layout.md
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/cute/02_tensor.md

### 进阶资源
3. **CUTLASS 架构文档**
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/efficient_gemm.md
   - https://github.com/NVIDIA/cutlass/blob/main/media/docs/profiler.md

4. **论文与演讲**
   - CUTLASS 原始论文: "CUTLASS: Fast Linear Algebra in CUDA C++" (2018)
   - GTC 演讲: "Developing CUDA Kernels to Push Tensor Cores to the Absolute Limit"
   - "Demystifying Tensor Cores"

### 源码精读
5. **核心头文件**
   - `include/cute/layout.hpp` - Layout 定义
   - `include/cute/tensor.hpp` - Tensor 封装
   - `include/cute/atom/mma_atom.hpp` - MMA 抽象
   - `include/cutlass/gemm/kernel/gemm_universal.hpp` - Gemm Kernel

## 学习阶段

### Phase 0: CUDA Tile 基础 (2-3天)
理解 Tile-based programming 的核心概念，这是学习 CuTe 和 CUTLASS 的基础：
- **Tile 概念**: 为什么需要分块、计算强度
- **Tile Shape**: CTA/Warp/Thread 三级分块
- **数据复用**: Global → Shared → Register 层次
- **内存布局**: Bank conflict 与 Swizzle
- **线程映射**: 协作加载与计算分配

### Phase 1: CuTe 基础抽象 (3-4天)
理解 CuTe 如何用声明式抽象表达 Tile 概念：
- **Shape**: 多维形状描述
- **Layout**: 内存布局映射（逻辑坐标 → 物理偏移）
- **Tensor**: Layout + 数据指针
- **布局代数**: Composition、Tiled Division

### Phase 2: CUTLASS 架构 (4-5天)
理解 CUTLASS 的分层设计：
- **Kernel 层**: 顶层协调（Grid 级）
- **TileIterator**: 数据加载/存储模式
- **Warp-level MMA**: Tensor Core 封装
- **Epilogue**: 输出融合（bias、activation）

### Phase 3: Gemm 实现原理 (5-6天)
从零理解一个高性能 Gemm 的完整流程：
- 问题划分（Tile → Warp → Thread）
- 数据加载（Gmem → Smem，双缓冲/多缓冲）
- 计算流水线（LDGSTS → MMA 重叠）
- 软件流水线（Software Pipelining）

### Phase 4: 实战调优 (3-4天)
- 使用 CUTLASS Profiler 探索配置空间
- 针对特定 Shape 调优 Tile Size
- 理解 Occupancy 与寄存器压力权衡

## 实践路径

```cpp
// 从简单到复杂的学习代码
00_tile_basics/           // Tile 概念与线程协作
01_cute_basics/           // Shape, Layout, Tensor 基础
02_layout_algebra/        // 布局组合与变换
03_copy_atom/             // 数据搬运原子操作
04_mma_atom/              // MMA 原子操作
05_gemm_naive/            // 最简 Gemm
06_gemm_shared/           // Shared Memory 优化
07_gemm_warp_tiling/      // Warp-level 分块
08_gemm_tensor_core/      // Tensor Core
09_gemm_pipeline/         // 多级流水线
10_cutlass_integration/   // 使用 CUTLASS 组件
```

## 关键问题清单

学习过程中持续追问：
1. Layout 如何描述 strided/contorted/blocked 内存模式？
2. 如何用 CuTe 表达复杂的 Swizzle 和 Permute？
3. Copy Atom 如何抽象不同架构的异步拷贝指令？
4. MMA Atom 如何封装不同代 Tensor Core 的差异？
5. 软件流水线如何隐藏内存延迟？
6. 为什么 CUTLASS 3 要引入 CuTe 重写？

## 产出目标

完成学习后应能：
- 独立阅读并理解 CUTLASS Gemm Kernel 源码
- 使用 CuTe 描述自定义数据布局
- 为特定问题编写 Cutom Gemm Kernel
- 调优 CUTLASS 配置以适配特定 workload

## 参考

- [[KB-20250309-002]] CUDA Tile 基础概念
- [[KB-20250309-003]] CuTe 核心抽象详解
- [[KB-20250309-004]] CUTLASS 架构设计
- [[KB-20250309-005]] Gemm 实现原理
- [[KB-20250309-006]] CUTLASS 性能调优实战
