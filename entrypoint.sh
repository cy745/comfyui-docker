#!/bin/bash
set -e

# Initialize custom_nodes with default nodes if volume is empty
if [ -d /default_custom_nodes ] && [ ! -z "$(ls -A /default_custom_nodes 2>/dev/null)" ]; then
    for node_dir in /default_custom_nodes/*/; do
        node_name=$(basename "$node_dir")
        target="/app/custom_nodes/$node_name"
        if [ ! -d "$target" ]; then
            echo "Installing default custom node: $node_name"
            cp -r "$node_dir" "$target"
        fi
    done
fi

# Install any pending custom node dependencies (continue on failure)
for node_dir in /app/custom_nodes/*/; do
    name=$(basename "$node_dir")
    if [ -f "$node_dir/requirements.txt" ]; then
        echo "Installing dependencies for $name (requirements.txt)..."
        pip install -r "$node_dir/requirements.txt" -q || echo "Warning: $name deps failed, continuing"
    elif [ -f "$node_dir/pyproject.toml" ]; then
        echo "Installing $name (pyproject.toml)..."
        pip install -e "$node_dir" -q || echo "Warning: $name deps failed, continuing"
    fi
done

# Patch transformers torch.load compat (torch 2.5.1 CVE workaround)
python3 -c "
p = '/usr/local/lib/python3.10/dist-packages/transformers/modeling_utils.py'
with open(p, 'r') as f:
    c = f.read()
c = c.replace(
    'return torch.load(checkpoint_path, map_location=map_location, weights_only=weights_only, **extra_args)',
    'return torch.load(checkpoint_path, map_location=map_location, weights_only=False, **extra_args)'
)
with open(p, 'w') as f:
    f.write(c)
print('applied modeling_utils patch')
" 2>/dev/null || true

python3 -c "
p = '/usr/local/lib/python3.10/dist-packages/transformers/utils/import_utils.py'
with open(p, 'r') as f:
    lines = f.readlines()
new_lines = []
skip = False
for line in lines:
    if 'def check_torch_load_is_safe() -> None:' in line:
        new_lines.append(line)
        new_lines.append('    return None\n')
        skip = True
    elif skip:
        if line.strip().startswith('def ') or line.strip().startswith('class '):
            skip = False
            new_lines.append(line)
    else:
        new_lines.append(line)
with open(p, 'w') as f:
    f.writelines(new_lines)
print('applied import_utils patch')
" 2>/dev/null || true

# Download LSNet model files if missing
echo "Checking LSNet models..."
LS_DIR="/app/models/lsnet/sharingan"
mkdir -p "$LS_DIR"
BASE_URL="https://huggingface.co/heathcliff01/Kaloscope2.0/resolve/main"
PROXY="http://host.docker.internal:10081"
for entry in "config.json:100" "class_mapping.csv:700000" "best_checkpoint.pth:2684354560"; do
    IFS=':' read -r name min_size <<< "$entry"
    f="$LS_DIR/$name"
    size=$(stat -c%s "$f" 2>/dev/null || echo 0)
    if [ "$size" -ge "$min_size" ] 2>/dev/null; then
        echo "  [SKIP] $name"
    else
        echo "  [DOWNLOAD] $name..."
        rm -f "$f"
        if [ "$name" = "best_checkpoint.pth" ]; then
            remote="448-90.13/best_checkpoint.pth"
        else
            remote="$name"
        fi
        curl -sL --connect-timeout 30 -x "$PROXY" -o "$f" "$BASE_URL/$remote" || echo "  [WARN] $name download failed"
    fi
done

echo "Starting ComfyUI..."
exec "$@"
