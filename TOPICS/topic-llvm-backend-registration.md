---
id: KB-20260308-001
title: LLVM Backend 注册与 TargetMachine 创建深度解析
category: llvm.backend
level: 3
summary: "深入解析 LLVM 后端注册机制与 TargetMachine 创建流程，包括 TargetRegistry、TargetInfo、TargetLowering 等核心组件"
contributor: bot-a
created: 2026-03-08
updated: 2026-03-08
tags: [llvm, backend, target-machine, registration, codegen]
status: done
relations:
  - KB-20260306-007  # LLVM IR 基础
  - KB-20260308-002  # Bufferization 一致性
---

# LLVM Backend 注册与 TargetMachine 创建深度解析

## 摘要

> 自定义 LLVM Backend 的核心在于理解 TargetRegistry 注册机制和 TargetMachine 创建流程，这是代码生成管线的基础设施。

---

## 1. 核心架构

### 1.1 TargetRegistry：后端注册中心

`TargetRegistry` 是 LLVM 的后端注册中心，管理所有可用的 target 后端。

```cpp
// llvm/Target/TargetRegistry.h
class TargetRegistry {
public:
  // 注册新 target
  static void RegisterTarget(Target &T,
                             const char *Name,
                             const char *ShortDesc,
                             Target::ArchMatchFnTy ArchMatchFn,
                             bool HasJIT);
  
  // 查找 target
  static const Target *lookupTarget(const std::string &Triple,
                                    std::string &Error);
  
  // 遍历所有 target
  static iterator_range<iterator> targets();
};
```

**注册时机**：
- 静态初始化期（通过 `InitializeAllTargets` 宏）
- 每个 target 有对应的 `LLVMInitializeXXXTarget` 函数

### 1.2 Target 类：后端描述

`Target` 类描述了一个 target 后端的元信息：

```cpp
class Target {
public:
  // 核心创建函数
  TargetMachine *createTargetMachine(StringRef TT,
                                     StringRef CPU,
                                     StringRef Features,
                                     const TargetOptions &Options,
                                     Reloc::Model RM,
                                     CodeModel::Model CM,
                                     CodeGenOptLevel OL) const;
  
  // 组件创建函数
  TargetIRAnalysis getTargetIRAnalysis() const;
  
  // 元信息
  const char *getName() const;
  const char *getShortDescription() const;
};
```

### 1.3 TargetMachine：代码生成核心

`TargetMachine` 是代码生成的核心接口：

```cpp
class TargetMachine {
protected:
  const Target &TheTarget;
  const DataLayout DL;
  Triple TargetTriple;
  std::string TargetCPU;
  std::string TargetFS;
  Reloc::Model RM;
  CodeModel::Model CMModel;
  CodeGenOptLevel OptLevel;
  
public:
  // 核心代码生成接口
  virtual bool addPassesToEmitFile(PassManagerBase &PM,
                                   raw_pwrite_stream &Out,
                                   raw_pwrite_stream *DwoOut,
                                   CodeGenFileType FileType,
                                   bool DisableVerify,
                                   MachineModuleInfoWrapperPass *MMIWP);
  
  // 创建 Pass 配置
  virtual TargetPassConfig *createPassConfig(PassManagerBase &PM);
  
  // 新 Pass Manager 支持
  virtual Error buildCodeGenPipeline(ModulePassManager &MPM,
                                     raw_pwrite_stream &Out,
                                     raw_pwrite_stream *DwoOut,
                                     CodeGenFileType FileType,
                                     const CGPassBuilderOption &Opt,
                                     MCContext &Ctx,
                                     PassInstrumentationCallbacks *PIC);
  
  // 关键 getter
  const TargetSubtargetInfo *getSubtargetImpl(const Function &F) const;
  const DataLayout createDataLayout() const;
};
```

---

## 2. 注册流程详解

### 2.1 静态注册模式

每个 target 必须提供初始化函数：

```cpp
// 在 XXXTarget.cpp 中
namespace llvm {
  Target &getTheXXXTarget() {
    static Target TheXXXTarget;
    return TheXXXTarget;
  }
}

extern "C" void LLVMInitializeXXXTargetInfo() {
  TargetRegistry::RegisterTarget(getTheXXXTarget(), "xxx",
    "XXX 32-bit", "XXX 64-bit",
    [](Triple::ArchType Arch) { return Arch == Triple::xxx; },
    true);  // HasJIT
}

extern "C" void LLVMInitializeXXXTarget() {
  // 注册 TargetMachine 创建器
  RegisterTargetMachine<XXXTargetMachine> X(getTheXXXTarget());
}

extern "C" void LLVMInitializeXXXTargetMC() {
  // 注册 MC 层组件
  RegisterMCAsmInfo<XXXMCAsmInfo> A(getTheXXXTarget());
  RegisterMCInstrInfo<XXXMCInstrInfo> B(getTheXXXTarget());
  RegisterMCRegInfo<XXXMCRegisterInfo> C(getTheXXXTarget());
  RegisterMCSubtargetInfo<XXXMCSubtargetInfo> D(getTheXXXTarget());
}
```

### 2.2 使用便捷宏

LLVM 提供了便捷宏简化注册：

```cpp
// 使用 TargetRegistry.h 中的宏
#include "llvm/Target/TargetRegistry.h"

Target &llvm::getTheXXXTarget() {
  static Target TheXXXTarget;
  return TheXXXTarget;
}

// 自动生成 LLVMInitializeXXXTarget 等函数
#define LLVM_TARGET_TRIPLE_LIST
#include "llvm/Config/Targets.def"
```

---

## 3. TargetMachine 创建流程

### 3.1 创建入口

```cpp
// 用户代码
std::string Error;
const Target *TheTarget = TargetRegistry::lookupTarget(Triple, Error);
if (!TheTarget) {
  errs() << Error;
  return 1;
}

TargetOptions Options;
Options.AllowFPErrors = true;

TargetMachine *TM = TheTarget->createTargetMachine(
    Triple, CPU, Features, Options, Reloc::Model::PIC_,
    CodeModel::Model::Small, CodeGenOptLevel::Default);
```

### 3.2 具体实现（以 RISCV 为例）

```cpp
// RISCVTargetMachine.cpp
class RISCVTargetMachine : public LLVMTargetMachine {
  std::unique_ptr<TargetLoweringObjectFile> TLOF;
  RISCVSubtarget Subtarget;
  
public:
  RISCVTargetMachine(const Target &T, const Triple &TT, StringRef CPU,
                     StringRef FS, const TargetOptions &Options,
                     Reloc::Model RM, CodeModel::Model CM,
                     CodeGenOptLevel OL)
      : LLVMTargetMachine(T, computeDataLayout(TT, FS), TT, CPU, FS,
                          Options, RM, CM, OL),
        TLOF(std::make_unique<RISCVTargetObjectFile>()),
        Subtarget(TT, CPU, FS, *this) {
    initAsmInfo();
  }
  
  TargetPassConfig *createPassConfig(PassManagerBase &PM) override {
    return new RISCVPassConfig(*this, PM);
  }
  
  const RISCVSubtarget *getSubtargetImpl(const Function &F) const override {
    return &Subtarget;
  }
};

// 注册
Target &llvm::getTheRISCVTarget() {
  static Target TheRISCVTarget;
  return TheRISCVTarget;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRISCVTarget() {
  RegisterTargetMachine<RISCVTargetMachine> X(getTheRISCVTarget());
}
```

---

## 4. 代码生成管线

### 4.1 Legacy Pass Manager 流程

```cpp
// TargetMachine::addPassesToEmitFile 的典型实现
bool RISCVTargetMachine::addPassesToEmitFile(
    PassManagerBase &PM, raw_pwrite_stream &Out,
    raw_pwrite_stream *DwoOut, CodeGenFileType FileType,
    bool DisableVerify, MachineModuleInfoWrapperPass *MMIWP) {
  
  // 1. 创建 Pass 配置
  TargetPassConfig *PassConfig = createPassConfig(PM);
  
  // 2. 添加代码生成 Pass
  PassConfig->addISelPasses();
  PassConfig->addPreRegAllocPasses();
  PassConfig->addRegAllocPasses();
  PassConfig->addPostRegAllocPasses();
  PassConfig->addPreSched2Passes();
  PassConfig->addPreEmitPasses();
  
  // 3. 添加 AsmPrinter
  PassConfig->addPassesToEmitFile(Out, DwoOut, FileType, MMIWP);
  
  return false;
}
```

### 4.2 新 Pass Manager 流程

```cpp
// TargetMachine::buildCodeGenPipeline 的典型实现
Error RISCVTargetMachine::buildCodeGenPipeline(
    ModulePassManager &MPM, raw_pwrite_stream &Out,
    raw_pwrite_stream *DwoOut, CodeGenFileType FileType,
    const CGPassBuilderOption &Opt, MCContext &Ctx,
    PassInstrumentationCallbacks *PIC) {
  
  // 构建代码生成管线
  CodeGenPassBuilder Builder(*this, Opt, PIC);
  
  // 添加各阶段
  MPM.addPass(Builder.buildISelPipeline());
  MPM.addPass(Builder.buildRegAllocPipeline());
  MPM.addPass(BuilderbuildEmissionPipeline(Out, FileType));
  
  return ErrorSuccess();
}
```

---

## 5. 核心子组件

### 5.1 TargetSubtargetInfo

```cpp
class TargetSubtargetInfo {
public:
  // 特性查询
  virtual bool hasFeature(unsigned Feature) const;
  
  // 指令调度器
  virtual const InstrItineraryData *getInstrItineraryData() const;
  
  // ABI 信息
  virtual unsigned getStackAlignment() const;
  
  // 寄存器信息
  virtual const TargetRegisterClass *getPointerRegClass(unsigned Kind) const;
};
```

### 5.2 TargetLowering

```cpp
class TargetLowering {
public:
  // 类型转换
  virtual MVT getRegisterType(MVT VT) const;
  
  // 操作合法化
  virtual bool isOperationLegal(unsigned Op, EVT VT) const;
  
  // 调用约定
  virtual CCAssignFn *getCCAssignFnForCall() const;
  
  // DAG 节点转换
  virtual SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const;
};
```

### 5.3 MC 层组件

```cpp
// MCAsmInfo: 汇编语法
class MCAsmInfo {
public:
  virtual const char *getData16bitsDirective() const;
  virtual bool isLittleEndian() const;
};

// MCInstrInfo: 指令描述
class MCInstrInfo {
public:
  const MCInstrDesc &get(unsigned Opcode) const;
};

// MCRegisterInfo: 寄存器信息
class MCRegisterInfo {
public:
  MCRegister getMatchingSuperReg(MCRegister Reg, unsigned SubIdx,
                                  const MCRegisterClass *RC) const;
};
```

---

## 6. 自定义 Backend 集成要点

### 6.1 必须实现的组件

| 组件 | 文件 | 作用 |
|------|------|------|
| `XXXTargetMachine` | `XXXTargetMachine.cpp` | 核心代码生成 |
| `XXXSubtarget` | `XXXSubtarget.cpp` | 子目标特性 |
| `XXXTargetLowering` | `XXXISelLowering.cpp` | DAG 转换 |
| `XXXMCAsmInfo` | `XXXMCAsmInfo.cpp` | 汇编格式 |
| `XXXRegisterInfo` | `XXXRegisterInfo.cpp` | 寄存器信息 |
| `XXXInstrInfo` | `XXXInstrInfo.cpp` | 指令描述 |

### 6.2 TableGen 描述文件

```
// XXX.td - Target 描述
def XXX : Target {
  let InstructionSet = XXXInstrInfo;
  let AssemblyParsers = [XXXAsmParser];
  let AssemblyPrinters = [XXXAsmPrinter];
}

// XXXRegisterInfo.td - 寄存器定义
def R0 : Register<"r0">;
def GPR : RegisterClass<"XXX", [i32], 32, (add R0, R1, ...)>;

// XXXInstrInfo.td - 指令定义
def ADD : Instruction {
  let OutOperandList = (outs GPR:$rd);
  let InOperandList = (ins GPR:$rs1, GPR:$rs2);
  let AsmString = "add $rd, $rs1, $rs2";
}
```

### 6.3 CMake 配置

```cmake
# CMakeLists.txt
add_llvm_target(XXXCodeGen
  XXXAsmPrinter.cpp
  XXXISelDAGToDAG.cpp
  XXXISelLowering.cpp
  XXXInstrInfo.cpp
  XXXMCInstLower.cpp
  XXXRegisterInfo.cpp
  XXXSubtarget.cpp
  XXXTargetMachine.cpp
)

add_llvm_target_group(XXX
  XXXCodeGen
  XXXAsmParser
  XXXDesc
  XXXInfo
)
```

---

## 7. 调试技巧

### 7.1 启用调试输出

```bash
# 打印所有注册的 target
llc -version

# 打印 Pass 管线
llc -debug-pass=Structure -march=xxx input.ll

# 打印 DAG
llc -view-isel-dags -march=xxx input.ll
```

### 7.2 常见问题

**问题 1**: `Unable to find target for 'xxx'`
- 原因：未调用 `LLVMInitializeXXXTarget`
- 解决：在 `main()` 中添加 `InitializeAllTargets()` 或显式调用初始化函数

**问题 2**: `cannot select intrinsic`
- 原因：TargetLowering 未实现对应 intrinsic
- 解决：在 `XXXISelLowering.cpp` 中添加 `LowerOperation` 处理

**问题 3**: 寄存器分配失败
- 原因：寄存器类定义或调用约定问题
- 解决：检查 `XXXCallingConv.td` 和 `XXXRegisterInfo.td`

---

## 8. 与 MLIR/Triton 集成

### 8.1 从 MLIR 到 LLVM IR

```cpp
// MLIR Pass 管线
mlir::PassManager pm;
pm.addPass(mlir::createConvertSCFToCFPass());
pm.addPass(mlir::createConvertMathToLLVMPass());
pm.addPass(mlir::createConvertFuncToLLVMPass());
pm.addPass(mlir::createConvertVectorToLLVMPass());
pm.addPass(mlir::createFinalizeMemRefToLLVMConversionPass());
```

### 8.2 LLVM IR 到目标代码

```cpp
// 通过 TargetMachine 生成目标代码
std::unique_ptr<TargetMachine> TM(TheTarget->createTargetMachine(...));

legacy::PassManager PM;
TM->addPassesToEmitFile(PM, Out, nullptr, CodeGenFileType::ObjectFile);
PM.run(*Module);
```

---

## 9. 参考资源

### 9.1 官方文档
- [LLVM WritingAnLLVMBackend](https://releases.llvm.org/13.0.0/docs/WritingAnLLVMBackend.html)
- [LLVM TargetRegistry.h](https://llvm.org/doxygen/TargetRegistry_8h_source.html)
- [LLVM TargetMachine.h](https://llvm.org/doxygen/classllvm_1_1TargetMachine.html)

### 9.2 示例代码
- [RISCV Target](https://github.com/llvm/llvm-project/tree/main/llvm/lib/Target/RISCV)
- [WebAssembly Target](https://github.com/llvm/llvm-project/tree/main/llvm/lib/Target/WebAssembly)
- [AMDGPU Target](https://github.com/llvm/llvm-project/tree/main/llvm/lib/Target/AMDGPU)

---

## 10. 关键结论

1. **注册机制**：通过 `TargetRegistry` 在静态初始化期注册所有 target
2. **创建流程**：`TargetRegistry::lookupTarget` → `Target::createTargetMachine`
3. **核心组件**：`TargetMachine` + `TargetSubtargetInfo` + `TargetLowering` + MC 层
4. **代码生成**：Legacy Pass Manager 或 New Pass Manager 管线
5. **TableGen**：通过 `.td` 文件自动生成寄存器、指令描述


