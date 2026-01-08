# 跨集群 External Mirror 示例

纯外部镜像（External Mirror）场景，不使用 Gateway 或 Supercluster。

## 场景说明

```
┌─────────────────────────────────────────────────────────────┐
│                    跨集群 Mirror 架构                        │
└─────────────────────────────────────────────────────────────┘

源集群 (qa1a)                    目标集群 (qa1b)
┌──────────────┐                 ┌──────────────┐
│  js1-qa1a    │                 │  js1-qa1b    │
│  js2-qa1a    │                 │  js2-qa1b    │
│  js3-qa1a    │                 │  js3-qa1b    │
└──────┬───────┘                 └──────┬───────┘
       │                                │
       └────────── External ────────────┘
       ┌───────────────────────────────┐
       │  qa (Source Stream)           │
       │  → qa_mirror_qa1a (Mirror)    │
       └───────────────────────────────┘
```

### 配置详情

- **源集群**: qa1a (3节点 JetStream)
- **目标集群**: qa1b (3节点 JetStream)
- **账号**: app / app
- **Source Stream**: `qa`
- **Subjects**: `events.qa.qa1a.>`
- **Mirror Stream**: `qa_mirror_qa1a`

## 快速开始

### 1. 启动环境

```bash
cd /Users/yumin/code/github/personal/nats-samples/nats-cluster/external-mirror-qa1a-to-qa1b/scripts

# 启动所有服务
./start-all.sh
```

### 2. 创建 Mirror

```bash
# 创建 Source Stream (qa1a) 和 Mirror Stream (qa1b)
./setup-mirror.sh
```

### 3. 测试消息流

```bash
# Terminal 1: 发送消息到 qa1a
./producer.sh 20 0.1

# Terminal 2: 消费镜像消息 (从 qa1b)
./consumer.sh
```

### 4. 验证同步状态

```bash
./verify.sh
```

### 5. 停止环境

```bash
./stop-all.sh
```

## 核心配置

### Source Stream (qa1a)

```bash
nats stream add qa \
  --subjects "events.qa.qa1a.>" \
  --storage file \
  --replicas 3
```

### Mirror Stream (qa1b)

```bash
nats stream add qa_mirror_qa1a \
  --mirror "qa" \
  --external "nats://js1-qa1a:4222" \
  --storage file \
  --replicas 3
```

或使用 JSON 配置：

```json
{
  "name": "qa_mirror_qa1a",
  "mirror": {
    "name": "qa",
    "external": {
      "api": "nats://js1-qa1a:4222"
    }
  },
  "storage": "file",
  "num_replicas": 3
}
```

## 关键参数说明

### --external

指定源集群的 API 地址。在 Docker 环境中使用容器名，在生产环境中使用实际的 NATS 服务器地址。

**格式**: `nats://<host>:<port>`

**示例**:
- Docker: `nats://js1-qa1a:4222`
- 生产: `nats://qa1a-nats.example.com:4222`

### --mirror

指定要镜像的源 Stream 名称。

### --subjects (可选)

过滤要镜像的 subjects。如果不指定，会镜像源 Stream 的所有 subjects。

## 端口映射

| 服务 | 客户端端口 | HTTP 监控 | 集群通信 |
|------|-----------|-----------|----------|
| js1-qa1a | 16222 | 18222 | 17222 |
| js2-qa1a | 16223 | 18223 | 17223 |
| js3-qa1a | 16224 | 18224 | 17224 |
| js1-qa1b | 16232 | 18232 | 17232 |
| js2-qa1b | 16233 | 18233 | 17233 |
| js3-qa1b | 16234 | 18234 | 17234 |

## 手动操作

### 查看 Stream 列表

```bash
# qa1a
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream ls

# qa1b
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream ls
```

### 查看 Stream 详情

```bash
# Source Stream
docker exec -i nats-box-qa1a nats --server nats://app:app@js1-qa1a:4222 stream info qa

# Mirror Stream
docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info qa_mirror_qa1a
```

### 查看 HTTP 监控

```bash
# qa1a
curl -s "http://localhost:18222/jsz?streams=qa&config=1&state=1" | python3 -m json.tool

# qa1b
curl -s "http://localhost:18232/jsz?streams=qa_mirror_qa1a&config=1&state=1" | python3 -m json.tool
```

## 故障排查

### Mirror 不同步

1. **检查网络连接**
   ```bash
   docker exec -i nats-box-qa1b ping js1-qa1a
   ```

2. **检查 Mirror 配置**
   ```bash
   docker exec -i nats-box-qa1b nats --server nats://app:app@js1-qa1b:4222 stream info qa_mirror_qa1a
   ```

3. **检查日志**
   ```bash
   docker logs js1-qa1b
   ```

### 常见错误

- **"no servers available"**: 源集群不可达，检查网络和端口
- **"stream not found"**: Source Stream 未创建
- **"authorization violation"**: 账号密码不匹配

## 生产环境配置

### 使用 TLS

```conf
# 在 js1.conf 中添加
tls {
  cert_file: "/path/to/cert.pem"
  key_file: "/path/to/key.pem"
  ca_file: "/path/to/ca.pem"
}
```

### 使用外部域名

```bash
# Mirror 配置
nats stream add qa_mirror_qa1a \
  --mirror "qa" \
  --external "nats://qa1a-nats.example.com:4222" \
  --storage file \
  --replicas 3
```

## 目录结构

```
external-mirror-qa1a-to-qa1b/
├── README.md
├── QUICKSTART.md
├── zone-qa1a/
│   ├── allinone.yml
│   ├── js1.conf
│   ├── js2.conf
│   └── js3.conf
├── zone-qa1b/
│   ├── allinone.yml
│   ├── js1.conf
│   ├── js2.conf
│   └── js3.conf
└── scripts/
    ├── create-network.sh
    ├── start-all.sh
    ├── stop-all.sh
    ├── setup-mirror.sh
    ├── producer.sh
    ├── consumer.sh
    └── verify.sh
```

## 参考资料

- [NATS JetStream Mirror Documentation](https://docs.nats.io/using-nats/jetstream/streams/mirrors)
- [NATS External API](https://docs.nats.io/using-nats/jetstream/streams/external)
