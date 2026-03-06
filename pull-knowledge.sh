#!/bin/bash
# pull-knowledge.sh
# 简化版拉取脚本（供其他 Agent 使用）
#
# 用法：./pull-knowledge.sh [知识库路径]
# 示例：./pull-knowledge.sh
#        ./pull-knowledge.sh /Users/laosan/.openclaw/workspace-bot-a/KNOWLEDGE_BASE

set -e

KB_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
REMOTE_REPO="$HOME/repos/knowledge-base.git"

echo "[INFO] 从中央仓库拉取最新内容..."
echo "[INFO] 知识库路径：$KB_DIR"
echo "[INFO] 远端仓库：$REMOTE_REPO"
echo ""

cd "$KB_DIR"

# 检查是否已初始化
if [ ! -d ".git" ]; then
    echo "[WARN] 知识库未初始化，正在初始化..."
    git init
    git remote add origin "$REMOTE_REPO"
    git pull origin main
else
    # 已有仓库，直接拉取
    git pull origin main
fi

# 生成索引
if [ -x "generate-index.sh" ]; then
    echo ""
    ./generate-index.sh
fi

echo ""
echo "[SUCCESS] 拉取完成"
