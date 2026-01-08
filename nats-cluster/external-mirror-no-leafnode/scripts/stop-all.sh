#!/bin/bash

# 停止所有服务

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== 停止所有服务 ===${NC}"

# 停止 qa1a
echo -e "${YELLOW}停止 Zone qa1a...${NC}"
cd "$BASE_DIR/zone-qa1a"
docker compose -f allinone.yml down -v
rm -rf data

# 停止 qa1b
echo -e "${YELLOW}停止 Zone qa1b...${NC}"
cd "$BASE_DIR/zone-qa1b"
docker compose -f allinone.yml down -v
rm -rf data

# 清理网络（如果存在且没有容器使用）
echo -e "${YELLOW}清理网络...${NC}"
docker network inspect external-mirror-network &> /dev/null && \
docker network rm external-mirror-network 2>/dev/null || true

echo -e "${GREEN}✓ 所有服务已停止${NC}"
