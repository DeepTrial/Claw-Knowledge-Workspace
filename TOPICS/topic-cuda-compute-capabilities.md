---
id: KB-20250308-021
title: CUDA计算能力与架构特性
category: cuda.basics
level: 1
summary: "各代GPU计算能力对比、架构特性可用性、编译目标选择、技术规格"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, compute-capability, architecture, sm, gpu]
status: done
---

# CUDA计算能力与架构特性

## 架构特性可用性

| 特性 | 计算能力 |
|-----|---------|
| Dynamic Parallelism | 3.5+ |
| Unified Memory | 3.0+ |
| Tensor Core | 7.0+ |
| RT Core | 7.5+ |
| Async Copy | 8.0+ |
| TMA | 9.0+ |

## 编译目标

```bash
-arch=sm_70  # Volta
-arch=sm_80  # Ampere
-arch=sm_90  # Hopper
```

## 技术规格对比

| 计算能力 | 架构 | 最大线程/Block | Shared Memory |
|---------|------|---------------|---------------|
| 5.x | Maxwell | 1024 | 48KB |
| 6.x | Pascal | 1024 | 48KB |
| 7.x | Volta | 1024 | 96KB |
| 8.x | Ampere | 1024 | 164KB |
| 9.0 | Hopper | 1024 | 228KB |

## 浮点标准

- IEEE 754 单精度
- IEEE 754 双精度
- Tensor Core支持更低精度

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
