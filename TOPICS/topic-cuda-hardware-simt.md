---
id: KB-20250308-014
title: CUDA硬件实现与SIMT架构
category: cuda.basics
level: 2
summary: "SIMT架构详解、Warp执行模型、分支发散、独立线程调度、SM硬件多线程"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, hardware, simt, warp, sm, multithreading]
status: done
---

# CUDA硬件实现与SIMT架构

## SIMT架构

**SIMT (Single Instruction Multiple Thread)**：
- **Warp**: 32个线程组成一个执行单位
- 同一Warp内所有线程共享PC (程序计数器)
- 一条指令同时执行32次

```
Warp调度:
┌────────────────────────────────┐
│  Warp Scheduler                 │
│       │                         │
│       ▼                         │
│  ┌─────────────┐                │
│  │ Thread 0-31 │───▶ 执行单元    │
│  │ (same inst) │                │
│  └─────────────┘                │
└────────────────────────────────┘
```

## 分支发散

当Warp内线程走不同分支时，硬件串行化执行：

```cpp
// 发散分支 - 性能差
if (threadIdx.x % 2 == 0) {
    // 路径A
} else {
    // 路径B
}
// Warp先执行A(奇数线程等待)，再执行B
```

**优化**: 让同一Warp内线程走相同分支

## 独立线程调度 (Volta+)

- 每个线程有自己的PC
- 支持细粒度同步
- 需要`__syncwarp()`显式同步

## SM硬件多线程

**Streaming Multiprocessor结构**：

```
┌────────────────────────────────────────┐
│  Warp Schedulers (通常4个)              │
│       │                                │
│       ▼                                │
│  Warp Pool (最多64 warps = 2048线程)   │
│       │                                │
│       ▼                                │
│  Execution Units (FP32/INT32/LD/ST)   │
│       │                                │
│       ▼                                │
│  Shared Memory / L1 Cache              │
└────────────────────────────────────────┘
```

### 零开销上下文切换
- Warp等待内存时自动切换
- 不需要保存寄存器状态
- 更多常驻warp = 更好延迟隐藏

### 占用率
```
占用率 = 实际常驻warp数 / 最大支持warp数
```

使用Occupancy Calculator优化：
```cpp
cudaOccupancyMaxActiveBlocksPerMultiprocessor(
    &numBlocks, kernel, blockSize, dynamicSmemSize
);
```

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
