#!/usr/bin/env python3
# generate.py
import argparse
from pathlib import Path
from nats_cluster_gen import renderer

# locations (adjust if needed)
DISTRIBUTED = Path("distributed")
TEMPLATES_DIR = DISTRIBUTED / "templates"
CONFIG_FILE = DISTRIBUTED / "config.yml"
OUTPUT_BASE = DISTRIBUTED  # will produce node directories here

def cmd_all(config_path: Path):
    cfg = renderer.load_yaml_config(config_path)
    nodes = cfg["nodes"]
    ports = cfg["ports"]
    env = renderer.create_jinja_env(TEMPLATES_DIR)
    for name, nd in nodes.items():
        ctx = {
            "current_node": name,
            "node": nd,
            "nodes": nodes,
            "ports": ports,
        }
        out_dir = OUTPUT_BASE / name
        renderer.render_template_file(env, "js.conf.j2", ctx, out_dir / "js.conf")
        renderer.render_template_file(env, "nats.conf.j2", ctx, out_dir / "nats.conf")
        renderer.render_template_file(env, "docker-compose.yml.j2", ctx, out_dir / "docker-compose.yml")
        print(f"[OK] generated {out_dir}")

def cmd_node(config_path: Path, node_name: str):
    cfg = renderer.load_yaml_config(config_path)
    nodes = cfg["nodes"]
    ports = cfg["ports"]
    if node_name not in nodes:
        raise SystemExit(f"node {node_name} not found in config")
    env = renderer.create_jinja_env(TEMPLATES_DIR)
    nd = nodes[node_name]
    ctx = {"current_node": node_name, "node": nd, "nodes": nodes, "ports": ports}
    out_dir = OUTPUT_BASE / node_name
    renderer.render_template_file(env, "js.conf.j2", ctx, out_dir / "js.conf")
    renderer.render_template_file(env, "nats.conf.j2", ctx, out_dir / "nats.conf")
    renderer.render_template_file(env, "docker-compose.yml.j2", ctx, out_dir / "docker-compose.yml")
    print(f"[OK] generated {out_dir}")

def cmd_clean():
    for p in DISTRIBUTED.iterdir():
        if p.is_dir() and p.name.startswith("node"):
            import shutil
            shutil.rmtree(p)
            print(f"[CLEAN] removed {p}")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["all", "node", "clean"])
    p.add_argument("--node", help="node name for action 'node' (e.g. node1)")
    p.add_argument("--config", default=str(CONFIG_FILE), help="path to config.yml")
    args = p.parse_args()

    config_path = Path(args.config)
    if args.action == "all":
        cmd_all(config_path)
    elif args.action == "node":
        if not args.node:
            raise SystemExit("Please pass --node NODE_NAME")
        cmd_node(config_path, args.node)
    else:
        cmd_clean()

if __name__ == "__main__":
    main()