---
id: KB-20250306-006C
title: LLVM 类型系统
category: llvm.basics
level: 2
summary: "LLVM 类型系统详解：基础类型、聚合类型、向量类型及类型推断规则"
contributor: DeepTrial
created: 2026-03-06
updated: 2026-03-06
tags: [llvm, type-system, ir, aggregate-types, vector]
status: done
---

# LLVM 类型系统

> **学习天数**: Day 006 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-06

---

## 核心概念

LLVM IR 是强类型的中间表示，类型系统包括：
- **基本类型**: 整数、浮点、指针
- **聚合类型**: 数组、结构体、向量
- **特殊类型**: 标签、元数据、token

---

## 基本类型

```llvm
; 整数类型 (iN)
i1    ; 布尔类型
i8    ; 字节
i32   ; 32位整数
i64   ; 64位整数

; 浮点类型
float      ; 32位浮点
double     ; 64位浮点
half       ; 16位浮点 (FP16)
bfloat     ; 16位脑浮点

; 指针类型 (LLVM 15+ 使用无类型指针)
ptr        ; 无类型指针
ptr i32    ; 指向 i32 的指针 (typed pointer, 旧版)

; 空类型
void       ; 仅用于函数返回
```

---

## 聚合类型

```llvm
; 数组类型: [N x Type]
[1024 x i8]      ; 1024 字节的数组
[10 x i32]       ; 10 个 i32 的数组
[3 x [3 x float]] ; 3x3 浮点矩阵

; 结构体类型: {Type1, Type2, ...}
{i32, i32}       ; 两个 i32 的结构体
{float, ptr}     ; float 和指针的结构体 (Rust slice)
<{i8, i32}>      ; packed 结构体，无填充

; 向量类型: <N x T> (SIMD)
<4 x i32>        ; 4个 i32 的向量 (AVX2)
<8 x float>      ; 8个 float 的向量
```

---

## 类型使用示例

### 全局变量定义

```llvm
; 定义全局变量
@global_array = global [1024 x i32] zeroinitializer
@global_struct = global {i32, float} { i32 10, float 3.14 }
```

### 函数定义

```llvm
; 函数定义使用类型
define i32 @add(i32 %a, i32 %b) {
    %sum = add i32 %a, %b
    ret i32 %sum
}
```

### 指针和数组操作

```llvm
define void @array_access(ptr %arr, i64 %idx) {
    ; 获取元素指针 (GEP)
    %elem_ptr = getelementptr i32, ptr %arr, i64 %idx
    
    ; 加载元素
    %value = load i32, ptr %elem_ptr
    
    ; 存储元素
    store i32 42, ptr %elem_ptr
    ret void
}
```

### 结构体访问

```llvm
define float @struct_access(ptr %s) {
    ; 获取第二个字段的指针 (索引 1)
    %field_ptr = getelementptr {i32, float}, ptr %s, i32 0, i32 1
    
    ; 加载 float 值
    %value = load float, ptr %field_ptr
    ret float %value
}
```

---

## 类型对齐

```llvm
; 数据布局字符串定义对齐
; i<size>:<abi>[:<pref>]
; p:<abi>[:<pref>] (指针)
; a:<abi>[:<pref>] (聚合类型)

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
; 含义:
; e = little endian
; i64:64 = i64 类型 64 位对齐
; p270:32:32 = 地址空间 270 的指针 32 位对齐
```

---

## 函数类型

```llvm
; 函数类型: ret_type (param_types)
define i32 @example(i32 %a, float %b, ptr %c) {
    ; 参数类型: i32, float, ptr
    ; 返回类型: i32
    ret i32 0
}
```

---

## 类型转换

```llvm
define void @type_casting(i32 %i, float %f, ptr %p) {
    ; 整数到浮点
    %f_from_i = sitofp i32 %i to float
    
    ; 浮点到整数
    %i_from_f = fptosi float %f to i32
    
    ; 整数到指针
    %p_from_i = inttoptr i32 %i to ptr
    
    ; 指针到整数
    %i_from_p = ptrtoint ptr %p to i64
    
    ; 位转换 (bitcast)
    %i_from_f_bits = bitcast float %f to i32
    
    ret void
}
```

---

## 参考资源

- LLVM Language Reference Manual: https://llvm.org/docs/LangRef.html
- "A Gentle Introduction to LLVM IR" (mcyoung.xyz)

---

*归档时间: 2026-03-06 | 学习天数: Day 006*
