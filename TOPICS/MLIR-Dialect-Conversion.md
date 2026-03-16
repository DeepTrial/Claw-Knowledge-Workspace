---
id: KB-20260308-005
title: MLIR Dialect Conversion 深度调研
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [MLIR, Dialect Conversion, 类型转换，模式重写]
status: done
---

# MLIR Dialect Conversion 深度调研

> **知识库 ID**: KB-20260308-005
> **创建时间**: 2026-03-08
> **优先级**: P2（中）
> **状态**: 已完成
> **贡献者**: main

---

## 📋 概述

Dialect Conversion 是 MLIR 中用于在不同 Dialect 之间或同一 Dialect 内部转换操作的核心框架。它通过**基于模式的操作重写**，将非法操作转换为目标 Dialect 支持的合法操作。

### 核心价值
- **统一的转换框架**：所有 Dialect 间转换使用同一套基础设施
- **自动转换图构建**：框架自动构建转换路径
- **类型安全保证**：通过 TypeConverter 确保类型一致性
- **多模式支持**：部分转换、完全转换、分析转换

---

## 🏗️ 框架组成

### 三大核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                   Dialect Conversion 框架                   │
├─────────────────────────────────────────────────────────────┤
│  1. ConversionTarget  │  定义目标合法性（哪些操作是合法的）  │
│  2. Rewrite Patterns  │  转换规则（如何将非法操作转为合法）  │
│  3. TypeConverter     │  类型转换（可选，处理类型差异）      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 转换模式

### 1. Partial Conversion（部分转换）

**特点**：
- 尽可能将操作合法化
- 允许未标记为"非法"的操作保持不变
- 适用于渐进式转换

**API**：
```cpp
LogicalResult applyPartialConversion(
  Operation *op,
  ConversionTarget &target,
  const FrozenRewritePatternSet &patterns
);
```

**使用场景**：
- 部分 lowering（如只转换计算密集部分）
- 混合 Dialect 共存

---

### 2. Full Conversion（完全转换）

**特点**：
- 所有输入操作必须被合法化
- 只有成功转换所有操作才算成功
- 确保转换后只有已知操作

**API**：
```cpp
LogicalResult applyFullConversion(
  Operation *op,
  ConversionTarget &target,
  const FrozenRewritePatternSet &patterns
);
```

**使用场景**：
- 完全 lowering 到目标 Dialect
- 确保输出 IR 纯净

---

### 3. Analysis Conversion（分析转换）

**特点**：
- 分析哪些操作可以被合法化
- 不实际执行转换
- 用于预检查

**API**：
```cpp
LogicalResult applyAnalysisConversion(
  Operation *op,
  ConversionTarget &target,
  const FrozenRewritePatternSet &patterns
);
```

---

## 🎯 ConversionTarget 详解

### 合法性动作

| 动作 | 含义 | API |
|------|------|-----|
| **Legal** | 所有实例都合法 | `addLegalOp<Op>()` / `addLegalDialect<Dialect>()` |
| **Dynamic** | 部分实例合法（需回调判断） | `addDynamicallyLegalOp<Op>(callback)` |
| **Illegal** | 所有实例都非法 | `addIllegalOp<Op>()` / `addIllegalDialect<Dialect>()` |

### 示例

```cpp
struct MyTarget : public ConversionTarget {
  MyTarget(MLIRContext &ctx) : ConversionTarget(ctx) {
    // 标记 LLVM Dialect 所有操作为合法
    addLegalDialect<LLVMDialect>();
    
    // 标记特定操作为合法
    addLegalOp<arith::ConstantOp>();
    
    // 动态合法性：只有 32 位整数的 arith.addi 才合法
    addDynamicallyLegalOp<arith::AddIOp>([](arith::AddIOp op) {
      auto type = op.getType();
      return type.isInteger(32);
    });
    
    // 标记 GPU Dialect 所有操作为非法
    addIllegalDialect<GPUDialect>();
    
    // 标记特定操作为非法
    addIllegalOp<cf::BranchOp, cf::CondBranchOp>();
  }
  
  // 处理未显式设置的动态合法操作
  bool isDynamicallyLegal(Operation *op) override { ... }
};
```

### 递归合法性

将整个 Region 标记为合法（嵌套操作也合法）：

```cpp
// 先标记为 Legal 或 Dynamic
target.addLegalOp<MyOp>();

// 然后标记为递归合法
target.markOpRecursivelyLegal<MyOp>();

// 带回调的选择性递归合法
target.markOpRecursivelyLegal<MyOp>([](MyOp op) {
  return op.hasSomeProperty();
});
```

---

## 🔧 ConversionPattern 详解

### 核心概念

**ConversionPattern** 是专门用于 Dialect Conversion 的 RewritePattern，它提供：
1. **Remapped Operands**：已重映射的操作数
2. **Type Safety**：类型安全保证
3. **Rollback Support**：回滚支持

### 基本结构

```cpp
struct MyConversionPattern : public ConversionPattern {
  MyConversionPattern(TypeConverter &converter, MLIRContext *context)
      : ConversionPattern(converter, MyOp::getOperationName(), 1, context) {}
  
  LogicalResult matchAndRewrite(
    Operation *op, 
    ArrayRef<Value> operands,  // 已重映射的操作数
    ConversionPatternRewriter &rewriter
  ) const override {
    // 匹配和重写逻辑
    return success();
  }
};
```

### OpConversionPattern 模板

针对特定操作类型的便捷模板：

```cpp
struct TransposeOpLowering : public OpConversionPattern<toy::TransposeOp> {
  using OpConversionPattern<toy::TransposeOp>::OpConversionPattern;
  
  LogicalResult matchAndRewrite(
    toy::TransposeOp op,
    OpAdaptor adaptor,  // 类型安全的操作数适配器
    ConversionPatternRewriter &rewriter
  ) const final {
    // 获取已转换的操作数
    Value input = adaptor.getInput();
    
    // 创建新操作
    ...
    
    return success();
  }
};
```

---

### Remapped Operands / Adaptor

**核心机制**：当操作数被其他 pattern 替换为不同类型的值时，框架自动插入 `builtin.unrealized_conversion_cast`。

**示例**：
```
原始 IR:
  %0 = "test.foo"() : () -> i1
  "test.bar"(%0) : (i1) -> ()

Pattern A 应用后:
  %0 = "test.qux"() : () -> i2        // 类型从 i1 变为 i2
  %r = builtin.unrealized_conversion_cast %0 : i2 to i1
  "test.bar"(%r) : (i1) -> ()

Pattern B 应用时:
  - op.getOperand() 返回 %r（类型 i1）
  - operands 参数包含 %0（类型 i2）
```

**Adaptor 的优势**：
- 类型安全访问
- 自动处理操作数映射
- 与 TypeConverter 集成

---

### Immediate vs Delayed IR Modification

**两种模式**：

| 模式 | 特点 | 控制 |
|------|------|------|
| **Rollback Mode**（默认） | IR 修改延迟，支持回滚 | `ConversionConfig::allowPatternRollback = true` |
| **No-Rollback Mode** | IR 修改立即生效，更快 | `ConversionConfig::allowPatternRollback = false` |

**延迟操作（Rollback Mode）**：

| 操作类型 | Rollback Mode | No-Rollback Mode |
|----------|---------------|------------------|
| Op Insertion | 立即 | 立即 |
| Op Replacement (`replaceOp`) | **延迟** | 立即 |
| Op Erasure (`eraseOp`) | **延迟** | 立即 |
| Value Replacement | **延迟** | 立即 |
| Block Signature Conversion | 部分延迟 | 立即 |

**建议**：
- 调试时使用 Rollback Mode
- 生产环境优先使用 No-Rollback Mode（更快）

---

## 🔄 TypeConverter 详解

### 两大功能

```
TypeConverter
├── Conversion（类型转换）
│   ├── Context-unaware: Type → Type
│   └── Context-aware: Value → Type
│
└── Materialization（具体化）
    ├── Source Materialization: 目标类型 → 源类型
    ├── Target Materialization: 源类型 → 目标类型
    └── Argument Materialization: Block 参数类型转换
```

### 类型转换

```cpp
TypeConverter converter;

// 1:1 类型转换（Context-unaware）
converter.addConversion([](FloatType t) -> std::optional<Type> {
  return IntegerType::get(t.getContext(), t.getWidth());
});

// 1:N 类型转换
converter.addConversion([](ComplexType t, SmallVectorImpl<Type> &types) 
  -> std::optional<LogicalResult> {
  types.push_back(t.getElementType());  // 实部
  types.push_back(t.getElementType());  // 虚部
  return success();
});

// Context-aware 类型转换
converter.addConversion([](Value v) -> std::optional<Type> {
  // 可以根据 IR 上下文决定转换
  if (auto use = v.getUses().begin()) {
    return transformBasedOnUse(v.getType(), *use);
  }
  return std::nullopt;
});
```

**注意**：
- Context-unaware 转换会被缓存
- Context-aware 转换不被缓存
- 建议尽早添加 context-aware 转换（后添加的先执行）

---

### Materialization

**三种 Materialization**：

#### 1. Source Materialization

**用途**：将替换值转换回原始类型

**场景**：
- Block 参数被转换，但仍有用户需要原始类型
- 操作结果被转换，但仍有用户需要原始类型

```cpp
converter.addSourceMaterialization([](
  OpBuilder &builder, 
  Type resultType, 
  ValueRange inputs, 
  Location loc
) -> std::optional<Value> {
  // 创建类型转换操作
  return builder.create<UnrealizedConversionCastOp>(
    loc, resultType, inputs
  ).getResult(0);
});
```

#### 2. Target Materialization

**用途**：将值转换为 Pattern 期望的目标类型

```cpp
converter.addTargetMaterialization([](
  OpBuilder &builder,
  Type outputType,
  ValueRange inputs,
  Location loc,
  Type originalType  // 原始类型（可选）
) -> std::optional<Value> {
  return builder.create<SomeCastOp>(loc, outputType, inputs[0]);
});
```

#### 3. Argument Materialization

**用途**：Block 参数类型转换

```cpp
converter.addArgumentMaterialization([](
  OpBuilder &builder,
  Type resultType,
  ValueRange inputs,
  Location loc
) -> std::optional<Value> {
  return builder.create<BuiltinCastOp>(loc, resultType, inputs[0]);
});
```

---

### Region Signature Conversion

**用途**：转换 Region 中 Block 参数的类型

```cpp
// 转换整个 Region 的 Block 参数类型
FailureOr<Block*> convertRegionTypes(
  Region *region,
  const TypeConverter &converter,
  TypeConverter::SignatureConversion *entryConversion = nullptr
);

// 转换单个 Block 的签名
Block* applySignatureConversion(
  Block *block,
  TypeConverter::SignatureConversion &conversion,
  const TypeConverter *converter = nullptr
);
```

**SignatureConversion 构建**：

```cpp
TypeConverter::SignatureConversion conversion(numOldArgs);

// 1:1 映射
conversion.remapInput(0, newArg0);

// 1:N 映射
conversion.addInputs(1, {newType1, newType2});

// 完全替换
conversion.remapInput(2, replacementValue);
```

---

## 📊 转换图自动构建

框架会自动构建转换图：

```
目标：foo.add 合法

提供的 Patterns：
  bar.add -> baz.add
  baz.add -> foo.add

框架自动检测：
  bar.add -> baz.add -> foo.add ✓
```

**优势**：
- 无需定义直接转换
- 支持多步转换链
- 自动选择最短路径

---

## 🛠️ 完整示例

### Toy to Affine Lowering

```cpp
void ToyToAffineLoweringPass::runOnOperation() {
  // 1. 定义 ConversionTarget
  ConversionTarget target(getContext());
  target.addLegalDialect<
    affine::AffineDialect,
    arith::ArithDialect,
    func::FuncDialect,
    memref::MemRefDialect
  >();
  
  // Toy Dialect 非法，但 toy.print 动态合法
  target.addIllegalDialect<ToyDialect>();
  target.addDynamicallyLegalOp<toy::PrintOp>([](toy::PrintOp op) {
    return !llvm::any_of(op->getOperandTypes(), 
                         llvm::IsaPred<TensorType>);
  });
  
  // 2. 定义 Rewrite Patterns
  RewritePatternSet patterns(&getContext());
  patterns.add<
    TransposeOpLowering,
    MulOpLowering,
    ConstantOpLowering
  >(&getContext());
  
  // 3. 应用 Partial Conversion
  if (failed(applyPartialConversion(getOperation(), target, patterns)))
    signalPassFailure();
}
```

---

## 🔍 调试工具

### 启用调试日志

```bash
mlir-opt input.mlir \
  -convert-linalg-to-loops \
  -debug-only=dialect-conversion
```

### 输出示例

```
//===-------------------------------------------===//
Legalizing operation : 'func.return'(0x608000002e20) {
  "func.return"() : () -> ()

  * Fold {
  } -> FAILURE : unable to fold

  * Pattern : 'func.return -> ()' {
    ** Insert  : 'spirv.Return'(0x6070000453e0)
    ** Replace : 'func.return'(0x608000002e20)

    //===-------------------------------------------===//
    Legalizing operation : 'spirv.Return'(0x6070000453e0) {
      "spirv.Return"() : () -> ()

    } -> SUCCESS : operation marked legal by the target
    //===-------------------------------------------===//

  } -> SUCCESS : pattern applied successfully
} -> SUCCESS
//===-------------------------------------------===//
```

---

## 📚 对 Triton 项目的启示

### 关键发现

1. **Dialect Conversion 是成熟的转换框架**
   - 自动转换图构建
   - 类型安全保证
   - 多种转换模式

2. **核心 API 清晰**
   - `applyPartialConversion`：部分转换
   - `applyFullConversion`：完全转换
   - `ConversionTarget`：定义目标合法性
   - `ConversionPattern`：定义转换规则

3. **TypeConverter 是关键**
   - 处理 Triton 类型到 LLVM 类型的映射
   - Materialization 处理类型差异

### 应用场景

**场景 1：Triton IR → LLVM IR**
```cpp
// 定义目标
ConversionTarget target(getContext());
target.addLegalDialect<LLVMDialect>();

// 定义类型转换
TypeConverter converter;
converter.addConversion([](TritonType t) { ... });

// 定义转换规则
patterns.add<TritonOpToLLVMOpLowering>(&getContext());

// 应用转换
applyFullConversion(op, target, patterns);
```

**场景 2：渐进式 Lowering**
```cpp
// 阶段 1：Triton → Standard Dialects
applyPartialConversion(op, target1, patterns1);

// 阶段 2：Standard → LLVM
applyFullConversion(op, target2, patterns2);
```

---

## 🔬 待深入研究课题

### 1. 转换图优化算法
- **课题**: 框架如何选择最优转换路径
- **优先级**: P2
- **应用**: 理解性能特性

### 2. TypeConverter 缓存机制
- **课题**: Context-aware 转换的缓存策略
- **优先级**: P2
- **应用**: 性能优化

### 3. Rollback 机制的实现
- **课题**: 模式回滚的内部实现
- **优先级**: P3
- **应用**: 调试复杂转换

### 4. 1:N 类型转换的处理
- **课题**: 一个类型拆分为多个类型的完整流程
- **优先级**: P1
- **应用**: 复杂类型映射

### 5. Pattern Benefit 与成本模型
- **课题**: 如何设计合理的 pattern benefit
- **优先级**: P2
- **应用**: 优化转换效率

---

## 📝 总结

### 核心要点

1. **三大组件**：ConversionTarget + Patterns + TypeConverter
2. **三种模式**：Partial / Full / Analysis Conversion
3. **三种合法性**：Legal / Dynamic / Illegal
4. **Remapped Operands**：自动处理操作数映射
5. **Type Safety**：通过 TypeConverter 保证类型一致性

### 最佳实践

1. **优先使用 No-Rollback Mode**（除非调试）
2. **尽早添加 Context-aware 转换**
3. **利用自动转换图构建**
4. **使用 `-debug-only=dialect-conversion` 调试**
5. **渐进式 Lowering 使用 Partial Conversion**

---

*最后更新：2026-03-08 | 耗时：约 2 小时*
