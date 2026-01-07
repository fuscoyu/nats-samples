#!/bin/bash

# 场景1验证脚本 - 基本功能验证

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OUTPUT_FILE="./scenario1_results.txt"

echo "========================================" > "$OUTPUT_FILE"
echo "场景1: 基本功能验证结果" >> "$OUTPUT_FILE"
echo "测试时间: $(date)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo -e "${GREEN}=== 场景1: 基本功能验证 ===${NC}"

echo "" >> "$OUTPUT_FILE"
echo "1. 检查 Zone qa1a Source Stream (qa)" >> "$OUTPUT_FILE"
echo "-----------------------------------" >> "$OUTPUT_FILE"
curl -s "http://localhost:16222/jsz?streams=qa&config=1&state=1" | python3 -m json.tool 2>/dev/null >> "$OUTPUT_FILE" || echo "无法获取详细信息" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "2. 检查 Zone qa1b Source Stream (qa)" >> "$OUTPUT_FILE"
echo "-----------------------------------" >> "$OUTPUT_FILE"
curl -s "http://localhost:16232/jsz?streams=qa&config=1&state=1" | python3 -m json.tool 2>/dev/null >> "$OUTPUT_FILE" || echo "无法获取详细信息" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "3. 检查 Zone qa1a Mirror Stream (qa_mirror_qa1b)" >> "$OUTPUT_FILE"
echo "-----------------------------------" >> "$OUTPUT_FILE"
curl -s "http://localhost:16222/jsz?streams=qa_mirror_qa1b&config=1&state=1" | python3 -m json.tool 2>/dev/null >> "$OUTPUT_FILE" || echo "无法获取详细信息" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "4. 检查 Zone qa1b Mirror Stream (qa_mirror_qa1a)" >> "$OUTPUT_FILE"
echo "-----------------------------------" >> "$OUTPUT_FILE"
curl -s "http://localhost:16232/jsz?streams=qa_mirror_qa1a&config=1&state=1" | python3 -m json.tool 2>/dev/null >> "$OUTPUT_FILE" || echo "无法获取详细信息" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "=== 测试总结 ===" >> "$OUTPUT_FILE"
echo "Producer-qa1a: 已发送 30 条消息 (1-30)" >> "$OUTPUT_FILE"
echo "Producer-qa1b: 已发送 30 条消息 (1-30)" >> "$OUTPUT_FILE"
echo "预期: Zone qa1a Source Stream 应有 30 条消息" >> "$OUTPUT_FILE"
echo "预期: Zone qa1b Source Stream 应有 30 条消息" >> "$OUTPUT_FILE"
echo "预期: Mirror Stream 应同步对方 Source Stream 的消息" >> "$OUTPUT_FILE"

echo -e "${GREEN}场景1验证完成，结果已保存到 $OUTPUT_FILE${NC}"
cat "$OUTPUT_FILE"