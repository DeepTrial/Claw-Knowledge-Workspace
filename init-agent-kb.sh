#!/bin/bash
# init-agent-kb.sh
# 为新 Agent 初始化本地知识库
#
# 用法：./init-agent-kb.sh <agent-name> [workspace-path]
# 示例：./init-agent-kb.sh bot-a
#        ./init-agent-kb.sh bot-a $HOME/.openclaw/workspace-bot-a

set -e

# ==================== 参数 ====================
AGENT_NAME="${1:-}"
WORKSPACE_ROOT="${2:-$HOME/.openclaw}"
REMOTE_REPO="https://github.com/DeepTrial/Claw-Knowledge-Workspace.git"

# ==================== 帮助信息 ====================
if [ -z "$AGENT_NAME" ]; then
    echo "用法：$0 <agent-name> [workspace-path]"
    echo ""
    echo "示例:"
    echo "  $0 bot-a"
    echo "  $0 bot-a $HOME/.openclaw/workspace-bot-a"
    echo ""
    echo "当前配置:"
    echo "  工作区根目录：$WORKSPACE_ROOT"
    echo "  远端仓库：$REMOTE_REPO"
    exit 1
fi

# 确定工作区路径
if [ "$AGENT_NAME" = "main" ] || [ "$AGENT_NAME" = "workspace" ]; then
    WORKSPACE_DIR="$WORKSPACE_ROOT/workspace"
else
    WORKSPACE_DIR="$WORKSPACE_ROOT/workspace-$AGENT_NAME"
fi

KB_DIR="$WORKSPACE_DIR/KNOWLEDGE_BASE"

# ==================== 检查 ====================
echo "[INFO] 正在为 Agent '$AGENT_NAME' 初始化知识库..."
echo "[INFO] 工作区路径：$WORKSPACE_DIR"
echo "[INFO] 知识库路径：$KB_DIR"
echo "[INFO] 远端仓库：$REMOTE_REPO"
echo ""

# 检查远端仓库是否存在
if [ ! -d "$REMOTE_REPO" ]; then
    echo "[ERROR] 远端仓库不存在：$REMOTE_REPO"
    echo "[ERROR] 请先创建远端仓库："
    echo "  git init --bare ~/repos/knowledge-base.git"
    exit 1
fi

# 检查知识库是否已存在
if [ -d "$KB_DIR/.git" ]; then
    echo "[WARN] 知识库已存在 Git 仓库"
    echo "[INFO] 将执行拉取操作而非初始化"
    cd "$KB_DIR"
    git pull origin main
    echo "[SUCCESS] 知识库已更新"
    exit 0
fi

# ==================== 初始化 ====================
echo "[INFO] 创建知识库目录..."
mkdir -p "$KB_DIR"

echo "[INFO] 初始化 Git 仓库..."
cd "$KB_DIR"
git init

echo "[INFO] 配置远端仓库..."
git remote add origin "$REMOTE_REPO"

echo "[INFO] 拉取中央仓库内容..."
git pull origin main

echo ""
echo "[SUCCESS] Agent '$AGENT_NAME' 知识库初始化完成！"
echo ""
echo "知识库位置：$KB_DIR"
echo ""
echo "使用方法:"
echo "  cd $KB_DIR"
echo "  ./sync-knowledge.sh pull    # 拉取最新内容"
echo "  ./sync-knowledge.sh push    # 推送本地变更"
echo "  ./sync-knowledge.sh status  # 查看状态"
echo ""
