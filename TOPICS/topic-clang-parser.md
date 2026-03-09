---
id: KB-20250309-009
title: Clang Parser语法分析详解
category: llvm.frontend
level: 2
summary: "Clang语法分析器、递归下降解析、AST构建、声明/语句/表达式解析关键文件"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [llvm, clang, frontend, parser, ast, parsing]
status: done
relations: [KB-20250309-007, KB-20250309-008, KB-20250309-010]
---

# Clang Parser语法分析详解

## Parser功能

将Token序列解析为AST（抽象语法树）。

### 递归下降解析

```cpp
// Parse表达式
ExprResult ParseExpression() {
  return ParseAssignmentExpression();
}

// Parse语句
StmtResult ParseStatement() {
  switch (Tok.getKind()) {
    case tok::kw_if: return ParseIfStatement();
    case tok::kw_for: return ParseForStatement();
    // ...
  }
}
```

## 关键文件

| 文件 | 功能 |
|-----|------|
| `ParseDecl.cpp` | 声明解析 |
| `ParseStmt.cpp` | 语句解析 |
| `ParseExpr.cpp` | 表达式解析 |

## 解析入口

```cpp
// Parser入口：解析顶层声明
bool Parser::ParseTopLevelDecl(DeclGroupPtrTy &Result) {
  // 跳过EOF
  if (Tok.is(tok::eof)) return false;
  
  // 解析单个声明
  Result = ParseExternalDeclaration();
  return true;
}
```

## 函数声明解析

```cpp
// Parse函数声明
Decl *ParseFunctionDefinition(...) {
  // 1. 解析声明说明符
  ParseDeclarationSpecifiers(...);
  
  // 2. 解析声明符（函数名+参数）
  ParseDeclarator(...);
  
  // 3. 解析函数体
  if (Tok.is(tok::l_brace)) {
    return ParseFunctionStatementBody(...);
  }
}
```

## 参考

- [[KB-20250309-007]] Clang前端架构深度解析
- [[KB-20250309-008]] Clang Lexer词法分析详解
- [[KB-20250309-010]] Clang Sema语义分析详解
