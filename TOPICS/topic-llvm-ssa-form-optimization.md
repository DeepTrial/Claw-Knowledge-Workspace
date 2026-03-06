---
id: KB-20250307-007C
title: LLVM SSA 形式与编译器优化
contributor: DeepTrial
created: 2026-03-07
updated: 2026-03-07
tags: [llvm, ssa, compiler-optimization, phi-function, ir]
status: done
---

# LLVM SSA 形式与编译器优化

> **学习天数**: Day 007 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-07

---

## 核心概念

SSA（Static Single Assignment）形式是现代编译器的基石，其关键特性：**每个变量只被赋值一次**。

---

## 示例

```
原始代码:                    SSA 形式:
x = 1                        x1 = 1
x = x + 2                    x2 = x1 + 2
y = x * 3                    y1 = x2 * 3
```

---

## Phi 函数（Φ 函数）

在控制流合并点使用 Phi 函数选择不同路径的值：

```llvm
; 条件分支后的合并点
%result = phi i32 [ %val1, %block1 ], [ %val2, %block2 ]
```

---

## SSA 的优势

1. **优化友好** - 常量传播、死代码消除更简单
2. **简化分析** - 数据流分析更清晰
3. **错误检测** - 更容易发现未初始化变量

---

## LLVM IR SSA 示例

```llvm
define i32 @example(i32 %a, i32 %b) {
entry:
    %cmp = icmp sgt i32 %a, %b
    br i1 %cmp, label %if.then, label %if.else

if.then:
    %sum = add i32 %a, %b
    br label %if.end

if.else:
    %diff = sub i32 %a, %b
    br label %if.end

if.end:
    %result = phi i32 [ %sum, %if.then ], [ %diff, %if.else ]
    ret i32 %result
}
```

---

## 在 LLVM 中的应用

- **函数内联** - 减少调用开销
- **死代码消除** - 移除无用代码
- **循环优化** - 循环展开、不变量外提
- **常量传播** - 编译时计算常量表达式

---

*归档时间: 2026-03-07*
