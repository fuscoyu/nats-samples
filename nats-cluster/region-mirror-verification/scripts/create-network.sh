#!/bin/bash

# 创建共享网络

NETWORK_NAME="region-mirror-network"

if docker network inspect "$NETWORK_NAME" &> /dev/null; then
    echo "网络 $NETWORK_NAME 已存在"
else
    echo "创建网络 $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
    echo "网络创建完成"
fi

