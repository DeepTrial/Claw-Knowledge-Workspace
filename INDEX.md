# 知识库索引

> 维护者: ZIV-BOT | 管理员: yizw | 创建时间: 2026-03-05

---

## 📚 知识库概览

本知识库用于存储深度调研成果，供 Agent 学习和复用。

### 核心价值

- **可移植**: 纯 Markdown 格式，任何 Agent 都能读取
- **可检索**: 标准化 ID 和标签，支持语义搜索
- **可传承**: 新 Agent 5 分钟快速上手

---

## 📂 目录结构

```
KNOWLEDGE_BASE/
├── INDEX.md                    # 知识地图（本文件）
├── FORMAT.md                   # 知识格式规范
├── QUICK_START/                # 快速上手
│   └── GETTING_STARTED.md      # 新 Agent 指南
├── TOPICS/                     # 课题调研
│   └── topic-xxx.md
├── SKILLS/                     # 技能文档
│   └── skill-xxx.md
└── BEST_PRACTICES/             # 最佳实践
    └── practice-xxx.md
```

---

## 🗺️ 知识地图

### TOPICS（课题调研）

| ID | 课题 | 领域 | 状态 | 更新时间 |
|----|------|------|------|----------|
| KB-20250306-001 | CUDA 线程层次结构深度解析 | CUDA/GPU | done | 2026-03-06 |
| KB-20250306-002 | CUDA 内存层次结构深度解析 | CUDA/GPU | done | 2026-03-06 |
| KB-20250306-003 | Triton @triton.jit Decorator 原理深度解析 | Triton/Compiler | done | 2026-03-06 |
| KB-20250306-004 | LLVM 架构设计深度解析 | LLVM/Compiler | done | 2026-03-06 |
| KB-20260306-006 | Triton 编程语言深度调研 | Triton/GPU | done | 2026-03-06 |
| KB-20260306-003 | 多 Agent 协作调研 | Collaboration | done | 2026-03-06 |

### SKILLS（技能文档）

| ID | 技能 | 用途 | 状态 | 更新时间 |
|----|------|------|------|----------|
| - | 暂无 | - | - | - |

### BEST_PRACTICES（最佳实践）

| ID | 实践 | 场景 | 状态 | 更新时间 |
|----|------|------|------|----------|
| - | 暂无 | - | - | - |

---

## 🚀 快速开始

**新 Agent 首次访问请按顺序阅读：**

1. `QUICK_START/GETTING_STARTED.md` - 5 分钟快速了解
2. `FORMAT.md` - 知识卡片格式规范
3. 根据任务需求查阅 `TOPICS/` 或 `SKILLS/`

---

## 📝 贡献指南

1. 深度调研完成后，按 `FORMAT.md` 格式创建知识卡片
2. 更新本文件的索引表格
3. 使用 `sessions_send` 通知其他会话

---

## 📊 统计

- **课题总数**: 7
- **技能总数**: 1
- **最佳实践**: 1
- **最后更新**: 2026-03-06

---

*本知识库由 ZIV-BOT 维护，管理员 yizw 拥有唯一修改权限。*