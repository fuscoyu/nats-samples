本指南旨在搭建同时具备持久化能力 (NATS JetStream) 和无持久化能力 (传统 NATS) 的 NATS 消息队列集群

## All-in-One 的 NATS 集群

All-in-One 的 NATS 集群主要用于为研发和测试快速在一个虚拟机或本地 laptop 搭建一个 NATS 集群，包括 3 个有持久化能力的 NATS JetStream 节点和 3 个无持久化能力的标准 NATS 节点

```shell
# 创建集群
docker compose -f ./nats-cluster/allinone/allinone.yml up -d

# 查看集群内的容器
docker ps

# 拉起使用容器网络的容器环境进行测试
docker run -it --rm --network nats-cluster natsio/nats-box:latest
nats --server nats://js1:4222 --user admin --password admin server report jetstream

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
# 按实际情况修改 nats-cluster/distributed/config.yml 中各节点的 IP
ports:
  jetstream: 16222    # JetStream default (cluster) port
  nats: 16223         # NATS default (cluster) port

nodes:
  node1:
    ip: 192.168.0.11
    jetstream:
      max_mem_store: 1Gb
      max_file_store: 10Gb
  node2:
    ip: 192.168.0.12
    jetstream:
      max_mem_store: 1Gb
      max_file_store: 10Gb
  node3:
    ip: 192.168.0.13
    jetstream:
      max_mem_store: 1Gb
      max_file_store: 10Gb

# 重新生成所有节点 NATS 持久化和非持久化节点部署的配置
cd nats-cluster
pip install -r requirements.txt
python3 generate.py all

# 重新生成指定节点 NATS 持久化和非持久化节点部署的配置

# 清除所有 NATS 节点配置
```

```shell
# 创建集群
docker compose -f ./nats-cluster/distributed/node1/docker-compose.yml up -d
docker compose -f ./nats-cluster/distributed/node2/docker-compose.yml up -d
docker compose -f ./nats-cluster/distributed/node3/docker-compose.yml up -d

# 测试方法参考 allinone 章节

# 销毁集群
docker compose -f ./nats-cluster/distributed/node1/docker-compose.yml down 
docker compose -f ./nats-cluster/distributed/node2/docker-compose.yml down
docker compose -f ./nats-cluster/distributed/node3/docker-compose.yml down
```

## Trouble Shooting
- 查看日志
```shell
# 使用 docker compose 查看所有或特定容器日志
docker compose -f ./nats-cluster/allinone/allinone.yml logs
docker compose -f ./nats-cluster/allinone/allinone.yml logs <container name like: n1 or js1>
# 使用 docker 查看所有或特定容器日志
docker logs
docker logs <container name like: n1 or js1> 
# 查看当前日志驱动和限制是否生效
docker inspect n1 | grep -A6 LogConfig
```

```yaml
# 设置容器日志文件最多保存 5 个，每个最多 20 MB
  n1:
    image: nats:2.10
    container_name: n1
    command: ["-c", "/etc/nats/nats.conf"]
    volumes:
      - ./nats1.conf:/etc/nats/nats.conf:ro
    ports:
      - "14223:4222"
      - "18223:8222"
      - "16223:6222"
    logging:
      driver: "json-file"
      options:
        max-size: "20m"     # 单个日志文件最大 20MB
        max-file: "5"       # 最多保留 5 个文件（共 ~100MB）
```

```shell
# 查看当前日志驱动和限制是否生效: 
docker inspect n1 | grep -A6 LogConfig

"LogConfig": {
    "Type": "json-file",
    "Config": {
        "max-size": "20m",
        "max-file": "5"
    }
}
```