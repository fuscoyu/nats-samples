#!/usr/bin/env bash
set -e

source .env
NODE="$1"

if [[ -z "$NODE" ]]; then
  echo "Usage: ./generate.sh node1"
  exit 1
fi

eval NODE_IP=\$${NODE^^}_IP

generate_nats_routes() {
  routes=""
  # same node's JetStream container
  routes+="    nats://${NODE_IP}:16222\n"
  for n in node1 node2 node3; do
    ipvar="${n^^}_IP"
    eval ip=\$$ipvar
    # skip itself
    if [[ "$ip" != "$NODE_IP" ]]; then
      routes+="    nats://${ip}:16223\n"
    fi
  done
  echo -e "$routes"
}
NATS_ROUTES=$(generate_nats_routes)

generate_js_routes() {
  routes=""
  # JetStream containers on all nodes
  for n in node1 node2 node3; do
    ipvar="${n^^}_IP"
    eval ip=\$$ipvar
    # skip itself
    if [[ "$ip" != "$NODE_IP" ]]; then
      routes+="    nats://${ip}:16222\n"
    fi
  done
  # same node's NATS container
  routes+="    nats://${NODE_IP}:16223\n"
  echo -e "$routes"
}
JS_ROUTES=$(generate_js_routes)

OUT_DIR="./${NODE}"

export NODE_NAME="$NODE"
export NODE_IP="$NODE_IP"
export NATS_ROUTES
export JS_ROUTES

# NATS_ROUTES="$NATS_ROUTES"
envsubst '${NODE_NAME} ${NODE_IP} ${NATS_ROUTES}' \
  < templates/nats.conf.tpl \
  > "${OUT_DIR}/nats.conf"

# JS_ROUTES="$JS_ROUTES"
envsubst '${NODE_NAME} ${NODE_IP} ${JS_ROUTES}' \
  < templates/js.conf.tpl \
  > "${OUT_DIR}/js.conf"

envsubst '${NODE_NAME} ${NODE_IP}' \
  < templates/docker-compose.yml.tpl \
  > "${OUT_DIR}/docker-compose.yml"

echo "Generated config for $NODE"
