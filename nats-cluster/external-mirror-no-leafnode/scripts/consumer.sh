#!/bin/bash

# 从 qa1b 的 Mirror Stream 消费消息

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MIRROR_STREAM="qa_mirror_qa1a"

echo -e "${GREEN}从 qa1b 的 Mirror Stream 消费消息${NC}"

# 检查容器
if ! docker ps --filter "name=js1-qa1b" --filter "status=running" | grep -q js1-qa1b; then
    echo -e "${RED}错误: qa1b 未运行${NC}"
    exit 1
fi

echo -e "${YELLOW}Stream 信息:${NC}"
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info "$MIRROR_STREAM" 2>/dev/null || echo "获取信息失败"

echo ""
echo -e "${YELLOW}消费消息 (按 Ctrl+C 退出):${NC}"
echo "----------------------------------------"

# 消费消息
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 \
    consume "$MIRROR_STREAM" --subject "events.qa.qa1a.>" --last 100 --force
