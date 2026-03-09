---
id: KB-20250309-011
title: Clang GPU编译架构详解
category: llvm.frontend
level: 3
summary: "Clang对CUDA/HIP的编译支持、NVPTX/AMDGPU后端流程、GPU编译特有FrontendAction与ToolChain"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [llvm, clang, frontend, gpu, cuda, hip, nvptx, amdgpu]
status: done
relations: [KB-20250309-007]
---

# Clang GPU编译架构详解

## GPU编译支持概述

Clang通过以下方式支持GPU编译：
- **CUDA**: `-x cuda` → NVPTX后端 → PTX代码
- **HIP**: `-x hip` → AMDGPU或NVPTX后端
- **OpenMP Offload**: `-fopenmp-targets=`

## GPU编译调用链

```
$ clang -x cuda test.cu
  └─▶ Driver识别CUDA源文件
        └─▶ 创建Host+Device双重编译任务
              ├─▶ Host编译: x86_64 → 主机代码
              └─▶ Device编译: nvptx64 → PTX代码
                    └─▶ 运行时由CUDA驱动加载
```

## GPU ToolChain

```cpp
// CUDA ToolChain
class CudaToolChain : public ToolChain {
  // 管理CUDA编译流程
  // 协调Host和Device编译
};

// AMDGPU ToolChain
class AMDGPUToolChain : public ToolChain {
  // 管理HIP/AMDGPU编译
};
```

## 关键FrontendAction

| Action | 用途 |
|--------|------|
| `EmitPTXAction` | 输出PTX代码 |
| `EmitBCAction` | 输出LLVM Bitcode |
| `EmitObjAction` | 编译为对象文件(含设备代码) |

## NVPTX后端流程

```cpp
// 1. Frontend生成LLVM IR
// 2. NVPTX后端 lowering
// 3. 生成PTX汇编

// Backend调用链
TargetMachine::addPassesToEmitFile()
  └─▶ NVPTXPassConfig::addInstSelector()
        └─▶ 生成NVPTX指令
```

## 参考

- [[KB-20250309-007]] Clang前端架构深度解析
