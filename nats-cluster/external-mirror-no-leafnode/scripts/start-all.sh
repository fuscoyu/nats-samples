#!/bin/bash

# 启动所有服务

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== 启动跨集群 Mirror 环境 ===${NC}"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: docker 未安装${NC}"
    exit 1
fi

# 创建网络
echo -e "${YELLOW}创建 Docker 网络...${NC}"
"$SCRIPT_DIR/create-network.sh"

# 启动 qa1a
echo -e "${YELLOW}启动 Zone qa1a...${NC}"
cd "$BASE_DIR/zone-qa1a"
docker compose -f allinone.yml up -d

# 启动 qa1b
echo -e "${YELLOW}启动 Zone qa1b...${NC}"
cd "$BASE_DIR/zone-qa1b"
docker compose -f allinone.yml up -d

# 等待服务就绪
echo -e "${YELLOW}等待服务就绪...${NC}"
sleep 5

# 检查状态
echo -e "${GREEN}=== 服务状态 ===${NC}"
docker ps --filter "name=js.*qa1[ab]" --format "table {{.Names}}\t{{.Status}}"

echo -e "${GREEN}✓ 所有服务已启动${NC}"
echo -e "${YELLOW}运行 ./setup-mirror.sh 创建 Stream 和 Mirror${NC}"
