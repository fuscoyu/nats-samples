# nats_cluster_gen/renderer.py
from pathlib import Path
from typing import Dict, Any
import yaml
from jinja2 import Environment, FileSystemLoader

# defaults
DEFAULT_JS_PORT = 16222
DEFAULT_NATS_PORT = 16223
DEFAULT_MAX_MEM = "1Gb"
DEFAULT_MAX_FILE = "10Gb"


def load_yaml_config(path: Path) -> Dict[str, Any]:
    """
    Load YAML config and normalize nodes and global ports.
    Returns a dict: { 'nodes': { name: { ip, jetstream: {max_mem_store, max_file_store}, index } }, 'ports': {jetstream, nats} }
    """
    if not path.exists():
        raise FileNotFoundError(f"config.yml not found at {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not data:
        raise ValueError("Empty config.yml")

    # global ports (top-level)
    ports_raw = data.get("ports", {})
    jetstream_port = ports_raw.get("jetstream", DEFAULT_JS_PORT)
    nats_port = ports_raw.get("nats", DEFAULT_NATS_PORT)
    normalized_ports = {"jetstream": jetstream_port, "nats": nats_port}

    raw_nodes = data.get("nodes", {})
    if not raw_nodes:
        raise ValueError("config.yml must contain 'nodes' mapping")

    nodes: Dict[str, Dict[str, Any]] = {}
    for idx, name in enumerate(sorted(raw_nodes.keys()), start=1):
        val = raw_nodes[name]
        if isinstance(val, str):
            ip = val
            js_cfg = {}
        elif isinstance(val, dict):
            ip = val.get("ip")
            js_cfg = val.get("jetstream", {}) if isinstance(val.get("jetstream", {}), dict) else {}
        else:
            raise ValueError(f"invalid node entry for {name}: must be string or mapping")

        if not ip:
            raise ValueError(f"node {name} missing ip")

        max_mem = js_cfg.get("max_mem_store", DEFAULT_MAX_MEM)
        max_file = js_cfg.get("max_file_store", DEFAULT_MAX_FILE)

        nodes[name] = {
            "ip": ip,
            "jetstream": {
                "max_mem_store": max_mem,
                "max_file_store": max_file,
            },
            "index": idx,
        }

    return {"nodes": nodes, "ports": normalized_ports}


def create_jinja_env(template_dir: Path) -> Environment:
    """
    Create Jinja2 environment with FileSystemLoader pointing to template_dir.
    Register any filters/globals here if needed.
    """
    env = Environment(
        loader=FileSystemLoader(str(template_dir)),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    # Example helper: indent multiline string (if templates want to use)
    def indent_lines(s: str, width: int = 4) -> str:
        if s is None:
            return ""
        pad = " " * width
        return "\n".join(pad + line if line.strip() != "" else line for line in str(s).splitlines())

    env.filters["indent_lines"] = indent_lines
    return env


def render_template_file(env: Environment, template_name: str, context: Dict[str, Any], output_path: Path) -> str:
    """
    Render a single template (loaded by env.get_template(template_name)) with `context`
    and write to output_path. Returns rendered text.
    """
    tpl = env.get_template(template_name)
    rendered = tpl.render(**context)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    return rendered