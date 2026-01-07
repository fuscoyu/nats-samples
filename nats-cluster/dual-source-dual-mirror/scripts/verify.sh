#!/bin/bash

# 双Source双Mirror验证方案 - 验证脚本
# 验证消息完整性：不丢、不重、能补，以及Mirror同步正确性

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认日志文件
CONSUMER_QA1A_LOG="${CONSUMER_QA1A_LOG:-./consumer-qa1a.log}"
CONSUMER_QA1A_MIRROR_LOG="${CONSUMER_QA1A_MIRROR_LOG:-./consumer-qa1a-mirror.log}"
CONSUMER_QA1B_LOG="${CONSUMER_QA1B_LOG:-./consumer-qa1b.log}"
CONSUMER_QA1B_MIRROR_LOG="${CONSUMER_QA1B_MIRROR_LOG:-./consumer-qa1b-mirror.log}"

# 临时文件
TEMP_DIR=$(mktemp -d)
CONSUMER_QA1A_SEQS="$TEMP_DIR/consumer-qa1a-seqs.txt"
CONSUMER_QA1A_MIRROR_SEQS="$TEMP_DIR/consumer-qa1a-mirror-seqs.txt"
CONSUMER_QA1B_SEQS="$TEMP_DIR/consumer-qa1b-seqs.txt"
CONSUMER_QA1B_MIRROR_SEQS="$TEMP_DIR/consumer-qa1b-mirror-seqs.txt"

# 清理函数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 函数：从日志中提取消息序号和zone信息
extract_seqs() {
    local log_file=$1
    local output_file=$2
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}错误: 日志文件 $log_file 不存在${NC}"
        return 1
    fi
    
    # 提取 JSON 中的 seq 字段和 zone 字段
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

# 函数：验证Mirror同步正确性
verify_mirror_sync() {
    echo -e "${YELLOW}=== 验证 Mirror Stream 同步正确性 ===${NC}"
    
    # Consumer-qa1a-mirror 应该消费到 Producer-qa1b 的消息
    # Consumer-qa1b-mirror 应该消费到 Producer-qa1a 的消息
    
    local qa1a_mirror_count=$(wc -l < "$CONSUMER_QA1A_MIRROR_SEQS" 2>/dev/null || echo "0")
    local qa1b_count=$(wc -l < "$CONSUMER_QA1B_SEQS" 2>/dev/null || echo "0")
    local qa1b_mirror_count=$(wc -l < "$CONSUMER_QA1B_MIRROR_SEQS" 2>/dev/null || echo "0")
    local qa1a_count=$(wc -l < "$CONSUMER_QA1A_SEQS" 2>/dev/null || echo "0")
    
    echo -e "Consumer-qa1a (Source): $qa1a_count 条消息"
    echo -e "Consumer-qa1a-mirror (Mirror from qa1b): $qa1a_mirror_count 条消息"
    echo -e "Consumer-qa1b (Source): $qa1b_count 条消息"
    echo -e "Consumer-qa1b-mirror (Mirror from qa1a): $qa1b_mirror_count 条消息"
    
    # 验证 Mirror Stream 同步了对方的 Source Stream
    if [ "$qa1a_mirror_count" -eq "$qa1b_count" ] && [ "$qa1b_mirror_count" -eq "$qa1a_count" ]; then
        echo -e "${GREEN}✓ Mirror Stream 同步正确：${NC}"
        echo -e "  - Zone qa1a 的 Mirror 正确同步了 Zone qa1b 的 Source ($qa1a_mirror_count = $qa1b_count)"
        echo -e "  - Zone qa1b 的 Mirror 正确同步了 Zone qa1a 的 Source ($qa1b_mirror_count = $qa1a_count)"
        return 0
    else
        echo -e "${RED}✗ Mirror Stream 同步不正确：${NC}"
        [ "$qa1a_mirror_count" -ne "$qa1b_count" ] && echo -e "  - Zone qa1a 的 Mirror 消息数 ($qa1a_mirror_count) 不等于 Zone qa1b 的 Source ($qa1b_count)"
        [ "$qa1b_mirror_count" -ne "$qa1a_count" ] && echo -e "  - Zone qa1b 的 Mirror 消息数 ($qa1b_mirror_count) 不等于 Zone qa1a 的 Source ($qa1a_count)"
        return 1
    fi
}

# 函数：比较消息内容
compare_messages() {
    echo -e "${YELLOW}=== 比较消息内容 ===${NC}"
    
    # 比较 Consumer-qa1a 和 Consumer-qa1b-mirror 的消息（应该相同）
    comm -12 "$CONSUMER_QA1A_SEQS" "$CONSUMER_QA1B_MIRROR_SEQS" > "$TEMP_DIR/common-qa1a.txt" || true
    local common_qa1a=$(wc -l < "$TEMP_DIR/common-qa1a.txt")
    
    # 比较 Consumer-qa1b 和 Consumer-qa1a-mirror 的消息（应该相同）
    comm -12 "$CONSUMER_QA1B_SEQS" "$CONSUMER_QA1A_MIRROR_SEQS" > "$TEMP_DIR/common-qa1b.txt" || true
    local common_qa1b=$(wc -l < "$TEMP_DIR/common-qa1b.txt")
    
    echo -e "Consumer-qa1a 和 Consumer-qa1b-mirror 共同消息: $common_qa1a 条"
    echo -e "Consumer-qa1b 和 Consumer-qa1a-mirror 共同消息: $common_qa1b 条"
    
    if [ "$common_qa1a" -gt 0 ] && [ "$common_qa1b" -gt 0 ]; then
        echo -e "${GREEN}✓ Mirror Stream 正确同步了对方的 Source Stream${NC}"
        return 0
    else
        echo -e "${RED}✗ Mirror Stream 同步验证失败${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${GREEN}=== 双Source双Mirror验证方案 - 消息完整性验证 ===${NC}"
    echo ""
    
    # 提取消息序号
    echo -e "${YELLOW}提取消息序号...${NC}"
    extract_seqs "$CONSUMER_QA1A_LOG" "$CONSUMER_QA1A_SEQS" || true
    extract_seqs "$CONSUMER_QA1A_MIRROR_LOG" "$CONSUMER_QA1A_MIRROR_SEQS" || true
    extract_seqs "$CONSUMER_QA1B_LOG" "$CONSUMER_QA1B_SEQS" || true
    extract_seqs "$CONSUMER_QA1B_MIRROR_LOG" "$CONSUMER_QA1B_MIRROR_SEQS" || true
    echo ""
    
    # 检查各个Consumer的消息完整性
    local result_qa1a=0
    local result_qa1a_mirror=0
    local result_qa1b=0
    local result_qa1b_mirror=0
    
    if [ -s "$CONSUMER_QA1A_SEQS" ]; then
        check_integrity "$CONSUMER_QA1A_SEQS" "Consumer-qa1a"
        result_qa1a=$?
        echo ""
    fi
    
    if [ -s "$CONSUMER_QA1A_MIRROR_SEQS" ]; then
        check_integrity "$CONSUMER_QA1A_MIRROR_SEQS" "Consumer-qa1a-mirror"
        result_qa1a_mirror=$?
        echo ""
    fi
    
    if [ -s "$CONSUMER_QA1B_SEQS" ]; then
        check_integrity "$CONSUMER_QA1B_SEQS" "Consumer-qa1b"
        result_qa1b=$?
        echo ""
    fi
    
    if [ -s "$CONSUMER_QA1B_MIRROR_SEQS" ]; then
        check_integrity "$CONSUMER_QA1B_MIRROR_SEQS" "Consumer-qa1b-mirror"
        result_qa1b_mirror=$?
        echo ""
    fi
    
    # 验证Mirror同步正确性
    verify_mirror_sync
    local result_mirror=$?
    echo ""
    
    # 比较消息内容
    compare_messages
    local result_compare=$?
    echo ""
    
    # 总结
    echo -e "${GREEN}=== 验证总结 ===${NC}"
    local all_passed=0
    if [ $result_qa1a -eq 0 ] && [ $result_qa1a_mirror -eq 0 ] && [ $result_qa1b -eq 0 ] && [ $result_qa1b_mirror -eq 0 ] && [ $result_mirror -eq 0 ] && [ $result_compare -eq 0 ]; then
        echo -e "${GREEN}✓ 所有验证通过：消息不丢、不重、能补，Mirror同步正确${NC}"
        exit 0
    else
        echo -e "${RED}✗ 验证失败：存在消息丢失、重复或Mirror同步不正确${NC}"
        exit 1
    fi
}

main "$@"

