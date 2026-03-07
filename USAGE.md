# 知识库工具使用指南

> **版本**: v4.0  
> **更新时间**: 2026-03-07  
> **维护者**: bot-a

---

## 快速开始

### 1. 初始化

```bash
cd /path/to/knowledge-base
.kb/kb init
```

输出示例：
```
🔍 检测环境...
✅ Python 3.9.6
✅ pyyaml
✅ rank-bm25
📁 创建目录结构...
✅ 目录结构已创建
🔧 扫描知识点...
✅ 发现 15 个知识点
✅ 初始化完成！
```

### 2. 重建索引

```bash
.kb/kb rebuild
```

### 3. 检索知识

```bash
.kb/kb search "GPU 内存优化"
.kb/kb search "CUDA" --category cuda --limit 10
.kb/kb search --id KB-20260307-001
```

---

## 命令详解

### kb init

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

### kb status

查看知识库状态。

```bash
.kb/kb status
```

输出示例：
```
📊 知识库状态
────────────────────────────────────────
├─ 总知识点: 15
├─ 分类数: 12
├─ 索引版本: 4.0
├─ 最后更新: 2026-03-07T13:09:01
├─ 检索模式: BM25
├─ 向量模型: 未启用
└─ 相似对数: 0
```

---

### kb rebuild

重建索引。

```bash
.kb/kb rebuild                # 重建索引
.kb/kb rebuild --no-embeddings # 跳过向量生成
```

功能：
- 扫描所有知识点文件
- 解析元数据
- 执行去重检测
- 生成辅助索引

---

### kb search

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
- `query`: 查询语句（自然语言）
- `--category`: 分类筛选（如 `cuda`, `cuda.memory`）
- `--level`: 等级筛选（1-3）
- `--limit`: 返回数量（默认 5）
- `--id`: 通过 ID 直接获取

---

### kb browse

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

总计: 15 个知识点

📁 cuda (4)
   • [KB-20250306-001] CUDA 线程层次结构深度解析
   • [KB-20250306-002] CUDA 内存层次结构深度解析
   ...

📁 triton (4)
   • [KB-20250306-003] Triton @triton.jit Decorator 原理深度解析
   ...
```

---

### kb context

获取知识点的上下文信息。

```bash
.kb/kb context --id KB-20260307-001
```

输出示例：
```
📍 CUDA 共享内存优化策略
   分类: cuda.memory
   等级: 2

   相关知识点:
     • CUDA 内存层次结构
     • Bank Conflict 详解

   被引用:
     • CUDA 性能调优指南
```

---

### kb dedup

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

[content] 相似度: 92%
  • KB-20260306-003: Triton JIT 原理
  • KB-20260307-003: Triton 编译器解析
```

---

### kb ingest

入库新知识。

```bash
# 预览模式（不实际写入）
.kb/kb ingest new_article.md --dry-run

# 入库并指定分类
.kb/kb ingest new_article.md --category cuda.memory --level 2

# 正式入库
.kb/kb ingest new_article.md
```

参数：
- `file`: 知识文件路径
- `--category`: 指定分类
- `--level`: 指定等级（1-3）
- `--dry-run`: 预览模式

功能：
- 解析知识文件
- 执行三层去重检测
- 添加到索引

---

### kb merge

合并重复的知识点。

```bash
# 预览合并
.kb/kb merge KB-SOURCE-ID KB-TARGET-ID --preview

# 执行合并
.kb/kb merge KB-SOURCE-ID KB-TARGET-ID
```

参数：
- `source_id`: 将被合并的知识点（标记为 deprecated）
- `target_id`: 保留的知识点
- `--preview`: 预览模式

功能：
- 合并知识内容
- 迁移关系引用
- 标记源文件为 deprecated
- 更新索引

---

## 知识卡片格式

### 标准模板

```markdown
---
id: KB-YYYYMMDD-XXX
title: 知识标题
category: domain.subdomain
level: 1
tags: [tag1, tag2, tag3]
summary: "一句话摘要"
created: 2026-03-07
updated: 2026-03-07
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
| `tags` | 标签列表 | `[cuda, memory, optimization]` |
| `summary` | 摘要 | `"介绍 bank conflict 优化方法"` |

### 可选字段

| 字段 | 说明 |
|------|------|
| `relations` | 知识关联 |
| `keywords` | 关键词列表 |
| `contributors` | 贡献者 |

---

## 分类体系

```
cuda                    # CUDA 编程
├── cuda.memory         # 内存管理
├── cuda.kernel         # 核函数
├── cuda.threads        # 线程层次
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

## 检索模式

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

## 工作流示例

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
vim new-knowledge.md

# 2. 预览入库
.kb/kb ingest new-knowledge.md --dry-run

# 3. 正式入库
.kb/kb ingest new-knowledge.md --category cuda.memory --level 2

# 4. 验证
.kb/kb search --id KB-NEW-ID
```

### 3. 处理重复知识

```bash
# 1. 检测重复
.kb/kb dedup

# 2. 预览合并
.kb/kb merge KB-SOURCE KB-TARGET --preview

# 3. 执行合并
.kb/kb merge KB-SOURCE KB-TARGET

# 4. 验证
.kb/kb search --id KB-TARGET
```

---

## 故障排除

### Q: 检索结果为空

```bash
# 检查索引
.kb/kb status

# 重建索引
.kb/kb rebuild
```

### Q: ingest 失败

```bash
# 检查文件格式
# 确保有必填字段：id, title, category, level, tags, summary

# 使用 dry-run 预览
.kb/kb ingest file.md --dry-run
```

### Q: 分类显示 unknown

```bash
# 知识点缺少 category 字段
# 在 frontmatter 中添加：
# category: cuda.memory
```

---

## 相关文档

- [最终设计方案](/Users/laosan/Documents/knowledge-base-final-design.md)
- [配置文件](.kb/config.yaml)

---

*本文档由 bot-a 生成 | 版本：v4.0 | 最后更新：2026-03-07*
