# Local Knowledge Search Skill

## 概述

查询当前 agent workspace 下的本地知识库，获取结构化技术知识点。

**特性**：
- 📖 只读查询，不修改知识库
- 🔌 离线运行，不依赖网络
- 🌐 通用适配，不限定特定领域

## 路径约定

所有路径相对于 **workspace 根目录**：

| 用途 | 相对路径 |
|------|----------|
| 知识库根目录 | `KNOWLEDGE_BASE/` |
| CLI 工具 | `KNOWLEDGE_BASE/.kb/kb` |
| 知识点目录 | `KNOWLEDGE_BASE/TOPICS/` |
| 索引文件 | `KNOWLEDGE_BASE/.kb/index.json` |

## ⚠️ 只读原则

### 禁止操作

Agent **禁止**执行以下操作：

| 操作 | 命令 | 原因 |
|------|------|------|
| 入库新知识 | `kb ingest` | 会修改知识库 |
| 合并知识点 | `kb merge` | 会删除/修改文件 |
| 推送变更 | `sync-knowledge.sh push` | 会修改远端 |
| 双向同步 | `sync-knowledge.sh sync` | 会修改本地和远端 |
| 编辑文件 | 任何写入操作 | 会修改知识库内容 |

### 允许操作

| 操作 | 命令 |
|------|------|
| 搜索知识点 | `kb search "关键词"` |
| 浏览分类 | `kb browse --category <分类>` |
| 查看详情 | `kb search --id <ID>` |
| 查看状态 | `kb status` |
| 读取文件 | `cat KNOWLEDGE_BASE/TOPICS/*.md` |

## 🔌 离线运行

本 Skill 完全离线运行：

- 不调用外部 API
- 不访问互联网资源
- 所有数据来自本地知识库
- 不与其他工具联动

## 何时激活

- 用户需要查询技术领域的结构化知识
- 用户明确提到 "知识库"、"本地知识库"
- 用户说 "查一下知识库"、"知识库里有没有..."
- 用户询问的问题可能需要系统性、可引用的知识解答

## 判断流程

1. 优先尝试 `kb search "关键词"`
2. 有匹配结果 → 使用知识库内容回答
3. 无匹配结果 → 告知用户知识库暂无相关内容

## 查询流程

### Step 1: 确定检索策略

| 问题类型 | 策略 |
|----------|------|
| 具体概念/关键词 | `search "关键词"` |
| 浏览某个领域 | `browse --category <分类>` |
| 已知知识点 ID | `search --id <ID>` |
| 了解覆盖范围 | `browse` 或 `status` |

### Step 2: 执行检索

```bash
cd KNOWLEDGE_BASE
./.kb/kb search "查询内容" --category <分类> --limit 5
```

### Step 3: 获取完整内容

```bash
# 根据返回的文件名读取（只读）
cat KNOWLEDGE_BASE/TOPICS/topic-xxx.md
```

### Step 4: 格式化输出

- 引用知识点 ID: `[KB-YYYYMMDD-XXX]`
- 包含摘要和核心结论
- 提供知识关联链接

## 🔍 发现问题时的处理

当发现知识库内容可能有误或过时时：

### 输出格式

```
⚠️ 知识库内容存疑

知识点: [KB-YYYYMMDD-XXX] 知识点标题
文件位置: KNOWLEDGE_BASE/TOPICS/topic-xxx.md
疑似问题: <具体描述问题所在>

建议: 请用户检查并确认是否需要更新
```

### 处理原则

1. **不自行修改** - Agent 不编辑任何知识库文件
2. **明确告知用户** - 输出问题位置和具体疑点
3. **等待用户决策** - 由用户决定是否修正

## 分类体系

当前知识库的分类结构（可通过 `kb browse` 查看最新）：

| 顶层分类 | 说明 |
|----------|------|
| cuda | CUDA 编程 |
| llvm | LLVM 编译器 |
| triton | Triton 编程 |
| mlir | MLIR 中间表示 |
| system-design | 系统设计 |

子分类示例：
- `cuda.memory`, `cuda.optimization`, `cuda.threads`
- `llvm.frontend`, `llvm.backend`, `llvm.basics`
- `triton.basics`, `triton.optimization`

## 知识等级

| Level | 说明 |
|-------|------|
| 1 | 基础入门 |
| 2 | 进阶深入 |
| 3 | 专家级 |

## CLI 命令速查

```bash
# 搜索
./.kb/kb search "关键词"

# 分类筛选
./.kb/kb search "内存" --category cuda --level 2

# 浏览分类
./.kb/kb browse --category cuda

# 获取详情
./.kb/kb search --id KB-20260307-001

# 查看状态
./.kb/kb status

# 查看所有分类
./.kb/kb browse
```

## 知识点格式

每个知识点文件包含以下字段：

| 字段 | 说明 |
|------|------|
| `id` | 唯一标识 `KB-YYYYMMDD-XXX` |
| `title` | 标题 |
| `category` | 分类路径 |
| `level` | 深度等级 1-3 |
| `summary` | 一句话摘要 |
| `tags` | 标签列表 |

## 相关文件（只读参考）

- `KNOWLEDGE_BASE/README.md` - 知识库使用指南
- `KNOWLEDGE_BASE/FORMAT.md` - 知识卡片格式规范
- `KNOWLEDGE_BASE/INDEX_TOPICS.md` - 知识点索引（人类可读）

---

*此 Skill 由知识库维护，通过 git 同步分发*
