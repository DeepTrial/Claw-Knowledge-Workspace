---
id: KB-20260308-003
title: MLIR LLVM IR Target 深度调研
contributor: bot-a
created: 2026-03-08
updated: 2026-03-08
tags: [MLIR, LLVM IR, 编译器, Target, Dialect转换, 数据布局]
status: done
---

# MLIR LLVM IR Target 深度调研

> 本文档是对 MLIR LLVM IR Target 机制的深度技术调研，重点关注 MLIR → LLVM IR 的转换流程和与自定义 LLVM 后端的对接。

---

## 📋 目录

1. [核心概念与架构](#1-核心概念与架构)
2. [LLVM Dialect 类型系统](#2-llvm-dialect-类型系统)
3. [转换流程](#3-转换流程)
4. [translateModuleToLLVMIR 机制详解](#4-translatemoduletollvmir-机制详解)
5. [目标三元组与数据布局配置](#5-目标三元组与数据布局配置)
6. [类型转换规则](#6-类型转换规则)
7. [调用约定](#7-调用约定)
8. [代码示例](#8-代码示例)
9. [与自定义 LLVM 后端对接](#9-与自定义-llvm-后端对接)
10. [调试技巧](#10-调试技巧)
11. [参考资料](#11-参考资料)

---

## 1. 核心概念与架构

### 1.1 MLIR → LLVM IR 两阶段流程

**MLIR LLVM IR Target** 的整体流程分为两个阶段：

```
┌─────────────────────────────────────────────────────────┐
│  Stage 1: Conversion (Dialect Conversion)               │
│  ─────────────────────────────────────────────────────  │
│  MLIR Dialects → LLVM Dialect                           │
│  (Affine/SCF/Func → LLVM)                               │
│                                                          │
│  • 使用 DialectConversion 框架                          │
│  • 类型转换 (TypeConverter)                              │
│  • 操作转换 (Conversion Patterns)                        │
│  • 渐进式转换 (Progressive Lowering)                     │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 2: Translation (Module Translation)              │
│  ─────────────────────────────────────────────────────  │
│  LLVM Dialect → LLVM IR                                 │
│  (MLIR 表示 → LLVM IR)                                   │
│                                                          │
│  • 使用 ModuleTranslation 类                             │
│  • 直接映射到 LLVM IR 指令                               │
│  • 保持 LLVM IR 语义一致性                               │
│  • 生成可执行的 LLVM IR                                  │
└─────────────────────────────────────────────────────────┘
```

**关键设计原则**：
1. ✅ **转换在 MLIR 内完成**：所有非平凡转换在 MLIR 层完成
2. ✅ **简单翻译**：LLVM Dialect → LLVM IR 是简单映射
3. ✅ **最小依赖**：减少对 LLVM IR 库的依赖
4. ✅ **双向潜力**：设计上支持 LLVM IR → MLIR（虽然目前不完整）

### 1.2 核心组件

**Conversion 阶段组件**：
- **ConversionTarget**: 定义目标 dialect 的合法性
- **TypeConverter**: 类型转换规则
- **RewritePatternSet**: 操作转换模式
- **applyFullConversion / applyPartialConversion**: 转换驱动

**Translation 阶段组件**：
- **ModuleTranslation**: MLIR → LLVM IR 翻译器
- **translateModuleToLLVMIR**: 翻译入口函数
- **DialectTranslation**: 各 dialect 的翻译接口

### 1.3 关键文件位置

```
llvm-project/mlir/
├── include/mlir/
│   ├── Target/LLVMIR/
│   │   ├── ModuleTranslation.h       # 翻译器头文件
│   │   ├── Export.h                  # 导出接口
│   │   └── Import.h                  # 导入接口（LLVM IR → MLIR）
│   ├── Conversion/
│   │   ├── Passes.h                  # 转换 passes 注册
│   │   └── ConvertToLLVM/            # 通用转换 passes
│   └── Dialect/LLVMIR/
│       ├── LLVMDialect.h             # LLVM Dialect 定义
│       └── LLVMTypes.h               # LLVM 类型定义
├── lib/Target/LLVMIR/
│   ├── ModuleTranslation.cpp         # 翻译器实现
│   ├── DataLayoutImporter.cpp        # 数据布局导入
│   └── Dialect/                      # 各 dialect 翻译实现
│       ├── LLVMIR/
│       │   └── LLVMToLLVMIRTranslation.cpp
│       └── Builtin/
│           └── BuiltinToLLVMIRTranslation.cpp
└── lib/Conversion/
    ├── FuncToLLVM/                   # Func → LLVM 转换
    ├── AffineToStandard/             # Affine → Standard 转换
    └── ...
```

---

## 2. LLVM Dialect 类型系统

### 2.1 LLVM Dialect 概述

**LLVM Dialect** 是 MLIR 中对 LLVM IR 的直接映射，包含：
- **操作 (Operations)**: LLVM IR 指令的 MLIR 表示
- **类型 (Types)**: LLVM IR 类型的 MLIR 表示
- **属性 (Attributes)**: LLVM IR 元数据的 MLIR 表示

**核心特性**：
- ✅ **语义一致性**：LLVM Dialect 操作的语义必须与 LLVM IR 指令完全一致
- ✅ **直接映射**：尽可能保持 1:1 映射关系
- ✅ **辅助操作**：提供 MLIR 特有的辅助操作（如 `llvm.mlir.constant`）

### 2.2 类型系统

#### 2.2.1 兼容的内置类型 (Built-in Type Compatibility)

以下 MLIR 内置类型在 LLVM Dialect 中**保持不变**：

```mlir
// 整数类型
i1, i8, i16, i32, i64, i128

// 浮点类型
f16, bf16, f32, f64, f80, f128

// 指针类型（LLVM Dialect 特有）
!llvm.ptr        // 不透明指针（opaque pointer）
!llvm.ptr<i32>   // 带类型的指针（LLVM 15+ 已废弃）
```

#### 2.2.2 LLVM Dialect 特有类型

**1. 指针类型**
```mlir
// 不透明指针（推荐，LLVM 15+）
!llvm.ptr

// 带地址空间的指针
!llvm.ptr<addrspace=3>

// 已废弃：带类型的指针
!llvm.ptr<i32>  // ⚠️ 不推荐使用
```

**2. 数组类型**
```mlir
// LLVM 数组类型
!llvm.array<10 x i32>
!llvm.array<4 x vector<8 x f32>>
```

**3. 向量类型**
```mlir
// LLVM 向量类型（一维）
!llvm.vec<4 x i32>
!llvm.vec<8 x f32>

// 可伸缩向量（RISC-V V 扩展等）
!llvm.vec<? x i32>
```

**4. 结构体类型**

**字面结构体（Literal Struct）**：
```mlir
// 匿名结构体
!llvm.struct<(i32, f32)>

// 带字段名的结构体
!llvm.struct<(i32: "x", f32: "y")>

// 打包结构体（packed）
!llvm.struct<packed (i8, i32)>
```

**标识结构体（Identified Struct）**：
```mlir
// 命名结构体（需要先定义）
llvm.mlir.alias @MyStruct = !llvm.struct<(i32, f32)>
%0 = llvm.mlir.undef : !llvm.struct<(i32, f32)>
```

**5. 函数类型**
```mlir
// LLVM 函数类型
!llvm.func<i32 (i32, f32)>
!llvm.func<void ()>
!llvm.func<i32 (...)>>  // 可变参数
```

**6. void 类型**
```mlir
!llvm.void  // 用于函数返回类型
```

### 2.3 类型转换规则

#### 2.3.1 复杂类型 → LLVM Dialect 类型

**Complex 类型**：
```mlir
// MLIR Complex 类型
complex<f32>

// 转换为 LLVM 结构体
!llvm.struct<(f32, f32)>  // (real, imaginary)
```

**Index 类型**：
```mlir
// MLIR Index 类型
index

// 根据 data layout 转换（x86_64 示例）
i64  // 64-bit 平台
```

**MemRef 类型**（详见第 6 章）：
```mlir
// MLIR MemRef
memref<?xf32>

// 转换为 LLVM 描述符结构体
!llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
```

---

## 3. 转换流程

### 3.1 Conversion 阶段：Dialects → LLVM Dialect

#### 3.1.1 ConversionTarget 配置

```cpp
// 定义转换目标
mlir::ConversionTarget target(getContext());

// 指定合法的 dialects
target.addLegalDialect<mlir::LLVMDialect>();

// 允许顶层 ModuleOp
target.addLegalOp<mlir::ModuleOp>();

// 可选：标记特定操作为合法
target.addLegalOp<mlir::UnrealizedConversionCastOp>();
```

#### 3.1.2 TypeConverter 配置

```cpp
// 创建 LLVM TypeConverter
LLVMTypeConverter typeConverter(&getContext());

// 自定义类型转换规则（可选）
typeConverter.addConversion([&](MyType type) {
  return convertMyTypeToLLVM(type);
});

// 添加类型转换的 materialization hook
typeConverter.addArgumentMaterialization(
    [](OpBuilder &builder, Type type, ValueRange inputs, Location loc) {
      return builder.create<UnrealizedConversionCastOp>(loc, type, inputs)
          .getResult(0);
    });
```

#### 3.1.3 Conversion Patterns

**标准转换 Patterns**（MLIR 已提供）：
```cpp
mlir::RewritePatternSet patterns(&getContext());

// Affine → Standard
mlir::populateAffineToStdConversionPatterns(patterns, &getContext());

// SCF → ControlFlow
mlir::cf::populateSCFToControlFlowConversionPatterns(patterns, &getContext());

// Arith → LLVM
mlir::arith::populateArithToLLVMConversionPatterns(typeConverter, patterns);

// Func → LLVM
mlir::populateFuncToLLVMConversionPatterns(typeConverter, patterns);

// ControlFlow → LLVM
mlir::cf::populateControlFlowToLLVMConversionPatterns(patterns, &getContext());

// MemRef → LLVM
mlir::populateFinalizeMemRefToLLVMConversionPatterns(typeConverter, patterns);
```

**自定义 Pattern 示例**：
```cpp
struct MyOpLowering : public OpConversionPattern<MyOp> {
  using OpConversionPattern<MyOp>::OpConversionPattern;
  
  LogicalResult matchAndRewrite(
      MyOp op, OpAdaptor adaptor,
      ConversionPatternRewriter &rewriter) const override {
    
    // 转换操作
    Value result = rewriter.create<llvm::AddOp>(
        op.getLoc(), adaptor.getOperands()[0], adaptor.getOperands()[1]);
    
    rewriter.replaceOp(op, result);
    return success();
  }
};

// 注册 pattern
patterns.add<MyOpLowering>(&getContext());
```

#### 3.1.4 完整转换示例

```cpp
// 完整的转换流程
mlir::ModuleOp module = getOperation();

// 1. 定义 ConversionTarget
mlir::ConversionTarget target(getContext());
target.addLegalDialect<mlir::LLVMDialect>();
target.addLegalOp<mlir::ModuleOp>();

// 2. 配置 TypeConverter
LLVMTypeConverter typeConverter(&getContext());

// 3. 收集 Patterns
mlir::RewritePatternSet patterns(&getContext());
mlir::populateFuncToLLVMConversionPatterns(typeConverter, patterns);
mlir::arith::populateArithToLLVMConversionPatterns(typeConverter, patterns);
// ... 添加更多 patterns

// 4. 执行转换
if (failed(mlir::applyFullConversion(module, target, std::move(patterns)))) {
  signalPassFailure();
}
```

### 3.2 Translation 阶段：LLVM Dialect → LLVM IR

#### 3.2.1 ModuleTranslation 核心类

**ModuleTranslation** 是 LLVM Dialect → LLVM IR 翻译的核心类：

```cpp
namespace mlir::LLVM {
class ModuleTranslation {
public:
  // 翻译 MLIR ModuleOp 到 LLVM Module
  static std::unique_ptr<llvm::Module> 
  translateModule(Operation *op, llvm::LLVMContext &llvmContext);
  
private:
  // 翻译函数
  LogicalResult convertFunction(LLVMFuncOp func);
  
  // 翻译基本块
  LogicalResult convertBlock(Block *block);
  
  // 翻译操作
  LogicalResult convertOperation(Operation &op);
  
  // 类型映射
  llvm::Type *convertType(Type type);
  
  // 值映射
  llvm::Value *lookupValue(Value value);
  
  // ... 更多内部方法
};
}
```

#### 3.2.2 翻译流程

```
MLIR ModuleOp
      ↓
[初始化 LLVM Context & Module]
      ↓
[翻译 Module 属性]
  - data layout
  - target triple
  - module flags
      ↓
[翻译全局变量和别名]
  - llvm.mlir.global
  - llvm.mlir.alias
      ↓
[翻译函数]
  For each llvm.func:
    ├─ 创建 LLVM Function
    ├─ 翻译函数属性
    ├─ 翻译基本块
    │   For each block:
    │     ├─ 创建 LLVM BasicBlock
    │     └─ 翻译操作
    │         For each operation:
    │           ├─ 查找或创建 LLVM Value
    │           ├─ 翻译操作到 LLVM 指令
    │           └─ 处理 PHI 节点（MLIR Block Arguments）
    └─ 验证函数
      ↓
[验证 LLVM Module]
      ↓
返回 std::unique_ptr<llvm::Module>
```

---

## 4. translateModuleToLLVMIR 机制详解

### 4.1 核心函数签名

```cpp
namespace mlir {

// 主要入口函数
std::unique_ptr<llvm::Module> 
translateModuleToLLVMIR(
    Operation *op,                  // MLIR 操作（通常是 ModuleOp）
    llvm::LLVMContext &llvmContext  // LLVM Context
);

// 带选项的版本
std::unique_ptr<llvm::Module> 
translateModuleToLLVMIR(
    Operation *op,
    llvm::LLVMContext &llvmContext,
    llvm::StringRef name  // Module 名称
);

} // namespace mlir
```

### 4.2 使用示例

#### 4.2.1 基本使用

```cpp
#include "mlir/Target/LLVMIR/Export.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"

mlir::ModuleOp mlirModule = /* ... */;

// 创建 LLVM Context
llvm::LLVMContext llvmContext;

// 翻译 MLIR → LLVM IR
std::unique_ptr<llvm::Module> llvmModule = 
    mlir::translateModuleToLLVMIR(mlirModule, llvmContext);

if (!llvmModule) {
  llvm::errs() << "Failed to translate MLIR to LLVM IR\n";
  return;
}

// 打印 LLVM IR
llvm::outs() << *llvmModule << "\n";
```

#### 4.2.2 完整代码生成流程

```cpp
#include "mlir/Target/LLVMIR/Export.h"
#include "mlir/ExecutionEngine/ExecutionEngine.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/MC/TargetRegistry.h"

// 1. 翻译 MLIR → LLVM IR
llvm::LLVMContext llvmContext;
auto llvmModule = mlir::translateModuleToLLVMIR(mlirModule, llvmContext);
if (!llvmModule) {
  return failure();
}

// 2. 初始化 LLVM targets
llvm::InitializeNativeTarget();
llvm::InitializeNativeTargetAsmPrinter();

// 3. 设置目标三元组（重要！）
mlir::ExecutionEngine::setupTargetTriple(llvmModule.get());

// 4. 优化 LLVM IR（可选）
auto optPipeline = mlir::makeOptimizingTransformer(
    /*optLevel=*/3,     // -O3
    /*sizeLevel=*/0,
    /*targetMachine=*/nullptr
);
if (auto err = optPipeline(llvmModule.get())) {
  llvm::errs() << "Failed to optimize LLVM IR: " << err << "\n";
  return failure();
}

// 5. 生成汇编代码
std::error_code EC;
llvm::raw_fd_ostream dest("output.s", EC, llvm::sys::fs::OF_None);

llvm::legacy::PassManager pass;
if (targetMachine->addPassesToEmitFile(pass, dest, nullptr, 
                                        llvm::CGFT_AssemblyFile)) {
  llvm::errs() << "TargetMachine can't emit assembly\n";
  return failure();
}

pass.run(*llvmModule);
dest.flush();
```

### 4.3 翻译过程中的关键映射

#### 4.3.1 操作映射

| MLIR 操作 | LLVM IR 指令 |
|-----------|-------------|
| `llvm.add` | `add` |
| `llvm.fadd` | `fadd` |
| `llvm.mul` | `mul` |
| `llvm.load` | `load` |
| `llvm.store` | `store` |
| `llvm.call` | `call` |
| `llvm.br` | `br` |
| `llvm.cond_br` | `br` (conditional) |
| `llvm.return` | `ret` |
| `llvm.mlir.constant` | LLVM constant |
| `llvm.getelementptr` | `getelementptr` |

#### 4.3.2 Block Arguments → PHI Nodes

**MLIR 使用 Block Arguments 替代 PHI 节点**：

```mlir
// MLIR 代码
^bb0(%arg0: i32):
  llvm.br ^bb1(%arg0 : i32)
^bb1(%arg1: i32):  // Block argument
  llvm.return %arg1 : i32
```

翻译为 LLVM IR：
```llvm
; LLVM IR
bb0:
  br label %bb1
bb1:
  %0 = phi i32 [ %arg0, %bb0 ]  ; PHI node
  ret i32 %0
```

**翻译过程**：
1. MLIR Block Arguments 在翻译时创建 PHI nodes
2. 前驱块传递的值映射到 PHI 节点
3. PHI 节点的值映射回 Block Argument 的使用处

---

## 5. 目标三元组与数据布局配置

### 5.1 目标三元组 (Target Triple)

#### 5.1.1 概念

**目标三元组**描述目标平台的架构、厂商和操作系统：
```
<arch><sub>-<vendor>-<sys>-<env>

示例：
x86_64-unknown-linux-gnu
aarch64-unknown-linux-gnu
nvptx64-nvidia-cuda
amdgcn-amd-amdhsa
```

#### 5.1.2 在 MLIR 中设置

**方法 1: 通过 Module 属性**
```mlir
module attributes {llvm.target_triple = "x86_64-unknown-linux-gnu"} {
  // ...
}
```

**方法 2: 通过 C++ API**
```cpp
mlir::ModuleOp module = /* ... */;

// 获取或创建 LLVM dialect 属性
auto targetTriple = mlir::StringAttr::get(&context, "x86_64-unknown-linux-gnu");
module->setAttr("llvm.target_triple", targetTriple);
```

**方法 3: 使用 MLIR 工具函数（推荐）**
```cpp
#include "mlir/ExecutionEngine/ExecutionEngine.h"

llvm::LLVMContext llvmContext;
auto llvmModule = mlir::translateModuleToLLVMIR(mlirModule, llvmContext);

// 自动设置宿主机的目标三元组
mlir::ExecutionEngine::setupTargetTriple(llvmModule.get());
```

#### 5.1.3 自定义目标三元组

```cpp
#include "llvm/IR/Module.h"

// 翻译后修改
llvmModule->setTargetTriple("my-custom-target-unknown-unknown");

// 或者设置数据布局
llvmModule->setDataLayout("e-m:e-p270:32:32-p271:32:32-p272:64:64-"
                          "i64:64-f80:128-n8:16:32:64-S128");
```

### 5.2 数据布局 (Data Layout)

#### 5.2.1 概念

**数据布局**描述：
- 类型的**大小**（size）
- 类型的**对齐**（alignment）
- 类型的**首选对齐**（preferred alignment）
- 指针的**大小和对齐**
- **字节序**（endianness）
- **栈对齐**

#### 5.2.2 MLIR Data Layout 建模

**MLIR 使用 `DataLayoutSpecInterface`**：
```mlir
module attributes {
  llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-"
                     "i64:64-f80:128-n8:16:32:64-S128"
} {
  // ...
}
```

**Data Layout 属性解析**：
```
e       : 小端字节序
m:e     : mangling: ELF
p:270:32:32 : pointer size=64, abi alignment=32, preferred alignment=32
i64:64  : i64 size=64, alignment=64
f80:128 : f80 size=128, alignment=128
n8:16:32:64 : native integer widths
S128    : stack alignment=128
```

#### 5.2.3 从 LLVM Target 推导 Data Layout

**使用 Pass 推导**：
```bash
mlir-opt --llvm-target-to-data-layout input.mlir
```

**C++ API**：
```cpp
#include "mlir/Conversion/LLVMCommon/Target.h"

// 从 LLVM target 属性推导 data layout
mlir::LLVM::deriveDataLayoutFromTarget(module);
```

### 5.3 自定义 LLVM Backend 的目标配置

#### 5.3.1 设置自定义目标

```cpp
#include "llvm/IR/Module.h"
#include "llvm/Target/TargetMachine.h"

// 1. 翻译 MLIR → LLVM IR
llvm::LLVMContext llvmContext;
auto llvmModule = mlir::translateModuleToLLVMIR(mlirModule, llvmContext);

// 2. 设置自定义目标三元组
llvmModule->setTargetTriple("my-custom-target-unknown-unknown");

// 3. 设置自定义数据布局
llvmModule->setDataLayout("e-m:e-p:32:32-i64:64-n32");

// 4. 获取自定义 TargetMachine
std::string error;
const llvm::Target *target = 
    llvm::TargetRegistry::lookupTarget("my-custom-target", error);

if (!target) {
  llvm::errs() << "Failed to lookup target: " << error << "\n";
  return;
}

llvm::TargetOptions options;
std::unique_ptr<llvm::TargetMachine> TM = 
    target->createTargetMachine(
        "my-custom-target",  // Triple
        "generic",            // CPU
        "",                   // Features
        options,
        llvm::Reloc::PIC_
    );

// 5. 生成汇编
llvm::legacy::PassManager pass;
llvm::raw_fd_ostream dest("output.s", EC, llvm::sys::fs::OF_None);

if (TM->addPassesToEmitFile(pass, dest, nullptr, llvm::CGFT_AssemblyFile)) {
  llvm::errs() << "Failed to emit assembly\n";
  return;
}

pass.run(*llvmModule);
dest.flush();
```

---

## 6. 类型转换规则

### 6.1 MemRef 类型转换

**MemRef 是 MLIR 中最复杂的类型转换之一**。

#### 6.1.1 Ranked MemRef 描述符

**MemRef 描述符结构**：
```cpp
// C++ 结构体表示
template<typename T, size_t N>
struct MemRefDescriptor {
  T *allocated;       // 分配的指针（用于释放）
  T *aligned;         // 对齐的指针（用于访问）
  intptr_t offset;    // 偏移量
  intptr_t sizes[N];  // 各维度大小
  intptr_t strides[N];// 各维度步幅
};
```

**MLIR 类型 → LLVM 类型映射**：
```mlir
// 0D MemRef
memref<f32>
→ !llvm.struct<(ptr, ptr, i64)>

// 1D MemRef
memref<?xf32>
→ !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>

// 2D MemRef
memref<10x42xf32>
→ !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>

// 静态维度示例
memref<10x42x42x43x123xf32>
→ !llvm.struct<(ptr, ptr, i64, array<5 x i64>, array<5 x i64>)>
```

#### 6.1.2 Unranked MemRef 描述符

**Unranked MemRef 描述符**：
```mlir
// Unranked MemRef
memref<*xf32>
→ !llvm.struct<(i64, ptr)>  // (rank, pointer to ranked descriptor)
```

**内存布局**：
- 第一个字段：动态 rank（i64）
- 第二个字段：指向 ranked descriptor 的指针（void*）

### 6.2 函数类型转换

#### 6.2.1 基本规则

**函数类型转换规则**：
1. **多返回值** → 包装为结构体
2. **无返回值** → 使用 `!llvm.void`
3. **MemRef 参数** → 展开为多个标量参数
4. **函数指针参数** → 使用 `!llvm.ptr`

#### 6.2.2 转换示例

**示例 1: 无返回值函数**
```mlir
// MLIR
func.func @foo() -> ()

// LLVM Dialect
llvm.func @foo() -> !llvm.void
```

**示例 2: 单返回值函数**
```mlir
// MLIR
func.func @add(%a: i32, %b: i32) -> i32

// LLVM Dialect
llvm.func @add(%a: i32, %b: i32) -> i32
```

**示例 3: 多返回值函数**
```mlir
// MLIR
func.func @divmod(%a: i32, %b: i32) -> (i32, i32)

// LLVM Dialect
llvm.func @divmod(%a: i32, %b: i32) -> !llvm.struct<(i32, i32)>
```

**示例 4: MemRef 参数**
```mlir
// MLIR
func.func @process(%arg0: memref<?xf32>) -> ()

// LLVM Dialect（展开为多个参数）
llvm.func @process(
  %arg0: !llvm.ptr,  // allocated pointer
  %arg1: !llvm.ptr,  // aligned pointer
  %arg2: i64,        // offset
  %arg3: i64,        // size in dim 0
  %arg4: i64         // stride in dim 0
) -> !llvm.void
```

### 6.3 向量类型转换

**MLIR 支持多维向量，LLVM 只支持一维向量**。

**转换规则**：
- **1D 向量**：直接映射
- **ND 向量**：转换为 (N-1)D 数组 + 1D 向量

```mlir
// 1D 向量（直接映射）
vector<8xf32>
→ !llvm.vec<8 x f32>

// 2D 向量（转换为数组）
vector<4x8xf32>
→ !llvm.array<4 x vector<8 x f32>>

// 3D 向量
vector<2x4x8xf32>
→ !llvm.array<2 x array<4 x vector<8 x f32>>>
```

---

## 7. 调用约定

### 7.1 默认调用约定

#### 7.1.1 MemRef 调用约定

**默认约定**：MemRef 描述符在函数边界**展开为多个标量参数**。

**示例**：
```mlir
// 调用者
func.func @caller() {
  %0 = "get"() : () -> (memref<?xf32>)
  call @callee(%0) : (memref<?xf32>) -> ()
  return
}

// 被调用者
func.func @callee(%arg0: memref<?xf32>) {
  "use"(%arg0) : (memref<?xf32>) -> ()
  return
}
```

**转换后的 LLVM Dialect**：
```mlir
// 调用者
llvm.func @caller() {
  %0 = "get"() : () -> !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  
  // 解包描述符
  %1 = llvm.extractvalue %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %2 = llvm.extractvalue %0[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %3 = llvm.extractvalue %0[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %4 = llvm.extractvalue %0[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %5 = llvm.extractvalue %0[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  
  // 调用
  llvm.call @callee(%1, %2, %3, %4, %5) : (!llvm.ptr, !llvm.ptr, i64, i64, i64) -> ()
  llvm.return
}

// 被调用者
llvm.func @callee(
  %arg0: !llvm.ptr,
  %arg1: !llvm.ptr,
  %arg2: i64,
  %arg3: i64,
  %arg4: i64
) {
  // 重新打包描述符
  %0 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %1 = llvm.insertvalue %arg0, %0[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %2 = llvm.insertvalue %arg1, %1[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %3 = llvm.insertvalue %arg2, %2[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %4 = llvm.insertvalue %arg3, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  %5 = llvm.insertvalue %arg4, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
  
  "use"(%5) : (!llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>) -> ()
  llvm.return
}
```

### 7.2 Bare Pointer 调用约定

**Bare Pointer 约定**：MemRef 参数仅传递**对齐后的数据指针**。

**限制**：
- MemRef 必须是**默认布局**
- 所有维度必须**静态已知**
- 分配指针和对齐指针必须**相同**

**示例**：
```mlir
// MLIR
func.func @callee(memref<2x4xf32>)
func.func @caller(%0: memref<2x4xf32>) {
  call @callee(%0) : (memref<2x4xf32>) -> ()
}

// LLVM Dialect（Bare Pointer 约定）
llvm.func @callee(!llvm.ptr)

llvm.func @caller(%arg0: !llvm.ptr) {
  // 直接传递指针
  llvm.call @callee(%arg0) : (!llvm.ptr) -> ()
  llvm.return
}
```

### 7.3 C 兼容包装器

**生成与 C 兼容的函数包装器**（用于外部调用）。

**启用方式**：
```cpp
// 在转换 pass 中启用
converter.setCWrapperEmitter(true);

// 或在函数级别设置属性
func.func @foo(%arg0: memref<?xf32>) attributes {llvm.emit_c_interface}
```

**生成的包装器**：
```cpp
// C 兼容的结构体
template<typename T, size_t N>
struct MemRefDescriptor {
  T *allocated;
  T *aligned;
  intptr_t offset;
  intptr_t sizes[N];
  intptr_t strides[N];
};

// 包装器函数
extern "C" void foo(MemRefDescriptor<float, 1> *desc);
```

---

## 8. 代码示例

### 8.1 完整的转换流程示例

```cpp
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Builders.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Conversion/FuncToLLVM/FuncToLLVM.h"
#include "mlir/Conversion/ArithToLLVM/ArithToLLVM.h"
#include "mlir/Target/LLVMIR/Export.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/Support/raw_ostream.h"

using namespace mlir;

void exampleConversion() {
  // 1. 创建 MLIR Context
  MLIRContext context;
  context.loadDialect<LLVM::LLVMDialect, func::FuncDialect>();
  
  // 2. 构建 MLIR Module
  OpBuilder builder(&context);
  auto module = ModuleOp::create(UnknownLoc::get(&context));
  
  // 创建一个简单的函数
  builder.setInsertionPointToStart(module.getBody());
  auto funcType = builder.getFunctionType({builder.getI32Type()}, builder.getI32Type());
  auto func = func::FuncOp::create(UnknownLoc::get(&context), "test", funcType);
  func.addEntryBlock();
  builder.insert(func);
  
  builder.setInsertionPointToStart(&func.getBody().front());
  auto arg = func.getArgument(0);
  auto result = builder.create<arith::AddIOp>(UnknownLoc::get(&context), arg, arg);
  builder.create<func::ReturnOp>(UnknownLoc::get(&context), result);
  
  // 3. 转换到 LLVM Dialect
  ConversionTarget target(context);
  target.addLegalDialect<LLVM::LLVMDialect>();
  target.addLegalOp<ModuleOp>();
  
  LLVMTypeConverter typeConverter(&context);
  RewritePatternSet patterns(&context);
  
  populateFuncToLLVMConversionPatterns(typeConverter, patterns);
  arith::populateArithToLLVMConversionPatterns(typeConverter, patterns);
  
  if (failed(applyFullConversion(module, target, std::move(patterns)))) {
    llvm::errs() << "Conversion failed\n";
    return;
  }
  
  // 4. 翻译到 LLVM IR
  llvm::LLVMContext llvmContext;
  auto llvmModule = translateModuleToLLVMIR(module, llvmContext);
  
  if (!llvmModule) {
    llvm::errs() << "Translation failed\n";
    return;
  }
  
  // 5. 打印 LLVM IR
  llvm::outs() << *llvmModule << "\n";
}
```

### 8.2 MLIR 代码示例

**输入 MLIR 代码**：
```mlir
module {
  func.func @add(%arg0: i32, %arg1: i32) -> i32 {
    %0 = arith.addi %arg0, %arg1 : i32
    return %0 : i32
  }
}
```

**转换后的 LLVM Dialect**：
```mlir
module {
  llvm.func @add(%arg0: i32, %arg1: i32) -> i32 {
    %0 = llvm.add %arg0, %arg1 : i32
    llvm.return %0 : i32
  }
}
```

**翻译后的 LLVM IR**：
```llvm
define i32 @add(i32 %0, i32 %1) {
  %2 = add i32 %0, %1
  ret i32 %2
}
```

---

## 9. 与自定义 LLVM 后端对接

### 9.1 对接点选择

**三个主要对接层次**：

| 层次 | 优点 | 缺点 | 开发量 |
|------|------|------|--------|
| **LLVM IR 层** | 最简单，复用最多 | 可能包含 GPU 特定代码 | ⭐⭐ |
| **LLVM Dialect 层** | 更早介入，可控性好 | 需要了解 MLIR | ⭐⭐⭐ |
| **转换前层** | 完全控制 | 工作量最大 | ⭐⭐⭐⭐⭐ |

### 9.2 LLVM IR 层对接（推荐）

**架构**：
```
MLIR (任意 dialects)
      ↓
LLVM Dialect
      ↓
【对接点】translateModuleToLLVMIR()
      ↓
修改 LLVM Module
  - setTargetTriple("my-custom-target")
  - setDataLayout("e-m:e-p:32:32-i64:64")
      ↓
自定义 LLVM Backend
      ↓
自定义汇编代码
```

**实现步骤**：

```cpp
// 1. 翻译 MLIR → LLVM IR
llvm::LLVMContext llvmContext;
auto llvmModule = mlir::translateModuleToLLVMIR(mlirModule, llvmContext);

// 2. 修改目标三元组和数据布局
llvmModule->setTargetTriple("my-custom-target-unknown-unknown");
llvmModule->setDataLayout("e-m:e-p:32:32-i64:64-n32");

// 3. 获取自定义 TargetMachine
const llvm::Target *target = 
    llvm::TargetRegistry::lookupTarget("my-custom-target", error);
std::unique_ptr<llvm::TargetMachine> TM = 
    target->createTargetMachine(/* ... */);

// 4. 生成汇编
llvm::legacy::PassManager pass;
TM->addPassesToEmitFile(pass, dest, nullptr, llvm::CGFT_AssemblyFile);
pass.run(*llvmModule);
```

### 9.3 LLVM Dialect 层对接

**架构**：
```
MLIR (任意 dialects)
      ↓
【对接点】自定义转换 passes
      ↓
LLVM Dialect（自定义）
      ↓
translateModuleToLLVMIR()
      ↓
自定义 LLVM Backend
```

**实现要点**：
1. 在 LLVM Dialect 转换阶段添加自定义 passes
2. 修改或扩展 LLVM Dialect 操作
3. 使用自定义的 translation 接口

### 9.4 自定义 LLVM Backend 集成检查清单

**必要步骤**：
- ✅ LLVM backend 已注册（`LLVMInitializeMyTarget*`）
- ✅ TargetMachine 创建成功
- ✅ 数据布局匹配
- ✅ ABI 兼容（调用约定、类型大小等）

**测试流程**：
1. 简单函数测试（add, sub）
2. 内存操作测试（load, store）
3. 控制流测试（branch, loop）
4. 函数调用测试（call, return）
5. 复杂类型测试（struct, array）

---

## 10. 调试技巧

### 10.1 IR 转储

**MLIR 层**：
```bash
# 转储 MLIR passes
mlir-opt --mlir-print-ir-after-all input.mlir

# 转储特定 pass
mlir-opt --mlir-print-ir-before=convert-func-to-llvm input.mlir
```

**LLVM IR 层**：
```cpp
// 在翻译后转储 LLVM IR
llvm::outs() << *llvmModule << "\n";

// 在优化前后转储
optPipeline(llvmModule.get());
llvm::outs() << "After optimization:\n" << *llvmModule << "\n";
```

### 10.2 类型转换调试

```cpp
// 启用类型转换调试
LLVMTypeConverter typeConverter(&context);

// 检查类型转换
Type mlirType = /* ... */;
Type llvmType = typeConverter.convertType(mlirType);
if (!llvmType) {
  llvm::errs() << "Failed to convert type: " << mlirType << "\n";
}
```

### 10.3 转换失败调试

```cpp
// 使用 PartialConversion 而不是 FullConversion
if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
  // 检查哪些操作未转换
  module.walk([&](Operation *op) {
    if (!target.isLegal(op)) {
      llvm::errs() << "Illegal operation: " << op->getName() << "\n";
    }
  });
}
```

### 10.4 常见问题

**问题 1: 类型不匹配**
```
error: failed to legalize operation 'foo.bar'
```
**解决**：检查 TypeConverter 是否正确配置，添加必要的 conversion patterns。

**问题 2: 目标不支持**
```
error: target does not support this operation
```
**解决**：检查 ConversionTarget 配置，确保所有必要操作标记为合法。

**问题 3: LLVM IR 验证失败**
```
error: LLVM IR verification failed
```
**解决**：检查 LLVM Dialect 操作的正确性，特别是类型和属性。

---

## 11. 参考资料

### 11.1 官方文档

- **LLVM IR Target**: https://mlir.llvm.org/docs/TargetLLVMIR/
- **LLVM Dialect**: https://mlir.llvm.org/docs/Dialects/LLVM/
- **Dialect Conversion**: https://mlir.llvm.org/docs/DialectConversion/
- **Data Layout**: https://mlir.llvm.org/docs/DataLayout/

### 11.2 教程

- **Toy Tutorial Chapter 6**: https://mlir.llvm.org/docs/Tutorials/Toy/Ch-6/
- **Using mlir-opt**: https://mlir.llvm.org/docs/Tutorials/MlirOpt

### 11.3 源代码

- **ModuleTranslation**: `mlir/lib/Target/LLVMIR/ModuleTranslation.cpp`
- **LLVM Dialect**: `mlir/lib/Dialect/LLVMIR/`
- **Conversion Passes**: `mlir/lib/Conversion/`

### 11.4 相关 RFC 和讨论

- **Mandatory Data Layout**: https://discourse.llvm.org/t/mandatory-data-layout-in-the-llvm-dialect/85875
- **Target Triple Propagation**: https://reviews.llvm.org/D92182

---

## 12. 总结与建议

### 12.1 核心要点

1. ✅ **两阶段流程**：Conversion（MLIR → LLVM Dialect）+ Translation（LLVM Dialect → LLVM IR）
2. ✅ **类型系统**：理解 LLVM Dialect 类型和转换规则
3. ✅ **目标配置**：正确设置 target triple 和 data layout
4. ✅ **调用约定**：理解 MemRef 的参数传递机制

### 12.2 最小化对接建议

**推荐路径**：LLVM IR 层对接
1. 使用 `translateModuleToLLVMIR` 获取 LLVM IR
2. 修改 `target triple` 和 `data layout`
3. 调用自定义 LLVM backend

**开发周期**：1-2 周

### 12.3 后续行动

1. **实验 LLVM IR 对接**（优先）
2. **测试简单 kernel**
3. **逐步增加复杂度**

---

*本文档由冰美（bot-a）基于 2026-03-08 的深度调研生成*
*最后更新：2026-03-08 15:53*
