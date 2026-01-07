# 双Source双Mirror验证方案 - 快速开始

## 前置要求

- Docker 和 Docker Compose
- NATS CLI 工具（`nats` 命令）
  - 安装方法: https://github.com/nats-io/natscli

## 快速启动

```bash
cd nats-cluster/dual-source-dual-mirror/scripts
chmod +x *.sh
./start-all.sh
```

## 快速验证

### 1. 发送消息

**终端1**: 启动 Producer-qa1a
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./producer-qa1a.sh 1 50 0.1
```

**终端2**: 启动 Producer-qa1b
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./producer-qa1b.sh 1 50 0.1
```

### 2. 消费消息

**终端3**: 启动 Consumer-qa1a（消费自己的Source）
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./consumer-qa1a.sh > consumer-qa1a.log 2>&1 &
```

**终端4**: 启动 Consumer-qa1a-mirror（消费Mirror）
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./consumer-qa1a-mirror.sh > consumer-qa1a-mirror.log 2>&1 &
```

**终端5**: 启动 Consumer-qa1b（消费自己的Source）
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./consumer-qa1b.sh > consumer-qa1b.log 2>&1 &
```

**终端6**: 启动 Consumer-qa1b-mirror（消费Mirror）
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./consumer-qa1b-mirror.sh > consumer-qa1b-mirror.log 2>&1 &
```

### 3. 验证结果

等待几秒钟让消息同步，然后运行验证脚本：

```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./verify.sh
```

### 4. 停止所有服务

```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./stop-all.sh
```

## 验证要点

- ✅ Consumer-qa1a 应该消费到 Producer-qa1a 的消息
- ✅ Consumer-qa1b 应该消费到 Producer-qa1b 的消息
- ✅ Consumer-qa1a-mirror 应该消费到 Producer-qa1b 的消息（通过Mirror）
- ✅ Consumer-qa1b-mirror 应该消费到 Producer-qa1a 的消息（通过Mirror）

## 网络分区测试

### 断开网络
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./network-partition.sh disconnect
```

### 恢复网络
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./network-partition.sh connect
```

### 检查网络状态
```bash
cd nats-cluster/dual-source-dual-mirror/scripts
./network-partition.sh status
```

## 查看Stream状态

```bash
# Zone qa1a Source Stream
nats --server nats://localhost:16222 stream info qa

# Zone qa1a Mirror Stream
nats --server nats://localhost:16222 stream info qa_mirror_qa1b

# Zone qa1b Source Stream
nats --server nats://localhost:16232 stream info qa

# Zone qa1b Mirror Stream
nats --server nats://localhost:16232 stream info qa_mirror_qa1a
```

## 常见问题

### 1. 无法连接到NATS服务器

确保Docker容器正在运行：
```bash
docker ps | grep qa1
```

### 2. Mirror Stream无法同步

检查网络连接：
```bash
./network-partition.sh status
```

检查Mirror Stream状态：
```bash
nats --server nats://localhost:16222 stream info qa_mirror_qa1b
```

### 3. 消息丢失

运行验证脚本检查：
```bash
./verify.sh
```

查看日志文件：
```bash
cat consumer-qa1a.log
cat consumer-qa1a-mirror.log
cat consumer-qa1b.log
cat consumer-qa1b-mirror.log
```

## 更多信息

详细文档请参考 [README.md](README.md)

