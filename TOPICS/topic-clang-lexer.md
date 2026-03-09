---
id: KB-20250309-008
title: Clang Lexer词法分析详解
category: llvm.frontend
level: 2
summary: "Clang词法分析器核心功能、Token种类、Lexer与Preprocessor关键类、Token创建流程"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [llvm, clang, frontend, lexer, token, preprocessor]
status: done
relations: [KB-20250309-007, KB-20250309-009]
---

# Clang Lexer词法分析详解

## Lexer核心功能

```cpp
// 将源代码字符流转换为Token序列
// 例如: "int main()" → [int, main, (, )]
```

## 关键类

| 类 | 作用 |
|-----|------|
| `Lexer` | 主词法分析器 |
| `Token` | Token定义 |
| `Preprocessor` | 预处理 |

## Token种类

```cpp
// 关键字
kw_int, kw_return, kw_if, kw_for...

// 标识符
identifier

// 字面量
numeric_constant, string_literal...

// 操作符
plus, minus, star, slash...

// 分隔符
l_paren, r_paren, l_brace, r_brace...
```

## 源码位置

- `clang/lib/Lex/Lexer.cpp` - 主词法分析器实现
- `clang/include/clang/Lex/Token.h` - Token定义
- `clang/lib/Lex/Preprocessor.cpp` - 预处理器

## Token创建流程

```cpp
void Lexer::LexTokenInternal(Token &Result) {
  // 1. 跳过空白字符
  SkipWhitespace();
  
  // 2. 识别当前字符类型
  switch (*CurPtr) {
    case 'a'...'z': case 'A'...'Z': case '_':
      return LexIdentifier(Result);
    case '0'...'9':
      return LexNumericConstant(Result);
    case '"':
      return LexStringLiteral(Result);
    // ... 其他情况
  }
}
```

## 参考

- [[KB-20250309-007]] Clang前端架构深度解析
- [[KB-20250309-009]] Clang Parser语法分析详解
