#!/bin/bash

# 发送测试消息到 qa1a

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 参数
COUNT=${1:-10}
INTERVAL=${2:-0.1}

echo -e "${GREEN}发送消息到 qa1a (Count: $COUNT, Interval: ${INTERVAL}s)${NC}"

# 检查容器
if ! docker ps --filter "name=js1-qa1a" --filter "status=running" | grep -q js1-qa1a; then
    echo -e "${RED}错误: qa1a 未运行${NC}"
    exit 1
fi

# 发送消息
for i in $(seq 1 $COUNT); do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    MSG="msg-$i-at-$TIMESTAMP"
    docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 pub events.qa.qa1a.test "$MSG" > /dev/null 2>&1
    echo -e "${GREEN}✓${NC} 发送: $MSG"
    sleep "$INTERVAL"
done

echo -e "${GREEN}完成! 共发送 $COUNT 条消息${NC}"
echo -e "${YELLOW}运行 ./consumer.sh 查看镜像消息${NC}"
