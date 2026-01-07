#!/bin/bash

# 双Source双Mirror验证方案 - 网络分区脚本
# 用于模拟跨 Zone 网络断开和恢复

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 网络名称
NETWORK_NAME="dual-source-dual-mirror-network"

# Zone qa1b 容器列表（断开这些容器以模拟网络分区）
ZONE_QA1B_CONTAINERS=("js1-qa1b" "js2-qa1b" "js3-qa1b")

# 函数：断开网络
disconnect_network() {
    echo -e "${YELLOW}=== 断开 Zone qa1b 到 Zone qa1a 的网络连接 ===${NC}"
    
    # 确保网络存在
    if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
        echo -e "${RED}错误: 网络 $NETWORK_NAME 不存在${NC}"
        exit 1
    fi
    
    # 断开 Zone qa1b 的所有容器
    for container in "${ZONE_QA1B_CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${YELLOW}断开容器 $container 的网络连接...${NC}"
            docker network disconnect "$NETWORK_NAME" "$container" 2>/dev/null || true
        else
            echo -e "${RED}警告: 容器 $container 不存在或未运行${NC}"
        fi
    done
    
    echo -e "${GREEN}网络断开完成${NC}"
    echo -e "${YELLOW}Zone qa1b 现在无法访问 Zone qa1a${NC}"
}

# 函数：恢复网络
connect_network() {
    echo -e "${YELLOW}=== 恢复 Zone qa1b 到 Zone qa1a 的网络连接 ===${NC}"
    
    # 确保网络存在
    if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
        echo -e "${RED}错误: 网络 $NETWORK_NAME 不存在${NC}"
        exit 1
    fi
    
    # 连接 Zone qa1b 的所有容器
    for container in "${ZONE_QA1B_CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${YELLOW}连接容器 $container 到网络...${NC}"
            docker network connect "$NETWORK_NAME" "$container" 2>/dev/null || true
        else
            echo -e "${RED}警告: 容器 $container 不存在或未运行${NC}"
        fi
    done
    
    echo -e "${GREEN}网络恢复完成${NC}"
    echo -e "${YELLOW}Zone qa1b 现在可以访问 Zone qa1a${NC}"
}

# 函数：检查网络状态
check_status() {
    echo -e "${YELLOW}=== 网络连接状态 ===${NC}"
    
    if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
        echo -e "${RED}网络 $NETWORK_NAME 不存在${NC}"
        return 1
    fi
    
    echo -e "${GREEN}网络 $NETWORK_NAME 存在${NC}"
    echo ""
    echo -e "${YELLOW}Zone qa1b 容器连接状态:${NC}"
    for container in "${ZONE_QA1B_CONTAINERS[@]}"; do
        if docker network inspect "$NETWORK_NAME" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "$container"; then
            echo -e "  ${GREEN}✓${NC} $container - 已连接"
        else
            echo -e "  ${RED}✗${NC} $container - 未连接"
        fi
    done
}

# 主函数
main() {
    case "${1:-}" in
        disconnect|disconnect-network|down)
            disconnect_network
            ;;
        connect|connect-network|up)
            connect_network
            ;;
        status|check)
            check_status
            ;;
        *)
            echo -e "${YELLOW}用法: $0 {disconnect|connect|status}${NC}"
            echo ""
            echo "命令:"
            echo "  disconnect  - 断开 Zone qa1b 到 Zone qa1a 的网络连接（拉闸）"
            echo "  connect     - 恢复 Zone qa1b 到 Zone qa1a 的网络连接"
            echo "  status      - 检查网络连接状态"
            exit 1
            ;;
    esac
}

main "$@"

