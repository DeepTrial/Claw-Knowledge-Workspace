# Agent 知识库配置指南

> 如何为其他 Agent 配置知识库

---

## 🎯 架构说明

**当前架构**: v2.0 (扁平化)

```
GitHub → 各 Agent 工作区
```

**中央仓库**: 已移除（~/Documents/KnowledgeBase 已废弃）

---

## 📁 工作区位置

| Agent | 工作区路径 |
|-------|-----------|
| main | `/Users/laosan/.openclaw/workspace/KNOWLEDGE_BASE` |
| bot-a | `/Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE` |
| bot-b | `/Users/laosan/.openclaw/workspace-bot-b/KNOWLEDGE_BASE` |
| bot-c | `/Users/laosan/.openclaw/workspace-bot-c/KNOWLEDGE_BASE` |

所有工作区都直接同步到 GitHub：
`https://github.com/DeepTrial/Claw-Knowledge-Workspace.git`

---

## 🚀 新 Agent 初始化

### 使用初始化脚本

```bash
# 为 bot-c 初始化
/Users/laosan/.openclaw/workspace/KNOWLEDGE_BASE/init-agent-kb.sh bot-c

# 这会：
# 1. 创建 /Users/laosan/.openclaw/workspace-bot-c/KNOWLEDGE_BASE
# 2. 初始化 Git 仓库
# 3. 配置 GitHub 远端
# 4. 拉取所有知识内容
```

### 手动初始化

```bash
# 1. 创建目录
mkdir -p /Users/laosan/.openclaw/workspace-bot-c/KNOWLEDGE_BASE

# 2. 初始化 Git
cd /Users/laosan/.openclaw/workspace-bot-c/KNOWLEDGE_BASE
git init

# 3. 配置远端
git remote add origin https://github.com/DeepTrial/Claw-Knowledge-Workspace.git

# 4. 拉取内容
git pull origin main
```

---

## 🔄 日常同步

```bash
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE

# 拉取最新内容
./sync-knowledge.sh pull

# 推送变更
./sync-knowledge.sh push -m "消息"

# 双向同步
./sync-knowledge.sh sync
```

---

## 📋 验证配置

```bash
# 检查 Git 远端
git remote -v
# 应该显示 GitHub 仓库 URL

# 检查分支状态
git status
git branch -a

# 测试同步
./sync-knowledge.sh status
```

---

## ⚠️ 注意事项

1. **所有 Agent 平等**: 没有中央仓库，所有工作区直接同步到 GitHub
2. **推送前拉取**: 避免冲突
3. **Token 安全**: 不要分享 Personal Access Token

---

*最后更新：2026-03-06 | 架构版本：v2.0*
