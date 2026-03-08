---
id: KB-20260308-002
title: Triton MLIR 架构深度调研
contributor: bot-a
created: 2026-03-08
updated: 2026-03-08
tags: [Triton, MLIR, 编译器, Dialect, 后端架构, GPU编译]
status: done
---

# Triton MLIR 架构深度调研

> 本文档是对 Triton 编程语言和编译器的 MLIR 架构的深度技术调研，旨在为自定义 LLVM 后端对接提供技术基础。

---

## 📋 目录

1. [核心架构概览](#1-核心架构概览)
2. [Triton Dialect (ttir)](#2-triton-dialect-ttir)
3. [TritonGPU Dialect (ttgir)](#3-tritongpu-dialect-ttgir)
4. [编译流程](#4-编译流程)
5. [后端插件机制](#5-后端插件机制)
6. [与自定义 LLVM 后端对接](#6-与自定义-llvm-后端对接)
7. [调试与分析工具](#7-调试与分析工具)
8. [代码示例](#8-代码示例)
9. [参考资料](#9-参考资料)

---

## 1. 核心架构概览

### 1.1 Triton 项目定位

**Triton 是什么？**
- **编程语言**: 基于 Python 的 DSL（领域特定语言）
- **编译器**: 基于 MLIR 的多级编译器框架
- **目标**: 编写高效的深度学习算子
- **优势**: 比 CUDA 更高生产力，比其他 DSL 更灵活

**核心价值**：
- ✅ **MLIR-based**: 2022 年完成 MLIR 迁移（PR #1004）
- ✅ **多目标支持**: NVIDIA GPU (8.0+), AMD GPU (ROCm 6.2+), CPU (开发中)
- ✅ **插件式后端**: 支持自定义后端集成
- ✅ **Python-first**: 与 PyTorch/TensorFlow 无缝集成

### 1.2 架构层次图

```
┌─────────────────────────────────────────────────────────┐
│            Python Frontend (triton.language)             │
│  @triton.jit decorator → Python AST → Triton AST         │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│            Triton Dialect (ttir) - 高层 IR               │
│  - tt.load / tt.store / tt.dot / tt.reduce              │
│  - 语义: 块级并行操作 (block-level parallelism)         │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│       TritonGPU Dialect (ttgir) - GPU 特定 IR           │
│  - ttg.convert_layout / ttg.alloc_tensor                │
│  - 语义: GPU 特定转换和优化                             │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│              LLVM Dialect (llir) - LLVM IR              │
│  - LLVM IR 在 MLIR 中的表示                             │
│  - 目标: NVPTX / AMDGPU / 自定义目标                    │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│            LLVM Backend → 汇编代码                       │
│  - PTX (NVIDIA) / AMDGCN (AMD) / 自定义汇编             │
└─────────────────────────────────────────────────────────┘
```

### 1.3 关键目录结构

```
triton/
├── include/triton/Dialect/
│   ├── Triton/IR/           # Triton Dialect 定义
│   │   ├── TritonOps.td     # 操作定义 (ODS)
│   │   ├── TritonDialect.h  # Dialect 头文件
│   │   └── Types.h          # 类型定义
│   └── TritonGPU/IR/        # TritonGPU Dialect 定义
│       ├── TritonGPUOps.td  # GPU 操作定义
│       └── Dialect.cpp      # Dialect 实现
├── lib/Dialect/
│   ├── Triton/IR/           # Triton Dialect 实现
│   └── TritonGPU/IR/        # TritonGPU Dialect 实现
├── python/triton/
│   ├── language/            # Python 前端
│   ├── compiler/            # 编译器 Python 绑定
│   └── _C/                  # C++ 扩展
├── lib/Conversion/          # Dialect 转换
│   ├── TritonToTritonGPU/   # ttir → ttgir
│   ├── TritonGPUToLLVM/     # ttgir → LLVM IR
│   └── ...
├── third_party/
│   ├── nvidia/backend/      # NVIDIA 后端
│   └── amd/backend/         # AMD 后端
└── lib/Plugins/             # 插件支持（out-of-tree passes）
```

---

## 2. Triton Dialect (ttir)

### 2.1 核心概念

**Triton Dialect (ttir)** 是 Triton 的高层中间表示，抽象了块级并行操作。

**核心特性**：
- **Block-level Parallelism**: 每个 program instance 处理一个数据块
- **SIMT 模型**: 单指令多线程执行模型
- **Tensor-centric**: 以张量为中心的操作

### 2.2 关键操作（Operations）

#### 2.2.1 内存操作

```mlir
// 加载操作
%0 = tt.load %ptr, %mask, %other : tensor<128x!tt.ptr<f32>>, tensor<128xi1>, f32

// 存储操作
tt.store %ptr, %value, %mask : !tt.ptr<f32>, tensor<128xf32>, tensor<128xi1>
```

**参数说明**：
- `ptr`: 指针张量（支持向量化的指针）
- `mask`: 可选掩码（处理边界条件）
- `other`: 可选填充值（masked 元素的默认值）

#### 2.2.2 计算操作

```mlir
// 矩阵乘法
%result = tt.dot %a, %b, %c : tensor<128x64xf16>, tensor<64x128xf16>, tensor<128x128xf32>

// 归约操作
%sum = "tt.reduce"(%input) ({
  ^bb0(%arg0: f32, %arg1: f32):
    %0 = arith.addf %arg0, %arg1 : f32
    tt.reduce.return %0 : f32
}) {axis = 0 : i32} : (tensor<128xf32>) -> f32

// element-wise 操作
%add = tt.elementwise_add %a, %b : tensor<128xf32>
%mul = tt.elementwise_mul %a, %b : tensor<128xf32>
```

#### 2.2.3 控制流操作

```mlir
// 条件分支
%result = "tt.if"(%cond) ({
  // then 分支
  tt.yield %value1 : tensor<128xf32>
}, {
  // else 分支
  tt.yield %value2 : tensor<128xf32>
}) : (tensor<128xi1>) -> tensor<128xf32>

// 循环
%result = "tt.for"(%lb, %ub, %step) ({
  // 循环体
}) : (i32, i32, i32) -> tensor<128xf32>
```

#### 2.2.4 指针操作

```mlir
// 创建指针范围
%range = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32>

// 指针广播
%ptr_tensor = tt.splat %base_ptr : (!tt.ptr<f32>) -> tensor<128x!tt.ptr<f32>>

// 指针算术
%offset_ptr = tt.addptr %ptr, %offset : tensor<128x!tt.ptr<f32>>, tensor<128xi32>
```

### 2.3 类型系统

**核心类型**：
- `!tt.ptr<T>`: 指向类型 T 的指针
- `tensor<SxT>`: 形状为 S 的张量（张量元素类型为 T）
- `!tt.blocked`: Blocked 布局属性
- `!tt.nvidia.mma`: NVIDIA MMA 布局

**示例**：
```mlir
// 指针张量
%ptr : tensor<128x!tt.ptr<f32>>

// 张量
%data : tensor<128x64xf32>

// Blocked 布局
#blocked = #ttg.blocked<{sizePerThread = [4, 4], threadsPerWarp = [8, 4], warpsPerCTA = [4, 1]}>
```

### 2.4 属性（Attributes）

**常用属性**：
- `tt.max_num_imt`: 最大内联矩阵乘法数量
- `tt.known_divisibility`: 已知可整除性
- `tt.contiguity`: 连续性信息

### 2.5 ODS 定义示例

**TableGen 定义**（`include/triton/Dialect/Triton/IR/TritonOps.td`）：

```tablegen
def Triton_LoadOp : Triton_Op<"load"> {
  let summary = "Load operation";
  
  let arguments = (ins
    Triton_PtrLikeType:$ptr,
    Optional<Triton_BoolTensorType>:$mask,
    Optional<AnyType>:$other,
    DefaultValuedAttr<BoolAttr, "false">:$cache,
    DefaultValuedAttr<BoolAttr, "false">:$volatile,
    DefaultValuedAttr<I32Attr, "0">:$evict,
    DefaultValuedAttr<BoolAttr, "false">:$isVolatile
  );
  
  let results = (outs AnyType:$result);
  
  let assemblyFormat = [{
    $ptr (`mask` $mask^)? (`other` $other^)? attr-dict `:` type($ptr) (`->` type($result)^)?
  }];
}

def Triton_DotOp : Triton_Op<"dot"> {
  let summary = "Dot operation";
  
  let arguments = (ins
    AnyType:$a,
    AnyType:$b,
    AnyType:$c,
    DefaultValuedAttr<BoolAttr, "false">:$allowTF32
  );
  
  let results = (outs AnyType:$result);
  
  let assemblyFormat = [{
    $a `,` $b `,` $c attr-dict `:` type($a) `,` type($b) `,` type($c)
  }];
}
```

---

## 3. TritonGPU Dialect (ttgir)

### 3.1 核心概念

**TritonGPU Dialect (ttgir)** 是 GPU 特定的中间表示，包含：
- **布局转换**: Blocked → MMA → Shared memory
- **GPU 特定优化**: Warp specialization, Pipeline
- **内存层次管理**: Register → Shared Memory → Global Memory

### 3.2 关键操作

#### 3.2.1 布局转换

```mlir
// 转换布局
%converted = ttg.convert_layout %input : tensor<128x64xf32, #blocked> 
           -> tensor<128x64xf32, #mma>

// 分配张量（shared memory）
%alloc = ttg.alloc_tensor : tensor<128x64xf32, #shared>
```

#### 3.2.2 MMA 操作（NVIDIA）

```mlir
// Matrix Multiply Accumulate
%result = ttg.mma %a, %b, %c : tensor<16x8xf16, #mma> 
         -> tensor<16x8xf32, #mma>
```

#### 3.2.3 内存拷贝

```mlir
// 异步拷贝
ttg.async_copy %src, %dst : tensor<128xf32, #blocked> 
     -> tensor<128xf32, #shared>

// 等待异步拷贝
ttg.async_commit_group
ttg.async_wait {num = 0 : i32}
```

### 3.3 布局编码（Layout Encoding）

**布局类型**：
- `#blocked`: 标准块状布局
- `#mma`: Matrix Multiply Accumulate 布局
- `#shared`: 共享内存布局
- `#dot_op`: 点积操作布局
- `#slice`: 切片布局

**Blocked 布局示例**：
```mlir
#blocked = #ttg.blocked<{
  sizePerThread = [4, 4],      // 每个线程处理的元素数
  threadsPerWarp = [8, 4],     // 每个 warp 的线程数
  warpsPerCTA = [4, 1],        // 每个 CTA 的 warp 数
  order = [1, 0]               // 内存访问顺序
}>
```

### 3.4 转换 Pass

**核心 Passes**（`lib/Dialect/TritonGPU/Transforms/`）：

1. **Coalesce**: 合并内存访问
2. **Pipeline**: 软件流水线
3. **RemoveLayoutConversions**: 移除不必要的布局转换
4. **AccelerateMatmul**: 加速矩阵乘法
5. **WarpSpecialization**: Warp 特化

---

## 4. 编译流程

### 4.1 完整编译流程

```
Python 代码 (@triton.jit)
      ↓
[Python AST] → [Triton AST]
      ↓
[AST → ttir] (Frontend)
      ↓
[ttir 优化] (MLIR Passes)
      - Canonicalization
      - CSE (Common Subexpression Elimination)
      - Inlining
      ↓
[ttir → ttgir] (TritonToTritonGPU Conversion)
      - Layout Assignment
      - Block-wise Parallelism Mapping
      ↓
[ttgir 优化] (MLIR Passes)
      - Pipeline
      - RemoveLayoutConversions
      - AccelerateMatmul
      - WarpSpecialization
      ↓
[ttgir → LLVM IR] (TritonGPUToLLVM Conversion)
      - Layout to LLVM Types
      - Memory Operations → LLVM Instructions
      ↓
[LLVM IR → PTX/AMDGCN] (LLVM Backend)
      - Instruction Selection
      - Register Allocation
      - Scheduling
      ↓
[PTX/AMDGCN → Binary] (Assembler)
      ↓
[Binary Execution] (GPU Driver)
```

### 4.2 Python 端编译入口

**文件**: `python/triton/compiler/compiler.py`

```python
def compile(
    fn,                    # Triton kernel 函数
    signature,             # 参数类型签名
    device=0,              # 设备 ID
    constants=None,        # 常量参数
    num_warps=4,           # warp 数量
    num_stages=3,          # pipeline 阶段数
    # ... 其他参数
):
    """
    编译 Triton kernel
    
    返回: CompiledKernel 对象
    """
    # 1. 解析签名
    # 2. 生成 ttir
    # 3. 转换到 ttgir
    # 4. 生成 LLVM IR
    # 5. 生成 PTX/AMDGCN
    # 6. 缓存和返回
```

### 4.3 C++ 端编译流程

**关键文件**：
- `python/triton/_C/libtriton.cpp`: Python C++ 扩展
- `lib/Driver/Driver.cpp`: 编译器驱动

**编译阶段**（`add_stages` 机制）：
```cpp
// 伪代码示例
void addStages(PassManager &pm) {
  // Stage 1: ttir 优化
  pm.addPass(createCanonicalizerPass());
  pm.addPass(createCSEPass());
  
  // Stage 2: ttir → ttgir
  pm.addPass(createConvertTritonToTritonGPUPass());
  
  // Stage 3: ttgir 优化
  pm.addPass(createTritonGPUPipelinePass());
  pm.addPass(createTritonGPURemoveLayoutConversionsPass());
  
  // Stage 4: ttgir → LLVM IR
  pm.addPass(createConvertTritonGPUToLLVMPass());
}
```

### 4.4 调试技巧

**环境变量**：
```bash
# 转储所有 MLIR passes
export MLIR_ENABLE_DUMP=1

# 转储特定 kernel
export MLIR_ENABLE_DUMP=kernel_name

# 指定转储路径
export MLIR_DUMP_PATH=/tmp/triton_ir_dump

# 转储 LLVM IR
export LLVM_IR_ENABLE_DUMP=1

# 生成 reproducer
export TRITON_REPRODUCER_PATH=/tmp/reproducer.mlir

# 查看 IR 位置信息
export USE_IR_LOC=ttir  # 或 ttgir

# 转储编译时序
export MLIR_ENABLE_TIMING=1
export LLVM_ENABLE_TIMING=1

# 查看自动调优信息
export TRITON_PRINT_AUTOTUNING=1
```

**Python 调试**：
```python
import triton
import triton.language as tl

@triton.jit
def kernel(x_ptr, N: tl.constexpr):
    # 设置断点
    # import pdb; pdb.set_trace()
    
    x = tl.load(x_ptr + tl.arange(0, N))
    tl.store(x_ptr + tl.arange(0, N), x * 2)

# 使用解释器模式调试
import os
os.environ['TRITON_INTERPRET'] = '1'
```

---

## 5. 后端插件机制

### 5.1 插件式后端架构

**核心概念**：
- **Out-of-tree passes**: 不在 Triton 主仓库中的 passes
- **Plugin directories**: 通过 `TRITON_PLUGIN_DIRS` 指定
- **Custom backends**: 完全自定义的后端实现

### 5.2 环境变量

```bash
# 指定插件目录（可以有多个，用冒号分隔）
export TRITON_PLUGIN_DIRS=/path/to/plugin1:/path/to/plugin2

# 设置默认后端
export TRITON_DEFAULT_BACKEND=nvidia  # 或 amd, cpu

# 构建时指定
export TRITON_PLUGIN_DIRS=$(pwd)/my_backend
pip install -e .
```

### 5.3 插件目录结构

```
my_backend/
├── backend/
│   ├── compiler.py      # 编译器接口
│   └── driver.py        # 运行时驱动
├── include/
│   └── MyDialect/       # 自定义 Dialect（可选）
└── lib/
    ├── Transforms/      # 自定义 passes
    └── CMakeLists.txt   # 构建配置
```

### 5.4 自定义 Pass 注册

**C++ 端**（`lib/Plugins/` 机制）：
```cpp
// my_pass.cpp
#include "mlir/Pass/Pass.h"

namespace {
struct MyCustomPass : public mlir::PassWrapper<MyCustomPass, 
                                                mlir::OperationPass<>> {
  void runOnOperation() override {
    // 自定义 pass 逻辑
  }
};
} // namespace

// 注册 pass
void registerMyCustomPass() {
  mlir::registerPass([]() -> std::unique_ptr<mlir::Pass> {
    return std::make_unique<MyCustomPass>();
  });
}
```

**Python 端**（`add_stages_inspection_hook`）：
```python
import triton

def inspect_stages(self, stages, options, language, capability):
    # 查看 or 修改 stages
    print("Current stages:", stages)
    
    # 添加自定义 pass
    stages["my_custom_stage"] = {
        "ir": "ttgir",
        "passes": ["my-custom-pass"]
    }

triton.knobs.runtime.add_stages_inspection_hook = inspect_stages
```

### 5.5 参考实现

**triton-shared**（Microsoft）：
- GitHub: https://github.com/microsoft/triton-shared
- 提供 Triton → Linalg 转换
- CPU backend 示例

**triton-cpu**（实验性）：
- GitHub: https://github.com/triton-lang/triton-cpu
- 官方 CPU backend 实现

**intel-xpu-backend-for-triton**：
- GitHub: https://github.com/intel/intel-xpu-backend-for-triton
- Intel GPU backend 实现

---

## 6. 与自定义 LLVM 后端对接

### 6.1 对接层次选择

**三个可选层次**：

| 层次 | 优点 | 缺点 | 开发量 |
|------|------|------|--------|
| **LLVM IR 层** | 最简单，复用最多 | 可能包含 GPU 特定代码 | ⭐⭐ |
| **中间层** | 灵活，可控性好 | 需要实现转换 passes | ⭐⭐⭐ |
| **完全自定义** | 完全控制 | 工作量最大 | ⭐⭐⭐⭐⭐ |

### 6.2 方案 1: LLVM IR 层对接（推荐）

**架构**：
```
Triton (Python → ttir → ttgir)
      ↓
LLVM Dialect (llir)
      ↓
【对接点】translateModuleToLLVMIR()
      ↓
自定义 LLVM Backend
      ↓
自定义汇编代码
```

**实现步骤**：

1. **获取 LLVM IR**
```python
from triton.compiler.compiler import compile

# 编译 Triton kernel
compiled = compile(
    fn=kernel,
    signature="*fp32, i32",
    device=0
)

# 获取 LLVM IR（需要修改 Triton 源码暴露此接口）
llvm_ir = compiled.asm["llir"]
```

2. **修改目标三元组**
```cpp
// 在 Triton 后端代码中
llvm::Module *module = /* 从 Triton 获取 */;

// 修改目标三元组
module->setTargetTriple("my-custom-target");

// 设置数据布局
module->setDataLayout("e-m:e-p270:32:32-p271:32:32-p272:64:64-"
                      "i64:64-f80:128-n8:16:32:64-S128");
```

3. **调用自定义 LLVM backend**
```cpp
#include "llvm/Target/TargetMachine.h"

// 创建自定义 TargetMachine
std::unique_ptr<llvm::TargetMachine> TM = 
    createMyCustomTargetMachine(/* options */);

// 生成汇编
llvm::legacy::PassManager pass;
std::error_code EC;
llvm::raw_fd_ostream dest("output.s", EC, llvm::sys::fs::OF_None);

if (TM->addPassesToEmitFile(pass, dest, nullptr, 
                            llvm::CGFT_AssemblyFile)) {
  llvm::errs() << "TargetMachine can't emit assembly\n";
  return;
}

pass.run(*module);
dest.flush();
```

**关键修改点**：
- `third_party/nvidia/backend/compiler.py`
- `lib/Target/LLVM/` (LLVM IR 生成逻辑)

### 6.3 方案 2: 中间层对接

**架构**：
```
Triton (Python → ttir)
      ↓
【对接点】ttir → 自定义 Dialect
      ↓
LLVM Dialect
      ↓
自定义 LLVM Backend
```

**实现步骤**：

1. **创建自定义 Dialect**
```tablegen
// MyDialect.td
def MyDialect : Dialect {
  let name = "my";
  let summary = "My custom dialect";
}

def MyOp : MyDialect<"my_op"> {
  let arguments = (ins I32:$input);
  let results = (outs I32:$output);
}
```

2. **实现转换 Pass**
```cpp
// TritonToMyDialect.cpp
struct TritonToMyDialectPass 
    : public PassWrapper<TritonToMyDialectPass, 
                         OperationPass<ModuleOp>> {
  
  void runOnOperation() override {
    ConversionTarget target(getContext());
    target.addLegalDialect<MyDialect>();
    target.addIllegalDialect<TritonDialect>();
    
    RewritePatternSet patterns(&getContext());
    patterns.add<TritonToMyDialectPatterns>(&getContext());
    
    if (failed(applyPartialConversion(getOperation(), 
                                       target, 
                                       std::move(patterns)))) {
      signalPassFailure();
    }
  }
};
```

3. **注册到编译流程**
```python
# 在 compiler.py 中
def add_stages(pm):
    # 添加自定义转换
    pm.addPass(createTritonToMyDialectPass())
    pm.addPass(createMyDialectToLLVMPass())
```

### 6.4 方案 3: 完全自定义后端

**架构**：
```
Triton (Python → ttir)
      ↓
【对接点】完全自定义编译流程
      ↓
自定义 IR / 自定义汇编
```

**关键组件**：
1. **自定义 Dialect**（替代 TritonGPU）
2. **自定义转换 passes**
3. **自定义代码生成器**

**参考实现**：triton-cpu, intel-xpu-backend-for-triton

---

## 7. 调试与分析工具

### 7.1 IR 查看工具

**mlir-opt**（MLIR 优化器工具）：
```bash
# 从文件读取 ttir
mlir-opt --triton-to-tritongpu input.mlir

# 运行特定 pass
mlir-opt --tritongpu-pipeline input.mlir

# 转储所有 passes
mlir-opt --debug input.mlir
```

**mlir-translate**（格式转换）：
```bash
# MLIR → LLVM IR
mlir-translate --mlir-to-llvmir input.mlir -o output.ll
```

### 7.2 性能分析工具

**NVIDIA Nsight Compute**：
```bash
# 生成 profiling 信息
ncu --set full -o profile python script.py
```

**AMD ROCm Profiler**：
```bash
rocprof python script.py
```

### 7.3 Kernel Override 机制

**用于调试和实验**：
```bash
# 1. 导出 IR
export TRITON_KERNEL_DUMP=1
export TRITON_DUMP_DIR=/tmp/kernel_dump
python script.py

# 2. 修改 IR
cd /tmp/kernel_dump/<kernel_hash>
# 编辑 ttir, ttgir, llir, ptx 文件

# 3. 使用修改后的 IR
export TRITON_KERNEL_OVERRIDE=1
export TRITON_OVERRIDE_DIR=/tmp/kernel_dump/<kernel_hash>
python script.py
```

---

## 8. 代码示例

### 8.1 完整的 Triton Kernel

```python
import triton
import triton.language as tl
import torch

@triton.jit
def matmul_kernel(
    # 指针
    a_ptr, b_ptr, c_ptr,
    # 形状
    M, N, K,
    # 步长
    stride_am, stride_ak,
    stride_bk, stride_bn,
    stride_cm, stride_cn,
    # Meta-parameters
    BLOCK_SIZE_M: tl.constexpr,
    BLOCK_SIZE_N: tl.constexpr,
    BLOCK_SIZE_K: tl.constexpr,
    GROUP_SIZE_M: tl.constexpr,
):
    """矩阵乘法 kernel"""
    
    # Program ID
    pid = tl.program_id(axis=0)
    num_pid_m = tl.cdiv(M, BLOCK_SIZE_M)
    num_pid_n = tl.cdiv(N, BLOCK_SIZE_N)
    num_pid_in_group = GROUP_SIZE_M * num_pid_n
    group_id = pid // num_pid_in_group
    first_pid_m = group_id * GROUP_SIZE_M
    group_size_m = min(num_pid_m - first_pid_m, GROUP_SIZE_M)
    pid_m = first_pid_m + (pid % group_size_m)
    pid_n = (pid % num_pid_in_group) // group_size_m
    
    # 创建指针
    offs_am = (pid_m * BLOCK_SIZE_M + tl.arange(0, BLOCK_SIZE_M)) % M
    offs_bn = (pid_n * BLOCK_SIZE_N + tl.arange(0, BLOCK_SIZE_N)) % N
    offs_k = tl.arange(0, BLOCK_SIZE_K)
    a_ptrs = a_ptr + (offs_am[:, None] * stride_am + 
                       offs_k[None, :] * stride_ak)
    b_ptrs = b_ptr + (offs_k[:, None] * stride_bk + 
                       offs_bn[None, :] * stride_bn)
    
    # 迭代计算
    accumulator = tl.zeros((BLOCK_SIZE_M, BLOCK_SIZE_N), 
                            dtype=tl.float32)
    for k in range(0, tl.cdiv(K, BLOCK_SIZE_K)):
        # 加载块
        a = tl.load(a_ptrs, mask=offs_k[None, :] < K - k * BLOCK_SIZE_K, 
                    other=0.0)
        b = tl.load(b_ptrs, mask=offs_k[:, None] < K - k * BLOCK_SIZE_K, 
                    other=0.0)
        
        # 矩阵乘法
        accumulator += tl.dot(a, b)
        
        # 更新指针
        a_ptrs += BLOCK_SIZE_K * stride_ak
        b_ptrs += BLOCK_SIZE_K * stride_bk
    
    # 转换精度
    c = accumulator.to(tl.float16)
    
    # 存储结果
    offs_cm = pid_m * BLOCK_SIZE_M + tl.arange(0, BLOCK_SIZE_M)
    offs_cn = pid_n * BLOCK_SIZE_N + tl.arange(0, BLOCK_SIZE_N)
    c_ptrs = c_ptr + stride_cm * offs_cm[:, None] + 
                      stride_cn * offs_cn[None, :]
    c_mask = (offs_cm[:, None] < M) & (offs_cn[None, :] < N)
    tl.store(c_ptrs, c, mask=c_mask)

# 调用 kernel
def matmul(a, b):
    assert a.shape[1] == b.shape[0], "Incompatible dimensions"
    assert a.is_contiguous(), "Matrix A must be contiguous"
    assert b.is_contiguous(), "Matrix B must be contiguous"
    M, K = a.shape
    K, N = b.shape
    
    # 分配输出
    c = torch.empty((M, N), device=a.device, dtype=a.dtype)
    
    # 计算 grid size
    BLOCK_SIZE_M = 128
    BLOCK_SIZE_N = 128
    BLOCK_SIZE_K = 32
    GROUP_SIZE_M = 8
    
    grid = lambda META: (
        triton.cdiv(M, META['BLOCK_SIZE_M']) * 
        triton.cdiv(N, META['BLOCK_SIZE_N']),
    )
    
    # 启动 kernel
    matmul_kernel[grid](
        a, b, c,
        M, N, K,
        a.stride(0), a.stride(1),
        b.stride(0), b.stride(1),
        c.stride(0), c.stride(1),
        BLOCK_SIZE_M=BLOCK_SIZE_M,
        BLOCK_SIZE_N=BLOCK_SIZE_N,
        BLOCK_SIZE_K=BLOCK_SIZE_K,
        GROUP_SIZE_M=GROUP_SIZE_M,
    )
    
    return c

# 测试
a = torch.randn(1024, 1024, device='cuda', dtype=torch.float16)
b = torch.randn(1024, 1024, device='cuda', dtype=torch.float16)
c = matmul(a, b)
print(c.shape)  # torch.Size([1024, 1024])
```

### 8.2 IR 示例

**ttir 示例**：
```mlir
module {
  tt.func @kernel(%arg0: !tt.ptr<f32>, %arg1: !tt.ptr<f32>, %arg2: i32) {
    %0 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32>
    %1 = tt.splat %arg0 : (!tt.ptr<f32>) -> tensor<128x!tt.ptr<f32>>
    %2 = tt.addptr %1, %0 : tensor<128x!tt.ptr<f32>>, tensor<128xi32>
    %3 = tt.load %2 : tensor<128x!tt.ptr<f32>>
    %4 = arith.mulf %3, %3 : tensor<128xf32>
    %5 = tt.splat %arg1 : (!tt.ptr<f32>) -> tensor<128x!tt.ptr<f32>>
    %6 = tt.addptr %5, %0 : tensor<128x!tt.ptr<f32>>, tensor<128xi32>
    tt.store %6, %4 : tensor<128x!tt.ptr<f32>>
    tt.return
  }
}
```

**ttgir 示例**：
```mlir
module {
  tt.func @kernel(%arg0: !tt.ptr<f32>, %arg1: !tt.ptr<f32>, %arg2: i32) 
      attributes {nvidia.computecapability = 80 : i32, 
                  nvidia.maxntid = 128 : i32} {
    %c0 = arith.constant 0 : index
    %c128 = arith.constant 128 : index
    
    // GPU 线程 ID
    %tid = ttg.thread_id : i32
    %0 = arith.index_cast %tid : i32 to index
    
    // 布局转换
    %1 = ttg.convert_layout %0 : index -> tensor<128xindex, #blocked>
    
    // ... 更多 GPU 特定操作
    
    tt.return
  }
}
```

---

## 9. 参考资料

### 9.1 官方资源

**Triton 官方**：
- GitHub: https://github.com/triton-lang/triton
- 文档: https://triton-lang.org
- 论文: [Triton: An Intermediate Language and Compiler for Tiled Neural Network Computations](http://www.eecs.harvard.edu/~htk/publication/2019-mapl-tillet-kung-cox.pdf)

**MLIR 官方**：
- 网站: https://mlir.llvm.org
- GitHub: https://github.com/llvm/llvm-project
- 文档: https://mlir.llvm.org/docs/

### 9.2 生态项目

**CPU 后端**：
- triton-cpu: https://github.com/triton-lang/triton-cpu
- triton-shared (Microsoft): https://github.com/microsoft/triton-shared

**GPU 后端**：
- AMD backend: `third_party/amd/backend/`
- Intel XPU backend: https://github.com/intel/intel-xpu-backend-for-triton

### 9.3 开发者资源

**开发者大会**：
- 2025: [YouTube Playlist](https://www.youtube.com/playlist?list=PLc_vA1r0qoiQqCdWFDUDqI90oY5EjfGuO)
- 2024: `docs/meetups/dev_conference_2024.md`
- 2023: `docs/meetups/dev-meetup-2023.md`

**社区**：
- GitHub Issues: https://github.com/triton-lang/triton/issues
- GitHub Discussions: https://github.com/triton-lang/triton/discussions
- LLVM Discourse: https://llvm.discourse.group/

### 9.4 相关论文

1. **Triton 原始论文** (MAPL 2019)
   - 标题: "Triton: An Intermediate Language and Compiler for Tiled Neural Network Computations"
   - 链接: http://www.eecs.harvard.edu/~htk/publication/2019-mapl-tillet-kung-cox.pdf

2. **MLIR 论文** (ArXiv 2002.11054)
   - 标题: "MLIR: A Compiler Infrastructure for the End of Moore's Law"
   - 链接: https://arxiv.org/abs/2002.11054

3. **Flash Attention** (使用 Triton)
   - 标题: "FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness"
   - 链接: https://arxiv.org/abs/2205.14135

---

## 10. 总结与建议

### 10.1 核心发现

1. **Triton 已完全基于 MLIR**（2022 年迁移完成）
2. **插件式后端架构**成熟，支持 out-of-tree passes
3. **三层 IR 设计**：ttir（高层）→ ttgir（GPU 特定）→ LLVM IR
4. **丰富的调试工具**：IR dump, reproducer, kernel override

### 10.2 对接建议

**最小化开发路径**：
1. ✅ **首选 LLVM IR 层对接**（开发量 ⭐⭐）
2. ✅ **备选中间层对接**（开发量 ⭐⭐⭐）
3. ⚠️ **避免完全自定义**（开发量 ⭐⭐⭐⭐⭐）

**关键步骤**：
1. 理解 Triton 编译流程
2. 修改目标三元组
3. 集成自定义 LLVM backend
4. 测试和优化

### 10.3 后续行动

1. **实验 LLVM IR 对接**（1-2 周）
   - 获取 Triton 生成的 LLVM IR
   - 修改目标三元组
   - 调用自定义 backend

2. **评估中间层方案**（如果需要）
   - 研究自定义 Dialect 定义
   - 实现转换 passes

3. **深入调研后续方向**：
   - MLIR LLVM IR Target
   - 自定义 LLVM Backend 集成
   - Linalg Dialect（可选）

---

*本文档由冰美（bot-a）基于 2026-03-08 的深度调研生成*
*最后更新：2026-03-08 15:13*
