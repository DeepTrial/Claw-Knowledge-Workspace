#!/bin/bash
# generate-index.sh
# 扫描知识库文件，自动生成索引文件

set -e

KB_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$KB_DIR"

echo "[INFO] 开始生成索引..."
echo "[INFO] 知识库路径：$KB_DIR"

# 生成 TOPICS 索引
generate_topics_index() {
    local count=0
    local tmpfile=$(mktemp)
    
    echo "# TOPICS 索引" > "$tmpfile"
    echo "" >> "$tmpfile"
    echo "> 自动生成于：$(date '+%Y-%m-%d %H:%M:%S')" >> "$tmpfile"
    echo ""
    echo "---" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ -d "TOPICS" ]; then
        for file in TOPICS/*.md; do
            [ -f "$file" ] || continue
            count=$((count + 1))
        done
    fi
    
    echo "> 文件总数：$count" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ "$count" -eq 0 ]; then
        echo "暂无内容" >> "$tmpfile"
    else
        echo "| 文件名 | 标题 | 贡献者 | 更新时间 | 标签 |" >> "$tmpfile"
        echo "|--------|------|--------|----------|------|" >> "$tmpfile"
        
        for file in TOPICS/*.md; do
            [ -f "$file" ] || continue
            filename=$(basename "$file")
            
            # 尝试从 YAML front matter 提取元数据
            title=""
            contributor=""
            updated=""
            tags=""
            
            if head -1 "$file" 2>/dev/null | grep -q "^---"; then
                title=$(grep "^title:" "$file" 2>/dev/null | head -1 | sed 's/^title:[ ]*//' | tr -d '"' || echo "")
                contributor=$(grep "^contributor:" "$file" 2>/dev/null | head -1 | sed 's/^contributor:[ ]*//' | tr -d '"' || echo "")
                updated=$(grep "^updated:" "$file" 2>/dev/null | head -1 | sed 's/^updated:[ ]*//' | tr -d '"' || echo "")
                tags=$(grep "^tags:" "$file" 2>/dev/null | head -1 | sed 's/^tags:[ ]*//' | tr -d '[]"' || echo "")
            fi
            
            [ -z "$title" ] && title=$(basename "$file" .md | tr '_' ' ')
            [ -z "$contributor" ] && contributor="-"
            [ -z "$updated" ] && updated="-"
            [ -z "$tags" ] && tags="-"
            
            echo "| $filename | $title | $contributor | $updated | $tags |" >> "$tmpfile"
        done
    fi
    
    echo "" >> "$tmpfile"
    mv "$tmpfile" "INDEX_TOPICS.md"
    echo "[INFO] 生成 INDEX_TOPICS.md ($count 个文件)"
}

# 生成 SKILLS 索引
generate_skills_index() {
    local count=0
    local tmpfile=$(mktemp)
    
    echo "# SKILLS 索引" > "$tmpfile"
    echo "" >> "$tmpfile"
    echo "> 自动生成于：$(date '+%Y-%m-%d %H:%M:%S')" >> "$tmpfile"
    echo "" >> "$tmpfile"
    echo "---" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ -d "SKILLS" ]; then
        for file in SKILLS/*.md; do
            [ -f "$file" ] || continue
            count=$((count + 1))
        done
    fi
    
    echo "> 文件总数：$count" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ "$count" -eq 0 ]; then
        echo "暂无内容" >> "$tmpfile"
    else
        echo "| 文件名 | 标题 | 贡献者 | 更新时间 | 标签 |" >> "$tmpfile"
        echo "|--------|------|--------|----------|------|" >> "$tmpfile"
        
        for file in SKILLS/*.md; do
            [ -f "$file" ] || continue
            filename=$(basename "$file")
            
            title=""
            contributor=""
            updated=""
            tags=""
            
            if head -1 "$file" 2>/dev/null | grep -q "^---"; then
                title=$(grep "^title:" "$file" 2>/dev/null | head -1 | sed 's/^title:[ ]*//' | tr -d '"' || echo "")
                contributor=$(grep "^contributor:" "$file" 2>/dev/null | head -1 | sed 's/^contributor:[ ]*//' | tr -d '"' || echo "")
                updated=$(grep "^updated:" "$file" 2>/dev/null | head -1 | sed 's/^updated:[ ]*//' | tr -d '"' || echo "")
                tags=$(grep "^tags:" "$file" 2>/dev/null | head -1 | sed 's/^tags:[ ]*//' | tr -d '[]"' || echo "")
            fi
            
            [ -z "$title" ] && title=$(basename "$file" .md | tr '_' ' ')
            [ -z "$contributor" ] && contributor="-"
            [ -z "$updated" ] && updated="-"
            [ -z "$tags" ] && tags="-"
            
            echo "| 文件名 | 标题 | 贡献者 | 更新时间 | 标签 |" >> "$tmpfile"
        done
    fi
    
    echo "" >> "$tmpfile"
    mv "$tmpfile" "INDEX_SKILLS.md"
    echo "[INFO] 生成 INDEX_SKILLS.md ($count 个文件)"
}

# 生成 BEST_PRACTICES 索引
generate_bp_index() {
    local count=0
    local tmpfile=$(mktemp)
    
    echo "# 最佳实践 索引" > "$tmpfile"
    echo "" >> "$tmpfile"
    echo "> 自动生成于：$(date '+%Y-%m-%d %H:%M:%S')" >> "$tmpfile"
    echo "" >> "$tmpfile"
    echo "---" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ -d "BEST_PRACTICES" ]; then
        for file in BEST_PRACTICES/*.md; do
            [ -f "$file" ] || continue
            count=$((count + 1))
        done
    fi
    
    echo "> 文件总数：$count" >> "$tmpfile"
    echo "" >> "$tmpfile"
    
    if [ "$count" -eq 0 ]; then
        echo "暂无内容" >> "$tmpfile"
    else
        echo "| 文件名 | 标题 | 贡献者 | 更新时间 | 标签 |" >> "$tmpfile"
        echo "|--------|------|--------|----------|------|" >> "$tmpfile"
        
        for file in BEST_PRACTICES/*.md; do
            [ -f "$file" ] || continue
            filename=$(basename "$file")
            
            title=""
            contributor=""
            updated=""
            tags=""
            
            if head -1 "$file" 2>/dev/null | grep -q "^---"; then
                title=$(grep "^title:" "$file" 2>/dev/null | head -1 | sed 's/^title:[ ]*//' | tr -d '"' || echo "")
                contributor=$(grep "^contributor:" "$file" 2>/dev/null | head -1 | sed 's/^contributor:[ ]*//' | tr -d '"' || echo "")
                updated=$(grep "^updated:" "$file" 2>/dev/null | head -1 | sed 's/^updated:[ ]*//' | tr -d '"' || echo "")
                tags=$(grep "^tags:" "$file" 2>/dev/null | head -1 | sed 's/^tags:[ ]*//' | tr -d '[]"' || echo "")
            fi
            
            [ -z "$title" ] && title=$(basename "$file" .md | tr '_' ' ')
            [ -z "$contributor" ] && contributor="-"
            [ -z "$updated" ] && updated="-"
            [ -z "$tags" ] && tags="-"
            
            echo "| 文件名 | 标题 | 贡献者 | 更新时间 | 标签 |" >> "$tmpfile"
        done
    fi
    
    echo "" >> "$tmpfile"
    mv "$tmpfile" "INDEX_BP.md"
    echo "[INFO] 生成 INDEX_BP.md ($count 个文件)"
}

# 更新 INDEX.md 统计
update_main_index() {
    if [ -f "INDEX.md" ]; then
        topics_count=$(find TOPICS -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        skills_count=$(find SKILLS -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        bp_count=$(find BEST_PRACTICES -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        today=$(date '+%Y-%m-%d')
        
        sed -i '' "s/\*\*课题总数\*\*:.*/\*\*课题总数\*\*: $topics_count/" INDEX.md
        sed -i '' "s/\*\*技能总数\*\*:.*/\*\*技能总数\*\*: $skills_count/" INDEX.md
        sed -i '' "s/\*\*最佳实践\*\*:.*/\*\*最佳实践\*\*: $bp_count/" INDEX.md
        sed -i '' "s/\*\*最后更新\*\*:.*/\*\*最后更新\*\*: $today/" INDEX.md
        
        echo "[INFO] 更新 INDEX.md 统计信息"
    fi
}

# 主流程
generate_topics_index
generate_skills_index
generate_bp_index
update_main_index

echo "[SUCCESS] 索引生成完成"
