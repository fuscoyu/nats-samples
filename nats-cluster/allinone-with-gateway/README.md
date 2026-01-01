## All-in-One with Gateway NATS JetStream 集群

```shell
# 创建集群
docker compose -f ./nats-cluster/allinone-with-gateway/cluster1/allinone.yml up
docker compose -f ./nats-cluster/allinone-with-gateway/cluster2/allinone.yml up

# 拉起使用容器网络的容器环境进行测试
docker run -it --rm --network nats-cluster natsio/nats-box:latest
#nats --server nats://c1-js1:4222 --user admin --password admin server report jetstream
nats context add c1 --server nats://c1-js1:4222,nats://c1-js2:4223,nats://c1-js3:4224
nats context add c2 --server nats://c2-js1:4222,nats://c2-js2:4223,nats://c2-js3:4224
nats context select c1 
nats --user admin --password admin server report health

╭───────────────────────────────────────────────────────────╮
│                       Health Report                       │
├────────┬─────────┬────────┬────────────────┬──────┬───────┤
│ Server │ Cluster │ Domain │ Status         │ Type │ Error │
├────────┼─────────┼────────┼────────────────┼──────┼───────┤
│ c1-js1 │ C1      │        │ ok (200)       │      │       │
│ c1-js2 │ C1      │        │ ok (200)       │      │       │
│ c1-js3 │ C1      │        │ ok (200)       │      │       │
│ c2-js1 │ C2      │        │ ok (200)       │      │       │
│ c2-js2 │ C2      │        │ ok (200)       │      │       │
│ c2-js3 │ C2      │        │ ok (200)       │      │       │
├────────┼─────────┼────────┼────────────────┼──────┼───────┤
│ 6      │ 2       │        │ ok: 6 / err: 0 │      │     0 │
╰────────┴─────────┴────────┴────────────────┴──────┴───────╯

nats --user admin --password admin server report jetstream

╭────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                        JetStream Summary                                       │
├─────────┬─────────┬─────────┬───────────┬──────────┬───────┬────────┬──────┬─────────┬─────────┤
│ Server  │ Cluster │ Streams │ Consumers │ Messages │ Bytes │ Memory │ File │ API Req │ Pending │
├─────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│ c1-js1* │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c1-js2  │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c1-js3  │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js1  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js2  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js3  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
├─────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│         │         │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
╰─────────┴─────────┴─────────┴───────────┴──────────┴───────┴────────┴──────┴─────────┴─────────╯

╭───────────────────────────────────────────────────────────────────────╮
│                      RAFT Meta Group Information                      │
├─────────────────┬──────────┬────────┬─────────┬────────┬────────┬─────┤
│ Connection Name │ ID       │ Leader │ Current │ Online │ Active │ Lag │
├─────────────────┼──────────┼────────┼─────────┼────────┼────────┼─────┤
│ c1-js1          │ vMkaN1q2 │ yes    │ true    │ true   │ 0s     │ 0   │
│ c1-js2          │ DPkt7us1 │        │ true    │ true   │ 989ms  │ 0   │
│ c1-js3          │ WYRreldn │        │ true    │ true   │ 989ms  │ 0   │
│ c2-js1          │ vj3GHpUd │        │ true    │ true   │ 989ms  │ 0   │
│ c2-js2          │ GyCdAJh8 │        │ true    │ true   │ 988ms  │ 0   │
│ c2-js3          │ S81RuaKa │        │ true    │ true   │ 988ms  │ 0   │
╰─────────────────┴──────────┴────────┴─────────┴────────┴────────┴─────╯

nats context select c2

nats --user admin --password admin server report health

╭───────────────────────────────────────────────────────────╮
│                       Health Report                       │
├────────┬─────────┬────────┬────────────────┬──────┬───────┤
│ Server │ Cluster │ Domain │ Status         │ Type │ Error │
├────────┼─────────┼────────┼────────────────┼──────┼───────┤
│ c1-js1 │ C1      │        │ ok (200)       │      │       │
│ c1-js2 │ C1      │        │ ok (200)       │      │       │
│ c1-js3 │ C1      │        │ ok (200)       │      │       │
│ c2-js1 │ C2      │        │ ok (200)       │      │       │
│ c2-js2 │ C2      │        │ ok (200)       │      │       │
│ c2-js3 │ C2      │        │ ok (200)       │      │       │
├────────┼─────────┼────────┼────────────────┼──────┼───────┤
│ 6      │ 2       │        │ ok: 6 / err: 0 │      │     0 │
╰────────┴─────────┴────────┴────────────────┴──────┴───────╯

nats --user admin --password admin server report jetstream

╭────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                        JetStream Summary                                       │
├─────────┬─────────┬─────────┬───────────┬──────────┬───────┬────────┬──────┬─────────┬─────────┤
│ Server  │ Cluster │ Streams │ Consumers │ Messages │ Bytes │ Memory │ File │ API Req │ Pending │
├─────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│ c1-js1* │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c1-js2  │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c1-js3  │ C1      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js1  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js2  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
│ c2-js3  │ C2      │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
├─────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│         │         │ 0       │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 0       │       0 │
╰─────────┴─────────┴─────────┴───────────┴──────────┴───────┴────────┴──────┴─────────┴─────────╯

╭───────────────────────────────────────────────────────────────────────╮
│                      RAFT Meta Group Information                      │
├─────────────────┬──────────┬────────┬─────────┬────────┬────────┬─────┤
│ Connection Name │ ID       │ Leader │ Current │ Online │ Active │ Lag │
├─────────────────┼──────────┼────────┼─────────┼────────┼────────┼─────┤
│ c1-js1          │ vMkaN1q2 │ yes    │ true    │ true   │ 0s     │ 0   │
│ c1-js2          │ DPkt7us1 │        │ true    │ true   │ 168ms  │ 0   │
│ c1-js3          │ WYRreldn │        │ true    │ true   │ 168ms  │ 0   │
│ c2-js1          │ vj3GHpUd │        │ true    │ true   │ 168ms  │ 0   │
│ c2-js2          │ GyCdAJh8 │        │ true    │ true   │ 168ms  │ 0   │
│ c2-js3          │ S81RuaKa │        │ true    │ true   │ 168ms  │ 0   │
╰─────────────────┴──────────┴────────┴─────────┴────────┴────────┴─────╯

# 销毁集群
docker compose -f ./nats-cluster/allinone-with-gateway/cluster1/allinone.yml down
docker compose -f ./nats-cluster/allinone-with-gateway/cluster2/allinone.yml down
```