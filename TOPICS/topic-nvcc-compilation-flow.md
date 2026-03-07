---
id: KB-20260307-002
title: NVCC 编译流程与分离编译
category: cuda.compiler
level: 2
tags: [cuda, nvcc, compilation, rdc, separate-compilation]
summary: "NVCC 编译器驱动的工作流程、分离编译模式与 whole-program 编译"
contributor: main
created: 2026-03-07
updated: 2026-03-07
status: done
---

# NVCC 编译流程与分离编译

## NVCC 编译轨迹概览

```
┌─────────────────────────────────────────────────────────────────┐
│                      .cu 源文件                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: 预处理（Device）                                        │
│  • 展开宏，处理 #include                                         │
│  • 生成 .cpp.ii 文件                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: 分离 Host/Device 代码                                   │
│  • 识别 __global__, __device__, __host__ 函数                   │
│  • Device 代码 → PTX/CUBIN                                       │
│  • Host 代码 → 标准编译                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: 生成 Fatbinary                                          │
│  • 包含多个架构的 PTX 和 CUBIN                                    │
│  • 嵌入到 Host 对象文件                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: Host 编译 + 链接                                        │
│  • 调用 gcc/cl.exe 编译 Host 代码                                 │
│  • 链接 CUDA Runtime 库                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Whole-Program vs Separate Compilation

### Whole-Program Compilation（默认模式）

```bash
nvcc -arch=sm_80 main.cu -o app
```

**特点**：
- 所有 device 代码必须在单个 .cu 文件内
- 跨文件 device 函数调用**不可用**
- 编译器可进行全局优化
- **Device link 无效**

**限制**：
```cpp
// a.cu
__device__ void helper();  // ❌ 声明无效

// b.cu
__device__ void helper() { /* ... */ }
__global__ void kernel() { helper(); }  // ❌ 编译错误
```

### Relocatable Device Code (RDC) 模式

```bash
nvcc -arch=sm_80 -rdc=true main.cu utils.cu -o app
```

**特点**：
- 允许跨文件 device 函数调用
- 需要 device link 阶段
- 生成 `.o` 文件包含可重定位 device 代码
- **编译时间更长**

**支持**：
```cpp
// utils.cu
__device__ void helper() { /* ... */ }

// main.cu
__device__ void helper();  // ✅ RDC 模式下有效

__global__ void kernel() { helper(); }  // ✅ 可调用
```

## 关键编译选项

| 选项 | 说明 | 示例 |
|------|------|------|
| `-arch=sm_XY` | 指定目标架构 | `-arch=sm_80` |
| `-code=sm_XY` | 指定生成代码 | `-code=sm_80,sm_90` |
| `-gencode` | 精细控制多架构 | `-gencode arch=compute_80,code=sm_80` |
| `-rdc=true` | 启用分离编译 | `-rdc=true` |
| `-dlink` | 仅执行 device link | `nvcc -dlink obj.o` |
| `-x cu` | 强制识别为 CUDA | `-x cu source.cpp` |
| `-dc` | 仅编译 device code | `nvcc -dc a.cu b.cu` |

## 多架构编译策略

### 策略 1：PTX 前向兼容

```bash
nvcc -arch=compute_80 -code=sm_80,compute_80 main.cu
```

- `compute_80`：生成 PTX（可在未来 GPU 运行）
- `sm_80`：生成 CUBIN（当前架构优化）

### 策略 2：多架构显式指定

```bash
nvcc \
  -gencode arch=compute_70,code=sm_70 \
  -gencode arch=compute_80,code=sm_80 \
  -gencode arch=compute_90,code=sm_90 \
  main.cu -o app
```

### Fatbinary 结构

```
┌─────────────────────────────┐
│        Fatbinary            │
├─────────────────────────────┤
│  PTX (compute_80)           │  ← JIT 编译后备
├─────────────────────────────┤
│  CUBIN (sm_70)              │  ← Volta 优化
├─────────────────────────────┤
│  CUBIN (sm_80)              │  ← Ampere 优化
├─────────────────────────────┤
│  CUBIN (sm_90)              │  ← Hopper 优化
└─────────────────────────────┘
```

## NVCC 预定义宏

| 宏 | 说明 |
|----|------|
| `__NVCC__` | NVCC 编译时定义 |
| `__CUDACC__` | CUDA 源文件编译时定义 |
| `__CUDACC_RDC__` | RDC 模式时定义 |
| `__CUDACC_VER_MAJOR__` | NVCC 主版本号 |
| `__CUDACC_VER_MINOR__` | NVCC 次版本号 |
| `__CUDA_ARCH__` | 当前编译架构（如 800） |

**使用示例**：
```cpp
#if defined(__CUDACC__)
#define CUDA_CALLABLE __host__ __device__
#else
#define CUDA_CALLABLE
#endif

CUDA_CALLABLE void func() {
#if __CUDA_ARCH__ >= 800
    // Ampere+ 专属优化
#endif
}
```

## 常见问题与解决

### 问题 1：跨文件 device 函数调用失败

**错误**：
```
error: identifier "helper" is undefined
```

**解决**：
```bash
# 启用 RDC
nvcc -rdc=true a.cu b.cu -o app

# 或分步编译
nvcc -dc a.cu b.cu
nvcc a.o b.o -o app
```

### 问题 2：架构不匹配

**错误**：
```
no kernel image is available for execution on the device
```

**解决**：
```bash
# 添加目标架构
nvcc -arch=sm_80 -gencode arch=compute_80,code=sm_80 main.cu
```

## 关联知识点

- [[KB-20260307-001]] - CUDA C++ Device Code 语法约束
- [[KB-20250306-003]] - CUDA 内存层次结构
