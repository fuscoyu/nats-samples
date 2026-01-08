# AGENTS.md - NATS Cluster Samples

## Overview

This repository contains NATS cluster configuration examples and verification scripts for various NATS JetStream deployment patterns. The codebase is primarily shell scripts (`.sh`), Python scripts (`.py`), Docker Compose files (`.yml`), and NATS configuration templates (`.conf`, `.j2`).

**Primary Language**: Shell scripts (Bash)  
**Secondary**: Python (Jinja2 template generation)  
**Configuration**: YAML, NATS config files

---

## Build/Test/Commands

### Quick Start Commands

```bash
# Navigate to specific scenario directory
cd nats-cluster/dual-source-dual-mirror/scripts
cd nats-cluster/region-mirror-verification/scripts
cd nats-cluster/allinone

# Make scripts executable (one-time setup)
chmod +x *.sh

# Start all services
./start-all.sh

# Stop all services
./stop-all.sh
```

### Running Tests/Verification

**For dual-source-dual-mirror scenario:**
```bash
cd nats-cluster/dual-source-dual-mirror/scripts

# 1. Start environment
./start-all.sh

# 2. Send test messages (Terminal 1 & 2)
./producer-qa1a.sh 1 50 0.1
./producer-qa1b.sh 1 50 0.1

# 3. Start consumers (Terminal 3-6)
./consumer-qa1a.sh > consumer-qa1a.log 2>&1 &
./consumer-qa1a-mirror.sh > consumer-qa1a-mirror.log 2>&1 &
./consumer-qa1b.sh > consumer-qa1b.log 2>&1 &
./consumer-qa1b-mirror.sh > consumer-qa1b-mirror.log 2>&1 &

# 4. Run verification
./verify.sh

# 5. Run scenario test
./scenario1-verify.sh
```

**For region-mirror-verification scenario:**
```bash
cd nats-cluster/region-mirror-verification/scripts

./start-all.sh
./producer.sh 1 100 0.1
./consumer-a.sh > consumer-a.log 2>&1 &
./consumer-b.sh > consumer-b.log 2>&1 &
./verify.sh
```

### Network Partition Testing

```bash
# Disconnect network
./network-partition.sh disconnect

# Check status
./network-partition.sh status

# Reconnect
./network-partition.sh connect
```

### Distributed Cluster Generation

```bash
cd nats-cluster

# Install dependencies
pip install -r requirements.txt

# Generate all node configurations
python3 generate.py all

# Generate specific node
python3 generate.py node --node node1

# Clean generated configs
python3 generate.py clean
```

### View NATS Stream Status

```bash
# Using NATS CLI (requires nats CLI tool installed)
nats --server nats://localhost:16222 stream info qa
nats --server nats://localhost:16222 stream info qa_mirror_qa1b

# Using HTTP monitoring endpoint
curl -s "http://localhost:18222/jsz?streams=qa&config=1&state=1" | python3 -m json.tool
```

### Docker Operations

```bash
# View all containers
docker ps

# View logs
docker compose -f ./nats-cluster/allinone/allinone.yml logs
docker logs <container-name>

# Check container network
docker inspect <container-name> | grep -A6 LogConfig

# Execute NATS CLI in container
docker exec -i nats-box-qa1a nats --server nats://js1-qa1a:4222 stream ls
```

---

## Code Style Guidelines

### Shell Scripts (Bash)

#### Shebang and Error Handling
```bash
#!/bin/bash
set -e  # Exit on error
set -u  # Exit on undefined variable
```

#### Color Output (Consistent across all scripts)
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
```

#### Function Naming
- Use `snake_case` for function names
- Prefix with action or purpose: `check_status()`, `disconnect_network()`, `extract_seqs()`
- Always include `local` keyword for variables in functions

```bash
check_status() {
    local container_name=$1
    echo -e "${YELLOW}Checking $container_name...${NC}"
}
```

#### Variable Naming
- **Constants**: UPPERCASE with underscores: `ZONE_QA1A_SERVERS`, `NETWORK_NAME`
- **Local variables**: lowercase with underscores: `seq_file`, `consumer_name`, `timestamp`
- **Parameters**: lowercase: `$1`, `$2` accessed as meaningful names

#### String Formatting
- Use `echo -e` for color output
- Quote all variables: `"$variable"`
- Use `${VAR}` for complex expansions: `"${VAR:-default}"`

#### Error Messages
```bash
echo -e "${RED}错误: docker 未安装。请安装 Docker。${NC}" >&2
echo -e "${YELLOW}警告: 无法连接到服务器，但继续...${NC}"
echo -e "${GREEN}✓ 检查通过${NC}"
```

#### JSON Processing
```bash
# Extract fields from JSON logs
grep -o '"seq":[0-9]*' "$log_file" | sed 's/"seq"://' | sort -n > "$output_file"

# Pretty print JSON
curl -s "http://localhost:8222/jsz" | python3 -m json.tool
```

#### Loop Patterns
```bash
# Number sequences
for i in $(seq $START $END); do
    # body
done

# Array iteration
for container in "${ZONE_QA1B_CONTAINERS[@]}"; do
    # body
done

# File reading
while IFS= read -r line; do
    # body
done < "$input_file"
```

#### Cleanup and Traps
```bash
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
```

### Python Code

#### Imports (Order)
```python
from pathlib import Path
from typing import Dict, Any
import argparse
import yaml
from jinja2 import Environment, FileSystemLoader
```

#### Type Hints
```python
def load_yaml_config(path: Path) -> Dict[str, Any]:
    """Load YAML config and normalize nodes."""
    ...
```

#### Function Naming
- `snake_case` for functions: `load_yaml_config`, `create_jinja_env`, `render_template_file`
- `CamelCase` for classes (if any)

#### Constants
```python
DEFAULT_JS_PORT = 16222
DEFAULT_NATS_PORT = 16223
DEFAULT_MAX_MEM = "1Gb"
```

#### Error Handling
```python
if not path.exists():
    raise FileNotFoundError(f"config.yml not found at {path}")

if not data:
    raise ValueError("Empty config.yml")

# Validate inputs
if not ip:
    raise ValueError(f"node {name} missing ip")
```

#### Docstrings
```python
def render_template_file(env: Environment, template_name: str, context: Dict[str, Any], output_path: Path) -> str:
    """
    Render a single template with context and write to output_path.
    Returns rendered text.
    """
    ...
```

### YAML/Docker Compose Files

#### Indentation
- 2 spaces for indentation
- Consistent throughout

#### Port Mapping Format
```yaml
ports:
  - "14222:4222"   # Client connection
  - "18222:8222"   # HTTP monitoring
  - "16222:6222"   # Cluster communication
```

#### Logging Configuration
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "20m"
    max-file: "5"
```

#### Volume Mounts
```yaml
volumes:
  - ./js1.conf:/etc/nats/nats.conf:ro
  - ./data/js1:/data
```

### Jinja2 Templates (.j2)

#### Template Variables
```jinja2
{{ ports.jetstream }}
{{ node.ip }}
{{ current_node }}
```

#### Conditional Logic
```jinja2
{% if node.jetstream %}
# JetStream config here
{% endif %}
```

#### Loops
```jinja2
{% for name, node in nodes.items() %}
# Node {{ name }}
{% endfor %}
```

#### Whitespace Control
- Use `trim_blocks=True` and `lstrip_blocks=True` in Python
- Templates use `{{-` and `-}}` for trimming if needed

### NATS Configuration Files (.conf)

#### Basic Structure
```conf
# NATS Server Configuration
server_name: "js1"
port: 4222
http_port: 8222

cluster {
  name: "JS-CLUSTER"
  port: 6222
  routes: [
    "nats://js1:6222",
    "nats://js2:6222",
    "nats://js3:6222"
  ]
}

jetstream {
  store_dir: "/data"
  max_mem: 1Gb
  max_file: 10Gb
}

authorization {
  user: "admin"
  password: "admin"
}
```

---

## File Naming Conventions

### Scripts
- `start-all.sh` - Start all services
- `stop-all.sh` - Stop all services
- `producer-<zone>.sh` - Producer for specific zone
- `consumer-<zone>.sh` - Consumer for specific zone
- `consumer-<zone>-mirror.sh` - Mirror consumer
- `verify.sh` - Verification script
- `network-partition.sh` - Network partition simulation
- `scenario-<num>-verify.sh` - Scenario-specific verification

### Config Files
- `config.yml` - Distributed cluster configuration
- `allinone.yml` - All-in-one docker compose
- `js1.conf`, `nats1.conf` - Server configurations
- `docker-compose.yml.j2` - Jinja2 template

### Logs
- `consumer-<name>.log` - Consumer output logs
- `scenario<#>_results.txt` - Test results

---

## Error Handling Patterns

### Shell Scripts
1. **Exit on error**: `set -e`
2. **Check prerequisites**: `command -v docker &> /dev/null`
3. **Validate connections**: `docker network inspect "$NETWORK_NAME" &> /dev/null`
4. **Graceful degradation**: `2>/dev/null || true`
5. **Error messages to stderr**: `>&2`

### Python Scripts
1. **File existence**: `if not path.exists(): raise FileNotFoundError()`
2. **Data validation**: `if not data: raise ValueError()`
3. **Type checking**: `isinstance(val, dict)`
4. **Missing keys**: `val.get("ip")` with defaults

### Docker Compose
1. **Restart policies**: `restart: unless-stopped`
2. **Volume permissions**: Use `:ro` for read-only configs
3. **Port conflicts**: Document port ranges used
4. **Logging limits**: Prevent disk space issues

---

## Testing Strategy

### Unit Testing
- Python modules: Use `pytest` if needed (not currently present)
- Test `load_yaml_config()` with various YAML inputs
- Test `render_template_file()` output correctness

### Integration Testing
- Shell scripts provide end-to-end testing
- `verify.sh` scripts check message integrity
- Network partition scripts test resilience

### Manual Verification
- Check stream info: `nats stream info <name>`
- Monitor HTTP endpoints: `curl http://localhost:8222/jsz`
- View logs: `docker logs <container>`

---

## Common Patterns

### Port Allocation
- **JetStream clients**: 14222-14227, 16222-16227
- **NATS clients**: 14223-14228, 16223-16228
- **HTTP monitoring**: 18222-18227
- **Cluster ports**: 16222-16227 (JetStream), 16223-16228 (NATS)

### Network Names
- `nats-cluster` - All-in-one scenarios
- `dual-source-dual-mirror-network` - Dual mirror scenarios

### Container Naming
- `js1`, `js2`, `js3` - JetStream nodes
- `n1`, `n2`, `n3` - Standard NATS nodes
- `js1-qa1a`, `js1-qa1b` - Zone-specific nodes
- `nats-box-qa1a` - NATS CLI container

### Stream Naming
- **Source**: `qa` (region_id)
- **Mirror**: `qa_mirror_qa1a`, `qa_mirror_qa1b` (mirror of other zone)

---

## Dependencies

### Required Tools
- Docker & Docker Compose
- Python 3.x
- NATS CLI (`nats` command)

### Python Packages
```bash
pip install -r nats-cluster/requirements.txt
# Contains:
# - Jinja2>=3.0
# - PyYAML>=5.4
```

---

## Documentation

### README Files
- `README.md` - Detailed architecture and usage
- `QUICKSTART.md` - Quick start guide
- `AGENTS.md` - This file (for AI agents)

### Comments
- Shell: Use `#` for section headers and explanations
- Python: Use docstrings for functions
- YAML: Use comments for configuration explanations
- NATS config: Use `#` for server settings

---

## Agent-Specific Notes

### When Making Changes
1. **Check existing patterns**: Look at similar scripts in the same directory
2. **Maintain consistency**: Follow the color codes, error handling, and naming
3. **Test thoroughly**: Run `verify.sh` after changes
4. **Update documentation**: Update README if adding new scenarios

### Adding New Scenarios
1. Create directory: `nats-cluster/<scenario-name>/`
2. Add `scripts/` directory with shell scripts
3. Add `zone-*/` directories with docker-compose and configs
4. Include `README.md` and `QUICKSTART.md`
5. Follow existing script patterns for producers/consumers

### Debugging
1. Check container logs: `docker logs <container-name>`
2. Verify network: `docker network inspect <network-name>`
3. Test connectivity: `docker exec <container> ping <other-container>`
4. Check stream state: `curl http://localhost:8222/jsz`

---

## Git Workflow

### Before Committing
1. Clean up generated files: `python3 generate.py clean`
2. Remove log files: `rm *.log` in script directories
3. Check for secrets: `grep -r "password\|secret" .`
4. Verify scripts are executable: `chmod +x *.sh`

### Commit Messages
- Use English or Chinese consistently
- Be descriptive: "Add dual-source-dual-mirror verification scenario"
- Reference issues if applicable

---

## Performance Considerations

### Docker Resource Limits
- Log rotation: 20MB per file, 5 files max
- JetStream memory: 1Gb default
- JetStream file store: 10Gb default

### Script Execution
- Use `sleep` for waiting on services
- Use `&` for background processes
- Use `wait` for parallel operations
- Use `timeout` for long-running commands

---

## Security Notes

### Credentials
- Default credentials: `admin/admin`
- Never commit real credentials
- Use environment variables for sensitive data

### Network Exposure
- All ports are documented
- Use host networking only when necessary
- Container networks are isolated by default

### File Permissions
- Config files: `:ro` (read-only) in volumes
- Data directories: Created by Docker with default permissions
- Scripts: `chmod +x` required

---

## Troubleshooting

### Common Issues
1. **Port conflicts**: Check if ports 14222-16227 are free
2. **Network not found**: Run `create-network.sh` first
3. **Container not starting**: Check Docker logs
4. **Mirror not syncing**: Check network partition status
5. **Missing messages**: Run `verify.sh` to identify gaps

### Quick Fixes
```bash
# Reset everything
./stop-all.sh
docker system prune -f
./start-all.sh

# Check what's running
docker ps | grep -E "js|nats|qa"

# View all logs
docker compose logs -f
```

---

## References

- NATS Documentation: https://docs.nats.io/
- NATS CLI: https://github.com/nats-io/natscli
- NATS JetStream: https://docs.nats.io/using-nats/jetstream
- Docker Compose: https://docs.docker.com/compose/

---

**Last Updated**: 2026-01-08  
**Maintainer**: Repository owner  
**Version**: 1.0
