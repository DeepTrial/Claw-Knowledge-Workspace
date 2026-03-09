---
id: KB-20250309-006
title: CUTLASS 性能调优实战
category: cuda.optimization
level: 3
summary: "CUTLASS Profiler使用、Tile Size选择、Nsight Compute分析、常见性能问题排查与优化技巧"
contributor: main
created: 2026-03-09
updated: 2026-03-09
tags: [cutlass, cuda, profiling, tuning, nsight-compute, optimization]
status: done
---

# CUTLASS 性能调优实战

## 使用 CUTLASS Profiler

CUTLASS 内置了强大的 Profiler 工具，可以自动搜索最优配置。

```bash
# 编译 Profiler
cd cutlass/build
make cutlass_profiler -j

# 运行 Gemm Profiler
./tools/profiler/cutlass_profiler \
    --operation=gemm \
    --m=1024,2048,4096 \
    --n=1024,2048,4096 \
    --k=1024,2048 \
    --A=f16:row \
    --B=f16:column \
    --C=f32:column \
    --accumulator-type=f32

# 输出包含每种配置的性能和内存使用情况
```

### Profiler 输出解读

```
Problem,Provider,OperationKind,Operation,Disposition,Status,conv_kind,n,s,d,h,w,c,k,r,s,p,q,gemm_mode,alpha,beta,split_k_mode,split_k_slices,epilogue,blas_mode,a,b,c,d,alpha,beta,split_k_mode,split_k_slices,batch_count,opcode_class,sm_count,cycles,elapsed_ms,gflops,...

Gemm, CUTLASS, gemm, cutlass_tensorop_f16_s16816gemm_f16_128x128_32x3..., passed, success, ..., 4096, 4096, 4096, ..., 0.47, 292.5, ...
                                                        ↑              ↑
                                                    耗时(ms)      TFLOPS
```

---

## Tile Size 选择指南

### 影响因素

```
Tile Size (CTA Shape) 的选择权衡:

┌─────────────┬─────────────────┬─────────────────┐
│   大 Tile   │     中 Tile     │    小 Tile      │
│ 256x128x64  │   128x128x32   │   64x64x32      │
├─────────────┼─────────────────┼─────────────────┤
• 数据复用好  │ • 平衡          │ • Occupancy 高  │
• SMEM 压力大 │ • 甜点配置      │ • 复用较少      │
• Occupancy 低│ • 适合通用场景  │ • 适合小矩阵    │
└─────────────┴─────────────────┴─────────────────┘
```

### 针对不同 Shape 的建议

| M,N,K 范围 | 推荐 Tile | 说明 |
|------------|-----------|------|
| 小 (<512) | 64x64x32 | 提高 Occupancy |
| 中 (512-2048) | 128x128x32 | 平衡选择 |
| 大 (>2048) | 256x128x64 | 最大化数据复用 |
| 瘦 K (<256) | 使用 SplitK | K 维并行 |

---

## 分析工具使用

### Nsight Compute

```bash
# 采集详细指标
ncu -o profile_report \
    --metrics \
    sm__throughput.avg.pct_of_peak_sustained_elapsed,\
    memory__throughput.avg.pct_of_peak_sustained_elapsed,\
    l1tex__t_sectors_pipe_lsu_mem_global_op_ld.sum,\
    lts__t_sectors_aperture_sysmem_op_read.sum \
    ./your_gemm_kernel

# 关键指标解读:
# - sm__throughput: SM 利用率
# - memory__throughput: 内存带宽利用率
# - l1tex__t_sectors: L1/Tex 缓存访问
```

### 常用诊断指标

```cpp
// 理论峰值计算 (A100 FP16 Tensor Core)
// 108 SMs * 256 FMA/cycle/SM * 2 (FMA) * 1.41 GHz = 78 TFLOPS

// 实际效率 = 实测 TFLOPS / 理论峰值 TFLOPS

// 如果效率低，检查:
// 1. Occupancy: ncu 中查看 achieved_occupancy
//    - 目标: > 50%
//    - 低 Occupancy 原因: 寄存器过多、SMEM 过多、Block 尺寸不当
//
// 2. 内存带宽: memory__throughput
//    - 如果接近峰值但计算效率低，可能是内存 bound
//    - 解决方案: 增大 Tile Size，提高数据复用
//
// 3. 指令发射: smsp__issue_active.avg.pct_of_peak_sustained_elapsed
//    - 低说明有气泡 (stall)
//    - 检查同步点和依赖
```

---

## 常见问题排查

### 1. Bank Conflict

```cpp
// 症状: Shared Memory 访问延迟高
// 诊断: ncu 中 l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum

// 解决方案: Swizzle 布局
using SmemLayoutAtom = decltype(composition(
    Swizzle<2,3,3>{},  // 2-bit swizzle
    make_layout(make_shape(Int<8>{}, Int<32>{}),
                make_stride(Int<32>{}, Int<1>{}))
));
```

### 2. 寄存器压力

```cpp
// 症状: Occupancy 低，编译器 spills
// 诊断: ncu 中显示 register_spill

// 解决方案:
// - 减小 Tile Size
// - 减少 live variable
// - 使用 __launch_bounds__ 限制寄存器

template <int MaxThreadsPerBlock, int MinBlocksPerMultiprocessor>
__launch_bounds__(MaxThreadsPerBlock, MinBlocksPerMultiprocessor)
__global__ void kernel(...) { }
```

### 3. 同步开销

```cpp
// 症状: SM 利用率低，大量时间花在同步
// 诊断: ncu 中 stall_sync 占比

// 解决方案:
// - 使用 cp.async 减少同步点
// - 采用 PipelineV2 细粒度同步
// - 调整 Stages 数量
```

---

## 性能调优 checklist

```cpp
□ 1. 确认问题规模
  □ 矩阵尺寸 (M, N, K)
  □ 数据类型 (FP32/FP16/BF16/INT8)
  □ 布局 (Row/Column major)

□ 2. 选择合适的 Tile Size
  □ CTA Tile: 128x128 或 256x128 (甜点)
  □ Warp Tile: CTA / 4 或 CTA / 8
  □ MMA Tile: 根据数据类型 (FP16: 16x8x16)

□ 3. 优化内存访问
  □ 确认 Global Memory 合并访问
  □ Shared Memory 无 bank conflict (使用 swizzle)
  □ 使用向量加载 (128-bit)

□ 4. 流水线优化
  □ Stages 数量 (2-5，根据 K 维度)
  □ 使用 cp.async (Ampere+)
  □ 检查同步开销

□ 5. Tensor Core 使用
  □ 确认数据布局符合 Tensor Core 要求
  □ 使用正确的 MMA instruction shape
  □ 验证 accumulator 精度

□ 6. Occupancy 检查
  □ 寄存器使用 < 255 per thread
  □ SMEM 使用 < 164KB (A100)
  □ 每个 SM 至少 4 warps
```

---

## 参考

- [[KB-20250309-001]] CUTLASS CuTe 系统性学习计划
- [[KB-20250309-004]] CUTLASS 架构设计详解
- [[KB-20250309-005]] Gemm 实现原理与优化
