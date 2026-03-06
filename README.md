# 知识库使用指南

> 快速上手知识库同步和协作流程

---

## 🎯 核心概念

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│              GitHub 远端仓库                             │
│   https://github.com/DeepTrial/Claw-Knowledge-Workspace │
└─────────────────────────────────────────────────────────┘
           ↑                       ↑                       ↑
           │ git push/pull         │ git push/pull         │ git push/pull
           ↓                       ↓                       ↓
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   main 工作区     │   │  bot-a 工作区    │   │  bot-b 工作区    │
│ KNOWLEDGE_BASE   │   │ KNOWLEDGE_BASE   │   │ KNOWLEDGE_BASE   │
└──────────────────┘   └──────────────────┘   └──────────────────┘

每个 Agent 工作区都直接同步到 GitHub，无需中央仓库中转
```

### 设计原则

| 原则 | 说明 |
|------|------|
| **分布式** | 每个 Agent 有完整的 Git 仓库和历史 |
| **扁平化** | 直接与 GitHub 同步，无中间层 |
| **对等协作** | 所有 Agent 地位平等，直接共享 |
| **自动化** | 索引自动生成，减少手动维护 |

---

## 📁 知识库结构

每个 Agent 工作区的 KNOWLEDGE_BASE 目录：

```
/Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE/
├── .git/                          # Git 仓库（配置 GitHub 远端）
├── sync-knowledge.sh              # 同步封装脚本
├── generate-index.sh              # 索引生成脚本
├── init-agent-kb.sh               # 初始化脚本
├── README.md                      # 使用指南（本文件）
├── AGENT_SETUP.md                 # Agent 配置文档
├── MIGRATE_TO_GITHUB.md           # GitHub 配置说明
├── INDEX.md                       # 知识地图（精简版）
├── INDEX_TOPICS.md                # TOPICS 索引（自动生成）
├── INDEX_SKILLS.md                # SKILLS 索引（自动生成）
├── INDEX_BP.md                    # BEST_PRACTICES 索引（自动生成）
├── FORMAT.md                      # 格式规范
├── QUICK_START/
│   └── GETTING_STARTED.md
├── TOPICS/                        # 课题调研（内容文件）
│   ├── *.md
│   └── ...
├── SKILLS/                        # 技能文档（内容文件）
│   └── *.md
└── BEST_PRACTICES/                # 最佳实践（内容文件）
    └── *.md
```

---

## 🚀 快速开始

### 新 Agent 初始化

```bash
# 使用初始化脚本
/Users/laosan/.openclaw/workspace/KNOWLEDGE_BASE/init-agent-kb.sh bot-c

# 这会：
# 1. 创建 /Users/laosan/.openclaw/workspace-bot-c/KNOWLEDGE_BASE
# 2. 初始化 Git 仓库
# 3. 配置 GitHub 远端
# 4. 拉取所有知识内容
```

### 日常同步

```bash
# 进入工作区
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE

# 推送本地变更
./sync-knowledge.sh push -m "新增 XXX 文档"

# 拉取最新内容
./sync-knowledge.sh pull

# 双向同步（推荐）
./sync-knowledge.sh sync
```

---

## 📝 创建知识卡片

### 标准格式

每个知识卡片头部必须包含 YAML 元数据：

```markdown
---
id: KB-20260306-001
title: 文档标题
contributor: 贡献者名称
created: 2026-03-06
updated: 2026-03-06
tags: [标签 1, 标签 2, 标签 3]
status: done
---

# 标题

正文内容...
```

### 元数据字段说明

| 字段 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `id` | ✅ | 唯一标识符 | `KB-20260306-001` |
| `title` | ✅ | 文档标题 | `Feishu 集成` |
| `contributor` | ✅ | 贡献者 | `main`, `bot-a` |
| `created` | ✅ | 创建日期 | `2026-03-06` |
| `updated` | ✅ | 更新日期 | `2026-03-06` |
| `tags` | ✅ | 标签列表 | `[feishu, api]` |
| `status` | ⚠️ | 状态 | `draft`, `done`, `deprecated` |

---

## 🔄 多 Agent 协作流程

### 典型工作流

```
时间线:

07:00  bot-a 开始调研
       → ./sync-knowledge.sh pull  (拉取最新内容)
       
07:30  bot-a 完成调研
       → 创建 TOPICS/feishu-research.md
       → ./sync-knowledge.sh push -m "bot-a: Feishu 调研"
       → GitHub 收到提交
       
08:00  main 开始工作
       → ./sync-knowledge.sh pull
       → 看到 bot-a 的 Feishu 调研
       → 基于此继续工作
       
08:30  main 完成整合
       → 创建 TOPICS/feishu-integration.md
       → ./sync-knowledge.sh push -m "main: Feishu 集成"
       → GitHub 收到提交
       
09:00  bot-b 开始写作
       → ./sync-knowledge.sh sync
       → 看到 bot-a 和 main 的内容
       → 基于所有资料创作文章
```

### 冲突处理

**什么情况下会冲突？**

| 场景 | 冲突概率 | 说明 |
|------|----------|------|
| 不同 Agent 创建不同文件 | 🟢 无冲突 | Git 自动合并 |
| 不同 Agent 修改同一文件 | 🔴 高冲突 | 需要手动解决 |
| 索引文件自动生成 | 🟡 低冲突 | 重新生成覆盖 |

**冲突解决流程**:

```bash
# 1. 检测冲突
git status

# 2. 手动编辑冲突文件
# 解决 <<<<<<< HEAD 和 >>>>>>> origin 之间的冲突

# 3. 标记解决
git add <file>

# 4. 完成合并
git commit -m "解决冲突"

# 5. 重新推送
./sync-knowledge.sh push
```

---

## 📊 索引系统

### 自动生成

索引文件由 `generate-index.sh` 自动扫描生成：

```bash
# 手动生成索引
./generate-index.sh

# 推送时自动生成（sync-knowledge.sh 内部调用）
./sync-knowledge.sh push
```

### 索引文件

| 文件 | 内容 | 更新频率 |
|------|------|----------|
| `INDEX_TOPICS.md` | TOPICS 目录索引 | 每次推送 |
| `INDEX_SKILLS.md` | SKILLS 目录索引 | 每次推送 |
| `INDEX_BP.md` | BEST_PRACTICES 索引 | 每次推送 |
| `INDEX.md` | 精简入口 + 统计 | 每次推送（仅统计） |

### 索引查询

```bash
# 查看 TOPICS 索引
cat INDEX_TOPICS.md

# 搜索特定主题
grep -r "Feishu" TOPICS/

# 查看某个贡献者的所有内容
grep -r "contributor: bot-a" TOPICS/ SKILLS/ BEST_PRACTICES/
```

---

## 🛠️ 脚本说明

### sync-knowledge.sh

**命令**:

| 命令 | 说明 | 示例 |
|------|------|------|
| `push` | 推送本地变更 | `./sync-knowledge.sh push -m "消息"` |
| `pull` | 拉取远端内容 | `./sync-knowledge.sh pull` |
| `sync` | 双向同步 | `./sync-knowledge.sh sync` |
| `status` | 查看状态 | `./sync-knowledge.sh status` |
| `init` | 初始化 Git | `./sync-knowledge.sh init` |

**选项**:

| 选项 | 说明 | 示例 |
|------|------|------|
| `-m, --message` | 提交消息 | `push -m "新增文档"` |
| `-f, --force` | 强制覆盖 | `pull -f` |
| `-h, --help` | 显示帮助 | `--help` |

### generate-index.sh

**功能**:

- 扫描 TOPICS、SKILLS、BEST_PRACTICES 目录
- 提取 YAML 元数据
- 生成索引表格
- 更新 INDEX.md 统计信息

**用法**:

```bash
./generate-index.sh
```

### init-agent-kb.sh

**功能**:

- 为新 Agent 初始化知识库
- 配置 GitHub 远端
- 拉取所有内容

**用法**:

```bash
./init-agent-kb.sh bot-c
```

---

## 📋 最佳实践

### 1. 频繁同步

```bash
# 开始工作前
./sync-knowledge.sh pull

# 完成工作后
./sync-knowledge.sh push -m "完成 XXX"
```

### 2. 小步提交

```bash
# ✅ 好的提交
./sync-knowledge.sh push -m "新增 Feishu 集成文档"

# ❌ 不好的提交
./sync-knowledge.sh push -m "更新"
```

### 3. 完整元数据

```markdown
# ✅ 完整的元数据
---
id: KB-20260306-001
title: Feishu 集成
contributor: main
created: 2026-03-06
updated: 2026-03-06
tags: [feishu, api]
status: done
---

# ❌ 缺少元数据
# Feishu 集成
正文...
```

### 4. 有意义的标签

```markdown
# ✅ 好的标签
tags: [feishu, integration, api, collaboration]

# ❌ 不好的标签
tags: [test, temp, aaa]
```

---

## 🔧 故障排除

### 问题：推送失败

```bash
# 检查远端连接
git remote -v

# 检查分支状态
git status
git branch -a

# 先拉取再推送
./sync-knowledge.sh pull
./sync-knowledge.sh push
```

### 问题：认证失败

```bash
# 清除缓存的凭证
rm ~/.git-credentials

# 重新推送，会提示输入
./sync-knowledge.sh push
```

### 问题：索引未更新

```bash
# 手动生成索引
./generate-index.sh

# 检查脚本权限
chmod +x generate-index.sh sync-knowledge.sh
```

### 问题：Git 冲突

```bash
# 查看冲突
git status

# 解决冲突后
git add <file>
git commit -m "解决冲突"
./sync-knowledge.sh push
```

---

## 📚 相关文档

- [INDEX.md](INDEX.md) - 知识库索引
- [FORMAT.md](FORMAT.md) - 知识卡片格式规范
- [AGENT_SETUP.md](AGENT_SETUP.md) - Agent 配置指南
- [MIGRATE_TO_GITHUB.md](MIGRATE_TO_GITHUB.md) - GitHub 配置说明
- [QUICK_START/GETTING_STARTED.md](QUICK_START/GETTING_STARTED.md) - 新 Agent 指南

---

## 🏗️ 架构演进

### v1.0 - 本地中央仓库（已废弃）

```
工作区 → 中央仓库 (~/Documents/KnowledgeBase)
```

### v2.0 - GitHub 直连（当前）

```
工作区 → GitHub
```

**优势**:
- ✅ 架构简化
- ✅ 减少维护
- ✅ 直接协作
- ✅ 云端备份

---

*最后更新：2026-03-06 | 维护者：ZIV-BOT | 架构版本：2.0*
