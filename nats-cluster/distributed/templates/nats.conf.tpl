server_name: n1-c1
port: 4222

accounts {
  $SYS {
    users : [
      { user: "admin",
        pass: "admin"
      }
    ]
  }
}

cluster {
  name: C1
  listen: 0.0.0.0:6222
  routes: [
${NATS_ROUTES}
  ]
}

monitor_port: 8222