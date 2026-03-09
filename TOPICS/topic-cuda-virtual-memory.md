---
id: KB-20250308-017
title: CUDA虚拟内存管理VMM
category: cuda.basics
level: 3
summary: "细粒度虚拟内存控制API：物理内存分配、虚拟地址预留、内存映射、访问权限控制、Fabric多GPU内存"
contributor: main
created: 2026-03-08
updated: 2026-03-08
tags: [cuda, vmm, virtual-memory, memory-management, fabric, multicast]
status: done
---

# CUDA虚拟内存管理VMM

## 简介

CUDA虚拟内存管理API，允许细粒度内存控制。

## 查询支持

```cpp
int vmmSupported;
cuDeviceGetAttribute(&vmmSupported, 
    CU_DEVICE_ATTRIBUTE_VIRTUAL_MEMORY_MANAGEMENT_SUPPORTED, device);
```

## 分配物理内存

```cpp
CUmemGenericAllocationHandle handle;
CUmemAllocationProp prop = {};
prop.type = CU_MEM_ALLOCATION_TYPE_PINNED;
prop.location.type = CU_MEM_LOCATION_TYPE_DEVICE;
prop.location.id = device;

cuMemCreate(&handle, size, &prop, 0);
```

## 预留虚拟地址

```cpp
CUdeviceptr ptr;
cuMemAddressReserve(&ptr, size, 0, 0, 0);
```

## 内存映射

```cpp
cuMemMap(ptr, size, 0, handle, 0);
```

## 访问权限控制

```cpp
CUmemAccessDesc accessDesc = {};
accessDesc.location.type = CU_MEM_LOCATION_TYPE_DEVICE;
accessDesc.location.id = device;
accessDesc.flags = CU_MEM_ACCESS_FLAGS_PROT_READWRITE;

cuMemSetAccess(ptr, size, &accessDesc, 1);
```

## 高级特性

### 虚拟别名
同一物理内存映射到多个虚拟地址。

### Fabric内存
多GPU共享内存支持。

### 多播支持 (Hopper+)
多播内存操作。

## 参考

- https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html
