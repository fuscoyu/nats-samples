#!/bin/bash

# 双Source双Mirror验证方案 - Setup 脚本
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

# 单节点连接地址（用于 Mirror external API）
ZONE_QA1A_NODE="nats://js1-qa1a:4222"
ZONE_QA1B_NODE="nats://js1-qa1b:4222"

# 容器内连接地址（用于 Mirror external API）
# JetStream domain 在配置中设置为 "zone-qa1a" 和 "zone-qa1b"
# external.api 需要使用有效的 subject 格式: $JS.<domain>.API
ZONE_QA1A_CONTAINER='$JS.zone-qa1a.API'
ZONE_QA1B_CONTAINER='$JS.zone-qa1b.API'

# Stream 名称（使用 region_id）
REGION_ID="qa"
SOURCE_STREAM_NAME="$REGION_ID"
MIRROR_QA1A_NAME="qa_mirror_qa1a"
MIRROR_QA1B_NAME="qa_mirror_qa1b"

# Subject 模式
SUBJECT_QA1A="events.qa.qa1a.>"
SUBJECT_QA1B="events.qa.qa1b.>"
# Deliver subject for mirror (must be different from source subjects to avoid cycles)
DELIVER_QA1A="mirror.qa1a"
DELIVER_QA1B="mirror.qa1b"

echo -e "${GREEN}=== 双Source双Mirror验证方案 - Setup ===${NC}"

# 检查 Docker 是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装。请安装 Docker。${NC}"
    exit 1
fi

# 等待 Zone qa1a 和 Zone qa1b 启动
echo -e "${YELLOW}等待 Zone qa1a 和 Zone qa1b 启动...${NC}"
sleep 5

# 在 nats-box-qa1a 中创建 context 保存认证凭据
echo -e "${YELLOW}配置 nats-box-qa1a 认证...${NC}"
docker exec -i nats-box-qa1a nats context save qa1a \
    --server "$ZONE_QA1A_NODE" \
    --user app \
    --password app \
    --description "Zone qa1a with app credentials"

# 在 nats-box-qa1b 中创建 context 保存认证凭据
echo -e "${YELLOW}配置 nats-box-qa1b 认证...${NC}"
docker exec -i nats-box-qa1b nats context save qa1b \
    --server "$ZONE_QA1B_NODE" \
    --user app \
    --password app \
    --description "Zone qa1b with app credentials"

# 检查 Zone qa1a 连接
echo -e "${YELLOW}检查 Zone qa1a 连接...${NC}"
if ! docker exec -i nats-box-qa1a nats --context qa1a stream ls &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Zone qa1a${NC}"
    exit 1
else
    echo -e "${GREEN}Zone qa1a 连接正常${NC}"
fi

# 检查 Zone qa1b 连接
echo -e "${YELLOW}检查 Zone qa1b 连接...${NC}"
if ! docker exec -i nats-box-qa1b nats --context qa1b stream ls &> /dev/null; then
    echo -e "${RED}错误: 无法连接到 Zone qa1b${NC}"
    exit 1
else
    echo -e "${GREEN}Zone qa1b 连接正常${NC}"
fi

# 清理已存在的 Stream（如果有）
echo -e "${YELLOW}清理已存在的 Stream...${NC}"
docker exec -i nats-box-qa1a nats stream rm "$SOURCE_STREAM_NAME" --context qa1a --force 2>/dev/null || true
docker exec -i nats-box-qa1a nats stream rm "$MIRROR_QA1B_NAME" --context qa1a --force 2>/dev/null || true
docker exec -i nats-box-qa1b nats stream rm "$SOURCE_STREAM_NAME" --context qa1b --force 2>/dev/null || true
docker exec -i nats-box-qa1b nats stream rm "$MIRROR_QA1A_NAME" --context qa1b --force 2>/dev/null || true

# 创建 Zone qa1a 的 Source Stream
echo -e "${YELLOW}创建 Zone qa1a 的 Source Stream: ${SOURCE_STREAM_NAME}...${NC}"
docker exec -i nats-box-qa1a nats --context qa1a stream add "$SOURCE_STREAM_NAME" \
    --subjects "$SUBJECT_QA1A" \
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
    --defaults

echo -e "${GREEN}Zone qa1a Source Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1b 的 Source Stream
echo -e "${YELLOW}创建 Zone qa1b 的 Source Stream: ${SOURCE_STREAM_NAME}...${NC}"
docker exec -i nats-box-qa1b nats --context qa1b stream add "$SOURCE_STREAM_NAME" \
    --subjects "$SUBJECT_QA1B" \
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
    --defaults

echo -e "${GREEN}Zone qa1b Source Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1a 的 Mirror Stream (镜像 Zone qa1b 的 Source Stream)
echo -e "${YELLOW}创建 Zone qa1a 的 Mirror Stream: ${MIRROR_QA1B_NAME} (镜像 Zone qa1b 的 Source Stream)...${NC}"

cat > /tmp/mirror_qa1b_config.json << HEREDOC
{
  "name": "${MIRROR_QA1B_NAME}",
  "mirror": {
    "name": "${SOURCE_STREAM_NAME}",
    "external": {
      "api": "\$JS.zone-qa1b.API"
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
HEREDOC

docker cp /tmp/mirror_qa1b_config.json nats-box-qa1a:/tmp/mirror_config.json
docker exec -i nats-box-qa1a nats stream add "$MIRROR_QA1B_NAME" --context qa1a --config /tmp/mirror_config.json 2>&1
rm -f /tmp/mirror_qa1b_config.json

echo -e "${GREEN}Zone qa1a Mirror Stream 创建成功${NC}"

# 等待一下确保 Stream 创建完成
sleep 2

# 创建 Zone qa1b 的 Mirror Stream (镜像 Zone qa1a 的 Source Stream)
echo -e "${YELLOW}创建 Zone qa1b 的 Mirror Stream: ${MIRROR_QA1A_NAME} (镜像 Zone qa1a 的 Source Stream)...${NC}"

cat > /tmp/mirror_qa1a_config.json << HEREDOC
{
  "name": "${MIRROR_QA1A_NAME}",
  "mirror": {
    "name": "${SOURCE_STREAM_NAME}",
    "external": {
      "api": "\$JS.zone-qa1a.API"
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
HEREDOC

docker cp /tmp/mirror_qa1a_config.json nats-box-qa1b:/tmp/mirror_config.json
docker exec -i nats-box-qa1b nats stream add "$MIRROR_QA1A_NAME" --context qa1b --config /tmp/mirror_config.json 2>&1
rm -f /tmp/mirror_qa1a_config.json

echo -e "${GREEN}Zone qa1b Mirror Stream 创建成功${NC}"

# 等待 Mirror 同步
echo -e "${YELLOW}等待 Mirror Stream 同步...${NC}"
sleep 3

# 显示 Stream 信息
echo -e "${GREEN}=== Stream 信息 ===${NC}"
echo -e "${YELLOW}Zone qa1a Source Stream (${SOURCE_STREAM_NAME}):${NC}"
docker exec -i nats-box-qa1a nats --context qa1a stream info "$SOURCE_STREAM_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1a Mirror Stream (${MIRROR_QA1B_NAME}):${NC}"
docker exec -i nats-box-qa1a nats --context qa1a stream info "$MIRROR_QA1B_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1b Source Stream (${SOURCE_STREAM_NAME}):${NC}"
docker exec -i nats-box-qa1b nats --context qa1b stream info "$SOURCE_STREAM_NAME" || echo "Stream 不存在或未就绪"

echo -e "${YELLOW}Zone qa1b Mirror Stream (${MIRROR_QA1A_NAME}):${NC}"
docker exec -i nats-box-qa1b nats --context qa1b stream info "$MIRROR_QA1A_NAME" || echo "Stream 不存在或未就绪"

echo -e "${GREEN}=== Setup 完成 ===${NC}"

# 验证 Mirror 同步状态
echo -e "${GREEN}=== Mirror 同步状态验证 ===${NC}"
sleep 2

echo -e "${YELLOW}Zone qa1a -> Zone qa1b Mirror 同步状态:${NC}"
docker exec -i nats-box-qa1b nats --context qa1b stream info "$MIRROR_QA1A_NAME" 2>&1 || echo "Mirror 不存在或无法访问"

echo -e "${YELLOW}Zone qa1b -> Zone qa1a Mirror 同步状态:${NC}"
docker exec -i nats-box-qa1a nats --context qa1a stream info "$MIRROR_QA1B_NAME" 2>&1 || echo "Mirror 不存在或无法访问"

echo -e "${GREEN}=== 验证完成 ===${NC}"
