#!/bin/bash
# sync-knowledge.sh
# 知识库同步封装脚本（基于 Git）
#
# 用法：./sync-knowledge.sh <command> [options]
#
# Commands:
#   push   - 推送本地变更到远端
#   pull   - 从远端拉取最新内容
#   sync   - 双向同步（先 pull 后 push）
#   status - 查看当前状态
#   init   - 初始化本地 Git（首次使用）
#
# Options:
#   -m, --message <msg>  - 提交消息（push 时使用）
#   -f, --force          - 强制覆盖本地变更（pull 时使用）
#   -h, --help           - 显示帮助
#
# 示例:
#   ./sync-knowledge.sh push -m "新增 Feishu 集成文档"
#   ./sync-knowledge.sh pull
#   ./sync-knowledge.sh sync

set -e

# ==================== 配置 ====================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KB_DIR="${KB_DIR:-$SCRIPT_DIR}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# ==================== 帮助信息 ====================
show_help() {
    cat << EOF
知识库同步工具 (基于 Git)

用法：$0 <command> [options]

Commands:
  push    推送本地变更到远端仓库
  pull    从远端仓库拉取最新内容
  sync    双向同步（先 pull 后 push）
  status  查看当前状态
  init    初始化本地 Git（首次使用）

Options:
  -m, --message <msg>  提交消息（push 时使用）
  -f, --force          强制覆盖本地变更（pull 时使用）
  -h, --help           显示帮助信息

示例:
  $0 push -m "新增 Feishu 集成文档"
  $0 pull
  $0 sync
  $0 status

配置:
  KB_DIR       知识库路径（默认：脚本所在目录）
  REMOTE_NAME  远端名称（默认：origin）
  MAIN_BRANCH  主分支名称（默认：main）

EOF
}

# ==================== 功能函数 ====================

# 初始化 Git
cmd_init() {
    log_info "初始化本地 Git 仓库..."
    
    if [ -d "$KB_DIR/.git" ]; then
        log_warn "Git 仓库已存在"
        cd "$KB_DIR" && git remote -v
        return
    fi
    
    cd "$KB_DIR"
    git init
    git add -A
    git commit -m "初始化知识库"
    
    # 检查是否有远端
    if [ -d "~/repos/knowledge-base.git" ] || [ -d "/Users/laosan/repos/knowledge-base.git" ]; then
        git remote add origin ~/repos/knowledge-base.git 2>/dev/null || true
        log_info "已配置远端：origin"
    fi
    
    log_success "初始化完成"
}

# 查看状态
cmd_status() {
    cd "$KB_DIR"
    
    echo ""
    log_info "知识库状态：$KB_DIR"
    echo ""
    
    git status
    echo ""
    
    log_info "远端配置:"
    git remote -v
    echo ""
    
    log_info "最近提交:"
    git log --oneline -5
    echo ""
}

# 推送
cmd_push() {
    local commit_msg="${1:-同步知识库 - $(date '+%Y-%m-%d %H:%M:%S')}"
    
    cd "$KB_DIR"
    
    log_info "推送本地变更到远端..."
    
    # 1. 生成索引
    if [ -x "$KB_DIR/generate-index.sh" ]; then
        log_info "生成索引..."
        "$KB_DIR/generate-index.sh"
    fi
    
    # 2. 检查变更
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    if [ "$changes" -eq 0 ]; then
        log_info "没有变更需要提交"
    else
        # 3. 提交
        git add -A
        git commit -m "$commit_msg" || log_warn "提交失败，可能没有变更"
    fi
    
    # 4. 拉取最新（避免冲突）
    log_info "拉取远端最新内容..."
    git pull --rebase origin "$MAIN_BRANCH" || {
        log_warn "拉取失败，可能存在冲突"
        log_info "请手动解决冲突后重新推送"
        return 1
    }
    
    # 5. 再次生成索引（合并后可能需要更新）
    if [ -x "$KB_DIR/generate-index.sh" ]; then
        "$KB_DIR/generate-index.sh"
        git add INDEX_*.md
        git commit -m "更新索引" || true
    fi
    
    # 6. 推送
    log_info "推送到远端..."
    git push origin "$MAIN_BRANCH"
    
    log_success "推送完成"
}

# 拉取
cmd_pull() {
    local force=false
    
    if [ "$1" = "-f" ] || [ "$1" = "--force" ]; then
        force=true
        log_warn "强制模式：本地变更将被覆盖"
    fi
    
    cd "$KB_DIR"
    
    log_info "从远端拉取最新内容..."
    
    # 检查本地变更
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ] && [ "$force" = false ]; then
        log_warn "本地有未提交的变更"
        log_info "请先提交或stash 本地变更，或使用 -f 强制覆盖"
        git status --short
        return 1
    fi
    
    # 拉取
    if [ "$force" = true ]; then
        git fetch origin
        git reset --hard origin/"$MAIN_BRANCH"
        log_info "已强制重置到远端版本"
    else
        git pull origin "$MAIN_BRANCH"
    fi
    
    # 生成索引
    if [ -x "$KB_DIR/generate-index.sh" ]; then
        log_info "生成索引..."
        "$KB_DIR/generate-index.sh"
    fi
    
    log_success "拉取完成"
}

# 双向同步
cmd_sync() {
    log_info "双向同步（先 pull 后 push）..."
    
    cmd_pull || {
        log_error "拉取失败，中止同步"
        return 1
    }
    
    cmd_push
    
    log_success "双向同步完成"
}

# ==================== 主流程 ====================

# 解析参数
COMMAND=""
COMMIT_MSG=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        push|pull|sync|status|init)
            COMMAND="$1"
            shift
            ;;
        -m|--message)
            COMMIT_MSG="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数：$1"
            show_help
            exit 1
            ;;
    esac
done

# 执行命令
case "$COMMAND" in
    init)
        cmd_init
        ;;
    status)
        cmd_status
        ;;
    push)
        cmd_push "$COMMIT_MSG"
        ;;
    pull)
        [ "$FORCE" = true ] && cmd_pull "-f" || cmd_pull
        ;;
    sync)
        cmd_sync
        ;;
    "")
        log_error "请指定命令 (push|pull|sync|status|init)"
        show_help
        exit 1
        ;;
    *)
        log_error "未知命令：$COMMAND"
        show_help
        exit 1
        ;;
esac
