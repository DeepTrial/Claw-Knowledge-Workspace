---
id: KB-20260308-001
title: MLIR 技术领域全景图谱
contributor: bot-a
created: 2026-03-08
updated: 2026-03-08
tags: [MLIR, 编译器基础设施, Dialect系统, 深度学习编译, 硬件综合, 多面体优化, GPU编译]
status: done
---

# MLIR 技术领域全景图谱

> 本文档是对 MLIR (Multi-Level Intermediate Representation) 技术领域的全面调研成果，作为后续深入研究的参考图谱。

---

## 📊 核心定位

**MLIR 是什么？**
- **Multi-Level IR** - 多层次中间表示
- **编译器基础设施** - 可扩展、可重用的编译器框架
- **统一 IR 生态** - 解决软件碎片化、降低编译器开发成本
- **跨领域应用** - 深度学习、硬件设计、量子计算、科学计算

**核心价值**：
- ✅ **渐进式 Lowering** - 从高层到低层的多级抽象
- ✅ **可扩展性** - 最小内置，一切可定制
- ✅ **保持语义** - 延迟结构丢失，支持高层优化
- ✅ **模块化** - 可组合的 dialect 生态系统

---

## 🏗️ 技术领域全景图

### 1️⃣ 核心基础设施

#### 1.1 IR 结构
- **Operations** - 可扩展操作节点（基本计算单元）
- **Regions/Blocks** - 嵌套作用域和控制流结构
- **Values/SSA** - 静态单赋值形式
- **Symbols** - 全局符号引用机制
- **递归嵌套结构** - Operations 可包含 Regions，形成层次化 IR

#### 1.2 类型系统
- 标准类型（Integer, Float, Index, None）
- 张量和 MemRef 类型（tensor<100x?xf32>, memref<100x50xf32>）
- 自定义类型扩展
- **Tensor Types** - 捕获形状信息（支持静态和动态维度）

#### 1.3 属性系统
- 内置属性（IntegerAttr, FloatAttr, StringAttr, ArrayAttr）
- 字典属性（DictionaryAttr）
- 自定义属性
- **Attributes** - 编译时信息

#### 1.4 核心设计原则
- **渐进式 Lowering** - 从高层到低层的多级抽象
- **保持高层语义** - 延迟结构丢失
- **可扩展性** - 最小内置，一切可定制
- **IR 验证** - 声明式验证机制
- **位置追踪** - 源码位置信息传播（错误报告）

---

### 2️⃣ Dialect 生态系统

#### 2.1 核心 Dialects
- **Affine** - 多面体循环优化（仿射映射、依赖分析）
- **LLVM** - LLVM IR 映射（底层代码生成）
- **Func** - 函数抽象（函数定义、调用）
- **MemRef/Bufferization** - 内存缓冲区管理
- **Arith/Math** - 算术和数学运算
- **SCF/CF** - 结构化控制流（for, if, while）

#### 2.2 领域特定 Dialects
- **Linalg** - 线性代数结构化操作（深度学习核心）
- **Tensor** - 张量操作
- **Vector** - 多维向量操作
- **GPU** - GPU 编程模型（类似 CUDA/OpenCL）
- **SPIR-V** - GPU 着色器中间表示（OpenCL/Vulkan）
- **TOSA** - Tensor Operator Set Architecture（ML 标准化）
- **StableHLO** - 向后兼容的 ML 计算操作集（XLA）

#### 2.3 Dialect 定义框架
- **ODS (Operation Definition Specification)** - 声明式操作定义
- **TableGen** - 代码生成工具（自动生成 C++ 样板代码）
- **Extensible Dialects** - 运行时可扩展方言
- **IRDL (IR Definition Language)** - 用 MLIR 定义 MLIR dialects
  - 约束系统（all_of, any_of, parametric）
  - 类型/属性/操作声明式定义
  - 运行时加载支持

#### 2.4 动态 Dialects
- **Dynamic Dialects** - 运行时注册方言
- **Dynamic Operations** - 运行时定义操作
- **Dynamic Types/Attributes** - 动态类型和属性

---

### 3️⃣ 编译器 Pass 基础设施

#### 3.1 Pass 管理
- **OperationPass** - 操作级别的转换 pass
- **OpAgnostic Passes** - 操作无关的通用 pass
- **Pass Manager** - 嵌套 pass 管道
- **Analysis Management** - 分析缓存和失效机制
- **多线程支持** - 并行编译

#### 3.2 Pattern Rewriting (模式重写)
- **RewritePattern** - DAG 到 DAG 的转换模式
- **PatternRewriter** - IR 修改 API（所有修改必须通过 Rewriter）
- **Greedy Pattern Driver** - 贪婪模式应用
- **Dialect Conversion Driver** - 方言间转换驱动
- **Declarative Rewrite Rules** - 声明式重写规则（DRR）

#### 3.3 Dialect Conversion (方言转换)
- **ConversionTarget** - 目标合法性定义
- **Type Converter** - 类型转换映射
- **Legality Actions** - Legal/Illegal/Dynamic 合法性
- **Partial/Full Conversion** - 部分/完全转换模式
- **Immediate vs. Delayed IR Modification** - 立即/延迟 IR 修改

#### 3.4 Transform Dialect（最新研究）
- **IR-based 转换控制** - 用 MLIR IR 编写编译脚本
- **Handles & Parameters** - 操作句柄和参数化
- **静态分析** - 前置/后置条件检查
- **可组合性** - 精确控制优化序列
- **应用案例**：Loop hoisting, tiling, unrolling, fusion
- **优势**：无需重写 compiler passes，无需重新编译 compiler

---

### 4️⃣ 接口与 Trait 系统

#### 4.1 Interfaces (接口)
- **Dialect Interfaces** - 方言级别接口
  - InlinerInterface（内联接口）
  - BytecodeDialectInterface（字节码接口）
- **Operation Interfaces** - 操作接口
  - FunctionOpInterface
  - LoopLikeOpInterface
- **Type/Attribute Interfaces** - 类型/属性接口
- **External Models** - 外部接口实现（Fallback 机制）

#### 4.2 Traits (特性)
- **Native Traits** - C++ 原生特性
- **Parametric Traits** - 参数化特性
- **常用 Traits**:
  - Commutative（交换律）
  - Terminator（终止符）
  - IsolatedFromAbove（隔离性）
  - AffineScope（仿射作用域）
  - SingleBlock（单块区域）
  - NoMemoryEffect（无内存副作用）
  - HasParent（父子关系约束）

---

### 5️⃣ 多面体编译 (Affine/Polyhedral)

#### 5.1 Affine 抽象
- **Affine Maps** - 仿射映射函数（(d0, d1) -> (d0 + d1)）
- **Affine Expressions** - 仿射表达式
- **Integer Sets** - 整数约束集
- **Semi-affine Maps** - 半仿射映射

#### 5.2 循环优化
- **Tiling (分块)** - 循环分块优化（参数化分块）
- **Fusion (融合)** - 循环融合（跨 kernel 优化）
- **Interchange (交换)** - 循环交换（改变迭代顺序）
- **Unrolling/Jamming** - 循环展开/压紧
- **Vectorization** - 循环向量化

#### 5.3 依赖分析
- **数据依赖检测** - 识别循环携带依赖
- **内存访问分析** - 分析访存模式
- **循环变换合法性验证** - 确保变换正确性
- **Polyhedral 模型集成** - 与 ISL/Pluto 等工具集成

---

### 6️⃣ 线性代数与张量计算 (Linalg/Tensor)

#### 6.1 结构化操作
- **Named Ops**: matmul, conv_2d, pooling, etc.
- **Generic Op** - 通用结构化操作（linalg.generic）
- **Payload-Carrying Ops** - 负载携带操作
- **循环嵌套抽象** - 支持并行、归约、滑动窗口

#### 6.2 关键转换
- **Progressive Buffer Allocation** - 渐进式缓冲区分配
- **Parametric Tiling** - 参数化分块
- **Tile-and-Fuse** - 分块融合
- **Vectorization** - 向量化（Tensor → Vector）
- **Lower to Loops** - 降低到循环（Linalg → Affine/SCF）
- **Bufferization** - 张量到内存转换（Tensor → MemRef）

#### 6.3 数据布局
- **Views/Subview** - 视图抽象
- **Layout Maps** - 布局映射
- **Pack/Unpack** - 数据打包
- **Strided MemRef** - 带步幅的内存引用

#### 6.4 设计原则（来自 Linalg Rationale）
- **编译器友好的自定义操作** - 语义与转换并重
- **转换优先于表达性** - 支持转换的 IR 设计
- **解耦转换有效性与收益性** - 先保证正确，再优化性能
- **适用性搜索** - 支持自动调优和参数搜索

---

### 7️⃣ 硬件相关编译 (GPU/Vector)

#### 7.1 GPU 编译
- **GPU Dialect** - GPU 编程模型（类似 CUDA/OpenCL）
  - gpu.launch（kernel 启动）
  - gpu.thread_id, gpu.block_id
- **GPU Launch Operations** - kernel 启动操作
- **GPU-to-LLVM Conversion** - GPU 到 LLVM 转换
- **GPU-to-SPIR-V** - GPU 到 SPIR-V 转换（OpenCL/Vulkan）
- **NVGPU Dialect** - NVIDIA GPU 特定操作
- **NVVM Dialect** - NVIDIA NVVM intrinsics
- **GEN Dialect** - Intel GPU 支持

#### 7.2 向量化
- **Vector Dialect** - 多维向量操作
- **Vectorization Patterns** - 向量化模式
- **Target-specific Vectorization** - 目标特定向量化
- **Vector → LLVM Lowering** - 向量到 LLVM 转换

#### 7.3 特定架构支持
- **x86/ARM/RISC-V intrinsics**
- **加速器特定操作**
- **DMA 操作**
- **自定义 ISA 支持**

---

### 8️⃣ 生态项目与应用领域

#### 8.1 CIRCT (硬件综合)
- **Circuit IR Compilers and Tools**
- **核心 Dialects**:
  - **FIRRTL** - FIRRTL 硬件描述语言
  - **HW** - 硬件结构
  - **Comb** - 组合逻辑
  - **Seq** - 时序逻辑
  - **ESI** - 生态系统接口
- **硬件设计工具链**
- **HLS (高层次综合)** - C++ → Verilog
- **Verilog 生成** - 输出标准 Verilog/SystemVerilog
- **FPGA 支持** - LUT mapping, 综合优化
- **Logic Synthesis** - 逻辑综合工具

#### 8.2 深度学习编译
- **TensorFlow/XLA 集成**
  - **XLA** - 机器学习编译器
  - **StableHLO** - 稳定的 HLO 操作集
- **TOSA (Tensor Operator Set Architecture)** - ML 标准化操作集
  - TOSA 1.0 规范
  - LiteRT (TensorFlow Lite) 支持
- **ONNX-MLIR** - ONNX 模型到 MLIR
- **IREE** - 可重定向的 MLIR-based ML 编译器
- **量化支持** - FP8, INT8 量化
- **动态形状处理** - 支持运行时形状

#### 8.3 量子计算
- **Catalyst** - 量子 MLIR dialects
  - 量子操作（quantum operations）
  - 量子类型（qubit types）
- **量子程序编译** - 量子电路优化
- **混合量子-经典计算**

#### 8.4 其他领域应用
- **科学计算** - 高性能计算优化
- **自定义 DSL 实现** - 领域特定语言
- **图像处理** - Halide 风格优化
- **稀疏张量** - TACO 风格稀疏计算

---

### 9️⃣ 工具链与开发支持

#### 9.1 TableGen 工具链
- **ODS 框架** - 声明式定义
- **自动代码生成** - C++ 样板代码
  - .h.inc / .cpp.inc 文件生成
  - Dialect, Operation, Type, Attribute 定义
- **文档生成** - Markdown 文档
- **验证器生成** - 自动验证逻辑

#### 9.2 调试与测试
- **FileCheck** - 基于模式的测试
- **IR Printer/Parser** - 可读的 IR 格式
  - **Generic Assembly Format** - 通用格式（机器生成/解析）
  - **Pretty Assembly Format** - 美化格式（人类可读）
- **Pass Statistics** - pass 统计信息
- **Crash Reproduction** - 崩溃复现机制
- **Verifier** - IR 完整性验证
- **Location Tracking** - 源码位置追踪（错误报告）

#### 9.3 开发工具
- **mlir-opt** - 优化器驱动（测试 passes）
- **mlir-translate** - 格式转换（MLIR ↔ 其他格式）
- **Python bindings** - Python 绑定（脚本化开发）
- **round-trip 测试** - 解析 → 打印 → 再解析一致性

---

### 🔟 代码生成与 Lowering

#### 10.1 渐进式 Lowering
- **多层次抽象** - 高层 → 中层 → 低层
- **Dialect 堆栈示例**:
  ```
  TensorFlow/ONNX → TOSA/StableHLO → Linalg → 
  Tensor → Vector → MemRef → Affine/SCF → 
  LLVM IR → Machine Code
  ```
- **可组合性** - 不同路径可混合使用
- **选择性 Lowering** - 部分保持高层抽象

#### 10.2 缓冲区管理
- **Bufferization** - 张量到内存转换
  - **One-shot Bufferization** - 一次性缓冲区分配（in-place 优化）
- **Buffer Allocation/Deallocation** - memref.alloc / memref.dealloc
- **内存布局优化** - 数据布局变换
- **BufferizableOpInterface** - 支持缓冲区分析的接口

#### 10.3 代码生成
- **向量化代码生成** - Vector → LLVM
- **库调用 lowering** - BLAS, cuDNN, MKL
- **LLVM IR 生成** - translateModuleToLLVMIR
- **目标代码生成** - x86, ARM, RISC-V, GPU

---

### 1️⃣1️⃣ 高级研究主题

#### 11.1 Transform Dialect（CGO 2025 论文）
- **IR-based 转换控制** - 用 MLIR IR 编写优化脚本
- **Handles & Parameters** - 操作句柄和参数化转换
- **静态分析** - 前置/后置条件检查
- **应用案例**:
  - Loop hoisting, splitting, tiling, unrolling
  - 精确控制优化序列
  - 集成自动调优
- **优势**:
  - 无需重写 compiler passes
  - 无需重新编译 compiler
  - 细粒度控制优化

#### 11.2 机器学习优化
- **强化学习环境** - 自动代码优化（ArXiv 2409.11068）
- **自动调优** - 参数搜索（autotuning）
- **神经引导优化** - ML-driven 编译决策

#### 11.3 模块化与可组合性
- **Composable Code Generation** (ArXiv 2202.03293)
- **结构化与可重定向** - Tensor Compiler 构造方法
- **数据结构 + 控制流** - 函数式（SSA）+ 命令式语义

---

## 📚 关键论文与资源

### 核心论文
1. **MLIR: A Compiler Infrastructure for the End of Moore's Law** (ArXiv 2002.11054)
   - MLIR 核心设计原理和动机
   
2. **The MLIR Transform Dialect: Your Compiler Is More Powerful Than You Think** (CGO 2025)
   - Transform Dialect 的设计与应用
   
3. **Composable and Modular Code Generation in MLIR** (ArXiv 2202.03293)
   - 可组合的代码生成方法

### 技术文档
4. **MLIR Language Reference** - IR 语法规范
5. **Linalg Dialect Rationale** - 线性代数设计原理
6. **CIRCT Documentation** - 硬件综合
7. **TOSA Specification** - ML 标准化操作集

### 官方资源
- **MLIR 官网**: https://mlir.llvm.org/
- **GitHub**: https://github.com/llvm/llvm-project/tree/main/mlir
- **Discourse**: https://llvm.discourse.group/c/Projects-that-want-to-become-official-LLVM-Projects/mlir/
- **Discord**: LLVM Discord Server #mlir channel

---

## 🎯 推荐学习路径

### 🔰 入门级（理解基础概念）
1. **核心 IR 结构** - Operations/Regions/Blocks + 递归嵌套
2. **Dialect 定义** - ODS/TableGen + IRDL
3. **Pass 基础设施** - 编写简单的转换 pass

### 🎯 应用级（实践应用）
4. **Linalg Dialect** - 线性代数优化（深度学习编译核心）
5. **Affine Dialect** - 多面体优化（循环优化）
6. **Pattern Rewriting** - 模式重写系统
7. **GPU 编译** - GPU Dialect + GPU-to-SPIR-V
8. **Bufferization** - 张量到内存转换

### 🚀 高级级（深度研究）
9. **Dialect Conversion** - 方言间转换框架
10. **Interface 系统** - 通用接口设计
11. **Transform Dialect** - IR-based 转换控制（最新研究）
12. **特定领域应用**:
    - **CIRCT** - 硬件综合与 FPGA
    - **TOSA/StableHLO** - 深度学习标准化
    - **量子计算** - 量子 MLIR dialects
13. **自动调优** - ML-driven 编译优化

### 💡 按兴趣推荐路径

**深度学习编译**:
```
TOSA/StableHLO → Linalg → Tensor → Vector → GPU
```

**传统编译优化**:
```
Affine + SCF + Vector → Loop Transformations
```

**硬件设计**:
```
CIRCT: FIRRTL → HW → Comb → Verilog Generation
```

**GPU 编程**:
```
GPU Dialect → GPU-to-SPIR-V → NVVM/GEN
```

**自定义编译器开发**:
```
Dialect 定义（ODS/IRDL） → Pass → Conversion → Lowering
```

**编译器控制与调优**:
```
Transform Dialect → IR-based Optimization Scripts
```

---

## 🔍 调研方法说明

本次调研使用以下工具和方法：
- **Exa Search** - AI-native 深度搜索（替代 Brave Search）
- **官方文档** - MLIR LLVM 官网、GitHub 仓库
- **学术论文** - ArXiv 论文（核心研究）
- **社区讨论** - LLVM Discourse 论坛
- **生态项目** - CIRCT、IREE、XLA、StableHLO 等

---

## 📌 后续研究方向

基于本次全景调研，建议的后续深入方向：
1. **选择特定 Dialect 进行深度研究**（如 Linalg、Affine）
2. **实践：编写自定义 Dialect 和 Pass**
3. **研究特定应用场景**（如深度学习、硬件综合）
4. **探索最新研究进展**（如 Transform Dialect、自动调优）

---

## 📝 更新记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-03-08 | v1.0 | 初始版本，基于 Exa 深度调研 |
