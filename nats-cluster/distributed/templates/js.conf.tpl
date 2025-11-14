server_name=js1-c1
port: 4222

accounts {
  $SYS {
    users = [
      { user: "admin",
        pass: "admin"
      }
    ]
  }
}

jetstream {
  store_dir: /data/jetstream
  max_mem_store: 1Gb
  max_file_store: 10Gb
}

cluster {
  name: C1
  listen: 0.0.0.0:6222
  routes: [
${JS_ROUTES}
  ] 
}

monitor_port: 8222