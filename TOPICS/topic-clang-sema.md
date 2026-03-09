---
id: KB-20250309-010
title: Clang Sema语义分析详解
category: llvm.frontend
level: 2
summary: "Clang语义分析器、类型检查、名称查找、作用域管理、Sema关键类与语义检查流程"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [llvm, clang, frontend, sema, type-checking, scope]
status: done
relations: [KB-20250309-007, KB-20250309-009]
---

# Clang Sema语义分析详解

## Sema功能

语义分析：类型检查、名称查找、作用域管理。

### 关键类

| 类 | 功能 |
|-----|------|
| `Sema` | 主语义分析器 |
| `Scope` | 作用域 |
| `Decl` | 声明 |

## 类型检查

```cpp
// 检查赋值类型
QualType Sema::CheckAssignmentOperands(...) {
  // 检查左右类型兼容
  // 检查const限定
  // 返回结果类型
}
```

## 作用域管理

```cpp
// 进入新作用域
void Sema::PushFunctionScope() {
  PushScope(Scope::FnScope);
}

// 名称查找
NamedDecl *Sema::LookupName(Scope *S, IdentifierInfo *II) {
  // 在当前作用域查找
  // 逐级向上查找父作用域
}
```

## 语义检查流程

```cpp
// 声明语义检查
bool Sema::ActOnFunctionDeclarator(...) {
  // 检查返回类型
  // 检查参数类型
  // 检查重载/重复定义
}

// 表达式语义检查
ExprResult Sema::ActOnBinOp(..., Expr *LHS, Expr *RHS) {
  // 检查操作数类型
  // 检查操作符兼容性
  // 进行类型转换
}
```

## 关键文件

- `clang/lib/Sema/SemaDecl.cpp` - 声明语义检查
- `clang/lib/Sema/SemaExpr.cpp` - 表达式语义检查
- `clang/lib/Sema/SemaStmt.cpp` - 语句语义检查

## 参考

- [[KB-20250309-007]] Clang前端架构深度解析
- [[KB-20250309-009]] Clang Parser语法分析详解
