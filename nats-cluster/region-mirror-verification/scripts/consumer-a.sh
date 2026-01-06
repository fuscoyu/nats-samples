#!/bin/bash

# Region Mirror/Source 验证方案 - Consumer-A 脚本
# 从 Zone A 消费消息并记录

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone A 连接地址（无认证）
ZONE_A_SERVERS="nats://localhost:15222,nats://localhost:15223,nats://localhost:15224"

# Stream 和 Consumer
STREAM_NAME="EVENTS.REGION"
CONSUMER_NAME="consumer-a"

# 输出文件
OUTPUT_FILE="${OUTPUT_FILE:-./consumer-a.log}"

echo -e "${GREEN}=== Region Mirror/Source 验证方案 - Consumer-A ===${NC}"
echo -e "Stream: ${STREAM_NAME}"
echo -e "Consumer: ${CONSUMER_NAME}"
echo -e "输出文件: ${OUTPUT_FILE}"
echo ""

# 检查 NATS CLI 是否可用
if ! command -v nats &> /dev/null; then
    echo -e "${RED}错误: nats CLI 未安装。请安装 nats CLI 工具。${NC}"
    exit 1
fi

# 检查 Zone A 连接
if ! nats --server "$ZONE_A_SERVERS" server ping &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Zone A。请确保 Zone A 已启动。${NC}"
    exit 1
fi

# 创建 Consumer（如果不存在）
echo -e "${YELLOW}创建 Consumer: ${CONSUMER_NAME}...${NC}"
nats --server "$ZONE_A_SERVERS" consumer add "$STREAM_NAME" "$CONSUMER_NAME" \
    --deliver all \
    --ack explicit \
    --replay instant \
    --filter "" \
    --max-deliver -1 \
    --sample 100 \
    --rate-limit=-1 \
    --heartbeat=-1 \
    --flow-control \
    --yes 2>/dev/null || echo "Consumer 已存在，继续使用..."

# 清空输出文件
> "$OUTPUT_FILE"

echo -e "${GREEN}开始消费消息...${NC}"
echo -e "${YELLOW}按 Ctrl+C 停止消费${NC}"
echo ""

# 消费消息
nats --server "$ZONE_A_SERVERS" consumer next "$STREAM_NAME" "$CONSUMER_NAME" \
    --count=-1 \
    --raw 2>&1 | while IFS= read -r line; do
    if [ -n "$line" ]; then
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$timestamp] $line" | tee -a "$OUTPUT_FILE"
    fi
done

