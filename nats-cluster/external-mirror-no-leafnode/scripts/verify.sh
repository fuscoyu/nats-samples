#!/bin/bash

# 验证 Mirror 同步状态

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SOURCE_STREAM="qa"
MIRROR_STREAM="qa_mirror_qa1a"

echo -e "${GREEN}=== 验证 Mirror 同步状态 ===${NC}"

# 检查容器
if ! docker ps --filter "name=js1-qa1a" --filter "status=running" | grep -q js1-qa1a; then
    echo -e "${RED}错误: qa1a 未运行${NC}"
    exit 1
fi
if ! docker ps --filter "name=js1-qa1b" --filter "status=running" | grep -q js1-qa1b; then
    echo -e "${RED}错误: qa1b 未运行${NC}"
    exit 1
fi

# 获取 Source Stream 状态
echo -e "${YELLOW}Source Stream (qa1a):${NC}"
SOURCE_INFO=$(docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream info "$SOURCE_STREAM" 2>/dev/null)
echo "$SOURCE_INFO"
SOURCE_MSGS=$(echo "$SOURCE_INFO" | grep "Messages:" | awk '{print $2}')
echo ""

# 获取 Mirror Stream 状态
echo -e "${YELLOW}Mirror Stream (qa1b):${NC}"
MIRROR_INFO=$(docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info "$MIRROR_STREAM" 2>/dev/null)
echo "$MIRROR_INFO"
MIRROR_MSGS=$(echo "$MIRROR_INFO" | grep "Messages:" | awk '{print $2}')
echo ""

# 验证
echo -e "${GREEN}=== 验证结果 ===${NC}"
if [ "$SOURCE_MSGS" = "$MIRROR_MSGS" ] && [ -n "$SOURCE_MSGS" ]; then
    echo -e "${GREEN}✓ 同步正常${NC}"
    echo -e "  Source: $SOURCE_MSGS 条消息"
    echo -e "  Mirror: $MIRROR_MSGS 条消息"
else
    echo -e "${YELLOW}⚠ 同步状态${NC}"
    echo -e "  Source: ${SOURCE_MSGS:-N/A} 条消息"
    echo -e "  Mirror: ${MIRROR_MSGS:-N/A} 条消息"
    echo -e "${YELLOW}  请检查网络连接和 Mirror 配置${NC}"
fi

# 检查 Mirror 状态
echo ""
echo -e "${YELLOW}Mirror 详细状态:${NC}"
MIRROR_STATE=$(echo "$MIRROR_INFO" | grep -A 5 "Mirror:" || echo "无 Mirror 信息")
echo "$MIRROR_STATE"
