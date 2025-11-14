services:
  js1:
    image: nats:2.12.2
    container_name: js1
    command: ["-c", "/etc/nats/nats.conf"]
    volumes:
      - ./js1.conf:/etc/nats/nats.conf:ro
      - ./data/js1:/data
    ports:
      - "14222:4222"
      - "16222:6222"
      - "18222:8222"
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "20m"
        max-file: "5"

  n1:
    image: nats:2.12.2
    container_name: n1
    command: ["-c", "/etc/nats/nats.conf"]
    volumes:
      - ./nats1.conf:/etc/nats/nats.conf:ro
    ports:
      - "14223:4222"
      - "16223:6222"
      - "18223:8222"
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "20m"
        max-file: "5"

  networks:
    default:
      name: nats-cluster