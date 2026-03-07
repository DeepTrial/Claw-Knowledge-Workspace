---
id: KB-20250306-006B
title: CUDA 常量内存 (Constant Memory)
category: cuda.memory
level: 2
summary: "介绍 CUDA 常量内存的特性：64KB 容量、广播机制、8KB 常量缓存，以及适用场景和性能优化"
contributor: DeepTrial
created: 2026-03-06
updated: 2026-03-06
tags: [cuda, constant-memory, broadcast, cache, optimization]
status: done
---

# CUDA 常量内存 (Constant Memory)

> **学习天数**: Day 006 of 100 Days Triton+CUDA+LLVM Learning Journey  
> **日期**: 2026-03-06

---

## 核心特性

CUDA 常量内存是只读内存，具有以下特性：
- **容量**: 64KB（所有 SM 共享）
- **缓存**: 每个 SM 有 8KB 常量缓存
- **广播**: 同一 warp 内所有线程读取同一地址时，单次读取广播到所有线程
- **适用场景**: 所有线程读取相同数据（如滤波器系数、变换矩阵）

---

## 声明与使用

```cuda
// 编译时常量内存声明
__constant__ float const_data[256];

// 主机端设置常量内存
float host_data[256];
// ... 初始化数据 ...
cudaMemcpyToSymbol(const_data, host_data, sizeof(host_data));

// 设备端使用
__global__ void kernel(float* output) {
    int idx = threadIdx.x;
    // 所有线程读取相同地址，缓存命中
    output[idx] = const_data[idx] * 2.0f;
}
```

---

## 常量内存 vs 全局内存

| 特性 | 常量内存 | 全局内存 |
|------|----------|----------|
| **容量** | 64KB | GB 级别 |
| **访问模式** | 只读 | 读写 |
| **广播** | 是（warp 级） | 是（缓存后） |
| **缓存** | 8KB/SM 专用 | L1/L2 共享 |
| **随机访问** | 慢（串行化） | 正常 |
| **统一访问** | 快（广播） | 缓存后快 |

---

## 使用建议

```cuda
// ✅ 好的使用场景：所有线程读取相同数据
__constant__ float filter_coeffs[9];  // 3x3 滤波器

__global__ void convolution(float* input, float* output, int width) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    float sum = 0.0f;
    for (int fy = 0; fy < 3; fy++) {
        for (int fx = 0; fx < 3; fx++) {
            // 所有线程读取相同的 filter_coeffs
            sum += input[(y + fy) * width + (x + fx)] * filter_coeffs[fy * 3 + fx];
        }
    }
    output[y * width + x] = sum;
}

// ❌ 不好的使用场景：每个线程读取不同地址
__global__ void bad_kernel(float* output, int idx) {
    // 线程 0 读 const_data[0]，线程 1 读 const_data[1]...
    // 导致访问串行化，性能极差
    output[idx] = const_data[idx];
}
```

---

## 运行时更新常量内存

```cuda
// 可以分块更新常量内存（最大 64KB）
for (int chunk = 0; chunk < total_size; chunk += 65536) {
    int size = min(65536, total_size - chunk);
    cudaMemcpyToSymbol(const_data, host_data + chunk, size);
    
    // 启动 kernel 使用当前 chunk
    kernel<<<grid, block>>>(...);
}
```

---

## 参考资源

- CUDA Programming Guide: Constant Memory
- "CUDA by Example" - Chapter on Constant Memory
- NVIDIA Developer Forums: Constant Cache

---

*归档时间: 2026-03-06 | 学习天数: Day 006*
