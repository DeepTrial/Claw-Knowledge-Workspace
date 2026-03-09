#!/bin/bash
# 知识库同步前比较和更新脚本（使用描述性文件名）
# 避免产生冗余topic内容和模糊文件名（dayxxx/chxxx）

set -e

KNOWLEDGE_BASE="/root/.openclaw/workspace/KNOWLEDGE_BASE"
LOCAL_TOPICS="/root/.openclaw/workspace/references"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} 开始比较本地知识与Knowledge Base..."
echo -e "${YELLOW}[RULE]${NC} 文件名规范: 使用描述性名称，禁止dayxxx/chxxx等模糊命名"

cd "$KNOWLEDGE_BASE"

# 1. 先拉取最新内容，确保比较的是最新状态
echo -e "${BLUE}[STEP]${NC} 拉取远端最新内容..."
./sync-knowledge.sh pull -s

# 2. 检查现有topic文件名是否符合规范
echo -e "${BLUE}[STEP]${NC} 检查现有topic文件名规范..."

INVALID_NAMES=$(ls TOPICS/*.md 2>/dev/null | grep -E "(day[0-9]+|ch[0-9]+|chapter[0-9]+)" || true)
if [ -n "$INVALID_NAMES" ]; then
    echo -e "${RED}[WARNING]${NC} 发现不符合规范的文件名:"
    echo "$INVALID_NAMES" | while read file; do
        echo -e "  ${RED}✗${NC} $(basename $file)"
    done
    echo -e "${YELLOW}[SUGGEST]${NC} 请使用描述性文件名，例如:"
    echo -e "  ${GREEN}✓${NC} topic-cuda-memory-optimization.md"
    echo -e "  ${GREEN}✓${NC} topic-llvm-pass-framework.md"
    echo -e "  ${GREEN}✓${NC} topic-triton-mlir-dialect.md"
else
    echo -e "  ${GREEN}✓${NC} 所有文件名符合规范"
fi

# 3. 扫描本地topic文件
echo -e "${BLUE}[STEP]${NC} 扫描本地学习笔记..."

# 获取已存在的topic名称列表（按主题内容，不是文件名）
EXISTING_TOPICS=$(grep -r "^title:" TOPICS/ 2>/dev/null | sed 's/.*title: //' | sort -u)

# 4. 检查本地学习目录的新内容（检查内容是否已存在，不依赖文件名）
echo -e "${BLUE}[STEP]${NC} 检查本地学习目录（内容比较）..."

# 检查CUDA笔记
if [ -d "$LOCAL_TOPICS/cuda-guide/topics" ]; then
    echo -e "  ${BLUE}[CUDA]${NC} 发现CUDA学习笔记"
    # 扫描chXX文件
    for file in "$LOCAL_TOPICS/cuda-guide/topics"/ch*.md; do
        if [ -f "$file" ]; then
            # 提取内容主题
            content_preview=$(head -20 "$file" | grep -E "^(#{1,2} |title:)" | head -3 | tr '\n' ' ')
            # 检查是否已存在相似内容（简单检查）
            if echo "$EXISTING_TOPICS" | grep -qi "cuda"; then
                echo -e "    ${YELLOW}[SKIP]${NC} CUDA相关内容已存在"
                break
            fi
        fi
    done
fi

# 检查LLVM笔记
if [ -d "$LOCAL_TOPICS/llvm-compiler" ]; then
    echo -e "  ${BLUE}[LLVM]${NC} 发现LLVM学习笔记"
    # 检查dayXX和triton-dayXX文件
    for file in "$LOCAL_TOPICS/llvm-compiler"/*.md; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .md)
            # 跳过非day文件
            if [[ "$filename" =~ ^(day|triton-day)[0-9]+ ]]; then
                # 提取主题
                title_line=$(grep -m1 "^title:" "$file" 2>/dev/null | sed 's/title: //' || echo "")
                if [ -n "$title_line" ]; then
                    # 检查是否已存在
                    if echo "$EXISTING_TOPICS" | grep -qiF "$title_line"; then
                        echo -e "    ${YELLOW}[SKIP]${NC} '$title_line' 已存在"
                    else
                        echo -e "    ${GREEN}[NEW]${NC} '$title_line' 待创建（需要转换为描述性文件名）"
                    fi
                fi
            fi
        fi
    done
fi

# 5. 提示转换脚本
echo ""
echo -e "${YELLOW}[NOTE]${NC} 如需将本地笔记转换为知识库topic（使用规范文件名）:"
echo -e "  cd $KNOWLEDGE_BASE"
echo -e "  ${GREEN}./scripts/convert-with-proper-names.sh${NC}"
echo ""
echo -e "${YELLOW}[NOTE]${NC} 自动同步时不会自动创建新topic或修改文件名"
echo -e "${YELLOW}[NOTE]${NC} 请手动运行转换脚本，确保使用描述性文件名"

# 6. 执行标准同步
echo ""
echo -e "${BLUE}[STEP]${NC} 执行标准同步..."
./sync-knowledge.sh sync -s

echo -e "${GREEN}[SUCCESS]${NC} 同步完成"
