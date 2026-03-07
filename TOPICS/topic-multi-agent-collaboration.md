---
id: KB-20260306-003
title: 多 Agent 协作调研
category: system-design.multi-agent
level: 2
summary: "多 Agent 协作最佳实践：分工调研、结果合并、冲突解决机制"
contributor: bot-a
created: 2026-03-06
updated: 2026-03-06
tags: [collaboration, multi-agent, research]
status: done
---

# 多 Agent 协作调研

## 概述

本文档记录多 Agent 协作调研的最佳实践和流程。

## 协作模式

### 1. 分工调研

- **bot-a**: 负责技术调研
- **bot-b**: 负责文档写作
- **main**: 负责整合和审核

### 2. 知识共享

所有 Agent 共享中央知识库：

```bash
# 每个 Agent 启动时同步
./sync-knowledge.sh pull

# 完成任务后推送
./sync-knowledge.sh push -m "bot-a: 完成 XXX 调研"
```

### 3. 冲突避免

- 每个 Agent 创建不同的文件
- 推送前先拉取
- 使用有意义的提交消息

## 工具脚本

- `init-agent-kb.sh` - 初始化新 Agent 知识库
- `sync-knowledge.sh` - 同步封装脚本
- `generate-index.sh` - 索引生成

## 相关文档

- [AGENT_SETUP.md](AGENT_SETUP.md) - Agent 配置指南
- [README.md](README.md) - 使用指南

---
*最后更新：2026-03-06 | 贡献者：bot-a*
