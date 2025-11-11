本指南旨在搭建同时具备持久化能力 (NATS JetStream) 和无持久化能力 (传统 NATS) 的 NATS 消息队列集群

## All In One 的 NATS 集群

All in One 的 NATS 集群主要用于为研发和测试快速搭建一个 NATS 集群环境，包括 3 个有持久化能力的 NATS JetStream 节点和 3 个无持久化能力的标准 NATS 节点

```shell
# 创建集群
docker compose -f ./nats-cluster/allinone.yml up -d

# 查看集群内的容器
docker ps

# 拉起测试容器环境
docker run -it --rm \
  --network nats-cluster \
  natsio/nats-box:latest

# 测试 NATS 集群
nats --server nats://js1:4222 --user admin --password admin server report jetstream

# 销毁集群
docker compose -f ./nats-cluster/allinone.yml down
```