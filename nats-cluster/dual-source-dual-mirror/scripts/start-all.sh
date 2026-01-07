#!/bin/bash

# 一键启动所有服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 双Source双Mirror验证方案 - 启动所有服务 ==="

# 创建网络
echo "1. 创建共享网络..."
"$SCRIPT_DIR/create-network.sh"

# 启动 Zone qa1a
echo "2. 启动 Zone qa1a..."
cd "$BASE_DIR/zone-qa1a"
docker compose -f allinone.yml up -d

# 启动 Zone qa1b
echo "3. 启动 Zone qa1b..."
cd "$BASE_DIR/zone-qa1b"
docker compose -f allinone.yml up -d

# 等待服务启动
echo "4. 等待服务启动..."
sleep 10

# 创建 Stream
echo "5. 创建 Stream 和 Mirror..."
cd "$SCRIPT_DIR"
./setup.sh

echo ""
echo "=== 启动完成 ==="
echo ""
echo "Zone qa1a 连接地址: nats://localhost:16222"
echo "Zone qa1b 连接地址: nats://localhost:16232"
echo ""
echo "下一步："
echo "  1. 运行 producer-qa1a.sh 和 producer-qa1b.sh 发送消息"
echo "  2. 运行 consumer-qa1a.sh, consumer-qa1a-mirror.sh, consumer-qa1b.sh, consumer-qa1b-mirror.sh 消费消息"
echo "  3. 运行 network-partition.sh disconnect 模拟网络断开"

