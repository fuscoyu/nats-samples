本指南旨在搭建同时具备持久化能力 (NATS JetStream) 和无持久化能力 (传统 NATS) 的 NATS 消息队列集群

## All In One 的 NATS 集群

All in One 的 NATS 集群主要用于为研发和测试快速在一个虚拟机或本地 laptop 搭建一个 NATS 集群，包括 3 个有持久化能力的 NATS JetStream 节点和 3 个无持久化能力的标准 NATS 节点

```shell
# 创建集群
docker compose -f ./nats-cluster/allinone/allinone.yml up -d

# 查看集群内的容器
docker ps

# 拉起使用容器网络的容器环境进行测试
docker run -it --rm --network nats-cluster natsio/nats-box:latest
nats --server nats://js1:14222 --user admin --password admin server report jetstream

# 拉起使用 host network 的容器环境进行测试
docker run -it --rm --network host natsio/nats-box:latest
nats context add local --server nats://localhost:14222,nats://localhost:14223,nats://localhost:14224,nats://localhost:14225,nats://localhost:14226,nats://localhost:14227
nats context select local
nats --user admin --password admin server report health
nats --user admin --password admin server report jetstream

# 销毁集群
docker compose -f ./nats-cluster/allinone/allinone.yml down
```

## 分布式的 NATS 集群

在三台虚拟机搭建一个 NATS 集群，包括 3 个有持久化能力的 NATS JetStream 节点和 3 个无持久化能力的标准 NATS 节点。
每台虚拟机都包含一个有持久化能力的 NATS JetStream 节点和一个无持久化能力的标准 NATS 节点。

```shell
# 修改 distributed/node1, distributed/node2, distributed/node3 中的 js1.conf 和 nats1.conf 文件
# 替换 node1, node2, node3 在 routes 中的实际 ip，比如将如下 routes 
cluster {
  name: C1
  listen: 0.0.0.0:6222
  routes: [
    nats://<node1-ip>:16222
    nats://<node3-ip>:16222
    nats://<node1-ip>:16223
    nats://<node2-ip>:16223
    nats://<node3-ip>:16223
  ]
}
  
# 改为

cluster {
  name: C1
  listen: 0.0.0.0:6222
  routes: [
    nats://192.168.0.11:16222
    nats://192.168.0.13:16222
    nats://192.168.0.11:16223
    nats://192.168.0.12:16223
    nats://192.168.0.13:16223
  ]
}
```

```shell
# 创建集群
docker compose -f ./nats-cluster/distributed/node1/nats-nodes.yml up -d
docker compose -f ./nats-cluster/distributed/node2/nats-nodes.yml up -d
docker compose -f ./nats-cluster/distributed/node3/nats-nodes.yml up -d

# 测试方法参考 allinone 章节

# 销毁集群
docker compose -f ./nats-cluster/distributed/node1/nats-nodes.yml down 
docker compose -f ./nats-cluster/distributed/node2/nats-nodes.yml down
docker compose -f ./nats-cluster/distributed/node3/nats-nodes.yml down
```