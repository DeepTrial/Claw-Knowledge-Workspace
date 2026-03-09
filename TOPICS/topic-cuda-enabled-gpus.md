---
id: KB-20250308-024
title: CUDA支持GPU架构与查询
category: cuda.basics
level: 1
summary: "消费级和数据中心GPU架构演进、计算能力、GPU信息查询API"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, gpu, architecture, compute-capability, query]
status: done
---

# CUDA支持GPU架构与查询

## 消费级GPU

| 系列 | 架构 | 计算能力 | 代表型号 |
|-----|------|---------|---------|
| GeForce 900 | Maxwell | 5.2 | GTX 980 |
| GeForce 10 | Pascal | 6.1 | GTX 1080 Ti |
| GeForce 20 | Turing | 7.5 | RTX 2080 Ti |
| GeForce 30 | Ampere | 8.6 | RTX 3090 |
| GeForce 40 | Ada | 8.9 | RTX 4090 |

## 数据中心GPU

| 系列 | 架构 | 计算能力 | 代表型号 |
|-----|------|---------|---------|
| Tesla V100 | Volta | 7.0 | V100 |
| Tesla T4 | Turing | 7.5 | T4 |
| A100 | Ampere | 8.0 | A100 |
| H100 | Hopper | 9.0 | H100 |

## Jetson嵌入式

| 型号 | 架构 | 计算能力 |
|-----|------|---------|
| Jetson Nano | Maxwell | 5.3 |
| Jetson TX2 | Pascal | 6.2 |
| Jetson Xavier | Volta | 7.2 |
| Jetson Orin | Ampere | 8.7 |

## 查询GPU信息

```cpp
cudaDeviceProp prop;
cudaGetDeviceProperties(&prop, deviceId);

printf("Device: %s\n", prop.name);
printf("Compute Capability: %d.%d\n", prop.major, prop.minor);
printf("Total Memory: %.2f GB\n", prop.totalGlobalMem / 1e9);
printf("Multiprocessors: %d\n", prop.multiProcessorCount);
printf("Max Threads/Block: %d\n", prop.maxThreadsPerBlock);
printf("Shared Memory/Block: %zu bytes\n", prop.sharedMemPerBlock);
```

## 架构演进

- **Maxwell**: 统一内存初步支持
- **Pascal**: Compute Preemption
- **Volta**: Tensor Core，独立线程调度
- **Turing**: RT Core，GDDR6
- **Ampere**: 第三代Tensor Core，MIG
- **Ada**: DLSS 3
- **Hopper**: 第四代Tensor Core，TMA

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
