# 自定义 Dialect 定义 深度调研

> **知识库 ID**: KB-20260308-006
> **创建时间**: 2026-03-08
> **优先级**: P2（中）
> **状态**: 已完成
> **贡献者**: main

---

## 📋 概述

MLIR 提供了强大的**声明式规范机制**（ODS - Operation Definition Specification），通过 **TableGen** 语言定义 Dialect、Operations、Types 和 Attributes，自动生成 C++ 代码，显著减少样板代码。

### 核心价值
- **自动代码生成**：.td → .h.inc / .cpp.inc
- **单点事实源**：所有定义集中在一处
- **减少维护负担**：修改定义自动传播
- **文档自动生成**：从定义生成 Markdown 文档

---

## 🏗️ Dialect 定义

### 基本结构

```tablegen
// 包含基础定义
include "mlir/IR/DialectBase.td"

def MyDialect : Dialect {
  let summary = "A short one line description of my dialect.";
  
  let description = [{
    My dialect is a very important dialect. This section contains a much more
    detailed description that documents all of the important pieces of information.
  }];
  
  // Dialect 命名空间（用于操作名前缀，如 "my_dialect.foo"）
  let name = "my_dialect";
  
  // C++ 命名空间
  let cppNamespace = "::my_dialect";
  
  // 依赖的其他 Dialect
  let dependentDialects = [
    "arith::ArithDialect",
    "func::FuncDialect"
  ];
}
```

### 关键字段

| 字段 | 说明 |
|------|------|
| `name` | Dialect 命名空间（操作名前缀） |
| `cppNamespace` | C++ 命名空间（支持嵌套 `::`） |
| `summary` | 单行描述 |
| `description` | 详细描述（Markdown 格式） |
| `dependentDialects` | 依赖的其他 Dialect |
| `isExtensible` | 是否支持运行时扩展 |
| `useDefaultAttributePrinterParser` | 使用默认属性解析器（默认 1） |
| `useDefaultTypePrinterParser` | 使用默认类型解析器（默认 1） |

### C++ 类名生成规则

TableGen 定义的名称会自动去除 `_` 字符：
- `My_Dialect` → `MyDialect`
- `Foo_Bar_Dialect` → `FooBarDialect`

---

## 🔧 Operation 定义

### 基本结构

```tablegen
// 定义基础 Op 类
class MyDialect_Op<string mnemonic, list<Trait> traits = []> :
    Op<MyDialect, mnemonic, traits>;

// 定义具体操作
def AddOp : MyDialect_Op<"add", [NoMemoryEffect]> {
  let summary = "Element-wise addition";
  
  let description = [{
    Performs element-wise addition of two tensors.
  }];
  
  // 操作数和属性
  let arguments = (ins
    F32Tensor:$lhs,
    F32Tensor:$rhs,
    OptionalAttr<F32Attr>:$bias
  );
  
  // 结果
  let results = (outs
    F32Tensor:$result
  );
  
  // 汇编格式
  let assemblyFormat = [{
    $lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)
  }];
  
  // 启用验证器
  let hasVerifier = 1;
}
```

### 参数类型

#### 1. Operands（操作数）

```tablegen
let arguments = (ins
  I32:$i32_operand,           // 单个 i32 操作数
  Variadic<AnyType>:$args,    // 可变数量操作数
  Optional<I32>:$opt,         // 可选操作数
);
```

#### 2. Attributes（属性）

```tablegen
let arguments = (ins
  I32Attr:$value,             // 整数属性
  F32Attr:$float_val,         // 浮点属性
  StrAttr:$name,              // 字符串属性
  UnitAttr:$is_read_only,     // 单元属性（布尔标志）
  ArrayAttr:$dims,            // 数组属性
  DefaultValuedAttr<I32Attr, "0">:$padding,  // 带默认值
  OptionalAttr<F32Attr>:$bias,  // 可选属性
);
```

#### 3. Properties（属性，内联存储）

```tablegen
let arguments = (ins
  I32Prop:$inline_param,      // 内联属性（不存储在 MLIR context 中）
);
```

### 结果定义

```tablegen
let results = (outs
  I32:$single,                // 单个结果
  Variadic<AnyType>:$multi,   // 可变数量结果
);
```

### Regions

```tablegen
let regions = (region
  AnyRegion:$body,            // 单个 region
  VariadicRegion<AnyRegion>:$nested,  // 可变数量 regions
);
```

### Successors

```tablegen
let successors = (successor
  AnySuccessor:$dest,         // 单个后继
);
```

---

### Assembly Format（汇编格式）

#### 基本语法

```tablegen
let assemblyFormat = [{
  $lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)
}];
```

#### 关键字

| 关键字 | 说明 |
|--------|------|
| `attr-dict` | 属性字典 |
| `type($operand)` | 操作数类型 |
| `functional-type($args, $results)` | 函数类型语法 |
| `custom<Directive>($params)` | 自定义指令 |
| `qualified($type)` | 带命名空间的类型 |
| `params` | 所有参数（简写） |

#### 可选组

```tablegen
// 条件打印
let assemblyFormat = "attr-dict ($operands^ `:` type($operands))?";

// if-else
let assemblyFormat = "attr-dict (`foo_is_present` $foo^):(`foo_is_absent`)?";
```

---

### Builders（构建器）

```tablegen
let builders = [
  // 简单构建器
  OpBuilder<(ins "Value":$lhs, "Value":$rhs)>,
  
  // 带默认参数
  OpBuilder<(ins "Value":$lhs, CArg<"Value", "nullptr">:$rhs)>,
  
  // 内联实现
  OpBuilder<(ins "float":$val), [{
    $_state.addAttribute("attr", $_builder.getF32FloatAttr(val));
  }]>,
  
  // 推断 MLIRContext
  OpBuilderWithInferredContext<(ins "Type":$typeParam), [{
    return $_get(typeParam.getContext(), ...);
  }]>,
];
```

---

### Verifier（验证器）

```tablegen
// 启用操作验证器
let hasVerifier = 1;

// 启用 Region 验证器
let hasRegionVerifier = 1;
```

C++ 实现：
```cpp
LogicalResult AddOp::verify() {
  if (getLhs().getType() != getRhs().getType())
    return emitOpError("operands must have the same type");
  return success();
}
```

---

## 📦 Type 定义

### 基本结构

```tablegen
include "mlir/IR/AttrTypeBase.td"

// 定义基础 Type 类
class MyDialect_Type<string name, string mnemonic, list<Trait> traits = []>
    : TypeDef<MyDialect, name, traits> {
  let mnemonic = mnemonic;
}

// 定义具体类型
def IntegerType : MyDialect_Type<"Integer", "int"> {
  let summary = "Integer type with arbitrary precision";
  
  let description = [{
    Integer types have a designated bit width.
  }];
  
  // 参数
  let parameters = (ins "unsigned":$width);
  
  // 汇编格式
  let assemblyFormat = "`<` $width `>`";
  
  // 启用验证
  let genVerifyDecl = 1;
}
```

### 参数定义

```tablegen
let parameters = (ins
  "unsigned":$width,          // 简单类型
  "AffineMap":$map,           // 复杂类型
  ArrayRefIntParam:$dims,     // 自定义参数类型
  DefaultValuedParameter<"int", "0">:$padding,  // 带默认值
);
```

### 自定义参数类型

```tablegen
def ArrayRefIntParam : TypeParameter<"::llvm::ArrayRef<int>", "Array of int"> {
  let allocator = "$_dst = $_allocator.copyInto($_self);";
  let printer = [{ $_printer << $_self }];
  let parser = [{ ... }];
}
```

### Builders

```tablegen
let builders = [
  TypeBuilder<(ins "int":$width)>,
  TypeBuilder<(ins CArg<"int", "32">:$width)>,
  TypeBuilderWithInferredContext<(ins "Type":$element), [{
    return Base::get(element.getContext(), ...);
  }]>,
];
```

### 生成的 API

```cpp
// 获取实例
static IntegerType get(MLIRContext *context, unsigned width);

// 带验证的获取
static IntegerType getChecked(
  function_ref<InFlightDiagnostic()> emitError,
  MLIRContext *context, 
  unsigned width
);

// 访问参数
unsigned getWidth() const;
```

---

## 🏷️ Attribute 定义

### 基本结构

```tablegen
include "mlir/IR/AttrTypeBase.td"

// 定义基础 Attr 类
class MyDialect_Attr<string name, string mnemonic, list<Trait> traits = []>
    : AttrDef<MyDialect, name, traits> {
  let mnemonic = mnemonic;
}

// 定义具体属性
def IntegerAttr : MyDialect_Attr<"Integer", "int"> {
  let summary = "An Attribute containing an integer value";
  
  let parameters = (ins
    AttributeSelfTypeParameter<"">:$type,
    APIntParameter<"">:$value
  );
  
  let assemblyFormat = "`<` $value `>`";
  
  let genVerifyDecl = 1;
  let skipDefaultBuilders = 1;
  
  let builders = [
    AttrBuilderWithInferredContext<(ins "Type":$type, "const APInt &":$value), [{
      return $_get(type.getContext(), type, value);
    }]>
  ];
}
```

### TypedAttrInterface

对于带有类型的属性：

```tablegen
def MyExternAttr : AttrDef<MyDialect, "MyExtern", [TypedAttrInterface]> {
  let parameters = (ins AttributeSelfTypeParameter<"">:$type);
  let mnemonic = "extern";
  let assemblyFormat = "";  // 仅打印类型
}
```

输出：
```
#my_dialect.extern : i32
```

---

## 🔨 代码生成

### CMake 配置

```cmake
# Operations
add_mlir_dialect(FooOps foo)
add_mlir_doc(FooOps FooDialect Dialects/ -gen-dialect-doc)

# Types/Attributes
set(LLVM_TARGET_DEFINITIONS FooAttrDefs.td)
mlir_tablegen(FooAttrDefs.h.inc -gen-attrdef-decls -attrdefs-dialect=Foo)
mlir_tablegen(FooAttrDefs.cpp.inc -gen-attrdef-defs -attrdefs-dialect=Foo)
mlir_tablegen(FooTypeDefs.h.inc -gen-typedef-decls -typedefs-dialect=Foo)
mlir_tablegen(FooTypeDefs.cpp.inc -gen-typedef-defs -typedefs-dialect=Foo)
add_public_tablegen_target(FooAttrDefsIncGen)

# Transforms (DRR patterns)
set(LLVM_TARGET_DEFINITIONS FooTransforms.td)
mlir_tablegen(FooTransforms.h.inc -gen-rewriters)
add_public_tablegen_target(FooTransformsIncGen)
```

### Bazel 配置

```python
gentbl_sharded_ops(
    name = "MyDialectOpSrcs",
    hdr_out = "MyDialectOps.h.inc",
    shard_count = 8,
    sharder = "//mlir:mlir-src-sharder",
    src_file = "MyDialectOps.cpp",
    src_out = "MyDialectOps.cpp.inc",
    tblgen = "//mlir:mlir-tblgen",
    td_file = "MyDialectOps.td",
    deps = [":MyDialectOpsTdFiles"],
)
```

### 手动调用 mlir-tblgen

```bash
# 生成操作声明
mlir-tblgen MyDialect.td -gen-op-decls -I /path/to/mlir/include -o MyDialectOps.h.inc

# 生成操作定义
mlir-tblgen MyDialect.td -gen-op-defs -I /path/to/mlir/include -o MyDialectOps.cpp.inc

# 生成类型声明
mlir-tblgen MyDialect.td -gen-typedef-decls -typedefs-dialect=MyDialect -o MyDialectTypes.h.inc

# 生成属性定义
mlir-tblgen MyDialect.td -gen-attrdef-defs -attrdefs-dialect=MyDialect -o MyDialectAttrs.cpp.inc
```

---

### Dialect 初始化

```cpp
// MyDialect.cpp
#include "MyDialect.h"

// 包含生成的文件
#include "MyDialectOps.cpp.inc"
#include "MyDialectTypes.cpp.inc"
#include "MyDialectAttrs.cpp.inc"

void MyDialect::initialize() {
  // 注册操作（自动生成）
  registerMyDialectOperations(this);
  
  // 注册类型
  registerMyDialectTypes(this);
  
  // 注册属性
  registerMyDialectAttributes(this);
  
  // 添加接口
  addInterfaces<MyDialectInterface>();
}
```

---

## 🔌 Extensible Dialect（可扩展 Dialect）

### 定义可扩展 Dialect

**TableGen 方式**：
```tablegen
def Test_Dialect : Dialect {
  let isExtensible = 1;
  ...
}
```

**C++ 方式**：
```cpp
class MyDialect : public mlir::ExtensibleDialect {
  ...
};
```

### 运行时定义操作

```cpp
// 定义操作
std::unique_ptr<DynamicOpDefinition> opDef =
  DynamicOpDefinition::get(
    "my_op", 
    dialect,
    verifyFn,      // 验证函数
    parseFn,       // 解析函数
    printFn,       // 打印函数
    foldHookFn,    // Fold 钩子
    getCanonicalizationPatterns  // 规范化模式
  );

// 注册操作
extensibleDialect->registerDynamicOperation(std::move(opDef));
```

### 运行时定义类型

```cpp
std::unique_ptr<DynamicTypeDefinition> typeDef =
  DynamicTypeDefinition::get(
    "my_type",
    dialect,
    verifier,  // 参数验证
    printer,   // 参数打印
    parser     // 参数解析
  );

dialect->registerDynamicType(std::move(typeDef));
```

### 使用运行时定义的类型

```cpp
auto typeDef = extensibleDialect->lookupTypeDefinition("my_type");
ArrayRef<Attribute> params = {...};
auto type = DynamicType::get(typeDef, params);
```

---

## 📊 对 Triton 项目的启示

### 关键发现

1. **ODS 是定义 Dialect 的标准方式**
   - 自动生成大量样板代码
   - 维护成本低
   - 文档自动生成

2. **核心组件清晰**
   - Dialect：容器
   - Op：操作定义
   - Type：类型定义
   - Attr：属性定义

3. **可扩展 Dialect 提供运行时灵活性**
   - 无需重新编译 C++ 代码
   - 支持元编程定义

### 应用场景

**场景 1：为自定义 Backend 定义 Dialect**

```tablegen
def MyBackend_Dialect : Dialect {
  let name = "my_backend";
  let cppNamespace = "::my_backend";
  let summary = "Dialect for MyBackend";
}

// 定义操作
def MyBackend_AddOp : MyBackend_Op<"add"> {
  let arguments = (ins MyBackend_Tensor:$lhs, MyBackend_Tensor:$rhs);
  let results = (outs MyBackend_Tensor:$result);
}

// 定义类型
def MyBackend_Tensor : MyBackend_Type<"Tensor", "tensor"> {
  let parameters = (ins "ArrayRef<int64_t>":$shape, "Type":$element);
  let assemblyFormat = "`<` $shape `x` $element `>`";
}
```

**场景 2：定义 Triton 到自定义 Backend 的转换规则**

```tablegen
// 使用 DRR (Declarative Rewrite Rules)
def : Pat<(Triton_AddOp $lhs, $rhs),
          (MyBackend_AddOp $lhs, $rhs)>;
```

---

## 🔬 待深入研究课题

### 1. ODS 自定义参数类型
- **课题**: 复杂参数类型的 allocator/printer/parser 实现
- **优先级**: P2
- **应用**: 自定义复杂类型参数

### 2. Assembly Format 高级特性
- **课题**: custom directive、optional groups 完整语法
- **优先级**: P2
- **应用**: 设计友好的 IR 文本格式

### 3. DRR (Declarative Rewrite Rules)
- **课题**: 模式匹配和重写规则的声明式定义
- **优先级**: P1
- **应用**: 定义 Triton → 自定义 Backend 转换规则

### 4. Bytecode 序列化
- **课题**: 自定义 Dialect 的二进制序列化格式
- **优先级**: P2
- **应用**: 高效 IR 存储

### 5. Interface 定义
- **课题**: 自定义 OpInterface、TypeInterface、AttrInterface
- **优先级**: P1
- **应用**: 定义操作/类型的通用行为

### 6. Sharded Ops 生成
- **课题**: 大规模 Dialect 的分片代码生成
- **优先级**: P3
- **应用**: 减少编译时间

---

## 📝 总结

### 核心要点

1. **TableGen 是定义 Dialect 的核心工具**
2. **四大组件**: Dialect / Op / Type / Attr
3. **自动生成**: .h.inc / .cpp.inc
4. **Assembly Format**: 声明式语法定义文本格式
5. **Extensible Dialect**: 支持运行时扩展

### 最佳实践

1. **分层定义**: Dialect / Op / Type / Attr 分别放在不同 .td 文件
2. **使用完整命名空间**: 便于跨项目交互
3. **优先使用声明式语法**: 减少手动 C++ 代码
4. **利用文档生成**: summary + description 自动生成文档

---

*最后更新：2026-03-08 | 耗时：约 2.5 小时*
