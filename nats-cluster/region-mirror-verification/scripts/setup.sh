#!/bin/bash

# Region Mirror/Source 验证方案 - Setup 脚本
# 用于创建 Source Stream 和 Mirror Stream

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone A 和 Zone B 的连接地址（无认证）
ZONE_A_SERVERS="nats://localhost:15222,nats://localhost:15223,nats://localhost:15224"
ZONE_B_SERVERS="nats://localhost:15232,nats://localhost:15233,nats://localhost:15234"

# 容器内连接地址（用于 Mirror external API）
ZONE_A_CONTAINER="js1-zone-a:4222"
ZONE_B_CONTAINER="js1-zone-b:4222"

# Stream 名称（不能包含点号）
STREAM_NAME="EVENTS_REGION"
SUBJECT="events.region.>"

echo -e "${GREEN}=== Region Mirror/Source 验证方案 - Setup ===${NC}"

# 检查 NATS CLI 是否可用
if ! command -v nats &> /dev/null; then
    echo -e "${RED}错误: nats CLI 未安装。请安装 nats CLI 工具。${NC}"
    echo "安装方法: https://github.com/nats-io/natscli"
    exit 1
fi

# 等待 Zone A 和 Zone B 启动
echo -e "${YELLOW}等待 Zone A 和 Zone B 启动...${NC}"
sleep 5

# 检查 Zone A 连接
echo -e "${YELLOW}检查 Zone A 连接...${NC}"
if ! nats --server "$ZONE_A_SERVERS" server ping &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Zone A。请确保 Zone A 已启动。${NC}"
    exit 1
fi
echo -e "${GREEN}Zone A 连接正常${NC}"

# 检查 Zone B 连接
echo -e "${YELLOW}检查 Zone B 连接...${NC}"
if ! nats --server "$ZONE_B_SERVERS" server ping &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Zone B。请确保 Zone B 已启动。${NC}"
    exit 1
fi
echo -e "${GREEN}Zone B 连接正常${NC}"

# 创建 Zone A 的 Source Stream
echo -e "${YELLOW}创建 Zone A 的 Source Stream: ${STREAM_NAME}...${NC}"
nats --server "$ZONE_A_SERVERS" stream add "$STREAM_NAME" \
    --subjects "$SUBJECT" \
    --storage file \
    --replicas 3 \
    --max-age 1h \
    --retention limits \
    --discard old \
    --dupe-window 2m \
    --max-msgs=-1 \
    --max-bytes=-1 \
    --max-msg-size=-1 \
    --allow-rollup \
    --no-deny-delete \
    --no-deny-purge \
    --yes

echo -e "${GREEN}Zone A Source Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone B 的 Mirror Stream
echo -e "${YELLOW}创建 Zone B 的 Mirror Stream: ${STREAM_NAME}...${NC}"
# Mirror Stream 需要通过 external API 连接到 Zone A
# 使用 JSON 配置文件方式创建 Mirror Stream
MIRROR_CONFIG=$(cat <<EOF
{
  "name": "${STREAM_NAME}",
  "mirror": {
    "name": "${STREAM_NAME}",
    "external": {
      "api": "nats://${ZONE_A_CONTAINER}",
      "deliver": "nats://${ZONE_A_CONTAINER}"
    }
  },
  "storage": "file",
  "num_replicas": 3,
  "max_age": 3600000000000,
  "retention": "limits",
  "discard": "old",
  "dupe_window": 120000000000,
  "max_msgs": -1,
  "max_bytes": -1,
  "max_msg_size": -1,
  "allow_rollup": true,
  "deny_delete": false,
  "deny_purge": false
}
EOF
)

# 创建临时配置文件
TEMP_CONFIG=$(mktemp)
echo "$MIRROR_CONFIG" > "$TEMP_CONFIG"

# 使用配置文件创建 Mirror Stream
nats --server "$ZONE_B_SERVERS" stream add "$STREAM_NAME" \
    --config "$TEMP_CONFIG" \
    --defaults

# 清理临时文件
rm -f "$TEMP_CONFIG"

echo -e "${GREEN}Zone B Mirror Stream 创建成功${NC}"

# 等待 Mirror 同步
echo -e "${YELLOW}等待 Mirror Stream 同步...${NC}"
sleep 3

# 显示 Stream 信息
echo -e "${GREEN}=== Stream 信息 ===${NC}"
echo -e "${YELLOW}Zone A Source Stream:${NC}"
nats --server "$ZONE_A_SERVERS" stream info "$STREAM_NAME"

echo -e "${YELLOW}Zone B Mirror Stream:${NC}"
nats --server "$ZONE_B_SERVERS" stream info "$STREAM_NAME"

echo -e "${GREEN}=== Setup 完成 ===${NC}"

