FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

LABEL description="ComfyUI with NVIDIA GPU support"

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# Install system dependencies
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
    cuda-nvcc-12-1 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python && \
    pip install --upgrade pip

# Install PyTorch with CUDA 12.1 support
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Clone ComfyUI (pinned to v0.22.0 with additional fixes)
WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    git checkout cd45f42a

# Install ComfyUI Python dependencies
RUN pip install -r requirements.txt

# Pre-install common dependencies for custom nodes
RUN pip install opencv-python-headless scipy einops transformers diffusers accelerate

# Install attention optimizations for SeedVR2
RUN pip install sageattention flash-attn --no-build-isolation

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
