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

# Install any pending custom node dependencies
for node_dir in /app/custom_nodes/*/; do
    if [ -f "$node_dir/requirements.txt" ]; then
        echo "Installing dependencies for $(basename $node_dir)..."
        pip install -r "$node_dir/requirements.txt" -q
    fi
done

echo "Starting ComfyUI..."
exec "$@"
