# 知识库索引

> 自动生成于：2026-03-09 10:00:07  
> 知识点总数：24

---

## 按领域分类

### CUDA (10)

- **[KB-20250306-001]** CUDA 线程层次结构深度解析
  - 分类: `cuda.threads` | 等级: 1
  - 摘要: 详细介绍 CUDA 的三级线程层次结构：Grid → Block → Thread，以及线程索引计算和调度机制

- **[KB-20250306-002]** CUDA 内存层次结构深度解析
  - 分类: `cuda.memory` | 等级: 1
  - 摘要: 全面解析 CUDA 内存层次：寄存器、共享内存、L1/L2 缓存、全局内存、常量内存、纹理内存

- **[KB-20250306-006B]** CUDA 常量内存 (Constant Memory)
  - 分类: `cuda.memory` | 等级: 2
  - 摘要: 介绍 CUDA 常量内存的特性：64KB 容量、广播机制、8KB 常量缓存，以及适用场景和性能优化

- **[KB-20250307-007B]** CUDA 全局内存与合并访问优化
  - 分类: `cuda.memory` | 等级: 2
  - 摘要: 详解全局内存合并访问原理，当 warp 访问连续地址时可合并为最少事务，性能提升 2 倍以上

- **[KB-20260307-001]** CUDA Device Code C++ 特性支持与限制
  - 分类: `cuda.syntax` | 等级: 2
  - 摘要: 基于 NVIDIA 官方文档的 CUDA Device Code C++ 特性支持列表与限制详解

- **[KB-20260307-002]** NVCC 编译流程与分离编译
  - 分类: `cuda.compiler` | 等级: 2
  - 摘要: NVCC 编译器驱动的工作流程、分离编译模式与 whole-program 编译

- **[KB-20260307-003]** CUDA 内存空间限定符详解
  - 分类: `cuda.memory` | 等级: 2
  - 摘要: CUDA 变量内存空间限定符的使用方法、性能特点与最佳实践

- **[KB-20260307-004]** CUDA 同步与内存屏障函数
  - 分类: `cuda.sync` | 等级: 2
  - 摘要: CUDA 同步原语：syncthreads、内存屏障、原子操作与协作组

- **[KB-20260307-005]** CUDA 内建变量与函数速查
  - 分类: `cuda.builtin` | 等级: 1
  - 摘要: CUDA 内建变量（threadIdx, blockIdx 等）与常用内建函数速查表

- **[KB-20260307-006]** CUDA C++ 语言扩展完整框架
  - 分类: `cuda.syntax` | 等级: 1
  - 摘要: 基于 NVIDIA 官方文档的 CUDA C++ 语言扩展完整框架，涵盖函数/变量限定符、内建类型、同步原语等

### LLVM (4)

- **[KB-20250306-004]** LLVM 架构设计深度解析
  - 分类: `llvm.basics` | 等级: 1
  - 摘要: LLVM 编译器基础设施深度解析：模块化设计、IR 三种形态、Pass 管理器、MLIR 扩展

- **[KB-20250306-006C]** LLVM 类型系统
  - 分类: `llvm.basics` | 等级: 2
  - 摘要: LLVM 类型系统详解：基础类型、聚合类型、向量类型及类型推断规则

- **[KB-20250307-007C]** LLVM SSA 形式与编译器优化
  - 分类: `llvm.optimization` | 等级: 2
  - 摘要: 详解 SSA（Static Single Assignment）形式：每个变量只赋值一次、Phi 函数、数据流分析

- **[KB-20260308-001]** LLVM Backend 注册与 TargetMachine 创建深度解析
  - 分类: `llvm.backend` | 等级: 3
  - 摘要: 深入解析 LLVM 后端注册机制与 TargetMachine 创建流程，包括 TargetRegistry、TargetInfo、TargetLowering...

### MLIR (1)

- **[KB-20260308-002]** MLIR Bufferization 一致性保证深度解析
  - 分类: `mlir.bufferization` | 等级: 3
  - 摘要: 深入解析 MLIR One-Shot Bufferize 的正确性保证机制，包括 RaW 冲突检测、内存别名分析、所有权管理

### SYSTEM-DESIGN (1)

- **[KB-20260306-003]** 多 Agent 协作调研
  - 分类: `system-design.multi-agent` | 等级: 2
  - 摘要: 多 Agent 协作最佳实践：分工调研、结果合并、冲突解决机制

### TRITON (4)

- **[KB-20250306-003]** Triton @triton.jit Decorator 原理深度解析
  - 分类: `triton.basics` | 等级: 2
  - 摘要: 深度解析 Triton JIT 编译器原理：AST 解析、MLIR 生成、PTX 编译流程

- **[KB-20250306-006A]** Triton mask 与边界处理
  - 分类: `triton.basics` | 等级: 2
  - 摘要: 介绍 Triton mask 机制处理边界条件，确保内存访问安全，避免越界读写

- **[KB-20250307-007A]** Triton tl.load/tl.store 内存操作与优化
  - 分类: `triton.optimization` | 等级: 2
  - 摘要: 详解 Triton 内存操作：tl.load/tl.store 参数、swizzling 优化、向量化访问

- **[KB-20260306-006]** Triton 编程语言深度调研
  - 分类: `triton.basics` | 等级: 1
  - 摘要: Triton 编程语言全景调研：编译架构、跨平台支持（NVIDIA/AMD）、与 CUDA 对比

### UNKNOWN (4)

- **[KB-20260308-001]** MLIR 技术领域全景图谱
  - 分类: `unknown` | 等级: 2
  - 摘要: # MLIR 技术领域全景图谱

> 本文档是对 MLIR (Multi-Level Intermediate Representation) 技术领域的全面调...

- **[KB-20260308-002]** Triton MLIR 架构深度调研
  - 分类: `unknown` | 等级: 2
  - 摘要: # Triton MLIR 架构深度调研

> 本文档是对 Triton 编程语言和编译器的 MLIR 架构的深度技术调研，旨在为自定义 LLVM 后端对接提供...

- **[KB-20260308-003]** MLIR LLVM IR Target 深度调研
  - 分类: `unknown` | 等级: 2
  - 摘要: # MLIR LLVM IR Target 深度调研

> 本文档是对 MLIR LLVM IR Target 机制的深度技术调研，重点关注 MLIR → LL...

- **[KB-20260308-004]** 自定义 LLVM Backend 集成深度调研
  - 分类: `unknown` | 等级: 2
  - 摘要: # 自定义 LLVM Backend 集成深度调研

> 本文档是对自定义 LLVM Backend 集成的深度技术调研，重点是如何让现有的自定义 LLVM b...

---

## 快速检索

使用 `.kb/kb search "关键词"` 进行检索。

例如：
- `.kb/kb search "CUDA 内存"`
- `.kb/kb search "优化" --category cuda`

---

*此文件由 `.kb/kb rebuild` 自动生成，请勿手动编辑*
