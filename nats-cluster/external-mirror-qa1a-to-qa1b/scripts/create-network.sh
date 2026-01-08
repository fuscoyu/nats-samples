#!/bin/bash

# 创建 Docker 网络

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NETWORK_NAME="external-mirror-network"

echo -e "${GREEN}创建 Docker 网络: ${NETWORK_NAME}${NC}"

# 检查网络是否已存在
if docker network inspect "$NETWORK_NAME" &> /dev/null; then
    echo -e "${YELLOW}网络已存在，跳过创建${NC}"
    exit 0
fi

# 创建网络
docker network create "$NETWORK_NAME"

echo -e "${GREEN}✓ 网络创建成功${NC}"
