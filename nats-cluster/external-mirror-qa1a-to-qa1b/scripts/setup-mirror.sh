#!/bin/bash

# 创建 Source Stream 和 Mirror Stream

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
QA1A_SERVERS="nats://js1-qa1a:4222,nats://js2-qa1a:4222,nats://js3-qa1a:4222"
QA1B_SERVERS="nats://js1-qa1b:4222,nats://js2-qa1b:4222,nats://js3-qa1b:4222"
QA1A_EXTERNAL="nats://app:app@js1-qa1a:4222"
QA1B_EXTERNAL="nats://app:app@js1-qa1b:4222"

SOURCE_STREAM="qa"
MIRROR_STREAM="qa_mirror_qa1a"
SUBJECTS="events.qa.qa1a.>"

echo -e "${GREEN}=== 创建跨集群 Mirror ===${NC}"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装${NC}"
    exit 1
fi

# 检查容器是否运行
echo -e "${YELLOW}检查容器状态...${NC}"
if ! docker ps --filter "name=js1-qa1a" --filter "status=running" | grep -q js1-qa1a; then
    echo -e "${RED}错误: qa1a 集群未运行，请先运行 ./start-all.sh${NC}"
    exit 1
fi
if ! docker ps --filter "name=js1-qa1b" --filter "status=running" | grep -q js1-qa1b; then
    echo -e "${RED}错误: qa1b 集群未运行，请先运行 ./start-all.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 所有容器运行正常${NC}"

# 在 qa1a 上创建 Source Stream
echo -e "${YELLOW}步骤 1: 在 qa1a 上创建 Source Stream '${SOURCE_STREAM}'...${NC}"
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream add "$SOURCE_STREAM" \
    --subjects "$SUBJECTS" \
    --storage file \
    --replicas 3 \
    --defaults 2>/dev/null || echo -e "${YELLOW}Stream 可能已存在，继续...${NC}"

sleep 2

# 在 qa1b 上创建 Mirror Stream
echo -e "${YELLOW}步骤 2: 在 qa1b 上创建 Mirror Stream '${MIRROR_STREAM}'...${NC}"

# 使用 JSON 配置创建 Mirror
MIRROR_CONFIG=$(cat <<EOF
{
  "name": "${MIRROR_STREAM}",
  "mirror": {
    "name": "${SOURCE_STREAM}",
    "external": {
      "api": "\$JS.az1.API"
    }
  },
  "storage": "file",
  "num_replicas": 3
}
EOF
)

# 保存配置到临时文件并创建 Mirror
echo "$MIRROR_CONFIG" > /tmp/mirror_config.json
docker cp /tmp/mirror_config.json nats-box-qa1b:/tmp/mirror_config.json
docker exec -i nats-box-qa1b nats --server $QA1B_EXTERNAL stream add "$MIRROR_STREAM" --config /tmp/mirror_config.json 2>&1 | head -20
rm -f /tmp/mirror_config.json

sleep 2

# 显示状态
echo -e "${GREEN}=== 创建完成 ===${NC}"
echo ""
echo -e "${YELLOW}Source Stream (qa1a):${NC}"
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream info "$SOURCE_STREAM" 2>/dev/null || echo "获取信息失败"
echo ""
echo -e "${YELLOW}Mirror Stream (qa1b):${NC}"
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info "$MIRROR_STREAM" 2>/dev/null || echo "获取信息失败"

echo ""
echo -e "${GREEN}✓ Mirror 创建完成${NC}"
echo -e "${YELLOW}运行 ./producer.sh 发送测试消息${NC}"
