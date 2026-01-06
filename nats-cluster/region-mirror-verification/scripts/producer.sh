#!/bin/bash

# Region Mirror/Source 验证方案 - Producer 脚本
# 向 Zone A 发送带序号的消息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Zone A 连接地址（无认证）
ZONE_A_SERVERS="nats://localhost:15222,nats://localhost:15223,nats://localhost:15224"

# Stream 和 Subject
STREAM_NAME="EVENTS.REGION"
SUBJECT="events.region.producer"

# 参数
START_SEQ=${1:-1}
END_SEQ=${2:-100}
INTERVAL=${3:-1}  # 发送间隔（秒）

echo -e "${GREEN}=== Region Mirror/Source 验证方案 - Producer ===${NC}"
echo -e "发送消息序列: ${START_SEQ} - ${END_SEQ}"
echo -e "发送间隔: ${INTERVAL} 秒"
echo -e "Subject: ${SUBJECT}"
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

# 发送消息
for i in $(seq $START_SEQ $END_SEQ); do
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="{\"seq\": $i, \"timestamp\": \"$timestamp\", \"data\": \"message-$i\"}"
    
    echo -e "${YELLOW}[$timestamp] 发送消息 #$i${NC}"
    
    echo "$message" | nats --server "$ZONE_A_SERVERS" pub "$SUBJECT" -
    
    if [ $INTERVAL -gt 0 ]; then
        sleep $INTERVAL
    fi
done

echo -e "${GREEN}=== Producer 完成，共发送 $((END_SEQ - START_SEQ + 1)) 条消息 ===${NC}"

