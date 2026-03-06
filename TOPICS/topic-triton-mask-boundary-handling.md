---
id: KB-20250306-006A
title: Triton mask 与边界处理
contributor: DeepTrial
created: 2026-03-06
updated: 2026-03-06
tags: [triton, mask, boundary-handling, memory-safety, padding]
status: done
---

# Triton mask 与边界处理

> **学习天数**: Day 006 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-06

---

## 核心概念

在 Triton 中，`mask` 是处理边界条件和防止越界访问的关键机制。当数据大小不是 block size 的整数倍时，必须使用 mask 来确保只访问有效内存。

---

## 关键 API

| API | 说明 | 示例 |
|-----|------|------|
| `tl.load(ptr, mask=mask, other=0.0)` | 带 mask 的加载 | 越界位置返回 `other` 值 |
| `tl.store(ptr, value, mask=mask)` | 带 mask 的存储 | 只存储 mask 为 True 的位置 |
| `boundary_check` | 边界检查维度 | 用于 block pointer |
| `padding_option` | 填充选项 | `"zero"`, `"nan"`, `""` |

---

## 代码示例

### 基础向量加法

```python
import triton
import triton.language as tl

@triton.jit
def add_kernel(x_ptr, y_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    block_start = pid * BLOCK_SIZE
    
    # 创建偏移量
    offsets = block_start + tl.arange(0, BLOCK_SIZE)
    
    # 创建 mask：只对有效元素进行操作
    mask = offsets < n_elements
    
    # 使用 mask 加载数据
    x = tl.load(x_ptr + offsets, mask=mask, other=0.0)
    y = tl.load(y_ptr + offsets, mask=mask, other=0.0)
    output = x + y
    
    # 使用 mask 存储结果
    tl.store(output_ptr + offsets, output, mask=mask)
```

### 矩阵乘法中的边界处理

```python
# 在循环中处理 K 维度的边界
for k in range(0, tl.cdiv(K, BLOCK_SIZE_K)):
    # 计算当前块的边界 mask
    k_mask = (k * BLOCK_SIZE_K + tl.arange(0, BLOCK_SIZE_K)) < K
    
    # 使用 mask 和 other=0.0 加载，确保越界位置为 0
    a = tl.load(a_ptrs, mask=k_mask[None, :], other=0.0)
    b = tl.load(b_ptrs, mask=k_mask[:, None], other=0.0)
    
    accumulator += tl.dot(a, b)
    
    # 移动指针到下一个 K 块
    a_ptrs += BLOCK_SIZE_K * stride_ak
    b_ptrs += BLOCK_SIZE_K * stride_bk
```

### Block Pointer 与边界处理

```python
# 使用 make_block_ptr 创建带边界信息的指针
desc = tl.make_block_ptr(
    base=base_ptr,
    shape=[M, N],
    strides=[stride_m, stride_n],
    block_shape=[BLOCK_M, BLOCK_N],
    offsets=[pid_m * BLOCK_M, pid_n * BLOCK_N]
)

# 使用 boundary_check 和 padding_option
tile = tl.load(desc, boundary_check=(0, 1), padding_option="zero")
```

---

## 关键要点

1. **mask 的重要性**: 防止非法内存访问，避免段错误
2. **other 参数**: 指定 mask 为 False 时的填充值，通常设为 0 或中性元素
3. **性能影响**: mask 会引入条件执行，但 Triton 编译器会优化广播访问
4. **连续访问**: 尽量保证 `tl.load` 和 `tl.store` 的地址连续，避免性能下降

---

## 参考资源

- Triton Documentation: https://triton-lang.org/main/python-api/generated/triton.language.load.html
- Flash Attention Implementation (LabML)

---

*归档时间: 2026-03-06 | 学习天数: Day 006*
