# 其他 Agent 知识库配置指南

> 如何让 bot-a、bot-b 等 Agent 使用中央知识库

---

## 🎯 场景说明

假设您有多个 Agent：

- `main` - 主 Agent（当前工作区）
- `bot-a` - 调研 Agent
- `bot-b` - 写作 Agent
- `bot-c` - 分析 Agent

每个 Agent 都需要访问中央知识库，并可能贡献新内容。

---

## 📋 方案对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|----------|------|------|
| **独立克隆** | 多 Agent 协作贡献 | 完整 Git 功能，可独立修改 | 需要初始化 |
| **符号链接** | 只读共享 | 简单，实时同步 | 不能独立修改 |
| **定时拉取** | 定期更新 | 自动化 | 需要额外脚本 |

**推荐**: 独立克隆（每个 Agent 一个副本）

---

## 🚀 方法 1: 使用初始化脚本（推荐）

### 步骤 1: 运行初始化脚本

```bash
# 为 bot-a 初始化
cd /Users/laosan/Documents/KnowledgeBase
./init-agent-kb.sh bot-a

# 为 bot-b 初始化
./init-agent-kb.sh bot-b

# 为自定义路径初始化
./init-agent-kb.sh bot-c /custom/workspace/path
```

### 步骤 2: 验证

```bash
# 检查 bot-a 的知识库
ls -la /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE/

# 查看 Git 状态
cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
git status
```

### 步骤 3: 使用

```bash
# 拉取最新内容
cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
./sync-knowledge.sh pull

# 推送贡献
./sync-knowledge.sh push -m "bot-a 新增调研文档"
```

---

## 🔧 方法 2: 手动初始化

### 为 bot-a 初始化

```bash
# 1. 创建目录
mkdir -p /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE

# 2. 初始化 Git
cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
git init

# 3. 配置远端
git remote add origin ~/repos/knowledge-base.git

# 4. 拉取内容
git pull origin main

# 5. 验证
ls -la
```

### 为 bot-b 初始化

```bash
mkdir -p /Users/laosan/.openclaw/workspace-bot-b/KNOWLEDGE_BASE
cd /Users/laosan/.openclaw/workspace-bot-b/KNOWLEDGE_BASE
git init
git remote add origin ~/repos/knowledge-base.git
git pull origin main
```

---

## 🤖 Agent 调用方式

### 在 Agent 代码中集成

```python
# Python 示例
import subprocess
import os

def sync_knowledge_base(agent_name):
    """为 Agent 同步知识库"""
    kb_dir = f"/Users/laosan/.openclaw/workspace-{agent_name}/KNOWLEDGE_BASE"
    
    # 检查是否已初始化
    if not os.path.exists(f"{kb_dir}/.git"):
        # 初始化
        subprocess.run([
            "/Users/laosan/Documents/KnowledgeBase/init-agent-kb.sh",
            agent_name
        ])
    else:
        # 拉取更新
        os.chdir(kb_dir)
        subprocess.run(["git", "pull", "origin", "main"])
        subprocess.run(["./generate-index.sh"])
    
    return kb_dir

# 使用
kb_path = sync_knowledge_base("bot-a")
```

### Shell 脚本调用

```bash
#!/bin/bash
# Agent 启动时自动同步

AGENT_NAME="bot-a"
KB_DIR="/Users/laosan/.openclaw/workspace-$AGENT_NAME/KNOWLEDGE_BASE"

if [ -d "$KB_DIR/.git" ]; then
    cd "$KB_DIR" && git pull origin main
fi
```

---

## 📊 多 Agent 协作流程

```
时间线:

07:00  bot-a 开始调研 Feishu
       → 从中央仓库拉取最新内容
       → ./sync-knowledge.sh pull

07:30  bot-a 完成调研
       → 创建 TOPICS/feishu-integration.md
       → ./sync-knowledge.sh push -m "bot-a: Feishu 集成调研"
       → 中央仓库收到更新

08:00  bot-b 开始写作
       → 从中央仓库拉取（包含 bot-a 的内容）
       → ./sync-knowledge.sh pull
       → 读取 TOPICS/feishu-integration.md
       → 基于此创作文章

08:30  bot-b 完成文章
       → 创建 TOPICS/feishu-article.md
       → ./sync-knowledge.sh push -m "bot-b: Feishu 文章"
       → 中央仓库收到更新

09:00  main 查看最新内容
       → ./sync-knowledge.sh sync
       → 看到 bot-a 和 bot-b 的贡献
```

---

## 📁 目录结构

```
/Users/laosan/.openclaw/
├── workspace/                          # main Agent
│   └── KNOWLEDGE_BASE/
│       ├── .git/
│       ├── sync-knowledge.sh
│       └── ...
│
├── workspace-bot-a/                    # bot-a Agent
│   └── KNOWLEDGE_BASE/
│       ├── .git/
│       ├── sync-knowledge.sh
│       └── ...
│
├── workspace-bot-b/                    # bot-b Agent
│   └── KNOWLEDGE_BASE/
│       ├── .git/
│       ├── sync-knowledge.sh
│       └── ...
│
└── ...
```

**每个 Agent 都有独立的 Git 仓库**，都指向同一个远端。

---

## 🔍 常见问题

### Q1: Agent 如何知道知识库位置？

**A**: 在 Agent 配置中指定：

```yaml
# Agent 配置文件
knowledge_base:
  path: /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
  auto_sync: true
  sync_on_startup: true
```

### Q2: 如何避免冲突？

**A**: 

1. **推送前先拉取**: `./sync-knowledge.sh sync`
2. **不同文件不冲突**: 每个 Agent 创建不同的文件
3. **同文件修改**: Git 会提示冲突，需要手动解决

### Q3: 只读访问可以吗？

**A**: 可以，只拉取不推送：

```bash
./sync-knowledge.sh pull
# 不使用 push
```

### Q4: 如何查看其他 Agent 的贡献？

**A**: 

```bash
# 查看提交历史
git log --oneline

# 查看特定贡献者
git log --author="bot-a" --oneline

# 查看索引
cat INDEX_TOPICS.md
```

---

## 🎯 最佳实践

### 1. Agent 启动时同步

```bash
# Agent 启动脚本
cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE
./sync-knowledge.sh pull
```

### 2. 完成任务后推送

```bash
# 完成任务后
./sync-knowledge.sh push -m "bot-a: 完成 XXX 调研"
```

### 3. 使用有意义的提交消息

```bash
# ✅ 好的提交消息
./sync-knowledge.sh push -m "bot-a: 新增 Feishu 集成调研"

# ❌ 不好的提交消息
./sync-knowledge.sh push -m "更新"
```

### 4. 定期同步

```bash
# 每 30 分钟同步一次（cron）
*/30 * * * * cd /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE && git pull origin main
```

---

## 📋 快速参考

### 初始化新 Agent

```bash
# 一行命令初始化
/Users/laosan/Documents/KnowledgeBase/init-agent-kb.sh <agent-name>
```

### 日常同步

```bash
# 拉取
cd /Users/laosan/.openclaw/workspace-<agent>/KNOWLEDGE_BASE
./sync-knowledge.sh pull

# 推送
./sync-knowledge.sh push -m "<agent>: 消息"

# 双向同步
./sync-knowledge.sh sync
```

### 查看状态

```bash
./sync-knowledge.sh status
```

---

## 🔧 故障排除

### 问题：权限错误

```bash
# 确保脚本可执行
chmod +x /Users/laosan/Documents/KnowledgeBase/*.sh
```

### 问题：远端仓库不存在

```bash
# 检查远端仓库
ls -la ~/repos/knowledge-base.git

# 如果不存在，创建
git init --bare ~/repos/knowledge-base.git
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

*最后更新：2026-03-06 | 维护者：ZIV-BOT*
