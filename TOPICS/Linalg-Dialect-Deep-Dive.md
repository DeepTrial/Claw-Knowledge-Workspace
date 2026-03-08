# Linalg Dialect 深度调研

> **知识库 ID**: KB-20260308-004
> **创建时间**: 2026-03-08
> **优先级**: P1（高）
> **状态**: 已完成
> **贡献者**: main

---

## 📋 概述

Linalg（Linear Algebra）Dialect 是 MLIR 中用于表示**结构化操作**的核心 Dialect，专为高性能代码生成设计。它解决了 MLIR 架构中的 **High-level Hierarchical Optimization (HHO)** 问题。

### 核心定位
- **设计目标**: 编译器友好的自定义操作
- **核心原则**: 保持计算结构，延迟 lowering，支持变换
- **应用领域**: 深度学习、科学计算、GPU 编译

---

## 🏗️ 核心概念

### 1. 结构化操作（Structured Operations）

Linalg 的核心思想是**保持计算结构**，而非过早展开为循环。

**示例：矩阵乘法**
```mlir
// 高层结构化表示
%matmul = linalg.matmul 
  ins(%lhs, %rhs: tensor<8x10xf32>, tensor<10x16xf32>)
  outs(%init: tensor<8x16xf32>) 
  -> tensor<8x16xf32>
```

**关键优势**：
- 编译器理解操作语义
- 变换保持结构（tiling 后仍是 matmul）
- 可映射到库调用或硬件指令

---

### 2. Generic Operation

`linalg.generic` 是最通用的结构化操作，可表达任意计算。

**核心属性**：
```mlir
linalg.generic {
  indexing_maps = [affine_map<(i, j, k) -> (i, k)>,   // lhs 访问模式
                   affine_map<(i, j, k) -> (k, j)>,   // rhs 访问模式
                   affine_map<(i, j, k) -> (i, j)>],  // output 访问模式
  iterator_types = ["parallel", "parallel", "reduction"]  // 迭代器类型
} ins(%lhs, %rhs : tensor<8x10xf32>, tensor<10x16xf32>)
  outs(%init : tensor<8x16xf32>) {
^bb0(%lhs_one: f32, %rhs_one: f32, %init_one: f32):
  %0 = arith.mulf %lhs_one, %rhs_one : f32
  %1 = arith.addf %init_one, %0 : f32
  linalg.yield %1 : f32
} -> tensor<8x16xf32>
```

**6 个核心属性**：
1. **输入/输出操作数定义迭代空间**
2. **控制结构与数据结构间的可逆映射**
3. **显式声明迭代器类型**（parallel/reduction）
4. **使用 Region 指定计算负载**
5. **可映射到外部库调用**
6. **完美嵌套写入整个输出区域**

---

### 3. Indexing Maps

`indexing_maps` 定义了迭代空间到数据空间的映射。

**语义**：
- 左侧是迭代变量（i, j, k）
- 右侧是操作数访问索引
- 使用 AffineMap 表达

**示例解读**：
```
indexing_map = affine_map<(i, j, k) -> (i, k)>
// 含义：当迭代变量为 (i, j, k) 时，访问操作数的 [i, k] 位置
```

---

### 4. Iterator Types

`iterator_types` 声明每个维度的迭代类型：

| 类型 | 语义 | 变换约束 |
|------|------|----------|
| `"parallel"` | 无依赖，可并行/重排序 | 可任意变换 |
| `"reduction"` | 需要归约 | 需保持归约顺序 |

---

## 🔄 关键变换

### 1. Tiling（分块）

将迭代空间划分为小块，提高缓存局部性。

**实现原理**：
```
原始: linalg.matmul on 8x16 tensor
Tiling (2, 8):
  → scf.forall (%i, %j) in (4, 2) {
      linalg.matmul on 2x8 tile
    }
```

**核心 API**：
```cpp
TiledLinalgOp tileLinalgOp(
  RewriterBase &rewriter,
  LinalgOp op,
  const LinalgTilingOptions &options
);
```

**变换效果**：
- 物化隐式循环
- 生成嵌套循环结构
- 保持原始操作语义

---

### 2. Fusion（融合）

合并生产者-消费者操作，减少内存访问。

**两种类型**：

#### a. Loop Fusion
合并具有相同迭代空间的操作

#### b. Producer-Consumer Fusion
即使迭代空间不同，也可融合：
```
%matmul = linalg.matmul ...  // 3D 迭代空间
%elemwise = linalg.generic ...  // 2D 迭代空间

// 可融合：tiling elemwise 后，将 matmul 融合进循环
```

**核心机制**：
- 通过 `tensor.extract_slice` 提取切片
- 反转 `indexing_map` 计算所需的迭代空间子集
- 用 tile 替换 slice 提取

**重物化（Rematerialization）**：
- 可能导致重复计算
- 权衡：计算 vs 内存访问

---

### 3. Vectorization（向量化）

将 Linalg 操作转换为 Vector Dialect 操作。

**核心工具**：
```cpp
VectorizationResult vectorize(
  RewriterBase &rewriter,
  LinalgOp op,
  const LinalgVectorizationOptions &options
);
```

**关键类**：
- `vector.contract`：表达 contraction 操作
- `vector.reduction`：表达 reduction 操作

---

### 4. Promotion（提升到快速内存）

将操作数提升到临时缓冲区（如共享内存）。

**核心 API**：
```cpp
PromotionInfo promoteSubViews(
  RewriterBase &rewriter,
  LinalgOp op,
  const LinalgPromotionOptions &options
);
```

---

### 5. Bufferization（缓冲区化）

将 Tensor 操作转换为 MemRef 操作。

**核心流程**：
```
Tensor (linalg.generic)
  → Bufferization Dialect
  → MemRef (linalg.generic)
```

**关键 Pass**：
- `one-shot-bufferize`
- `linalg-bufferize`

---

### 6. Padding（填充）

填充张量边界以满足分块对齐要求。

**核心 API**：
```cpp
PadTilingInterfaceResult padTilingInterfaceOp(
  RewriterBase &rewriter,
  TilingInterface op,
  const LinalgPaddingOptions &options
);
```

**Hoisting**：
- 将 `tensor.pad` 操作提升到循环外
- 减少重复填充开销

---

### 7. Decomposition（分解）

将复杂操作分解为更简单的操作序列。

**示例**：
```
linalg.pack → linalg.empty + linalg.fill + linalg.insert_slice
tensor.pad → tensor.empty + linalg.fill + tensor.insert_slice
```

---

## 🔽 Lowering 路径

### 路径 1：Linalg → Loops → LLVM IR

```
linalg.matmul
  ↓ (convert-linalg-to-loops)
scf.for + memref.load/store
  ↓ (convert-scf-to-cf)
cf.br + cf.cond_br
  ↓ (convert-memref-to-llvm)
LLVM IR
```

**核心 Pass**：
- `-convert-linalg-to-loops`：生成 scf.for
- `-convert-linalg-to-affine-loops`：生成 affine.for
- `-convert-linalg-to-parallel-loops`：生成 scf.parallel

---

### 路径 2：Linalg → Vector → LLVM IR

```
linalg.matmul
  ↓ (linalg-vectorize)
vector.contract
  ↓ (convert-vector-to-llvm)
LLVM IR
```

---

### 路径 3：Linalg → Standard → Library Call

```
linalg.matmul
  ↓ (convert-linalg-to-standard)
func.call @matmul
  ↓ (lower to C interface)
External library (e.g., BLAS)
```

**库调用约定**：
- 传递非拥有指针到 MemRef 描述符
- 类似 BLAS 接口风格
- 支持 `_mlir_ciface_xxx` C 接口

---

## 📊 作为中间层的可能性

### 方案 A：Triton → Linalg → LLVM IR

```
Triton (ttir)
  ↓
Linalg Dialect
  ↓ (linalg → loops → llvm)
LLVM IR
  ↓
Custom Backend
```

**优势**：
- 利用 Linalg 的优化 passes
- 结构化操作易于变换
- 成熟的 tiling/fusion 机制

**挑战**：
- 需要将 Triton IR 转换为 Linalg IR
- Triton GPU 特定操作可能难以映射

---

### 方案 B：Triton → MLIR → Linalg（可选优化）→ LLVM IR

```
Triton (ttir)
  ↓
MLIR (generic)
  ↓ [可选] Linalg 优化
LLVM IR
  ↓
Custom Backend
```

**优势**：
- 灵活性高
- 可选择性应用 Linalg 优化

---

### 方案 C：直接对接 LLVM IR 层（推荐）

```
Triton (ttir → ttgir → LLVM IR)
  ↓
Custom Backend
```

**优势**：
- 开发量最小（50-100 行）
- 利用 Triton 现有 lowering
- 无需额外 IR 转换

---

## 🔬 待深入研究课题

### 1. Linalg Tiling 策略优化
- **课题**: 如何选择最优 tile sizes
- **应用**: 性能调优
- **优先级**: P1

### 2. Producer-Consumer Fusion 算法
- **课题**: 反转 indexing_map 的数学原理
- **应用**: 自定义融合策略
- **优先级**: P1

### 3. Bufferization 一致性保证
- **课题**: One-shot bufferization 的正确性证明
- **应用**: 内存安全
- **优先级**: P0

### 4. Vector Dialect 与 Linalg 的协同
- **课题**: 向量化策略选择
- **应用**: SIMD/向量单元优化
- **优先级**: P1

### 5. Linalg → Affine 转换优化
- **课题**: 何时使用 Affine vs SCF loops
- **应用**: 多层优化
- **优先级**: P2

### 6. Sparse Tensor 支持
- **课题**: Linalg 对稀疏张量的扩展
- **应用**: 稀疏计算
- **优先级**: P2

---

## 🛠️ 实用工具

### MLIR Pass Pipeline 示例

```bash
# Linalg → Loops
mlir-opt input.mlir -convert-linalg-to-loops

# Linalg → Affine Loops
mlir-opt input.mlir -convert-linalg-to-affine-loops

# Tiling + Fusion
mlir-opt input.mlir -linalg-tiling="tile-sizes=2,8" \
                    -linalg-fuse-elementwise-ops

# Vectorization
mlir-opt input.mlir -linalg-vectorize

# Complete pipeline
mlir-opt input.mlir \
  -linalg-tiling="tile-sizes=32,64" \
  -linalg-fuse-elementwise-ops \
  -linalg-vectorize \
  -convert-linalg-to-loops \
  -convert-scf-to-cf \
  -convert-vector-to-llvm \
  -convert-func-to-llvm
```

---

### 调试工具

**MLIR_ENABLE_DUMP**：
```bash
MLIR_ENABLE_DUMP=1 mlir-opt input.mlir -linalg-tiling
```

**查看 Lowering 结果**：
```bash
mlir-opt input.mlir -convert-linalg-to-loops -debug-only=linalg
```

---

## 📚 参考资料

### 官方文档
- [Linalg Dialect](https://mlir.llvm.org/docs/Dialects/Linalg/)
- [Linalg Rationale](https://mlir.llvm.org/docs/Rationale/RationaleLinalgDialect/)
- [Transform Dialect Tutorial - Ch0](https://mlir.llvm.org/docs/Tutorials/transform/Ch0/)

### 源代码
- `mlir/lib/Dialect/Linalg/IR/` - IR 定义
- `mlir/lib/Dialect/Linalg/Transforms/` - 变换实现
- `mlir/lib/Conversion/LinalgToStandard/` - Lowering

### 相关 Dialect
- **Vector Dialect**: 向量操作
- **Affine Dialect**: 仿射循环
- **SCF Dialect**: 结构化控制流
- **Bufferization Dialect**: 缓冲区化

---

## 🎯 对 Triton 项目的启示

### 关键发现

1. **Linalg 提供成熟的结构化操作框架**
   - Tiling/Fusion 已在生产环境验证
   - 可考虑作为优化层

2. **但对接 Linalg 需要额外转换**
   - Triton IR → Linalg IR 需要开发
   - 增加复杂度

3. **推荐策略**
   - **短期**: 直接对接 LLVM IR 层（最小化开发）
   - **长期**: 如需复杂优化，可引入 Linalg 层

4. **值得借鉴的设计**
   - `indexing_maps` 的映射机制
   - `iterator_types` 的声明式并行语义
   - Producer-Consumer Fusion 算法

---

## 📝 总结

### 核心要点
1. **结构化操作是 Linalg 的核心**
2. **6 个属性定义了操作语义**
3. **Tiling/Fusion/Vectorization 是三大变换**
4. **多条 lowering 路径支持不同后端**
5. **作为中间层可行，但需权衡开发成本**

### 对接建议
- **不推荐**立即引入 Linalg 作为中间层
- **推荐**先完成 LLVM IR 层对接
- **可选**后续根据性能需求引入 Linalg 优化

---

*最后更新：2026-03-08 | 耗时：约 2 小时*
