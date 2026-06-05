#!/bin/bash
# download-lsnet-models.sh
# Downloads LSNet model files for comfyui-lsnet custom node.
# Skips if files exist and pass basic integrity check.
# Run this after cloning the repo or when models are missing.

set -e

MODEL_DIR="$(cd "$(dirname "$0")/storage/models/lsnet" && pwd)"
SUB_DIR="sharingan"
INSTALL_DIR="$MODEL_DIR/$SUB_DIR"
BASE_URL="https://huggingface.co/heathcliff01/Kaloscope2.0/resolve/main"
PROXY="http://127.0.0.1:10081"

# Model files: name, min_size, remote_path
FILES=(
    "config.json:100:config.json"
    "class_mapping.csv:700000:class_mapping.csv"
    "best_checkpoint.pth:2684354560:448-90.13/best_checkpoint.pth"
)

mkdir -p "$INSTALL_DIR"

for entry in "${FILES[@]}"; do
    IFS=':' read -r name min_size remote <<< "$entry"
    target="$INSTALL_DIR/$name"

    if [ -f "$target" ] && [ "$(stat -c%s "$target" 2>/dev/null || stat -f%z "$target" 2>/dev/null)" -ge "$min_size" ]; then
        echo "  [SKIP] $name (exists, size OK)"
    else
        echo "  [DOWNLOAD] $name..."
        rm -f "$target"
        curl -sL --connect-timeout 30 -x "$PROXY" -o "$target" "$BASE_URL/$remote" || {
            echo "  [ERROR] Failed to download $name"
            rm -f "$target"
            exit 1
        }
        actual_size=$(stat -c%s "$target" 2>/dev/null || stat -f%z "$target" 2>/dev/null)
        if [ "$actual_size" -ge "$min_size" ]; then
            echo "  [OK] $name ($((actual_size/1024/1024))MB)"
        else
            echo "  [ERROR] $name too small ($actual_size bytes), deleting"
            rm -f "$target"
            exit 1
        fi
    fi
done

echo "  LSNet models ready at $INSTALL_DIR"
