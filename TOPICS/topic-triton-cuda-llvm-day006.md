---
id: KB-20250306-006
title: Day 006 - Triton mask与边界处理 / CUDA常量内存 / LLVM类型系统
contributor: DeepTrial
created: 2026-03-06
updated: 2026-03-06
tags: [triton, cuda, llvm, mask, constant-memory, type-system]
status: done
---

# Day 006 - Triton mask与边界处理 / CUDA常量内存 / LLVM类型系统

> **日期**: 2026-03-06  
> **学习天数**: Day 006 of 100 Days Triton+CUDA+LLVM Learning Journey

---

## 🔷 Triton: mask 与边界处理

### 核心概念

在 Triton 中，`mask` 是处理边界条件和防止越界访问的关键机制。

### 关键 API

| API | 说明 | 示例 |
|-----|------|------|
| `tl.load(ptr, mask=mask, other=0.0)` | 带 mask 的加载 | 越界位置返回 `other` 值 |
| `tl.store(ptr, value, mask=mask)` | 带 mask 的存储 | 只存储 mask 为 True 的位置 |
| `boundary_check` | 边界检查维度 | 用于 block pointer |
| `padding_option` | 填充选项 | `"zero"`, `"nan"`, `""` |

### 代码示例

```python
@triton.jit
def add_kernel(x_ptr, y_ptr, output_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    block_start = pid * BLOCK_SIZE
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

### 关键要点

1. **mask 的重要性**: 防止非法内存访问，避免段错误
2. **other 参数**: 指定 mask 为 False 时的填充值
3. **性能影响**: mask 会引入条件执行，但 Triton 会优化广播访问

---

## 🔶 CUDA: 常量内存 (Constant Memory)

### 核心特性

| 特性 | 说明 |
|------|------|
| **容量** | 64KB（所有 SM 共享） |
| **缓存** | 每个 SM 有 8KB 常量缓存 |
| **广播** | 同一 warp 内所有线程读取同一地址时广播 |
| **适用场景** | 所有线程读取相同数据（如滤波器系数） |

### 声明与使用

```cuda
// 编译时常量内存声明
__constant__ float const_data[256];

// 主机端设置常量内存
cudaMemcpyToSymbol(const_data, host_data, sizeof(host_data));

// 设备端使用
__global__ void kernel(float* output) {
    int idx = threadIdx.x;
    output[idx] = const_data[idx] * 2.0f;
}
```

### 使用建议

- ✅ **好的使用场景**: 所有线程读取相同数据（滤波器系数、变换矩阵）
- ❌ **不好的使用场景**: 每个线程读取不同地址（导致访问串行化）

---

## 🔷 LLVM: 类型系统

### 基本类型

```llvm
; 整数类型
i1    ; 布尔类型
i8    ; 字节
i32   ; 32位整数
i64   ; 64位整数

; 浮点类型
float      ; 32位浮点
double     ; 64位浮点

; 指针类型
ptr        ; 无类型指针 (LLVM 15+)
```

### 聚合类型

```llvm
; 数组类型: [N x Type]
[1024 x i8]       ; 1024 字节的数组
[10 x i32]        ; 10 个 i32 的数组

; 结构体类型: {Type1, Type2, ...}
{i32, i32}        ; 两个 i32 的结构体
{float, ptr}      ; float 和指针的结构体
<{i8, i32}>       ; packed 结构体，无填充

; 向量类型 (SIMD)
<4 x i32>         ; 4个 i32 的向量
<8 x float>       ; 8个 float 的向量
```

### 类型使用示例

```llvm
; 结构体访问
define float @struct_access(ptr %s) {
    ; 获取第二个字段的指针 (索引 1)
    %field_ptr = getelementptr {i32, float}, ptr %s, i32 0, i32 1
    
    ; 加载 float 值
    %value = load float, ptr %field_ptr
    ret float %value
}
```

---

## 📚 核心要点总结

| 主题 | 核心要点 |
|------|----------|
| **Triton mask** | 使用 `mask` 参数防止越界，`other` 指定填充值 |
| **CUDA 常量内存** | 64KB 容量，适合所有线程读取相同数据，支持广播 |
| **LLVM 类型系统** | 强类型，包括基本类型、聚合类型，使用 GEP 访问复合类型 |

---

## 📖 参考资源

- Triton Documentation: https://triton-lang.org/
- CUDA Programming Guide
- LLVM Language Reference Manual: https://llvm.org/docs/LangRef.html

---

*归档时间: 2026-03-06 | 学习天数: Day 006*
