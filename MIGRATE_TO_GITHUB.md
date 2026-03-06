# GitHub 远端仓库配置

> 当前知识库已配置 GitHub 远端仓库

---

## ✅ 当前配置状态

**远端仓库**: `https://github.com/DeepTrial/Claw-Knowledge-Workspace.git`

**仓库所有者**: `DeepTrial`

**仓库名称**: `Claw-Knowledge-Workspace`

**可见性**: 公开 (Public)

**架构版本**: v2.0 (扁平化架构)

---

## 🏗️ 架构说明

### 当前架构（v2.0）

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

每个 Agent 工作区直接同步到 GitHub，无需中央仓库中转
```

### 历史架构（v1.0，已废弃）

```
工作区 → 中央仓库 (~/Documents/KnowledgeBase) → GitHub
```

**废弃原因**:
- ❌ 架构复杂，维护成本高
- ❌ 需要同步步骤冗余
- ❌ 磁盘空间浪费
- ❌ 不符合 Git 分布式理念

---

## 📁 仓库信息

| 项目 | 值 |
|------|-----|
| **仓库 URL** | `https://github.com/DeepTrial/Claw-Knowledge-Workspace.git` |
| **SSH URL** | `git@github.com:DeepTrial/Claw-Knowledge-Workspace.git` |
| **所有者** | DeepTrial |
| **名称** | Claw-Knowledge-Workspace |
| **可见性** | Public |
| **默认分支** | main |

---

## 🔧 配置详情

### Agent 工作区配置

每个 Agent 工作区的 KNOWLEDGE_BASE 目录都配置了相同的远端：

```bash
# main 工作区
cd /Users/laosan/.openclaw/workspace/KNOWLEDGE_BASE
git remote -v
# origin  https://github.com/DeepTrial/Claw-Knowledge-Workspace.git

# bot-a 工作区
cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
git remote -v

# bot-b 工作区
cd /Users/laosan/.openclaw/workspace-bot-b/KNOWLEDGE_BASE
git remote -v
```

### 初始化脚本配置

`init-agent-kb.sh` 中配置的默认远端：

```bash
REMOTE_REPO="https://github.com/DeepTrial/Claw-Knowledge-Workspace.git"
```

---

## 🚀 使用方式

### 推送变更到 GitHub

```bash
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE
./sync-knowledge.sh push -m "提交消息"
```

### 从 GitHub 拉取最新内容

```bash
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE
./sync-knowledge.sh pull
```

### 双向同步

```bash
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE
./sync-knowledge.sh sync
```

---

## 🔐 认证配置

### 使用 Personal Access Token

```bash
# 配置 Git 凭证存储
git config --global credential.helper store

# 推送时会提示输入用户名和 Token
git push origin main
```

### Token 权限要求

- ✅ `repo` - Full control of private repositories
- ✅ `workflow` - Update GitHub Action workflows (可选)

---

## 🔄 架构迁移历史

### 迁移时间线

| 时间 | 事件 | 架构版本 |
|------|------|----------|
| 2026-03-05 | 初始架构：本地中央仓库 | v1.0 |
| 2026-03-06 | 配置 GitHub 远端 | v1.5 |
| 2026-03-06 | 移除中央仓库，扁平化架构 | v2.0 |

### 迁移内容

**从**: `~/Documents/KnowledgeBase` (中央仓库)

**到**: GitHub 直连架构

**迁移项目**:
- ✅ Git 远端配置更新
- ✅ 所有文档更新
- ✅ 脚本配置更新
- ✅ 中央仓库移除（使用 trash，可恢复）

---

## ⚠️ 注意事项

1. **Token 安全**: 不要在任何公开场合分享 Personal Access Token
2. **定期同步**: 确保本地和 GitHub 保持同步
3. **大文件**: 如果有>100MB 文件，需要使用 Git LFS
4. **冲突处理**: 推送前先拉取，避免冲突
5. **中央仓库**: 已移除，不再使用 ~/Documents/KnowledgeBase

---

## 🔧 故障排除

### 认证失败

```bash
# 清除缓存的凭证
rm ~/.git-credentials

# 重新推送，会提示重新输入
git push origin main
```

### 推送被拒绝

```bash
# 先拉取最新内容
git pull --rebase origin main

# 然后重新推送
git push origin main
```

### 大文件推送失败

```bash
# 安装 Git LFS
brew install git-lfs
git lfs install

# 追踪大文件
git lfs track "*.pth"
git lfs track "*.bin"

# 重新推送
git add .gitattributes
git commit -m "配置 Git LFS"
git push origin main
```

---

## 📝 相关文档

- [README.md](README.md) - 知识库使用指南
- [AGENT_SETUP.md](AGENT_SETUP.md) - Agent 配置指南
- [README.md](README.md) - 架构说明

---

*最后更新：2026-03-06 | 贡献者：main | 架构版本：v2.0*
