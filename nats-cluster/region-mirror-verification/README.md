# Region 级 Mirror/Source 验证方案

本方案用于验证 Region 级事件使用 Mirror/Source 的 4 个关键结论，确保在测试环境中可以运行、拉闸验证，并获得可说服他人的结果。

## 验证目标

验证 4 个关键结论：

1. **跨 Zone 网络断开时，不影响本 Zone 消费**
2. **网络恢复后，不丢、不重、能补**
3. **各 Zone 消费进度彼此独立**
4. **Region 扩展 Zone，不需要改生产者**

## 拓扑设计

### 架构图

```
Zone A (Source Zone)              Zone B (Mirror Zone)
┌─────────────────┐              ┌─────────────────┐
│  js1-zone-a     │              │  js1-zone-b     │
│  js2-zone-a     │◄──Mirror─────│  js2-zone-b     │
│  js3-zone-a     │   (client)   │  js3-zone-b     │
└─────────────────┘              └─────────────────┘
       ▲                                  ▲
       │                                  │
   Producer                          Consumer-B
   Consumer-A
```

### 最小拓扑

- **Zone A (Source Zone)**：3 个 JetStream 节点（js1-zone-a, js2-zone-a, js3-zone-a）
  - 创建 Source Stream: `EVENTS.REGION`
  - 生产者连接到此 Zone
  - Consumer-A 消费此 Zone

- **Zone B (Mirror Zone)**：3 个 JetStream 节点（js1-zone-b, js2-zone-b, js3-zone-b）
  - 创建 Mirror Stream: `EVENTS.REGION`（镜像 Zone A 的流）
  - Mirror 通过客户端连接访问 Zone A
  - Consumer-B 消费此 Zone

### 技术约束

- **不使用** Gateway / Supercluster
- **只使用**：
  - JetStream
  - Mirror
  - 普通 Consumer

## 快速开始

### 前置要求

- Docker 和 Docker Compose
- NATS CLI 工具（`nats` 命令）
  - 安装方法: https://github.com/nats-io/natscli

### 启动环境

**方式一：一键启动（推荐）**

```bash
cd nats-cluster/region-mirror-verification/scripts
chmod +x *.sh
./start-all.sh
```

**方式二：手动启动**

1. **创建共享网络**

```bash
cd nats-cluster/region-mirror-verification
./scripts/create-network.sh
```

2. **启动 Zone A**

```bash
cd zone-a
docker compose -f allinone.yml up -d
```

3. **启动 Zone B**

```bash
cd zone-b
docker compose -f allinone.yml up -d
```

4. **创建 Stream 和 Mirror**

```bash
cd ../scripts
chmod +x *.sh
./setup.sh
```

### 验证步骤

#### 结论 1：跨 Zone 网络断开，不影响本 Zone 消费

**验证步骤**：

1. 启动 Producer（发送消息到 Zone A）
```bash
./producer.sh 1 100 0.1  # 发送消息 1-100，间隔 0.1 秒
```

2. 启动 Consumer-A（消费 Zone A）
```bash
./consumer-a.sh > consumer-a.log 2>&1 &
```

3. 启动 Consumer-B（消费 Zone B）
```bash
./consumer-b.sh > consumer-b.log 2>&1 &
```

4. 等待消息正常同步和消费（观察日志）

5. **拉闸**：断开 Zone B 到 Zone A 的网络连接
```bash
./network-partition.sh disconnect
```

6. 继续发送消息到 Zone A
```bash
./producer.sh 101 200 0.1
```

7. 观察 Consumer-A 和 Consumer-B 的行为

**预期结果**：
- ✅ Consumer-A 继续正常消费 Zone A 的消息（101-200）
- ✅ Consumer-B 停止接收新消息（因为 Mirror 无法连接 Source）
- ✅ Zone B 的 Mirror Stream 状态显示连接失败

**验证命令**：
```bash
# 检查网络状态
./network-partition.sh status

# 检查 Stream 状态
nats --server nats://admin:admin@localhost:15222 stream info EVENTS.REGION
nats --server nats://admin:admin@localhost:15232 stream info EVENTS.REGION
```

#### 结论 2：网络恢复后，不丢、不重、能补

**验证步骤**：

1. 在断网状态下，Producer 发送消息 201-300
```bash
./producer.sh 201 300 0.1
```

2. **恢复网络**：恢复 Zone B 到 Zone A 的连接
```bash
./network-partition.sh connect
```

3. 等待 Mirror 同步完成（观察日志，通常几秒内完成）

4. Producer 继续发送消息 301-400
```bash
./producer.sh 301 400 0.1
```

5. Consumer-B 恢复消费（应该自动恢复）

6. 停止所有 Consumer（Ctrl+C）

7. 检查消息完整性
```bash
./verify.sh
```

**预期结果**：
- ✅ Consumer-B 能消费到消息 201-400（不丢）
- ✅ 每条消息只消费一次（不重）
- ✅ 消息顺序正确（能补）

**验证命令**：
```bash
# 验证消息完整性
./verify.sh

# 查看消费日志
cat consumer-a.log | grep seq
cat consumer-b.log | grep seq
```

#### 结论 3：各 Zone 消费进度彼此独立

**验证步骤**：

1. Producer 发送消息 1-100
```bash
./producer.sh 1 100 0.1
```

2. Consumer-A 消费消息 1-50 后暂停（Ctrl+C）

3. Consumer-B 继续消费消息 1-100

4. Consumer-A 恢复消费，继续消费 51-100
```bash
./consumer-a.sh > consumer-a.log 2>&1 &
```

5. 等待消费完成

6. 检查两个 Consumer 的消费进度

**预期结果**：
- ✅ Consumer-A 和 Consumer-B 的消费进度独立
- ✅ Consumer-A 暂停不影响 Consumer-B
- ✅ 两个 Consumer 可以有不同的消费速度

**验证命令**：
```bash
# 检查 Consumer 状态
nats --server nats://admin:admin@localhost:15222 consumer info EVENTS.REGION consumer-a
nats --server nats://admin:admin@localhost:15232 consumer info EVENTS.REGION consumer-b

# 查看消费进度
tail -f consumer-a.log
tail -f consumer-b.log
```

#### 结论 4：Region 扩展 Zone，不需要改生产者

**验证步骤**：

1. Producer 已配置连接 Zone A（配置不变）
```bash
./producer.sh 1 50 0.1
```

2. 新增 Zone C（Mirror Zone）- 参考 Zone B 的配置
   - 创建 `zone-c/` 目录
   - 复制 Zone B 的配置文件
   - 修改端口和容器名称
   - 配置 Mirror Stream（镜像 Zone A）

3. 启动 Zone C
```bash
cd zone-c
docker compose -f allinone.yml up -d
```

4. 创建 Zone C 的 Mirror Stream
```bash
cd ../scripts
# 修改 setup.sh 添加 Zone C 的 Mirror Stream 创建逻辑
# 或手动创建：
nats --server nats://admin:admin@localhost:15242 stream add EVENTS.REGION \
    --mirror EVENTS.REGION \
    --mirror-external-api "nats://admin:admin@js1-zone-a:4222" \
    --mirror-external-deliver "nats://admin:admin@js1-zone-a:4222" \
    --storage file \
    --replicas 3 \
    --yes
```

5. 启动 Consumer-C
```bash
# 创建 consumer-c.sh（参考 consumer-b.sh）
./consumer-c.sh > consumer-c.log 2>&1 &
```

6. Producer 继续发送消息（配置不变）
```bash
./producer.sh 51 100 0.1
```

7. 验证三个 Zone 都能消费

**预期结果**：
- ✅ Producer 配置无需修改
- ✅ Zone C 的 Mirror 自动同步消息
- ✅ Consumer-C 能正常消费

**验证命令**：
```bash
# 检查三个 Zone 的 Stream 状态
nats --server nats://admin:admin@localhost:15222 stream info EVENTS.REGION
nats --server nats://admin:admin@localhost:15232 stream info EVENTS.REGION
nats --server nats://admin:admin@localhost:15242 stream info EVENTS.REGION

# 验证消息完整性
./verify.sh
```

## 脚本说明

### start-all.sh / stop-all.sh
一键启动/停止所有服务

### setup.sh
创建 Source Stream 和 Mirror Stream

### producer.sh
向 Zone A 发送带序号的消息
```bash
./producer.sh [起始序号] [结束序号] [间隔秒数]
```

### consumer-a.sh / consumer-b.sh
从各自 Zone 消费消息并记录到日志文件

### network-partition.sh
网络分区控制脚本
```bash
./network-partition.sh disconnect  # 断开网络
./network-partition.sh connect     # 恢复网络
./network-partition.sh status      # 检查状态
```

### verify.sh
验证消息完整性（不丢、不重、能补）
```bash
./verify.sh
```

## 清理环境

**方式一：一键停止（推荐）**

```bash
cd nats-cluster/region-mirror-verification/scripts
./stop-all.sh
```

**方式二：手动停止**

```bash
# 停止 Zone A
cd zone-a
docker compose -f allinone.yml down

# 停止 Zone B
cd ../zone-b
docker compose -f allinone.yml down

# 删除网络（可选）
docker network rm region-mirror-network
```

## 故障排查

### Mirror Stream 无法连接 Source

1. 检查网络连接
```bash
./network-partition.sh status
```

2. 检查 Zone A 是否可访问
```bash
nats --server nats://admin:admin@localhost:15222 server ping
```

3. 检查 Mirror Stream 配置
```bash
nats --server nats://admin:admin@localhost:15232 stream info EVENTS.REGION
```

### 消息丢失或重复

1. 检查 Stream 配置（dupe-window）
2. 检查网络分区状态
3. 使用 verify.sh 验证消息完整性

## 参考

- NATS JetStream 文档: https://docs.nats.io/nats-concepts/jetstream
- Mirror/Source 文档: https://docs.nats.io/nats-concepts/jetstream/mirrors_and_sources

