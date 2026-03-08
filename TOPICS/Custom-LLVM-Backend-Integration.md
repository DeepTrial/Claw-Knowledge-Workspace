---
id: KB-20260308-004
title: 自定义 LLVM Backend 集成深度调研
contributor: bot-a
created: 2026-03-08
updated: 2026-03-08
tags: [LLVM, Backend, TargetMachine, 代码生成, 寄存器分配, 汇编生成]
status: done
---

# 自定义 LLVM Backend 集成深度调研

> 本文档是对自定义 LLVM Backend 集成的深度技术调研，重点是如何让现有的自定义 LLVM backend 与 MLIR/Triton 对接。

---

## 📋 目录

1. [LLVM Backend 架构概览](#1-llvm-backend-架构概览)
2. [TargetMachine 核心类](#2-targetmachine-核心类)
3. [Target 注册机制](#3-target-注册机制)
4. [代码生成流程](#4-代码生成流程)
5. [与 MLIR/Triton 对接](#5-与-mlirtriton-对接)
6. [关键配置点](#6-关键配置点)
7. [调试与验证](#7-调试与验证)
8. [常见问题与解决方案](#8-常见问题与解决方案)
9. [参考资料](#9-参考资料)

---

## 1. LLVM Backend 架构概览

### 1.1 LLVM Backend 的核心组成

LLVM Backend 由以下核心组件构成：

```
┌─────────────────────────────────────────────────────────┐
│                  LLVM IR (输入)                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│            Target-Independent Code Generator            │
│  ─────────────────────────────────────────────────────  │
│  • Instruction Selection (SelectionDAG / GlobalISel)    │
│  • Scheduling and Formation                             │
│  • SSA-based Optimizations                              │
│  • Register Allocation                                  │
│  • Prolog/Epilog Insertion                              │
│  • Late Machine Code Optimizations                      │
│  • Code Emission                                        │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│           Target Description (你的自定义 Backend)        │
│  ─────────────────────────────────────────────────────  │
│  • TargetMachine (目标机器抽象)                         │
│  • TargetRegisterInfo (寄存器信息)                       │
│  • TargetInstrInfo (指令信息)                            │
│  • TargetFrameLowering (栈帧布局)                        │
│  • TargetLowering (LLVM IR → SelectionDAG lowering)     │
│  • AsmPrinter (汇编打印)                                │
│  • MC Layer (机器码层)                                  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│            Assembly / Object Code (输出)                 │
└─────────────────────────────────────────────────────────┘
```

### 1.2 两种指令选择方式

**SelectionDAG**（传统方式）：
- 基于 DAG 的指令选择
- 大多数 target 使用
- 成熟稳定

**GlobalISel**（新方式）：
- 直接在 MIR 上操作
- 更好的性能和模块化
- AArch64 已支持，其他 target 逐步迁移

**选择建议**：
- 如果你的 backend 已实现：使用现有方式（可能是 SelectionDAG）
- 如果新建 backend：可考虑 GlobalISel（但资料较少）

---

## 2. TargetMachine 核心类

### 2.1 TargetMachine 类层次

```
llvm::TargetMachine (基类)
      ↓
llvm::LLVMTargetMachine (使用 LLVM code generator 的基类)
      ↓
llvm::CodeGenTargetMachineImpl (代码生成 target 基类)
      ↓
YourTargetMachine (你的自定义 target)
```

### 2.2 TargetMachine 核心接口

**必须实现的方法**：

```cpp
class MyTargetMachine : public CodeGenTargetMachineImpl {
  const DataLayout DataLayout;         // 数据布局（必需）
  MyTargetSubtarget Subtarget;         // 子目标
  MyTargetInstrInfo InstrInfo;         // 指令信息
  MyTargetFrameLowering FrameInfo;     // 栈帧信息
  
public:
  MyTargetMachine(const Target &T, const Triple &TT, 
                   StringRef CPU, StringRef FS,
                   const TargetOptions &Options,
                   Reloc::Model RM, CodeModel::Model CM,
                   CodeGenOptLevel OL);
  
  // 必需的访问器
  const DataLayout *getDataLayout() const override { return &DataLayout; }
  const TargetSubtargetInfo *getSubtargetImpl() const override { return &Subtarget; }
  const TargetInstrInfo *getInstrInfo() const override { return &InstrInfo; }
  const TargetFrameLowering *getFrameLowering() const override { return &FrameInfo; }
  const TargetRegisterInfo *getRegisterInfo() const override {
    return &InstrInfo.getRegisterInfo();
  }
  
  // 可选但重要的方法
  TargetLowering *getTargetLowering() const override;
  TargetTransformInfo getTargetTransformInfo(const Function &F) const override;
  
  // Pass pipeline 配置
  bool addPassesToEmitFile(PassManagerBase &PM, raw_pwrite_stream &Out,
                            raw_pwrite_stream *DwoOut,
                            CodeGenFileType FileType,
                            bool DisableVerify = true) override;
  
  bool addInstSelector(PassManagerBase &PM, bool Fast) override;
};
```

### 2.3 Data Layout 配置

**Data Layout 字符串格式**：

```
<endianness>-<pointer>:<size>:<abi>:<pref>
                  -<type>:<abi>:<pref>
                  -<type>:<abi>:<pref>
                  ...

示例（x86_64）：
"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"

解析：
e       : 小端字节序
m:e     : mangling: ELF
p:270:32:32 : pointer size=64, abi alignment=32, preferred alignment=32
i64:64  : i64 size=64, alignment=64
f80:128 : f80 size=128, alignment=128
n8:16:32:64 : native integer widths
S128    : stack alignment=128
```

**配置示例**：

```cpp
MyTargetMachine::MyTargetMachine(...)
    : DataLayout("e-m:e-p:32:32-i64:64-n32"),  // 32-bit 指针，小端
      Subtarget(TT, CPU, FS),
      InstrInfo(Subtarget),
      FrameInfo(/* StackGrowsDown */ true, /* StackAlignment */ 16, ...) {
  initAsmInfo();
}
```

---

## 3. Target 注册机制

### 3.1 注册流程

**三步注册流程**：

```
1. 定义全局 Target 对象
   Target llvm::getTheMyTarget();

2. 注册 TargetInfo（基本信息）
   LLVMInitializeMyTargetTargetInfo()

3. 注册其他组件（可选）
   LLVMInitializeMyTargetAsmPrinter()
   LLVMInitializeMyTargetAsmParser()
   LLVMInitializeMyTargetDisassembler()
   LLVMInitializeMyTargetTargetMC()
   LLVMInitializeMyTargetCodeGen()
```

### 3.2 注册代码示例

**lib/Target/MyTarget/TargetInfo/MyTargetTargetInfo.cpp**：

```cpp
#include "llvm/Support/TargetRegistry.h"
#include "llvm/IR/Module.h"

namespace llvm {
Target &getTheMyTarget() {
  static Target TheMyTarget;
  return TheMyTarget;
}
} // namespace llvm

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeMyTargetTargetInfo() {
  using namespace llvm;
  
  RegisterTarget<Triple::myarch, /*HasJIT=*/false> X(
      getTheMyTarget(), "myarch", "My Custom Architecture",
      "MyArch"  // Arch name
  );
}
```

**lib/Target/MyTarget/MyTarget.cpp**（注册其他组件）：

```cpp
extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeMyTargetAsmPrinter() {
  using namespace llvm;
  RegisterAsmPrinter<MyTargetAsmPrinter> X(getTheMyTarget());
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeMyTargetTargetMC() {
  using namespace llvm;
  RegisterTargetMC<TargetMachine>(getTheMyTarget());
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeMyTargetCodeGen() {
  using namespace llvm;
  TargetRegistry::RegisterCodeEmitter(getTheMyTarget(), 
                                       createMyTargetCodeEmitter);
}
```

### 3.3 初始化调用顺序

**在使用 backend 前，必须调用初始化函数**：

```cpp
// 方式 1: 手动调用
extern "C" void LLVMInitializeMyTargetTargetInfo();
extern "C" void LLVMInitializeMyTargetAsmPrinter();
extern "C" void LLVMInitializeMyTargetTargetMC();
extern "C" void LLVMInitializeMyTargetCodeGen();

LLVMInitializeMyTargetTargetInfo();
LLVMInitializeMyTargetAsmPrinter();
LLVMInitializeMyTargetTargetMC();
LLVMInitializeMyTargetCodeGen();

// 方式 2: 使用 LLVM 提供的宏（推荐）
#include "llvm/Support/TargetSelect.h"

llvm::InitializeAllTargets();
llvm::InitializeAllTargetMCs();
llvm::InitializeAllAsmPrinters();

// 或只初始化特定 target
llvm::InitializeMyTargetTarget();
llvm::InitializeMyTargetTargetMC();
llvm::InitializeMyTargetAsmPrinter();
```

---

## 4. 代码生成流程

### 4.1 完整代码生成流程

```
LLVM IR (Module)
      ↓
┌─────────────────────────────────────────────────────────┐
│  1. Instruction Selection (指令选择)                     │
│  ─────────────────────────────────────────────────────  │
│  • SelectionDAG 构建或 GlobalISel IRTranslator          │
│  • 类型合法化（LegalizeTypes）                          │
│  • 操作合法化（Legalize）                               │
│  • DAG 优化（DAG Combiner）                             │
│  • 指令选择（DAG-to-DAG 或 GlobalISel）                 │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  2. Scheduling and Formation (调度和形成)                │
│  ─────────────────────────────────────────────────────  │
│  • 指令调度（Scheduling）                               │
│  • 形成 MachineInstr                                   │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  3. SSA-based Machine Code Optimizations                │
│  ─────────────────────────────────────────────────────  │
│  • MachineSSA 优化 passes                              │
│  • Dead code elimination                               │
│  • Peephole optimizations                              │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  4. Register Allocation (寄存器分配)                     │
│  ─────────────────────────────────────────────────────  │
│  • 活跃区间分析（Live Intervals）                       │
│  • 寄存器分配（greedy / basic / pbqp）                  │
│  • 插入 spill code                                     │
│  • 虚拟寄存器 → 物理寄存器                              │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  5. Prolog/Epilog Code Insertion                        │
│  ─────────────────────────────────────────────────────  │
│  • 插入函数 prolog 和 epilog                            │
│  • 栈帧布局确定                                        │
│  • 消除抽象栈位置引用                                  │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  6. Late Machine Code Optimizations                     │
│  ─────────────────────────────────────────────────────  │
│  • Spill code scheduling                               │
│  • Peephole optimizations                              │
│  • Branch folding / if conversion                      │
└─────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────┐
│  7. Code Emission (代码发射)                             │
│  ─────────────────────────────────────────────────────  │
│  • 汇编输出（AsmPrinter）                              │
│  • 或机器码输出（MC layer）                             │
└─────────────────────────────────────────────────────────┘
      ↓
Assembly / Object File
```

### 4.2 关键 Pass 管道配置

**TargetMachine::addPassesToEmitFile** 实现：

```cpp
bool MyTargetMachine::addPassesToEmitFile(
    PassManagerBase &PM, 
    raw_pwrite_stream &Out,
    raw_pwrite_stream *DwoOut,
    CodeGenFileType FileType,
    bool DisableVerify) {
  
  // 1. 添加代码生成 passes
  if (TargetPassConfig *TPC = getTargetPassConfig()) {
    if (!TPC->addPassesToEmitFile(PM, Out, DwoOut, FileType, DisableVerify))
      return false;
  }
  
  // 2. 添加 target-specific passes（可选）
  PM.add(createMyTargetPreEmitPass());
  
  // 3. 添加汇编发射
  switch (FileType) {
  case CGFT_AssemblyFile:
    PM.add(createMyTargetAsmPrinterPass(Out));
    break;
  case CGFT_ObjectFile:
    PM.add(createMyTargetMCCodeEmitterPass(Out));
    break;
  case CGFT_Null:
    break;
  }
  
  return false;
}
```

---

## 5. 与 MLIR/Triton 对接

### 5.1 对接点

**MLIR → LLVM IR → 自定义 Backend**：

```
Triton Python AST
      ↓
Triton Dialect (ttir)
      ↓
TritonGPU Dialect (ttgir)
      ↓
LLVM Dialect (llir)
      ↓
【对接点 1】translateModuleToLLVMIR()
      ↓
LLVM IR Module
      ↓
【对接点 2】修改 Target Triple + Data Layout
      ↓
【对接点 3】调用自定义 LLVM Backend
      ↓
自定义汇编代码
```

### 5.2 完整对接代码

```cpp
#include "mlir/Target/LLVMIR/Export.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Support/TargetRegistry.h"
#include "llvm/Support/FileSystem.h"

// 步骤 1: 翻译 MLIR → LLVM IR
llvm::LLVMContext llvmContext;
std::unique_ptr<llvm::Module> llvmModule = 
    mlir::translateModuleToLLVMIR(mlirModule, llvmContext);

if (!llvmModule) {
  llvm::errs() << "Failed to translate MLIR to LLVM IR\n";
  return failure();
}

// 步骤 2: 初始化自定义 backend（必需！）
extern "C" void LLVMInitializeMyTargetTargetInfo();
extern "C" void LLVMInitializeMyTargetAsmPrinter();
extern "C" void LLVMInitializeMyTargetTargetMC();
extern "C" void LLVMInitializeMyTargetCodeGen();

LLVMInitializeMyTargetTargetInfo();
LLVMInitializeMyTargetAsmPrinter();
LLVMInitializeMyTargetTargetMC();
LLVMInitializeMyTargetCodeGen();

// 步骤 3: 查找自定义 target
std::string error;
const llvm::Target *target = 
    llvm::TargetRegistry::lookupTarget("my-custom-target", error);

if (!target) {
  llvm::errs() << "Failed to lookup target: " << error << "\n";
  return failure();
}

// 步骤 4: 创建 TargetMachine
llvm::TargetOptions options;
std::unique_ptr<llvm::TargetMachine> TM = 
    target->createTargetMachine(
        "my-custom-target",  // Triple
        "generic",            // CPU
        "",                   // Features
        options,
        llvm::Reloc::PIC_,    // Relocation model
        llvm::CodeModel::Small, // Code model
        llvm::CodeGenOptLevel::Default  // Optimization level
    );

if (!TM) {
  llvm::errs() << "Failed to create TargetMachine\n";
  return failure();
}

// 步骤 5: 设置目标三元组和数据布局
llvmModule->setTargetTriple("my-custom-target-unknown-unknown");
llvmModule->setDataLayout(TM->createDataLayout());

// 步骤 6: 生成汇编
std::error_code EC;
llvm::raw_fd_ostream dest("output.s", EC, llvm::sys::fs::OF_None);

if (EC) {
  llvm::errs() << "Could not open output file: " << EC.message() << "\n";
  return failure();
}

llvm::legacy::PassManager pass;
if (TM->addPassesToEmitFile(pass, dest, nullptr, 
                             llvm::CGFT_AssemblyFile)) {
  llvm::errs() << "TargetMachine can't emit assembly\n";
  return failure();
}

pass.run(*llvmModule);
dest.flush();

llvm::outs() << "Assembly generated successfully!\n";
```

### 5.3 最小化对接检查清单

**必需步骤**：
- ✅ LLVM backend 已实现并测试
- ✅ 初始化函数已调用（`LLVMInitializeXXX`）
- ✅ TargetMachine 创建成功
- ✅ 目标三元组匹配
- ✅ 数据布局一致
- ✅ ABI 兼容（调用约定、类型大小等）

**测试步骤**：
1. 简单函数测试（add, sub）
2. 内存操作测试（load, store）
3. 控制流测试（branch, loop）
4. 函数调用测试（call, return）
5. 复杂类型测试（struct, array）

---

## 6. 关键配置点

### 6.1 目标三元组（Target Triple）

**标准格式**：
```
<arch><sub>-<vendor>-<sys>-<env>

示例：
x86_64-unknown-linux-gnu
aarch64-unknown-linux-gnu
nvptx64-nvidia-cuda
amdgcn-amd-amdhsa
```

**自定义 triple**：
```cpp
// 建议格式
"myarch-unknown-unknown"
"myarch-vendor-unknown"
```

**设置方式**：
```cpp
// 在 LLVM Module 上设置
llvmModule->setTargetTriple("myarch-unknown-unknown");

// 或在创建 TargetMachine 时指定
target->createTargetMachine("myarch-unknown-unknown", ...);
```

### 6.2 数据布局（Data Layout）

**必需配置**：
```cpp
// 方式 1: 在 TargetMachine 构造函数中
MyTargetMachine::MyTargetMachine(...)
    : DataLayout("e-m:e-p:32:32-i64:64-n32"),  // 你的布局
      ...

// 方式 2: 从 TargetMachine 获取
llvmModule->setDataLayout(TM->createDataLayout());

// 方式 3: 手动设置（不推荐）
llvmModule->setDataLayout("e-m:e-p:32:32-i64:64-n32");
```

**关键字段**：
- `e` / `E`: 小端 / 大端
- `p:size:abi:pref`: 指针大小和对齐
- `i<size>:abi`: 整数对齐
- `f<size>:abi`: 浮点对齐
- `n<size>`: 原生整数宽度

### 6.3 调用约定（Calling Convention）

**确保 ABI 兼容**：
- 参数传递方式（寄存器 vs 栈）
- 返回值处理
- 栈对齐要求
- 寄存器保存规则

**检查点**：
```cpp
// 在 TargetLowering 中检查
TargetLowering::getCallingConvPreservedRegs()
TargetLowering::getByValTypeAlignment()
```

---

## 7. 调试与验证

### 7.1 调试工具

**LLVM 工具链**：
```bash
# 1. 查看所有可用 targets
llc --version

# 2. 生成汇编
llc -march=myarch input.ll -o output.s

# 3. 生成目标文件
llc -march=myarch -filetype=obj input.ll -o output.o

# 4. 查看 LLVM IR
opt -S input.ll -o optimized.ll

# 5. 调试代码生成
llc -march=myarch -debug-only=isel input.ll
llc -march=myarch -debug-only=regalloc input.ll
```

### 7.2 MLIR 调试

```bash
# 转储所有 MLIR passes
export MLIR_ENABLE_DUMP=1

# 转储 LLVM IR
export LLVM_IR_ENABLE_DUMP=1

# 查看特定 pass
mlir-opt --mlir-print-ir-after-all input.mlir
```

### 7.3 常见调试选项

```cpp
// 在代码中启用调试输出
llvm::DebugFlag = true;
llvm::setCurrentDebugType("isel");
llvm::setCurrentDebugType("regalloc");

// 打印 LLVM Module
llvm::outs() << *llvmModule << "\n";

// 打印 MachineFunction
MF.dump();

// 打印 SelectionDAG
DAG.dump();
```

---

## 8. 常见问题与解决方案

### 8.1 Target 未找到

**错误**：
```
unable to get target for 'myarch', see --version and --march.
```

**解决方案**：
```cpp
// 确保调用初始化函数
LLVMInitializeMyTargetTargetInfo();
LLVMInitializeMyTargetTargetMC();
LLVMInitializeMyTargetAsmPrinter();
LLVMInitializeMyTargetCodeGen();

// 或使用全局初始化
llvm::InitializeAllTargets();
```

### 8.2 数据布局不匹配

**错误**：
```
LLVM ERROR: DataLayout for module and target do not match!
```

**解决方案**：
```cpp
// 使用 TargetMachine 的数据布局
llvmModule->setDataLayout(TM->createDataLayout());

// 确保一致
assert(llvmModule->getDataLayout() == TM->createDataLayout());
```

### 8.3 指令选择失败

**错误**：
```
Cannot select: t0: i32 = ...
```

**解决方案**：
1. 检查 TargetLowering 配置
2. 添加缺失的指令模式
3. 实现自定义 lowering

```cpp
// 在 TargetLowering 中
SDValue MyTargetLowering::LowerOperation(SDValue Op, SelectionDAG &DAG) {
  switch (Op.getOpcode()) {
  case ISD::ADD:
    return LowerADD(Op, DAG);
  // ... 处理其他操作
  default:
    return SDValue();
  }
}
```

### 8.4 寄存器分配失败

**错误**：
```
ran out of registers during register allocation
```

**解决方案**：
1. 检查寄存器类定义
2. 增加可用寄存器
3. 优化寄存器使用
4. 启用寄存器压力跟踪

```bash
llc -march=myarch -regalloc=greedy -debug-only=regalloc input.ll
```

---

## 9. 参考资料

### 9.1 官方文档

- **Writing an LLVM Backend**: https://llvm.org/docs/WritingAnLLVMBackend.html
- **The LLVM Target-Independent Code Generator**: https://llvm.org/docs/CodeGenerator.html
- **Global Instruction Selection**: https://llvm.org/docs/GlobalISel/
- **TableGen Programmer's Reference**: https://llvm.org/docs/TableGen/ProgRef.html

### 9.2 源代码参考

**示例 Target（从简单到复杂）**：
- **Sparc**: 简单 RISC，适合学习
- **MIPS**: 经典架构，文档完善
- **ARM/AArch64**: 复杂但完整
- **X86**: 最复杂，支持最多特性

**关键源文件**：
- `llvm/lib/Target/<Target>/`: Target 实现
- `llvm/include/llvm/Target/`: Target 接口
- `llvm/lib/CodeGen/`: 代码生成算法

### 9.3 开发者资源

- **LLVM Discourse**: https://discourse.llvm.org/
- **LLVM Doxygen**: https://llvm.org/doxygen/
- **LLVM GitHub**: https://github.com/llvm/llvm-project

---

## 10. 总结与建议

### 10.1 核心要点

1. ✅ **三步注册**：TargetInfo → TargetMC → AsmPrinter/CodeGen
2. ✅ **初始化必需**：必须调用 `LLVMInitializeXXX` 函数
3. ✅ **配置一致**：Target Triple 和 Data Layout 必须匹配
4. ✅ **ABI 兼容**：调用约定和类型大小必须一致

### 10.2 对接建议

**最小化对接路径**（推荐）：
```
MLIR → translateModuleToLLVMIR() → LLVM IR
      → setTargetTriple() + setDataLayout()
      → TargetMachine::addPassesToEmitFile()
      → 自定义汇编代码
```

**开发量**：约 50-100 行 C++ 代码

**关键 API**：
```cpp
// MLIR → LLVM IR
mlir::translateModuleToLLVMIR()

// Target 查找和创建
llvm::TargetRegistry::lookupTarget()
target->createTargetMachine()

// 代码生成
TM->addPassesToEmitFile()
```

### 10.3 后续行动

1. **验证 backend 可用性**
   - 使用 `llc --version` 检查
   - 测试简单 LLVM IR 程序

2. **对接测试**
   - 实现最小对接代码
   - 测试简单 kernel

3. **逐步增加复杂度**
   - 内存操作
   - 控制流
   - 函数调用

---

*本文档由冰美（bot-a）基于 2026-03-08 的深度调研生成*
*最后更新：2026-03-08 16:30*
