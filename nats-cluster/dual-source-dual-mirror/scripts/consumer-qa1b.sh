#!/bin/bash

# 双Source双Mirror验证方案 - Consumer qa1b 脚本
# 从 Zone qa1b 消费自己的 Source Stream

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone qa1b 连接地址（带认证）
ZONE_QA1B_SERVERS="nats://app:app@js1-qa1b:4222,nats://app:app@js2-qa1b:4222,nats://app:app@js3-qa1b:4222"

# 使用 nats-box 容器运行 NATS CLI
NATS_CMD="docker exec -i nats-box-qa1b nats"

# Stream 和 Consumer
STREAM_NAME="qa"
CONSUMER_NAME="consumer-qa1b"

# 输出文件
OUTPUT_FILE="${OUTPUT_FILE:-./consumer-qa1b.log}"

echo -e "${GREEN}=== 双Source双Mirror验证方案 - Consumer qa1b ===${NC}"
echo -e "Stream: ${STREAM_NAME} (Source)"
echo -e "Consumer: ${CONSUMER_NAME}"
echo -e "输出文件: ${OUTPUT_FILE}"
echo ""

# 检查 NATS CLI 是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装。请安装 Docker。${NC}"
    # 继续尝试
fi

# 检查 Zone qa1b 连接
if ! docker exec nats-box-qa1b nats --server "$ZONE_QA1B_SERVERS" stream ls &> /dev/null; then
    echo -e "${YELLOW}警告: 无法连接到 Zone qa1b，但继续尝试消费...${NC}"
fi

# 创建 Consumer（如果不存在）
echo -e "${YELLOW}创建 Consumer: ${CONSUMER_NAME}...${NC}"
$NATS_CMD --server "$ZONE_QA1B_SERVERS" consumer add "$STREAM_NAME" "$CONSUMER_NAME" \
    --deliver all \
    --ack explicit \
    --replay instant \
    --filter "" \
    --max-deliver -1 \
    --sample 100 \
    --rate-limit=-1 \
    --heartbeat=-1 \
    --flow-control \
    --defaults 2>/dev/null || echo "Consumer 已存在，继续使用..."

# 清空输出文件
> "$OUTPUT_FILE"

echo -e "${GREEN}开始消费消息...${NC}"
echo -e "${YELLOW}按 Ctrl+C 停止消费${NC}"
echo ""

# 消费消息
$NATS_CMD --server "$ZONE_QA1B_SERVERS" consumer next "$STREAM_NAME" "$CONSUMER_NAME" \
    --count=-1 \
    --raw 2>&1 | while IFS= read -r line; do
    if [ -n "$line" ]; then
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$timestamp] $line" | tee -a "$OUTPUT_FILE"
    fi
done

