---
id: KB-20250307-007A
title: Triton tl.load/tl.store 内存操作与优化
category: triton.optimization
level: 2
summary: "详解 Triton 内存操作：tl.load/tl.store 参数、swizzling 优化、向量化访问"
contributor: DeepTrial
created: 2026-03-07
updated: 2026-03-07
tags: [triton, memory, load-store, swizzling, optimization]
status: done
---

# Triton tl.load/tl.store 内存操作与优化

> **学习天数**: Day 007 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-07

---

## 核心概念

`tl.load` 和 `tl.store` 是 Triton 中最基础的内存操作原语，用于在 GPU 全局内存和 Triton 的寄存器之间传输数据。

---

## 编译器优化流程

编译器会将 `tl.load` 分解为两步过程：
1. 从 Global Memory 到 L1 Cache（或 Shared Memory）
2. 从 L1 Cache 到寄存器

---

## 基础代码示例

```python
import triton
import triton.language as tl

@triton.jit
def copy_kernel(x_ptr, z_ptr, n, bs: tl.constexpr):
    """
    正确的 copy kernel 实现
    """
    pid = tl.program_id(0)
    offs = pid * bs + tl.arange(0, bs)
    mask = offs < n
    
    # 加载输入值
    x = tl.load(x_ptr + offs, mask)
    
    # 存储到输出
    tl.store(z_ptr + offs, x, mask)
```

---

## Swizzling 内存访问优化

```python
@triton.jit
def swizzle_kernel(x_ptr, z_ptr, group_sz: tl.constexpr):
    """
    使用 swizzling 优化内存访问模式
    """
    pid_m, pid_n = tl.program_id(0), tl.program_id(1)
    num_pid_m, num_pid_n = tl.num_programs(0), tl.num_programs(1)
    
    # 应用 2D swizzling 重排 thread blocks
    pid_m_, pid_n_ = tl.swizzle2d(pid_m, pid_n, num_pid_m, num_pid_n, group_sz)
    
    # 计算偏移并执行 load/store
    offs_m = pid_m * BLOCK_SIZE
    offs_sw_m = pid_m_ * BLOCK_SIZE
    
    x = tl.load(x_ptr + offs_m * stride)
    tl.store(z_ptr + offs_sw_m * stride, x)
```

---

## 关键要点

1. **mask 是必须的** - 防止越界访问
2. **Swizzling 优化** - 改善内存局部性和缓存利用率
3. **编译器自动优化** - 将 load 分解为多级缓存传输

---

*归档时间: 2026-03-07*
