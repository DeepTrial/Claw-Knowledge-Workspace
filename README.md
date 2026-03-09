# 知识库使用指南

> 完整的使用指南，涵盖同步协作与知识检索 | **版本：v3.1** | 更新：2026-03-09

---

## ⚠️ 重要：请使用同步脚本

**为避免多 Agent 协作时发生冲突，请务必使用 `sync-knowledge.sh` 脚本进行所有同步操作，不要直接使用 git 命令。**

```bash
# ✅ 正确做法
./sync-knowledge.sh sync

# ❌ 错误做法（可能导致冲突）
git pull
git push
```

---

## 🎯 核心概念

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│              GitHub 远端仓库                             │
│   https://github.com/DeepTrial/Claw-Knowledge-Workspace │
└─────────────────────────────────────────────────────────┘
           ↑                       ↑                       ↑
           │ sync-knowledge.sh     │ sync-knowledge.sh     │ sync-knowledge.sh
           ↓                       ↓                       ↓
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   main 工作区     │   │  bot-a 工作区    │   │  bot-b 工作区    │
│ KNOWLEDGE_BASE   │   │ KNOWLEDGE_BASE   │   │ KNOWLEDGE_BASE   │
└──────────────────┘   └──────────────────┘   └──────────────────┘

每个 Agent 工作区都通过 sync-knowledge.sh 与 GitHub 同步
```

### 设计原则

| 原则 | 说明 |
|------|------|
| **分布式** | 每个 Agent 有完整的 Git 仓库和历史 |
| **扁平化** | 直接与 GitHub 同步，无中间层 |
| **对等协作** | 所有 Agent 地位平等，直接共享 |
| **自动化** | 索引自动生成，减少手动维护 |
| **统一同步** | 必须使用同步脚本，避免冲突 |

---

## 📁 知识库结构

```
KNOWLEDGE_BASE/
├── .git/                          # Git 仓库（配置 GitHub 远端）
├── .kb/                           # 知识库工具目录
│   ├── kb                         # 统一管理工具 (Python CLI)
│   ├── config.yaml                # 分类体系配置
│   ├── index.json                 # 检索索引
│   └── indexes/                   # 辅助索引
├── sync-knowledge.sh              # 同步脚本 v2.0（核心工具）
├── README.md                      # 使用指南（本文件）
├── FORMAT.md                      # 知识卡片格式规范
├── INDEX_TOPICS.md                # TOPICS 索引（自动生成）
├── TOPICS/                        # 课题调研
│   ├── topic-cuda-*.md
│   ├── topic-triton-*.md
│   ├── topic-llvm-*.md
│   └── ...
├── SKILLS/                        # 技能文档
│   └── local-knowledge-search/    # 知识库查询 Skill
│       ├── SKILL.md               # Skill 主文件
│       └── QUICK_REF.md           # 快速参考
└── BEST_PRACTICES/                # 最佳实践
```

---

## 🤖 Agent Skills

知识库内置了供 Agent 使用的 Skills，帮助 Agent 快速学会如何查询和使用知识库。

### 可用 Skills

| Skill | 说明 | 位置 |
|-------|------|------|
| local-knowledge-search | 查询本地知识库，获取结构化知识点 | `SKILLS/local-knowledge-search/` |

### 使用方法

Agent 在处理技术问题时，应：

1. **阅读 Skill 文件**
   ```
   SKILLS/local-knowledge-search/SKILL.md
   ```

2. **按 Skill 指引操作**
   - 使用 `kb search` 检索知识
   - 只读访问，不修改知识库
   - 离线运行，不依赖网络

3. **快速参考**
   ```
   SKILLS/local-knowledge-search/QUICK_REF.md
   ```

### Skill 设计原则

- **只读**：Agent 不修改知识库内容
- **离线**：不依赖网络，纯本地操作
- **通用**：不限定特定技术领域，自动适应知识库扩展

---

## 🔄 同步脚本使用指南

### 命令概览

| 命令 | 说明 | 推荐场景 |
|------|------|----------|
| `preview` | 预览本地与远端差异 | **同步前必用** |
| `status` | 查看当前状态 | 检查工作区状态 |
| `pull` | 拉取远端内容 | 获取最新内容 |
| `push` | 推送本地变更 | 提交并推送 |
| `sync` | 双向同步 | **日常推荐** |

### 选项

| 选项 | 说明 |
|------|------|
| `-m, --message <msg>` | 提交消息（push 时使用） |
| `-s, --stash` | 自动 stash 本地变更 |
| `-f, --force` | 强制覆盖本地变更（慎用） |
| `-h, --help` | 显示帮助 |

---

### 1. 预览差异（同步前检查）

```bash
./sync-knowledge.sh preview
```

**输出示例：**
```
📊 同步预览：
  - 本地领先：2 个提交（待推送）
  - 远端领先：1 个提交（待拉取）

📥 远端新提交：
  abc1234 [Karl-KimiClaw] Add new topic

📤 本地新提交：
  def5678 [bot-a] Update CUDA docs

⚠️  双方都有更新，同步时可能产生冲突
```

---

### 2. 日常同步（推荐）

```bash
# 双向同步（先拉取后推送）
./sync-knowledge.sh sync

# 如果本地有未提交的变更，使用 -s 自动暂存
./sync-knowledge.sh sync -s
```

---

### 3. 推送本地变更

```bash
# 提交并推送
./sync-knowledge.sh push -m "新增 CUDA 内存优化文档"

# 如果远端有更新，脚本会自动 rebase
```

---

### 4. 拉取远端内容

```bash
# 普通拉取
./sync-knowledge.sh pull

# 如果本地有未提交的变更，使用 -s 自动暂存
./sync-knowledge.sh pull -s

# 强制覆盖本地（慎用！会丢失未提交的变更）
./sync-knowledge.sh pull -f
```

---

### 5. 查看状态

```bash
./sync-knowledge.sh status
```

**输出示例：**
```
📊 同步状态:
  - 本地领先：0 个提交
  - 远端领先：0 个提交

最近提交:
  27b0dc3 bot-a: 清理冗余文档，补充元数据
  1872dd8 [Karl-KimiClaw] Add Day 007 study notes
```

---

## 🛠️ 知识库工具指南

### 快速开始

```bash
# 初始化
.kb/kb init

# 重建索引
.kb/kb rebuild

# 检索知识
.kb/kb search "GPU 内存优化"
```

---

### 命令详解

#### kb init

初始化知识库环境。

```bash
.kb/kb init
```

功能：
- 检测 Python 版本和依赖
- 创建目录结构
- 生成配置文件
- 扫描现有知识点

---

#### kb status

查看知识库状态。

```bash
.kb/kb status
```

输出示例：
```
📊 知识库状态
────────────────────────────────────────
├─ 总知识点: 18
├─ 分类数: 12
├─ 索引版本: 4.0
├─ 最后更新: 2026-03-07
├─ 检索模式: BM25
├─ 向量模型: 未启用
└─ 相似对数: 0
```

---

#### kb rebuild

重建索引。

```bash
.kb/kb rebuild
```

功能：
- 扫描所有知识点文件
- 解析元数据
- 执行去重检测
- 生成辅助索引（INDEX_TOPICS.md）

---

#### kb search

检索知识库。

```bash
# 基础检索
.kb/kb search "查询语句"

# 分类筛选
.kb/kb search "内存" --category cuda

# 等级筛选
.kb/kb search "优化" --level 2

# 组合筛选
.kb/kb search "内存优化" --category cuda --level 2 --limit 10

# ID 直接获取
.kb/kb search --id KB-20260307-001
```

参数：
| 参数 | 说明 |
|------|------|
| `query` | 查询语句（自然语言） |
| `--category` | 分类筛选（如 `cuda`, `cuda.memory`） |
| `--level` | 等级筛选（1-3） |
| `--limit` | 返回数量（默认 5） |
| `--id` | 通过 ID 直接获取 |

---

#### kb browse

浏览知识库。

```bash
# 浏览所有领域
.kb/kb browse

# 按分类浏览
.kb/kb browse --category cuda

# 按层级浏览
.kb/kb browse --level 2
```

输出示例：
```
📚 知识库浏览

总计: 18 个知识点

📁 cuda (10)
   • [KB-20250306-001] CUDA 线程层次结构深度解析
   • [KB-20250306-002] CUDA 内存层次结构深度解析
   ...

📁 triton (4)
   • [KB-20250306-003] Triton @triton.jit Decorator 原理深度解析
   ...
```

---

#### kb context

获取知识点的上下文信息。

```bash
.kb/kb context --id KB-20260307-001
```

---

#### kb dedup

检测重复或相似的知识点。

```bash
.kb/kb dedup
```

输出示例：
```
⚠️  检测到 2 组相似知识点:

[tags] 相似度: 85%
  • KB-20260306-005: CUDA 共享内存基础
  • KB-20260307-012: CUDA Shared Memory 入门
```

---

#### kb ingest

入库新知识。

```bash
# 预览模式（不实际写入）
.kb/kb ingest new_article.md --dry-run

# 入库并指定分类
.kb/kb ingest new_article.md --category cuda.memory --level 2

# 正式入库
.kb/kb ingest new_article.md
```

---

#### kb merge

合并重复的知识点。

```bash
# 预览合并
.kb/kb merge KB-SOURCE-ID KB-TARGET-ID --preview

# 执行合并
.kb/kb merge KB-SOURCE-ID KB-TARGET-ID
```

---

## 📝 知识卡片格式

### 标准模板

```markdown
---
id: KB-YYYYMMDD-XXX
title: 知识标题
category: domain.subdomain
level: 1
summary: "一句话摘要"
contributor: main
created: 2026-03-07
updated: 2026-03-07
tags: [tag1, tag2, tag3]
status: done
---

# 知识标题

## 摘要

> 一句话总结

## 核心内容

...

## 参考

- [[KB-OTHER-ID]] 相关知识
```

### 必填字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `id` | 唯一标识符 | `KB-20260307-001` |
| `title` | 标题 | `CUDA 共享内存优化` |
| `category` | 分类路径 | `cuda.memory` |
| `level` | 深度等级 | `1`=基础, `2`=进阶, `3`=专家 |
| `summary` | 摘要 | `"介绍 bank conflict 优化方法"` |
| `contributor` | 贡献者 | `main`, `bot-a`, `DeepTrial` |
| `created` | 创建日期 | `2026-03-07` |
| `updated` | 更新日期 | `2026-03-07` |
| `tags` | 标签列表 | `[cuda, memory, optimization]` |
| `status` | 状态 | `done`, `draft`, `deprecated` |

### 可选字段

| 字段 | 说明 |
|------|------|
| `relations` | 知识关联 |
| `keywords` | 关键词列表 |
| `references` | 参考链接 |

---

## 📂 分类体系

```
cuda                    # CUDA 编程
├── cuda.memory         # 内存管理
├── cuda.kernel         # 核函数
├── cuda.threads        # 线程层次
├── cuda.compiler       # 编译器
├── cuda.syntax         # 语法扩展
├── cuda.sync           # 同步原语
├── cuda.builtin        # 内建变量/函数
└── cuda.optimization   # 性能优化

triton                  # Triton 编程
├── triton.basics       # 基础概念
└── triton.optimization # 性能优化

llvm                    # LLVM 编译器
├── llvm.basics         # 基础架构
└── llvm.optimization   # 优化 Pass

system-design           # 系统设计
├── system-design.knowledge-base  # 知识库
└── system-design.multi-agent     # 多 Agent
```

---

## 🔍 检索模式

### BM25（当前）

- **依赖**: rank-bm25（~50KB）
- **特点**: 词频权重检索，支持中文
- **效果**: 比关键词精准，召回率 ~80%

### 语义检索（后续升级）

- **依赖**: sentence-transformers（~90MB）
- **特点**: 向量语义检索，理解同义词
- **效果**: 召回率 ~90%

### 切换方式

编辑 `.kb/config.yaml`：

```yaml
retrieval:
  mode: "bm25"      # 当前模式
  # mode: "semantic"  # 升级后切换
```

---

## 🔄 多 Agent 协作流程

### 推荐工作流

```
1. 开始工作前
   ./sync-knowledge.sh preview     # 检查远端状态
   ./sync-knowledge.sh pull -s     # 拉取最新内容

2. 创建/编辑知识卡片
   # 编辑 TOPICS/topic-xxx.md

3. 完成工作后
   ./sync-knowledge.sh push -m "新增 XXX 文档"

4. 或者使用一步同步
   ./sync-knowledge.sh sync -s
```

### 冲突处理

如果发生 Rebase 冲突，脚本会显示详细的解决指引：

```
❌ Rebase 发生冲突！

📋 冲突文件：
  TOPICS/topic-cuda-memory.md

🔧 解决方法：
  1. 查看冲突文件，手动编辑解决冲突标记（<<<<<<< / ======= / >>>>>>>）
  2. 解决后执行：git add .
  3. 继续 rebase：git rebase --continue
  4. 放弃本次操作：git rebase --abort
```

---

## 📋 工作流示例

### 1. 日常检索

```bash
# 搜索相关知识
.kb/kb search "CUDA 内存优化"

# 按分类浏览
.kb/kb browse --category cuda

# 查看详情
.kb/kb search --id KB-20260307-001
.kb/kb context --id KB-20260307-001
```

### 2. 添加新知识

```bash
# 1. 创建知识文件（按格式规范）
vim TOPICS/topic-new-knowledge.md

# 2. 重建索引
.kb/kb rebuild

# 3. 验证
.kb/kb search --id KB-NEW-ID

# 4. 同步到远端
./sync-knowledge.sh push -m "新增 XXX 文档"
```

### 3. 处理重复知识

```bash
# 1. 检测重复
.kb/kb dedup

# 2. 预览合并
.kb/kb merge KB-SOURCE KB-TARGET --preview

# 3. 执行合并
.kb/kb merge KB-SOURCE KB-TARGET
```

---

## 📋 最佳实践

### 1. 同步前先预览

```bash
# ✅ 好的习惯
./sync-knowledge.sh preview
./sync-knowledge.sh sync

# ❌ 不好的习惯（可能遇到意外冲突）
./sync-knowledge.sh sync
```

### 2. 频繁同步

```bash
# 开始工作前
./sync-knowledge.sh pull -s

# 完成工作后
./sync-knowledge.sh push -m "完成 XXX"
```

### 3. 小步提交

```bash
# ✅ 好的提交
./sync-knowledge.sh push -m "新增 CUDA 内存层次文档"

# ❌ 不好的提交
./sync-knowledge.sh push -m "更新"
```

### 4. 使用 -s 选项保护本地变更

```bash
# 如果本地有未提交的变更，使用 -s 自动暂存
./sync-knowledge.sh pull -s
./sync-knowledge.sh sync -s
```

---

## 🔧 故障排除

### 同步问题

**推送失败：**
```bash
# 先预览状态
./sync-knowledge.sh preview

# 拉取最新内容
./sync-knowledge.sh pull

# 重新推送
./sync-knowledge.sh push -m "提交消息"
```

**Rebase 冲突：**
按照脚本提示解决冲突：
1. 编辑冲突文件
2. `git add .`
3. `git rebase --continue`
4. `./sync-knowledge.sh push`

**想放弃当前操作：**
```bash
# 放弃 rebase
git rebase --abort

# 恢复 stash
git stash pop
```

### 检索问题

**检索结果为空：**
```bash
# 检查索引
.kb/kb status

# 重建索引
.kb/kb rebuild
```

**分类显示 unknown：**
知识点缺少 `category` 字段，在 frontmatter 中添加：
```yaml
category: cuda.memory
```

### 网络问题

```bash
# 检查网络连接
curl -I https://github.com

# 检查代理配置
git config --global --list | grep proxy
```

---

## 📚 相关文档

- [FORMAT.md](FORMAT.md) - 知识卡片格式规范
- [INDEX_TOPICS.md](INDEX_TOPICS.md) - TOPICS 索引

---

## 🏗️ 版本历史

### v3.1 (2026-03-09)

**新增 Agent Skills：**
- 新增 `SKILLS/local-knowledge-search/` Skill
- 帮助 Agent 学习如何查询知识库
- 只读、离线、通用设计原则
- 更新 README.md 添加 Agent Skills 章节

### v3.0 (2026-03-07)

**文档整合：**
- 合并 README.md 与 USAGE.md 为单一文档
- 统一知识卡片格式说明
- 统一分类体系说明
- 合并故障排除章节

**内容完善：**
- 新增完整的 kb 命令详解
- 新增检索模式说明
- 新增工作流示例

### v2.0 (2026-03-07)

**同步脚本改进：**
- 新增 `preview` 命令（预览差异）
- 新增 `-s/--stash` 选项（自动暂存）
- Rebase 冲突详细提示
- Sync 原子性 + 回滚机制
- 索引生成安全处理

**目录结构更新：**
- 新增 `.kb/` 工具目录
- 移除冗余的索引脚本

### v1.0 (2026-03-06)

- 初始版本
- GitHub 直连架构

---

*最后更新：2026-03-09 | 维护者：冰美 (bot-a) | 版本：v3.1*
