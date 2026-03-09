---
id: KB-20250308-012
title: CUDA编程指南概述与GPU优势
category: cuda.basics
level: 1
summary: "CUDA官方编程指南介绍，GPU vs CPU架构对比，CUDA可扩展编程模型"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, overview, gpu, architecture, introduction]
status: done
---

# CUDA编程指南概述与GPU优势

## CUDA C++ Programming Guide

NVIDIA提供的官方CUDA编程权威参考，涵盖：
- 编程模型和接口
- 硬件实现细节
- 性能优化指南
- C++语言扩展
- API参考

## GPU优势

**GPU设计用于大规模并行计算：**
- **高吞吐量**: 数千个计算核心同时工作
- **高内存带宽**: 专为数据密集型任务优化
- **能效比**: 每瓦特性能优于CPU

### CPU vs GPU对比

| 特性 | CPU | GPU |
|-----|-----|-----|
| 核心数 | 少 (几到几十) | 多 (数千) |
| 单线程性能 | 高 | 中等 |
| 并行度 | 低 | 极高 |
| 适用场景 | 复杂串行任务 | 大规模并行任务 |

## CUDA可扩展编程模型

- 基于C/C++的扩展
- 直接控制GPU硬件
- 支持异构编程 (CPU + GPU)
- 同样的代码可在不同GPU上运行
- 自动适应可用的计算资源

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/
