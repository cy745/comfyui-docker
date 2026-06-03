FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

LABEL description="ComfyUI with NVIDIA GPU support"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ============================================================
# Stage 1: System dependencies (rarely changes)
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python && \
    pip install --upgrade pip

# ============================================================
# Stage 2: PyTorch with CUDA 12.4
# BuildKit --mount=type=cache persists pip downloads across builds
# ============================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# ============================================================
# Stage 3: ComfyUI Python dependencies
# Fetch requirements.txt from pinned commit BEFORE cloning repo
# This keeps the pip layer cached even when ComfyUI code changes
# ============================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    wget -O /tmp/requirements.txt https://raw.githubusercontent.com/comfyanonymous/ComfyUI/cd45f42a/requirements.txt && \
    pip install -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Pre-install common dependencies for custom nodes
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install opencv-python-headless scipy einops transformers diffusers accelerate

# ============================================================
# Stage 4: Clone ComfyUI source code (fast, only this layer invalidates)
# ============================================================
WORKDIR /app
RUN git init && \
    git remote add origin https://github.com/comfyanonymous/ComfyUI.git && \
    git fetch origin cd45f42a --depth 1 && \
    git checkout cd45f42a

# ============================================================
# Stage 5: Build dependencies for flash-attn (late to avoid cache break)
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-nvcc-12-4 build-essential && \
    rm -rf /var/lib/apt/lists/*

# Attention optimizations for SeedVR2
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install sageattention flash-attn --no-build-isolation

# Clone ComfyUI-Manager as default custom node (pinned)
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /default_custom_nodes/ComfyUI-Manager && \
    cd /default_custom_nodes/ComfyUI-Manager && git checkout d6f480c9

# Create ComfyUI runtime directories
RUN mkdir -p /app/models /app/input /app/output /app/custom_nodes

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
