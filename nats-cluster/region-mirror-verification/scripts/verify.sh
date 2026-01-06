#!/bin/bash

# Region Mirror/Source 验证方案 - 验证脚本
# 验证消息完整性：不丢、不重、能补

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认日志文件
CONSUMER_A_LOG="${CONSUMER_A_LOG:-./consumer-a.log}"
CONSUMER_B_LOG="${CONSUMER_B_LOG:-./consumer-b.log}"

# 临时文件
TEMP_DIR=$(mktemp -d)
CONSUMER_A_SEQS="$TEMP_DIR/consumer-a-seqs.txt"
CONSUMER_B_SEQS="$TEMP_DIR/consumer-b-seqs.txt"

# 清理函数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 函数：从日志中提取消息序号
extract_seqs() {
    local log_file=$1
    local output_file=$2
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}错误: 日志文件 $log_file 不存在${NC}"
        return 1
    fi
    
    # 提取 JSON 中的 seq 字段
    grep -o '"seq":[0-9]*' "$log_file" | sed 's/"seq"://' | sort -n > "$output_file"
}

# 函数：检查消息完整性
check_integrity() {
    local seq_file=$1
    local consumer_name=$2
    
    echo -e "${YELLOW}=== 检查 $consumer_name 消息完整性 ===${NC}"
    
    if [ ! -s "$seq_file" ]; then
        echo -e "${RED}错误: $consumer_name 没有消费到任何消息${NC}"
        return 1
    fi
    
    local total=$(wc -l < "$seq_file")
    local min=$(head -n 1 "$seq_file")
    local max=$(tail -n 1 "$seq_file")
    local expected=$((max - min + 1))
    
    echo -e "消息范围: $min - $max"
    echo -e "实际消费: $total 条"
    echo -e "期望消费: $expected 条"
    
    # 检查是否有丢失
    local missing=0
    local duplicates=0
    
    # 检查丢失和重复
    local prev=0
    while IFS= read -r seq; do
        if [ "$prev" -gt 0 ]; then
            local diff=$((seq - prev))
            if [ "$diff" -gt 1 ]; then
                missing=$((missing + diff - 1))
                echo -e "${RED}  丢失消息: $((prev + 1)) - $((seq - 1))${NC}"
            elif [ "$diff" -eq 0 ]; then
                duplicates=$((duplicates + 1))
                echo -e "${RED}  重复消息: $seq${NC}"
            fi
        fi
        prev=$seq
    done < "$seq_file"
    
    # 检查第一个消息
    if [ "$min" -gt 1 ]; then
        missing=$((missing + min - 1))
        echo -e "${RED}  丢失消息: 1 - $((min - 1))${NC}"
    fi
    
    # 输出结果
    if [ "$missing" -eq 0 ] && [ "$duplicates" -eq 0 ] && [ "$total" -eq "$expected" ]; then
        echo -e "${GREEN}✓ 消息完整性检查通过：不丢、不重${NC}"
        return 0
    else
        echo -e "${RED}✗ 消息完整性检查失败：${NC}"
        [ "$missing" -gt 0 ] && echo -e "  - 丢失消息: $missing 条"
        [ "$duplicates" -gt 0 ] && echo -e "  - 重复消息: $duplicates 条"
        [ "$total" -ne "$expected" ] && echo -e "  - 消息数量不匹配"
        return 1
    fi
}

# 函数：比较两个消费者的消息
compare_consumers() {
    echo -e "${YELLOW}=== 比较 Consumer-A 和 Consumer-B 的消息 ===${NC}"
    
    # 找出共同的消息序号
    comm -12 "$CONSUMER_A_SEQS" "$CONSUMER_B_SEQS" > "$TEMP_DIR/common-seqs.txt" || true
    local common=$(wc -l < "$TEMP_DIR/common-seqs.txt")
    
    # 找出只在 Consumer-A 的消息
    comm -23 "$CONSUMER_A_SEQS" "$CONSUMER_B_SEQS" > "$TEMP_DIR/only-a-seqs.txt" || true
    local only_a=$(wc -l < "$TEMP_DIR/only-a-seqs.txt")
    
    # 找出只在 Consumer-B 的消息
    comm -13 "$CONSUMER_A_SEQS" "$CONSUMER_B_SEQS" > "$TEMP_DIR/only-b-seqs.txt" || true
    local only_b=$(wc -l < "$TEMP_DIR/only-b-seqs.txt")
    
    echo -e "共同消息: $common 条"
    echo -e "仅 Consumer-A: $only_a 条"
    echo -e "仅 Consumer-B: $only_b 条"
    
    if [ "$only_a" -gt 0 ]; then
        echo -e "${YELLOW}Consumer-A 独有的消息（前10条）:${NC}"
        head -n 10 "$TEMP_DIR/only-a-seqs.txt" | sed 's/^/  /'
    fi
    
    if [ "$only_b" -gt 0 ]; then
        echo -e "${YELLOW}Consumer-B 独有的消息（前10条）:${NC}"
        head -n 10 "$TEMP_DIR/only-b-seqs.txt" | sed 's/^/  /'
    fi
}

# 主函数
main() {
    echo -e "${GREEN}=== Region Mirror/Source 验证方案 - 消息完整性验证 ===${NC}"
    echo ""
    
    # 提取消息序号
    echo -e "${YELLOW}提取消息序号...${NC}"
    extract_seqs "$CONSUMER_A_LOG" "$CONSUMER_A_SEQS"
    extract_seqs "$CONSUMER_B_LOG" "$CONSUMER_B_SEQS"
    echo ""
    
    # 检查 Consumer-A
    check_integrity "$CONSUMER_A_SEQS" "Consumer-A"
    local result_a=$?
    echo ""
    
    # 检查 Consumer-B
    check_integrity "$CONSUMER_B_SEQS" "Consumer-B"
    local result_b=$?
    echo ""
    
    # 比较两个消费者
    compare_consumers
    echo ""
    
    # 总结
    echo -e "${GREEN}=== 验证总结 ===${NC}"
    if [ $result_a -eq 0 ] && [ $result_b -eq 0 ]; then
        echo -e "${GREEN}✓ 所有验证通过：消息不丢、不重、能补${NC}"
        exit 0
    else
        echo -e "${RED}✗ 验证失败：存在消息丢失或重复${NC}"
        exit 1
    fi
}

main "$@"

