# 快速开始指南

## 5分钟上手跨集群 Mirror

### 前置要求

- Docker & Docker Compose
- NATS CLI (可选，用于手动操作)

### 步骤 1: 启动环境

```bash
cd /Users/yumin/code/github/personal/nats-samples/nats-cluster/external-mirror-qa1a-to-qa1b/scripts

./start-all.sh
```

输出示例：
```
=== 启动跨集群 Mirror 环境 ===
创建 Docker 网络...
✓ 网络创建成功
启动 Zone qa1a...
启动 Zone qa1b...
等待服务就绪...
=== 服务状态 ===
js1-qa1a          Up 5 seconds
js2-qa1a          Up 5 seconds
js3-qa1a          Up 5 seconds
js1-qa1b          Up 5 seconds
js2-qa1b          Up 5 seconds
js3-qa1b          Up 5 seconds
✓ 所有服务已启动
```

### 步骤 2: 创建 Mirror

```bash
./setup-mirror.sh
```

输出示例：
```
=== 创建跨集群 Mirror ===
检查容器状态...
✓ 所有容器运行正常
步骤 1: 在 qa1a 上创建 Source Stream 'qa'...
步骤 2: 在 qa1b 上创建 Mirror Stream 'qa_mirror_qa1a'...
=== 创建完成 ===

Source Stream (qa1a):
Mirror Stream (qa1b):
✓ Mirror 创建完成
```

### 步骤 3: 发送测试消息

打开 Terminal 1，运行：
```bash
./producer.sh 10 0.1
```

这会发送 10 条消息到 qa1a，每条间隔 0.1 秒。

### 步骤 4: 查看镜像消息

打开 Terminal 2，运行：
```bash
./consumer.sh
```

你会看到从 qa1b 的 Mirror Stream 消费到的消息。

### 步骤 5: 验证同步状态

```bash
./verify.sh
```

检查 Source 和 Mirror 的消息数量是否一致。

### 步骤 6: 清理

```bash
./stop-all.sh
```

## 常用命令速查

### 查看 Stream 列表
```bash
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream ls
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream ls
```

### 查看 Stream 详情
```bash
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream info qa
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info qa_mirror_qa1a
```

### 手动发送消息
```bash
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 pub events.qa.qa1a.test "hello"
```

### 手动消费消息
```bash
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 sub events.qa.qa1a.>
```

### 查看 HTTP 监控
```bash
curl -s "http://localhost:18222/jsz" | python3 -m json.tool
curl -s "http://localhost:18232/jsz" | python3 -m json.tool
```

## 故障排查

### 问题: Mirror 没有数据

**检查步骤:**
1. 确认两个集群都运行正常
   ```bash
   docker ps | grep js
   ```

2. 确认 Source Stream 存在
   ```bash
   docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream ls
   ```

3. 检查 Mirror 配置
   ```bash
   docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info qa_mirror_qa1a
   ```

4. 查看 qa1b 日志
   ```bash
   docker logs js1-qa1b | grep -i mirror
   ```

### 问题: 无法连接源集群

**可能原因:**
- 网络不通
- 防火墙阻止端口
- 外部地址配置错误

**解决:**
```bash
# 测试网络连通性
docker exec -i nats-box-qa1b ping js1-qa1a

# 测试端口连通性
docker exec -i nats-box-qa1b nc -zv js1-qa1a 4222
```

## 下一步

- 阅读 [README.md](./README.md) 了解详细配置
- 尝试修改 subjects 过滤规则
- 测试网络分区场景
- 配置 TLS 和认证

## 提示

- 所有脚本都支持在 `scripts` 目录下运行
- 默认使用 `app/app` 账号
- 默认 subjects: `events.qa.qa1a.>`
- Mirror 会自动从源集群拉取历史数据
