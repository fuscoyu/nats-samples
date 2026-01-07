#!/bin/bash

# 双Source双Mirror验证方案 - Producer qa1b 脚本
# 向 Zone qa1b 的 Source Stream 发送带序号的消息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone qa1b 连接地址（容器内访问）
ZONE_QA1B_SERVERS="nats://js1-qa1b:4222,nats://js2-qa1b:4222,nats://js3-qa1b:4222"

# 使用 nats-box 容器运行 NATS CLI
NATS_BOX_IMAGE="natsio/nats-box:latest"
NATS_CMD="docker run --rm -i --network dual-source-dual-mirror-network $NATS_BOX_IMAGE nats"

# Stream 和 Subject
STREAM_NAME="qa"
SUBJECT="events.qa.qa1b.producer"

# 参数
START_SEQ=${1:-1}
END_SEQ=${2:-100}
INTERVAL=${3:-0.1}  # 发送间隔（秒）

echo -e "${GREEN}=== 双Source双Mirror验证方案 - Producer qa1b ===${NC}"
echo -e "发送消息序列: ${START_SEQ} - ${END_SEQ}"
echo -e "发送间隔: ${INTERVAL} 秒"
echo -e "Subject: ${SUBJECT}"
echo -e "Stream: ${STREAM_NAME}"
echo ""

# 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装。请安装 Docker。${NC}"
    exit 1
fi

# 拉取 nats-box 镜像（如果需要）
docker pull "$NATS_BOX_IMAGE" > /dev/null 2>&1 || true

# 检查 Zone qa1b 连接（尝试列出streams来验证连接）
if ! docker run --rm --network dual-source-dual-mirror-network $NATS_BOX_IMAGE nats --server "$ZONE_QA1B_SERVERS" stream ls &> /dev/null; then
    echo -e "${YELLOW}警告: 无法连接到 Zone qa1b，但继续尝试发送消息...${NC}"
fi

# 发送消息
for i in $(seq $START_SEQ $END_SEQ); do
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="{\"seq\": $i, \"zone\": \"qa1b\", \"timestamp\": \"$timestamp\", \"data\": \"message-$i\"}"
    
    echo -e "${YELLOW}[$timestamp] 发送消息 #$i (Zone qa1b)${NC}"
    
    echo "$message" | $NATS_CMD --server "$ZONE_QA1B_SERVERS" pub "$SUBJECT" -
    
    if [ $(echo "$INTERVAL > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        sleep $INTERVAL
    fi
done

echo -e "${GREEN}=== Producer qa1b 完成，共发送 $((END_SEQ - START_SEQ + 1)) 条消息 ===${NC}"

