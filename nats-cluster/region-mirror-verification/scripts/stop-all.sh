#!/bin/bash

# 一键停止所有服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Region Mirror/Source 验证方案 - 停止所有服务 ==="

# 停止 Zone A
echo "停止 Zone A..."
cd "$BASE_DIR/zone-a"
docker compose -f allinone.yml down

# 停止 Zone B
echo "停止 Zone B..."
cd "$BASE_DIR/zone-b"
docker compose -f allinone.yml down

echo ""
echo "=== 停止完成 ==="
echo ""
echo "提示: 如需删除网络，运行: docker network rm region-mirror-network"

