---
id: KB-20260306-001
title: Feishu 知识库集成
contributor: main
created: 2026-03-06
updated: 2026-03-06
tags: [feishu, integration, api]
status: done
---

# Feishu 知识库集成

## 概述

本文档记录 Feishu（飞书）知识库的集成方案，包括文档同步、云盘管理和知识库协作。

## 核心功能

### 1. 文档读写
- 使用 Feishu Open API 读取/写入云文档
- 支持 Markdown 格式转换
- 自动同步变更

### 2. 云盘管理
- 文件夹创建和移动
- 文件上传下载
- 权限管理

### 3. 知识库协作
- 多智能体知识共享
- 版本控制
- 贡献追溯

## 使用方法

```bash
# 读取 Feishu 文档
feishu_doc read --doc_token=xxx

# 写入 Feishu 文档
feishu_doc write --doc_token=xxx --content="..."
```

## 依赖

- Feishu Open API
- 应用权限：docx、drive、wiki

## 相关文档

- [Feishu API 文档](https://open.feishu.cn/document)
- [知识库同步脚本](../sync-knowledge.sh)

---
*最后更新：2026-03-06 | 贡献者：main*
