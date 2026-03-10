# 知识库索引

> 自动生成于：2026-03-10 10:00:36  
> 知识点总数：48

---

## 按领域分类

### CUDA (29)

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

- **[KB-20250308-012]** CUDA编程指南概述与GPU优势
  - 分类: `cuda.basics` | 等级: 1
  - 摘要: CUDA官方编程指南介绍，GPU vs CPU架构对比，CUDA可扩展编程模型

- **[KB-20250308-013]** CUDA编程接口详解
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: NVCC编译流程、CUDA Runtime API、设备内存管理、Stream和Event、CUDA Graphs

- **[KB-20250308-014]** CUDA硬件实现与SIMT架构
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: SIMT架构详解、Warp执行模型、分支发散、独立线程调度、SM硬件多线程

- **[KB-20250308-015]** CUDA性能优化指南
  - 分类: `cuda.optimization` | 等级: 2
  - 摘要: 三大优化方向：最大化利用率、最大化内存吞吐量、最大化指令吞吐量

- **[KB-20250308-016]** CUDA Cooperative Groups协作组
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: 灵活的线程分组和同步机制，支持隐式/显式分组、组分割、集合操作和网格同步

- **[KB-20250308-017]** CUDA虚拟内存管理VMM
  - 分类: `cuda.basics` | 等级: 3
  - 摘要: 细粒度虚拟内存控制API：物理内存分配、虚拟地址预留、内存映射、访问权限控制、Fabric多GPU内存

- **[KB-20250308-018]** CUDA流有序内存分配器
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: cudaMallocAsync/cudaFreeAsync流有序内存分配，内存池管理，多GPU和IPC支持

- **[KB-20250308-019]** CUDA Graph内存节点
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: CUDA Graph中管理内存生命周期，支持内存分配/释放节点、自动释放、内存复用优化

- **[KB-20250308-020]** CUDA C++语言扩展
  - 分类: `cuda.basics` | 等级: 1
  - 摘要: CUDA C++扩展：执行空间限定符、内存空间限定符、内置向量类型、内建变量、内存和同步函数

- **[KB-20250308-021]** CUDA计算能力与架构特性
  - 分类: `cuda.basics` | 等级: 1
  - 摘要: 各代GPU计算能力对比、架构特性可用性、编译目标选择、技术规格

- **[KB-20250308-022]** CUDA Cluster Launch Control
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: Hopper+动态Block调度，Thread Block取消机制，cudaLaunchKernelEx API

- **[KB-20250308-023]** CUDA动态并行CDP
  - 分类: `cuda.basics` | 等级: 2
  - 摘要: 设备端启动Kernel，递归和嵌套并行，CDP2改进，内存模型和同步

- **[KB-20250308-024]** CUDA支持GPU架构与查询
  - 分类: `cuda.basics` | 等级: 1
  - 摘要: 消费级和数据中心GPU架构演进、计算能力、GPU信息查询API

- **[KB-20250309-001]** CUTLASS CuTe 系统性学习计划
  - 分类: `cuda.optimization` | 等级: 2
  - 摘要: CUTLASS和CuTe的完整学习路线，包含Tile基础、CuTe抽象、CUTLASS架构、Gemm实现原理和实战调优五个阶段

- **[KB-20250309-002]** CUDA Tile 基础概念与编程模型
  - 分类: `cuda.optimization` | 等级: 2
  - 摘要: Tile-based programming核心概念，包含Tile分块原理、计算强度、CTA/Warp/Thread三级分块、bank conflict与Swi...

- **[KB-20250309-003]** CuTe 核心抽象详解
  - 分类: `cuda.optimization` | 等级: 3
  - 摘要: CuTe库的核心概念：Shape多维形状、Layout内存布局映射、Tensor数据封装，以及布局代数Composition和Tiled Division

- **[KB-20250309-004]** CUTLASS 架构设计详解
  - 分类: `cuda.optimization` | 等级: 3
  - 摘要: CUTLASS分层架构：Kernel层全局协调、Block层CTA管理、Warp级MMA抽象、Thread级寄存器操作，以及TileIterator和Epilo...

- **[KB-20250309-005]** Gemm 实现原理与优化
  - 分类: `cuda.optimization` | 等级: 3
  - 摘要: 从v0到v4的Gemm实现演进：基础实现、Shared Memory分块、寄存器分块、Tensor Core使用、异步拷贝与多阶段流水线优化

- **[KB-20250309-006]** CUTLASS 性能调优实战
  - 分类: `cuda.optimization` | 等级: 3
  - 摘要: CUTLASS Profiler使用、Tile Size选择、Nsight Compute分析、常见性能问题排查与优化技巧

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

### LLVM (9)

- **[KB-20250306-004]** LLVM 架构设计深度解析
  - 分类: `llvm.basics` | 等级: 1
  - 摘要: LLVM 编译器基础设施深度解析：模块化设计、IR 三种形态、Pass 管理器、MLIR 扩展

- **[KB-20250306-006C]** LLVM 类型系统
  - 分类: `llvm.basics` | 等级: 2
  - 摘要: LLVM 类型系统详解：基础类型、聚合类型、向量类型及类型推断规则

- **[KB-20250307-007C]** LLVM SSA 形式与编译器优化
  - 分类: `llvm.optimization` | 等级: 2
  - 摘要: 详解 SSA（Static Single Assignment）形式：每个变量只赋值一次、Phi 函数、数据流分析

- **[KB-20250309-007]** Clang前端架构深度解析
  - 分类: `llvm.frontend` | 等级: 3
  - 摘要: Clang前端双重入口模式、Driver与-cc1执行流程、FrontendAction机制、完整编译调用链

- **[KB-20250309-008]** Clang Lexer词法分析详解
  - 分类: `llvm.frontend` | 等级: 2
  - 摘要: Clang词法分析器核心功能、Token种类、Lexer与Preprocessor关键类、Token创建流程

- **[KB-20250309-009]** Clang Parser语法分析详解
  - 分类: `llvm.frontend` | 等级: 2
  - 摘要: Clang语法分析器、递归下降解析、AST构建、声明/语句/表达式解析关键文件

- **[KB-20250309-010]** Clang Sema语义分析详解
  - 分类: `llvm.frontend` | 等级: 2
  - 摘要: Clang语义分析器、类型检查、名称查找、作用域管理、Sema关键类与语义检查流程

- **[KB-20250309-011]** Clang GPU编译架构详解
  - 分类: `llvm.frontend` | 等级: 3
  - 摘要: Clang对CUDA/HIP的编译支持、NVPTX/AMDGPU后端流程、GPU编译特有FrontendAction与ToolChain

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
