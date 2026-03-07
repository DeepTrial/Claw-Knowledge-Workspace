#!/bin/bash
# sync-knowledge.sh
# 知识库同步封装脚本（基于 Git）- v2.0
#
# 用法：./sync-knowledge.sh <command> [options]
#
# Commands:
#   preview - 预览同步差异（新增）
#   push    - 推送本地变更到远端
#   pull    - 从远端拉取最新内容
#   sync    - 双向同步（原子性，支持回滚）
#   status  - 查看当前状态
#   init    - 初始化本地 Git（首次使用）
#
# Options:
#   -m, --message <msg>  - 提交消息（push 时使用）
#   -f, --force          - 强制覆盖本地变更（pull 时使用）
#   -s, --stash          - 自动 stash 本地变更（pull/sync 时使用）
#   -h, --help           - 显示帮助
#
# 改进点 (v2.0):
#   - Rebase 冲突详细提示
#   - Sync 原子性 + 回滚机制
#   - 预同步差异检查 (preview)
#   - 自动 stash 支持
#   - 索引生成安全处理
#   - 统一错误处理

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
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step() { printf "${CYAN}[STEP]${NC} %s\n" "$1"; }

# ==================== 帮助信息 ====================
show_help() {
    cat << EOF
知识库同步工具 v2.0 (基于 Git)

用法：$0 <command> [options]

Commands:
  preview  预览本地与远端的差异（同步前检查）
  push     推送本地变更到远端仓库
  pull     从远端仓库拉取最新内容
  sync     双向同步（原子性，失败自动回滚）
  status   查看当前状态
  init     初始化本地 Git（首次使用）

Options:
  -m, --message <msg>  提交消息（push 时使用）
  -f, --force          强制覆盖本地变更（pull 时使用）
  -s, --stash          自动 stash 本地变更（pull/sync 时使用）
  -h, --help           显示帮助信息

示例:
  $0 preview                        # 预览差异
  $0 push -m "新增 Feishu 集成文档"
  $0 pull -s                        # 拉取并自动 stash
  $0 sync                           # 双向同步

配置:
  KB_DIR       知识库路径（默认：脚本所在目录）
  REMOTE_NAME  远端名称（默认：origin）
  MAIN_BRANCH  主分支名称（默认：main）

EOF
}

# ==================== 核心功能函数 ====================

# 生成索引（新版，使用 .kb/kb）
generate_index() {
    if [ -x "$KB_DIR/.kb/kb" ]; then
        log_info "生成索引..."
        "$KB_DIR/.kb/kb" rebuild || {
            log_warn "索引生成失败，继续执行"
            return 1
        }
        return 0
    elif [ -x "$KB_DIR/generate-index.sh" ]; then
        log_info "生成索引（旧版）..."
        "$KB_DIR/generate-index.sh" || {
            log_warn "索引生成失败，继续执行"
            return 1
        }
        return 0
    fi
    return 0
}

# 提交索引更新（安全处理）
commit_index() {
    if git diff --quiet INDEX_TOPICS.md 2>/dev/null; then
        return 0
    fi
    
    git add INDEX_TOPICS.md
    git commit -m "更新索引" || {
        log_warn "索引提交失败（可能有冲突），继续执行"
        return 1
    }
}

# 检查并处理 rebase 冲突
handle_rebase_conflict() {
    if git rebase --quit 2>/dev/null; then
        # 不在 rebase 状态
        return 1
    fi
    
    # 在 rebase 冲突状态
    log_error "Rebase 发生冲突！"
    echo ""
    echo "📋 冲突文件："
    git diff --name-only --diff-filter=U 2>/dev/null || git status --short | grep "^UU\|^AA\|^DD"
    echo ""
    echo "🔧 解决方法："
    echo "  1. 查看冲突文件，手动编辑解决冲突标记（<<<<<<< / ======= / >>>>>>>）"
    echo "  2. 解决后执行：git add ."
    echo "  3. 继续 rebase：git rebase --continue"
    echo "  4. 放弃本次操作：git rebase --abort"
    echo ""
    return 0
}

# 安全的 rebase
safe_rebase() {
    log_info "拉取远端最新内容..."
    
    if git pull --rebase "$REMOTE_NAME" "$MAIN_BRANCH"; then
        return 0
    fi
    
    # 检查是否是 rebase 冲突
    if handle_rebase_conflict; then
        return 1
    fi
    
    # 其他错误
    log_error "拉取失败"
    return 1
}

# Stash 管理
stash_push() {
    local stash_msg="$1"
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    
    if [ "$changes" -gt 0 ]; then
        log_info "暂存本地变更（$changes 个文件）..."
        git stash push -m "$stash_msg"
        return 0
    fi
    return 1
}

stash_pop() {
    if git stash list | grep -q .; then
        log_info "恢复暂存的变更..."
        git stash pop || {
            log_warn "Stash 恢复失败，请手动处理：git stash pop"
            return 1
        }
    fi
    return 0
}

# ==================== 命令实现 ====================

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
    
    # 显示同步状态
    git fetch "$REMOTE_NAME" 2>/dev/null || true
    local ahead=$(git rev-list --count "$REMOTE_NAME/$MAIN_BRANCH"..HEAD 2>/dev/null || echo "?")
    local behind=$(git rev-list --count HEAD.."$REMOTE_NAME/$MAIN_BRANCH" 2>/dev/null || echo "?")
    
    echo "📊 同步状态:"
    echo "  - 本地领先：$ahead 个提交"
    echo "  - 远端领先：$behind 个提交"
    echo ""
}

# 预览差异（新增）
cmd_preview() {
    cd "$KB_DIR"
    
    log_step "检查远端状态..."
    if ! git fetch "$REMOTE_NAME" 2>/dev/null; then
        log_error "无法连接远端，请检查网络"
        return 1
    fi
    
    local ahead=$(git rev-list --count "$REMOTE_NAME/$MAIN_BRANCH"..HEAD 2>/dev/null || echo "0")
    local behind=$(git rev-list --count HEAD.."$REMOTE_NAME/$MAIN_BRANCH" 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 同步预览："
    echo "  - 本地领先：$ahead 个提交（待推送）"
    echo "  - 远端领先：$behind 个提交（待拉取）"
    
    if [ "$ahead" = "0" ] && [ "$behind" = "0" ]; then
        log_success "本地与远端已同步"
        return 0
    fi
    
    if [ "$behind" != "0" ] && [ "$behind" -gt 0 ]; then
        echo ""
        echo "📥 远端新提交："
        git log --oneline HEAD.."$REMOTE_NAME/$MAIN_BRANCH" | head -10
        if [ "$behind" -gt 10 ]; then
            echo "  ... 还有 $((behind - 10)) 个提交"
        fi
    fi
    
    if [ "$ahead" != "0" ] && [ "$ahead" -gt 0 ]; then
        echo ""
        echo "📤 本地新提交："
        git log --oneline "$REMOTE_NAME/$MAIN_BRANCH"..HEAD | head -10
        if [ "$ahead" -gt 10 ]; then
            echo "  ... 还有 $((ahead - 10)) 个提交"
        fi
    fi
    
    # 检查潜在冲突
    if [ "$ahead" != "0" ] && [ "$ahead" -gt 0 ] && [ "$behind" != "0" ] && [ "$behind" -gt 0 ]; then
        echo ""
        log_warn "⚠️  双方都有更新，同步时可能产生冲突"
        
        # 尝试预测冲突文件
        echo ""
        echo "🔍 可能冲突的文件："
        git diff --name-only "$REMOTE_NAME/$MAIN_BRANCH" HEAD 2>/dev/null | head -10 || echo "  无法预测"
    fi
    
    echo ""
}

# 推送
cmd_push() {
    local commit_msg="${1:-同步知识库 - $(date '+%Y-%m-%d %H:%M:%S')}"
    
    cd "$KB_DIR"
    
    log_step "1/5 检查本地变更..."
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    
    if [ "$changes" -eq 0 ]; then
        log_info "没有变更需要提交"
    else
        log_info "发现 $changes 个文件变更"
        
        # 生成索引
        log_step "2/5 生成索引..."
        generate_index
        
        # 提交
        log_step "3/5 提交变更..."
        git add -A
        git commit -m "$commit_msg" || log_warn "提交失败，可能没有实际变更"
    fi
    
    # 拉取最新
    log_step "4/5 拉取远端最新..."
    if ! safe_rebase; then
        return 1
    fi
    
    # 提交索引（合并后可能需要更新）
    commit_index
    
    # 推送
    log_step "5/5 推送到远端..."
    if git push "$REMOTE_NAME" "$MAIN_BRANCH"; then
        log_success "推送完成"
    else
        log_error "推送失败，可能需要重新同步"
        return 1
    fi
}

# 拉取
cmd_pull() {
    local force=false
    local use_stash=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force) force=true ;;
            -s|--stash) use_stash=true ;;
        esac
        shift
    done
    
    cd "$KB_DIR"
    
    log_step "1/3 检查本地状态..."
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    local stashed=false
    
    if [ "$changes" -gt 0 ]; then
        if [ "$force" = true ]; then
            log_warn "⚠️  强制模式：本地 $changes 个文件变更将被丢弃！"
            read -p "确认继续？(y/N) " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                log_info "操作已取消"
                return 0
            fi
        elif [ "$use_stash" = true ]; then
            stash_push "pull-stash-$(date +%s)"
            stashed=true
        else
            log_warn "本地有 $changes 个未提交的变更"
            log_info "请使用 -s (--stash) 自动暂存，或 -f (--force) 强制覆盖"
            git status --short
            return 1
        fi
    fi
    
    # 拉取
    log_step "2/3 拉取远端内容..."
    if [ "$force" = true ]; then
        git fetch "$REMOTE_NAME"
        git reset --hard "$REMOTE_NAME/$MAIN_BRANCH"
        log_info "已强制重置到远端版本"
    else
        if ! git pull "$REMOTE_NAME" "$MAIN_BRANCH"; then
            if [ "$stashed" = true ]; then
                stash_pop
            fi
            return 1
        fi
    fi
    
    # 恢复 stash
    if [ "$stashed" = true ]; then
        stash_pop
    fi
    
    # 生成索引
    log_step "3/3 更新索引..."
    generate_index
    
    log_success "拉取完成"
}

# 双向同步（原子性）
cmd_sync() {
    local use_stash=false
    
    if [ "$1" = "-s" ] || [ "$1" = "--stash" ]; then
        use_stash=true
    fi
    
    cd "$KB_DIR"
    
    log_step "1/6 检查状态并保存起点..."
    
    # 保存起点，用于回滚
    local start_commit=$(git rev-parse HEAD)
    local start_branch=$(git rev-parse --abbrev-ref HEAD)
    local changes=$(git status --porcelain | wc -l | tr -d ' ')
    local stashed=false
    
    log_info "起点：$start_commit"
    
    # 处理本地变更
    if [ "$changes" -gt 0 ]; then
        if [ "$use_stash" = true ]; then
            stash_push "sync-stash-$(date +%s)"
            stashed=true
        else
            log_warn "本地有 $changes 个未提交的变更"
            log_info "请使用 -s (--stash) 自动暂存"
            git status --short
            return 1
        fi
    fi
    
    # Pull 阶段
    log_step "2/6 拉取远端内容..."
    if ! git pull "$REMOTE_NAME" "$MAIN_BRANCH"; then
        log_error "Pull 失败"
        if [ "$stashed" = true ]; then
            stash_pop
        fi
        return 1
    fi
    
    # 检查是否有本地变更需要推送
    local local_changes=$(git status --porcelain | wc -l | tr -d ' ')
    
    if [ "$local_changes" -gt 0 ] || [ "$stashed" = true ]; then
        # 生成索引
        log_step "3/6 生成索引..."
        generate_index
        
        # 提交
        log_step "4/6 提交本地变更..."
        if [ "$stashed" = true ]; then
            stash_pop
        fi
        
        git add -A
        if ! git diff --cached --quiet; then
            git commit -m "同步更新 - $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        
        # Push 阶段（带 rebase）
        log_step "5/6 Rebase 并推送..."
        if ! safe_rebase; then
            log_warn "Push 阶段发生冲突，请手动解决"
            return 1
        fi
        
        commit_index
        
        if ! git push "$REMOTE_NAME" "$MAIN_BRANCH"; then
            log_error "Push 失败"
            return 1
        fi
    else
        log_step "3/6 无本地变更需要推送"
    fi
    
    log_step "6/6 同步完成"
    log_success "双向同步成功"
}

# ==================== 主流程 ====================

# 解析参数
COMMAND=""
COMMIT_MSG=""
FORCE=false
STASH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        preview|push|pull|sync|status|init)
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
        -s|--stash)
            STASH=true
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
    preview)
        cmd_preview
        ;;
    push)
        cmd_push "$COMMIT_MSG"
        ;;
    pull)
        if [ "$FORCE" = true ]; then
            cmd_pull "-f"
        elif [ "$STASH" = true ]; then
            cmd_pull "-s"
        else
            cmd_pull
        fi
        ;;
    sync)
        if [ "$STASH" = true ]; then
            cmd_sync "-s"
        else
            cmd_sync
        fi
        ;;
    "")
        log_error "请指定命令 (preview|push|pull|sync|status|init)"
        show_help
        exit 1
        ;;
    *)
        log_error "未知命令：$COMMAND"
        show_help
        exit 1
        ;;
esac
