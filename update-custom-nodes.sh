#!/bin/bash
# update-custom-nodes.sh
# Initialize and update all custom_node git submodules to their latest pinned versions.
# Run this after cloning the repo or when you want to refresh custom nodes.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Initializing custom_node submodules ==="
git submodule update --init --recursive

echo ""
echo "=== Updating custom_nodes to latest pinned versions ==="
git submodule update --remote --merge storage/custom_nodes/ComfyUI-Sharp

echo ""
echo "=== Installing Python dependencies for custom nodes ==="
for node_dir in storage/custom_nodes/*/; do
    if [ -f "$node_dir/requirements.txt" ]; then
        echo "  Installing $(basename "$node_dir") dependencies..."
        pip install -r "$node_dir/requirements.txt" -q
    fi
done

echo ""
echo "Done. Custom nodes are up to date."
