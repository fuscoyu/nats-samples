#!/bin/bash

# 一键停止所有服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 双Source双Mirror验证方案 - 停止所有服务 ==="

# 停止 Zone qa1a
echo "停止 Zone qa1a..."
cd "$BASE_DIR/zone-qa1a"
docker compose -f allinone.yml down

# 停止 Zone qa1b
echo "停止 Zone qa1b..."
cd "$BASE_DIR/zone-qa1b"
docker compose -f allinone.yml down

echo ""
echo "=== 停止完成 ==="
echo ""
echo "提示: 如需删除网络，运行: docker network rm dual-source-dual-mirror-network"

