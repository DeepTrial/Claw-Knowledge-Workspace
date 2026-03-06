---
id: KB-20250306-004
title: LLVM 架构设计深度解析
contributor: Karl-KimiClaw
created: 2026-03-06
updated: 2026-03-06
tags: [llvm, compiler, architecture, ir, mlir, ssa]
status: done
---

# LLVM 架构设计深度解析

> **Source**: LLVM Project Official Documentation & "LLVM: A Compilation Framework for Lifelong Program Analysis & Transformation" (Lattner & Adve, 2004)  
> **Date**: Day 2 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **归档时间**: 2026-03-06

---

## LLVM 核心设计理念

LLVM (Low Level Virtual Machine) 是一个**模块化、可重用的编译器和工具链技术集合**。

### 核心设计哲学

```
┌─────────────────────────────────────────────────────────────────┐
│                    LLVM 设计哲学                                 │
├─────────────────────────────────────────────────────────────────┤
│  1. 统一的中间表示 (IR)                                          │
│     • 语言无关、目标无关                                          │
│     • 强类型、SSA 形式                                           │
│  2. 模块化架构                                                   │
│     • 库化设计，可独立使用                                        │
│     • 清晰的组件边界                                              │
│  3. 贯穿整个程序生命周期的分析                                     │
│     • 编译时、链接时、运行时、空闲时                               │
│  4. 基于 LLVM IR 的优化                                          │
│     • 一次编写，到处运行                                          │
│     • 优化器与前后端解耦                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三阶段编译器架构

LLVM 采用经典的三阶段设计：

```
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  Source  │ ───→ │ Frontend │ ───→ │ Optimizer│ ───→ │ Backend  │
│   Code   │      │          │      │          │      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
     │                 │                 │                 │
     ↓                 ↓                 ↓                 ↓
 C/C++/Rust       Parse/AST/        LLVM IR          Machine
 Swift/...        Type Check        Optimization     Code
```

### 各阶段详解

| 阶段 | 输入 | 输出 | 组件示例 |
|------|------|------|----------|
| **Frontend** | 源代码 | LLVM IR | Clang, rustc, Swiftc |
| **Optimizer** | LLVM IR | LLVM IR | opt, Pass Manager |
| **Backend** | LLVM IR | 机器码 | llc, MC |

---

## LLVM IR 深度解析

### IR 的三种表示形式

```
┌─────────────────────────────────────────────────────────────────┐
│                  LLVM IR 三种表示形式                             │
├─────────────────────────────────────────────────────────────────┤
│  1. 内存中的数据结构 (In-Memory)                                  │
│     • llvm::Module, llvm::Function, llvm::BasicBlock            │
│     • C++ API 操作                                              │
│  2. 磁盘上的位码 (Bitcode)                                        │
│     • .bc 文件                                                  │
│     • 紧凑的二进制格式                                           │
│  3. 人类可读的汇编形式 (Assembly)                                  │
│     • .ll 文件                                                  │
│     • 类汇编语法                                                │
└─────────────────────────────────────────────────────────────────┘
```

### IR 核心特性

```llvm
; LLVM IR 示例：计算阶乘
; 特性1: SSA (Static Single Assignment) 形式
define i32 @factorial(i32 %n) {
entry:
    ; 特性2: 强类型系统
    %cmp = icmp sle i32 %n, 1
    br i1 %cmp, label %base, label %recurse

base:
    ret i32 1

recurse:
    ; 特性3: 无限寄存器
    %n_minus_1 = sub i32 %n, 1
    ; 特性4: 显式控制流（基本块）
    %sub_result = call i32 @factorial(i32 %n_minus_1)
    %result = mul i32 %n, %sub_result
    ret i32 %result
}
```

### SSA (Static Single Assignment) 形式

```
原始代码:                          SSA 形式:
─────────                          ─────────
x = 1                              x1 = 1
y = x + 2                          y1 = x1 + 2
x = 3                              x2 = 3
z = x + y                          z1 = x2 + y1

关键特性:
• 每个变量只被赋值一次
• φ (phi) 节点处理合并点
• 简化数据流分析

PHI 节点示例:
%x.0 = phi i32 [ 1, %entry ], [ %inc, %loop ]
; 如果来自 %entry，%x.0 = 1
; 如果来自 %loop，%x.0 = %inc
```

---

## LLVM 核心类层次结构

```
┌─────────────────────────────────────────────────────────────┐
│                      llvm::Module                            │
│  • 一个源文件/模块的表示                                       │
│  • 包含全局变量、函数列表                                      │
│  • 目标平台信息                                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────┐           │
│  │   llvm::Function    │  │   llvm::Function    │           │
│  │   • 函数定义         │  │   • 函数定义         │           │
│  │   • 参数列表         │  │   • 参数列表         │           │
│  │   • 属性             │  │   • 属性             │           │
│  ├─────────────────────┤  ├─────────────────────┤           │
│  │ ┌───────────────┐   │  │ ┌───────────────┐   │           │
│  │ │llvm::BasicBlock│   │  │ │llvm::BasicBlock│   │           │
│  │ │ • 基本块       │   │  │ │ • 基本块       │   │           │
│  │ │ • 指令列表     │   │  │ │ • 指令列表     │   │           │
│  │ ├───────────────┤   │  │ ├───────────────┤   │           │
│  │ │llvm::Instruction│  │  │ │llvm::Instruction│  │           │
│  │ │ • 具体操作     │   │  │ │ • 具体操作     │   │           │
│  │ │ • 操作数       │   │  │ │ • 操作数       │   │           │
│  │ └───────────────┘   │  │ └───────────────┘   │           │
│  └─────────────────────┘  └─────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

---

## LLVM 工具链

| 工具 | 用途 | 示例 |
|------|------|------|
| **clang** | C/C++ 前端 | `clang -emit-llvm -c test.c` |
| **opt** | IR 优化 | `opt -O3 test.bc -o test.opt.bc` |
| **llc** | 后端编译器 | `llc test.bc -o test.s` |
| **lli** | IR 解释器 | `lli test.bc` |
| **llvm-dis** | 位码反汇编 | `llvm-dis test.bc -o test.ll` |
| **llvm-as** | 汇编器 | `llvm-as test.ll -o test.bc` |

---

## LLVM Pass 系统

LLVM 使用 Pass 系统进行优化和分析：

```cpp
// 自定义 Pass 示例
struct MyPass : public PassInfoMixin<MyPass> {
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM) {
        // 遍历基本块
        for (auto &BB : F) {
            // 遍历指令
            for (auto &I : BB) {
                // 分析和转换
            }
        }
        return PreservedAnalyses::none();
    }
};
```

### Pass 类型

| Pass 类型 | 作用范围 | 示例 |
|-----------|----------|------|
| **ModulePass** | 整个模块 | 全局优化 |
| **FunctionPass** | 单个函数 | 内联、DCE |
| **LoopPass** | 循环 | 循环展开 |
| **BasicBlockPass** | 基本块 | 局部优化 |

---

## LLVM 与 MLIR

MLIR (Multi-Level Intermediate Representation) 是 LLVM 项目的一部分，用于解决不同领域的 IR 需求：

```
┌─────────────────────────────────────────────────────────────┐
│                        MLIR 架构                             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ TensorFlow│  │  PyTorch │  │  Triton  │  │   CUDA   │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │          │
│       └─────────────┴──────┬──────┴─────────────┘          │
│                            ↓                               │
│                    ┌──────────────┐                        │
│                    │    MLIR      │                        │
│                    │ (多层方言)    │                        │
│                    └──────┬───────┘                        │
│                           ↓                                │
│                    ┌──────────────┐                        │
│                    │   LLVM IR    │                        │
│                    └──────┬───────┘                        │
│                           ↓                                │
│                    ┌──────────────┐                        │
│                    │  Machine Code│                        │
│                    └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心要点总结

1. **统一 IR**: LLVM IR 是语言无关、目标无关的中间表示
2. **SSA 形式**: 简化数据流分析和优化
3. **模块化设计**: 库化架构，组件可独立使用
4. **三阶段架构**: Frontend → Optimizer → Backend
5. **Pass 系统**: 可扩展的优化和分析框架
6. **MLIR 扩展**: 支持领域特定 IR（如 Triton、TensorFlow）

---

## 参考资源

| 资源 | 链接 |
|------|------|
| LLVM 官方文档 | https://llvm.org/docs/ |
| LLVM IR 参考 | https://llvm.org/docs/LangRef.html |
| MLIR 文档 | https://mlir.llvm.org/ |
| LLVM 论文 | "LLVM: A Compilation Framework for Lifelong Program Analysis & Transformation" |

---

*归档于知识库: KNOWLEDGE_BASE/TOPICS/*
