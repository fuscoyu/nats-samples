# 快速开始指南

## 验证 4 个结论的快速流程

### 1. 启动环境

```bash
cd nats-cluster/region-mirror-verification/scripts
./start-all.sh
```

### 2. 验证结论 1：跨 Zone 网络断开，不影响本 Zone 消费

```bash
# 终端 1: 启动 Producer
./producer.sh 1 100 0.1

# 终端 2: 启动 Consumer-A
./consumer-a.sh > consumer-a.log 2>&1 &

# 终端 3: 启动 Consumer-B
./consumer-b.sh > consumer-b.log 2>&1 &

# 等待消息同步后，拉闸
./network-partition.sh disconnect

# 继续发送消息
./producer.sh 101 200 0.1

# 观察：Consumer-A 继续消费，Consumer-B 停止
```

### 3. 验证结论 2：网络恢复后，不丢、不重、能补

```bash
# 在断网状态下发送消息
./producer.sh 201 300 0.1

# 恢复网络
./network-partition.sh connect

# 继续发送消息
./producer.sh 301 400 0.1

# 停止 Consumer（Ctrl+C），然后验证
./verify.sh
```

### 4. 验证结论 3：各 Zone 消费进度彼此独立

```bash
# 发送消息
./producer.sh 1 100 0.1

# Consumer-A 消费 1-50 后暂停（Ctrl+C）
# Consumer-B 继续消费 1-100

# Consumer-A 恢复消费
./consumer-a.sh > consumer-a.log 2>&1 &

# 验证两个 Consumer 的进度独立
tail -f consumer-a.log
tail -f consumer-b.log
```

### 5. 验证结论 4：Region 扩展 Zone，不需要改生产者

```bash
# Producer 配置不变，继续发送
./producer.sh 1 50 0.1

# 新增 Zone C（参考 README.md 中的步骤）
# Producer 配置无需修改，继续发送
./producer.sh 51 100 0.1

# 验证三个 Zone 都能消费
```

### 清理

```bash
./stop-all.sh
```

