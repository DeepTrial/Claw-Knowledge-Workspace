# Quick Reference

## 只读原则

❌ 禁止修改知识库任何内容
✅ 仅允许 search / browse / status / 读取文件

## 离线运行

不依赖网络，不联动其他工具

## 路径约定

相对于 **workspace 根目录**：

| 用途 | 路径 |
|------|------|
| CLI 工具 | `KNOWLEDGE_BASE/.kb/kb` |
| 知识点 | `KNOWLEDGE_BASE/TOPICS/` |

## 命令速查

| 场景 | 命令 |
|------|------|
| 搜索 | `KNOWLEDGE_BASE/.kb/kb search "关键词"` |
| 分类浏览 | `KNOWLEDGE_BASE/.kb/kb browse --category cuda` |
| 获取详情 | `KNOWLEDGE_BASE/.kb/kb search --id KB-xxx` |
| 查看状态 | `KNOWLEDGE_BASE/.kb/kb status` |
| 查看所有分类 | `KNOWLEDGE_BASE/.kb/kb browse` |

## 读取知识点

```bash
cat KNOWLEDGE_BASE/TOPICS/topic-xxx.md
```

## 发现问题时

输出格式：

```
⚠️ 知识库内容存疑

知识点: [KB-xxx] 标题
文件位置: KNOWLEDGE_BASE/TOPICS/topic-xxx.md
疑似问题: <描述>

建议: 请用户检查
```

## 知识点 ID

格式：`KB-YYYYMMDD-XXX`

## 等级

| Level | 说明 |
|-------|------|
| 1 | 基础 |
| 2 | 进阶 |
| 3 | 专家 |
