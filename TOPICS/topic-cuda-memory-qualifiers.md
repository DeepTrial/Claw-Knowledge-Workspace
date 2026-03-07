---
id: KB-20260307-003
title: CUDA 内存空间限定符详解
category: cuda.memory
level: 2
tags: [cuda, memory, qualifiers, shared, constant, managed]
summary: "CUDA 变量内存空间限定符的使用方法、性能特点与最佳实践"
contributor: main
created: 2026-03-07
updated: 2026-03-07
status: done
---

# CUDA 内存空间限定符详解

## 内存限定符总览

| 限定符 | 内存类型 | 位置 | 速度 | 容量 |
|--------|----------|------|------|------|
| `__device__` | 全局内存 | DRAM | 慢 | 大（GB级）|
| `__constant__` | 常量内存 | DRAM + Cache | 快（命中时）| 64KB |
| `__shared__` | 共享内存 | On-chip | 最快 | 48KB+/SM |
| `__managed__` | 统一内存 | 自动迁移 | 视情况 | 大 |
| `__grid_constant__` | Grid 常量 | 常量缓存 | 快 | Kernel 参数 |

## 1. `__device__` - 全局内存

### 声明与使用
```cpp
// 全局变量（文件作用域）
__device__ float global_data[1024];

// Kernel 中访问
__global__ void kernel(float* output) {
    int idx = threadIdx.x;
    output[idx] = global_data[idx];
}
```

### 特性
- **生命周期**：程序全程
- **可见性**：所有 kernel（跨 grid）
- **访问**：Host 通过 `cudaMemcpy`/`cudaMemcpyToSymbol`
- **性能**：无缓存时延迟 400-600 cycles

### Host 访问示例
```cpp
// 写入
float host_data[1024] = {1.0f};
cudaMemcpyToSymbol(global_data, host_data, sizeof(host_data));

// 读取
cudaMemcpyFromSymbol(host_data, global_data, sizeof(host_data));
```

## 2. `__constant__` - 常量内存

### 声明与使用
```cpp
__constant__ float const_data[256];  // 最大 64KB

__global__ void kernel(float* output) {
    int idx = threadIdx.x;
    output[idx] = const_data[idx % 256];
}
```

### 特性
- **缓存**：常量缓存（8KB per SM）
- **广播**：warp 内相同地址访问时高效广播
- **限制**：64KB 总量，只读
- **性能**：缓存命中时 1 cycle，未命中 ~100 cycles

### 最佳实践
```cpp
// ✅ 适合常量内存：只读、warp 内统一访问
__constant__ float filter_weights[256];

// ❌ 不适合：warp 内分散访问
// 每个 thread 访问不同地址 → 串行化
```

## 3. `__shared__` - 共享内存

### 声明与使用
```cpp
// 静态共享内存
__global__ void kernel_static() {
    __shared__ float shared_data[256];
    shared_data[threadIdx.x] = threadIdx.x;
    __syncthreads();
}

// 动态共享内存
__global__ void kernel_dynamic(int n) {
    extern __shared__ float shared_data[];
    shared_data[threadIdx.x] = threadIdx.x;
}

// 启动时指定大小
kernel_dynamic<<<blocks, threads, 256 * sizeof(float)>>>(n);
```

### 特性
- **位置**：On-chip（每个 SM）
- **速度**：~20-30 cycles（比全局内存快 20-100 倍）
- **容量**：48KB-228KB/SM（架构相关）
- **可见性**：Block 内所有 thread

### Bank Conflict 问题
```cpp
// ❌ Bank conflict（步长为 32）
__shared__ float data[256];
float val = data[threadIdx.x * 32];  // 32-way bank conflict

// ✅ 无冲突
float val = data[threadIdx.x];       // 并行访问
```

**Bank 分配规则**：
- 32 个 bank（4 字节对齐）
- `bank_id = (address / 4) % 32`
- 同一 warp 内多个 thread 访问同一 bank → 串行化

### 优化技巧
```cpp
// Padding 消除 bank conflict
__shared__ float data[256 + 1];  // +1 padding
float val = data[threadIdx.x * 33];  // 无冲突
```

## 4. `__managed__` - 统一内存

### 声明与使用
```cpp
__managed__ float managed_data[1024];

int main() {
    // Host 直接访问
    for (int i = 0; i < 1024; i++) {
        managed_data[i] = i * 0.5f;
    }

    // Kernel 直接访问
    kernel<<<1, 1024>>>(managed_data);
    cudaDeviceSynchronize();

    // Host 再次访问
    printf("%f\n", managed_data[0]);
}
```

### 特性
- **自动迁移**：CUDA 运行时自动在 Host/Device 间迁移
- **简化编程**：无需手动 `cudaMemcpy`
- **要求**：计算能力 6.0+（Pascal 及以上）
- **提示**：使用 `cudaMemPrefetchAsync` 优化

### 性能优化
```cpp
// 预取到 Device
cudaMemPrefetchAsync(managed_data, size, deviceId);

// 预取到 Host
cudaMemPrefetchAsync(managed_data, size, cudaCpuDeviceId);

// 建议访问位置
cudaMemAdvise(managed_data, size, cudaMemAdviseSetPreferredLocation, deviceId);
```

## 5. `__grid_constant__` - Grid 常量（CUDA 11.1+）

### 用途
用于常量 kernel 参数，存储在常量缓存中。

```cpp
struct Params {
    float a, b, c;
    int n;
};

__global__ void kernel(__grid_constant__ const Params p) {
    // p 存储在常量缓存，高效访问
    float result = p.a * threadIdx.x + p.b;
}
```

### 特性
- **位置**：常量缓存
- **优势**：避免参数复制到共享内存
- **限制**：只读，仅用于 kernel 参数

## 性能对比

```
共享内存:     ~20 cycles  ████████████████████ (最快)
常量缓存:     ~1-100 cycles  ████████ (命中时极快)
全局内存:     ~400-600 cycles  █ (无缓存时最慢)
```

## 最佳实践总结

1. **频繁访问的小数据** → `__shared__`
2. **只读且 warp 统一访问** → `__constant__`
3. **大块只读数据** → `__device__` + `__restrict__`
4. **Host/Device 共享** → `__managed__`
5. **Kernel 常量参数** → `__grid_constant__`

## 关联知识点

- [[KB-20250306-002]] - CUDA 内存层次结构
- [[KB-20260307-001]] - CUDA C++ Device Code 语法约束
