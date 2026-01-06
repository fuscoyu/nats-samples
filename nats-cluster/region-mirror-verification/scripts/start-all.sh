#!/bin/bash

# 一键启动所有服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Region Mirror/Source 验证方案 - 启动所有服务 ==="

# 创建网络
echo "1. 创建共享网络..."
"$SCRIPT_DIR/create-network.sh"

# 启动 Zone A
echo "2. 启动 Zone A..."
cd "$BASE_DIR/zone-a"
docker compose -f allinone.yml up -d

# 启动 Zone B
echo "3. 启动 Zone B..."
cd "$BASE_DIR/zone-b"
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
echo "Zone A 连接地址: nats://admin:admin@localhost:15222"
echo "Zone B 连接地址: nats://admin:admin@localhost:15232"
echo ""
echo "下一步："
echo "  1. 运行 producer.sh 发送消息"
echo "  2. 运行 consumer-a.sh 和 consumer-b.sh 消费消息"
echo "  3. 运行 network-partition.sh disconnect 模拟网络断开"

