# 知识库使用指南

> 快速上手知识库同步和协作流程

---

## 🎯 核心概念

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                    远端仓库                              │
│            ~/repos/knowledge-base.git                   │
│              (Git Bare Repository)                      │
└─────────────────────────────────────────────────────────┘
           ↑                       ↑
           │ git push/pull         │ git push/pull
           ↓                       ↓
┌──────────────────────┐  ┌──────────────────────┐
│   中央仓库            │  │    本地仓库           │
│ /Documents/          │  │ /workspace/          │
│ KnowledgeBase/       │  │ KNOWLEDGE_BASE/      │
└──────────────────────┘  └──────────────────────┘
```

### 文件分层

| 层级 | 文件 | 维护方式 | 说明 |
|------|------|----------|------|
| **入口层** | INDEX.md | 手动 | 精简版知识地图，很少修改 |
| **索引层** | INDEX_TOPICS.md | 自动生成 | TOPICS 目录索引 |
| **索引层** | INDEX_SKILLS.md | 自动生成 | SKILLS 目录索引 |
| **索引层** | INDEX_BP.md | 自动生成 | BEST_PRACTICES 索引 |
| **内容层** | TOPICS/*.md | 各贡献者创建 | 课题调研文档 |
| **内容层** | SKILLS/*.md | 各贡献者创建 | 技能文档 |
| **内容层** | BEST_PRACTICES/*.md | 各贡献者创建 | 最佳实践 |
| **工具层** | generate-index.sh | 自动执行 | 索引生成脚本 |
| **工具层** | sync-knowledge.sh | 手动调用 | 同步封装脚本 |

---

## 🚀 快速开始

### 首次使用（已配置）

本地知识库和中央仓库已配置完成，远端为 `~/repos/knowledge-base.git`。

### 日常同步

```bash
# 推送本地变更到远端
./sync-knowledge.sh push -m "新增 XXX 文档"

# 从远端拉取最新内容
./sync-knowledge.sh pull

# 双向同步（推荐）
./sync-knowledge.sh sync
```

### 查看状态

```bash
./sync-knowledge.sh status
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

### 示例

```bash
# 创建新的 TOPIC
cat > TOPICS/my-topic.md << 'EOF'
---
id: KB-20260306-002
title: 我的研究课题
contributor: main
created: 2026-03-06
updated: 2026-03-06
tags: [research, topic]
status: done
---

# 我的研究课题

## 概述

...

EOF

# 同步到远端
./sync-knowledge.sh push -m "新增我的研究课题"
```

---

## 🔄 多 Agent 协作流程

### 场景：多个智能体同时贡献

```
时间线:

07:00  bot-a 完成 Feishu 调研
       → 创建 TOPICS/feishu.md
       → ./sync-knowledge.sh push
       → 远端收到更新
       → INDEX_TOPICS.md 自动更新

07:15  bot-b 完成 GitHub 调研
       → 创建 TOPICS/github.md
       → ./sync-knowledge.sh push
       → Git 自动合并（不同文件，无冲突）
       → INDEX_TOPICS.md 自动更新

07:30  main 完成天气技能
       → 创建 SKILLS/weather.md
       → ./sync-knowledge.sh push
       → Git 自动合并（不同目录，无冲突）
       → INDEX_SKILLS.md 自动更新
```

### 冲突处理

**什么情况下会冲突？**

- ❌ 两个 Agent 同时修改同一个文件
- ✅ 不同文件不会冲突
- ✅ 索引文件自动生成，不会冲突

**冲突解决流程:**

```bash
# 1. 拉取时检测冲突
./sync-knowledge.sh pull
# [WARN] 冲突：TOPICS/xxx.md

# 2. 手动解决冲突
# 编辑文件，选择保留的内容

# 3. 重新提交
git add TOPICS/xxx.md
git commit -m "解决冲突"
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

**命令:**

| 命令 | 说明 | 示例 |
|------|------|------|
| `push` | 推送本地变更 | `./sync-knowledge.sh push -m "消息"` |
| `pull` | 拉取远端内容 | `./sync-knowledge.sh pull` |
| `sync` | 双向同步 | `./sync-knowledge.sh sync` |
| `status` | 查看状态 | `./sync-knowledge.sh status` |
| `init` | 初始化 Git | `./sync-knowledge.sh init` |

**选项:**

| 选项 | 说明 | 示例 |
|------|------|------|
| `-m, --message` | 提交消息 | `push -m "新增文档"` |
| `-f, --force` | 强制覆盖 | `pull -f` |
| `-h, --help` | 显示帮助 | `--help` |

### generate-index.sh

**功能:**

- 扫描 TOPICS、SKILLS、BEST_PRACTICES 目录
- 提取 YAML 元数据
- 生成索引表格
- 更新 INDEX.md 统计信息

**用法:**

```bash
./generate-index.sh
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

### 问题：索引未更新

```bash
# 手动生成索引
./generate-index.sh

# 检查脚本权限
chmod +x generate-index.sh sync-knowledge.sh
```

### 问题：冲突无法解决

```bash
# 查看冲突文件
git status

# 重置到远端版本（谨慎使用）
git fetch origin
git reset --hard origin/main

# 重新应用本地修改
```

---

## 📚 相关文档

- [INDEX.md](INDEX.md) - 知识库索引
- [FORMAT.md](FORMAT.md) - 知识卡片格式规范
- [QUICK_START/GETTING_STARTED.md](QUICK_START/GETTING_STARTED.md) - 新 Agent 指南

---

*最后更新：2026-03-06 | 维护者：ZIV-BOT*
