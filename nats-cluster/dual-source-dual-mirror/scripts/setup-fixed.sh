#!/bin/bash

# 双Source双Mirror验证方案 - Setup 脚本 (修正版)
# 用于创建 Source Stream 和 Mirror Stream

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone qa1a 和 Zone qa1b 的连接地址（容器内访问）
ZONE_QA1A_SERVERS="nats://js1-qa1a:4222,nats://js2-qa1a:4222,nats://js3-qa1a:4222"
ZONE_QA1B_SERVERS="nats://js1-qa1b:4222,nats://js2-qa1b:4222,nats://js3-qa1b:4222"

# 容器内连接地址（用于 Mirror external API）
ZONE_QA1A_CONTAINER="js1-qa1a:4222"
ZONE_QA1B_CONTAINER="js1-qa1b:4222"

# Stream 名称（使用 region_id）
REGION_ID="qa"
SOURCE_STREAM_NAME="$REGION_ID"
MIRROR_QA1A_NAME="qa_mirror_qa1a"
MIRROR_QA1B_NAME="qa_mirror_qa1b"

# Subject 模式
SUBJECT_QA1A="events.qa.qa1a.>"
SUBJECT_QA1B="events.qa.qa1b.>"

echo -e "${GREEN}=== 双Source双Mirror验证方案 - Setup ===${NC}"

# 使用 nats-box 容器运行 NATS CLI (使用app账户)
NATS_CMD="docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222"
NATS_CMD_QA1B="docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222"

# 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装。请安装 Docker。${NC}"
    exit 1
fi

# 等待 Zone qa1a 和 Zone qa1b 启动
echo -e "${YELLOW}等待 Zone qa1a 和 Zone qa1b 启动...${NC}"
sleep 5

# 检查 Zone qa1a 连接
echo -e "${YELLOW}检查 Zone qa1a 连接...${NC}"
if ! $NATS_CMD stream ls &> /dev/null; then
    echo -e "${YELLOW}警告: 无法连接到 Zone qa1a，但继续尝试创建Stream...${NC}"
else
    echo -e "${GREEN}Zone qa1a 连接正常${NC}"
fi

# 检查 Zone qa1b 连接
echo -e "${YELLOW}检查 Zone qa1b 连接...${NC}"
if ! $NATS_CMD_QA1B stream ls &> /dev/null; then
    echo -e "${YELLOW}警告: 无法连接到 Zone qa1b，但继续尝试创建Stream...${NC}"
else
    echo -e "${GREEN}Zone qa1b 连接正常${NC}"
fi

# 创建 Zone qa1a 的 Source Stream
echo -e "${YELLOW}创建 Zone qa1a 的 Source Stream: ${SOURCE_STREAM_NAME}...${NC}"
$NATS_CMD stream add "$SOURCE_STREAM_NAME" \
    --subjects "$SUBJECT_QA1A" \
    --storage=file \
    --replicas=3 \
    --max-age=1h \
    --retention=limits \
    --discard=old \
    --dupe-window=2m \
    --max-msgs=-1 \
    --max-bytes=-1 \
    --max-msg-size=-1 \
    --allow-rollup \
    --no-deny-delete \
    --no-deny-purge \
    --defaults

echo -e "${GREEN}Zone qa1a Source Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1b 的 Source Stream
echo -e "${YELLOW}创建 Zone qa1b 的 Source Stream: ${SOURCE_STREAM_NAME}...${NC}"
$NATS_CMD_QA1B stream add "$SOURCE_STREAM_NAME" \
    --subjects "$SUBJECT_QA1B" \
    --storage=file \
    --replicas=3 \
    --max-age=1h \
    --retention=limits \
    --discard=old \
    --dupe-window=2m \
    --max-msgs=-1 \
    --max-bytes=-1 \
    --max-msg-size=-1 \
    --allow-rollup \
    --no-deny-delete \
    --no-deny-purge \
    --defaults

echo -e "${GREEN}Zone qa1b Source Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1a 的 Mirror Stream (镜像 Zone qa1b 的 Source Stream)
echo -e "${YELLOW}创建 Zone qa1a 的 Mirror Stream: ${MIRROR_QA1B_NAME} (镜像 Zone qa1b 的 Source Stream)...${NC}"
MIRROR_QA1B_CONFIG=$(cat <<EOF
{
  "name": "${MIRROR_QA1B_NAME}",
  "mirror": {
    "name": "${SOURCE_STREAM_NAME}",
    "external": {
      "api": "nats://${ZONE_QA1B_CONTAINER}",
      "deliver": "${SUBJECT_QA1B}"
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

# 通过stdin传递配置创建 Mirror Stream (使用app账户)
echo "$MIRROR_QA1B_CONFIG" | docker exec -i nats-box-qa1a nats --server nats://app:app@$ZONE_QA1A_SERVERS stream add "$MIRROR_QA1B_NAME" --config /dev/stdin --defaults

echo -e "${GREEN}Zone qa1a Mirror Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1b 的 Mirror Stream (镜像 Zone qa1a 的 Source Stream)
echo -e "${YELLOW}创建 Zone qa1b 的 Mirror Stream: ${MIRROR_QA1A_NAME} (镜像 Zone qa1a 的 Source Stream)...${NC}"
MIRROR_QA1A_CONFIG=$(cat <<EOF
{
  "name": "${MIRROR_QA1A_NAME}",
  "mirror": {
    "name": "${SOURCE_STREAM_NAME}",
    "external": {
      "api": "nats://${ZONE_QA1A_CONTAINER}",
      "deliver": "${SUBJECT_QA1A}"
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

# 通过stdin传递配置创建 Mirror Stream (使用app账户)
echo "$MIRROR_QA1A_CONFIG" | docker exec -i nats-box-qa1b nats --server nats://app:app@$ZONE_QA1B_SERVERS stream add "$MIRROR_QA1A_NAME" --config /dev/stdin --defaults

echo -e "${GREEN}Zone qa1b Mirror Stream 创建成功${NC}"

# 等待 Mirror 同步
echo -e "${YELLOW}等待 Mirror Stream 同步...${NC}"
sleep 3

# 显示 Stream 信息
echo -e "${GREEN}=== Stream 信息 ===${NC}"
echo -e "${YELLOW}Zone qa1a Source Stream (${SOURCE_STREAM_NAME}):${NC}"
$NATS_CMD stream info "$SOURCE_STREAM_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1a Mirror Stream (${MIRROR_QA1B_NAME}):${NC}"
$NATS_CMD stream info "$MIRROR_QA1B_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1b Source Stream (${SOURCE_STREAM_NAME}):${NC}"
$NATS_CMD_QA1B stream info "$SOURCE_STREAM_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1b Mirror Stream (${MIRROR_QA1A_NAME}):${NC}"
$NATS_CMD_QA1B stream info "$MIRROR_QA1A_NAME" || echo "Stream 不存在或未就绪"

echo -e "${GREEN}=== Setup 完成 ===${NC}"

# 验证 Mirror 同步状态
echo -e "${GREEN}=== Mirror 同步状态验证 ===${NC}"
sleep 2

echo -e "${YELLOW}Zone qa1a -> Zone qa1b Mirror 同步状态:${NC}"
$NATS_CMD_QA1B stream info "$MIRROR_QA1A_NAME" 2>&1 || echo "Mirror 不存在或无法访问"

echo -e "${YELLOW}Zone qa1b -> Zone qa1a Mirror 同步状态:${NC}"
$NATS_CMD stream info "$MIRROR_QA1B_NAME" 2>&1 || echo "Mirror 不存在或无法访问"

echo -e "${GREEN}=== 验证完成 ===${NC}"
