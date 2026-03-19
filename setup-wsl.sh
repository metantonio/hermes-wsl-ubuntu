#!/bin/bash

set -e

AI_OPT_DIR="/opt/llamaCPP"
MODEL_DIR="$HOME/models"

echo "🔐 Requesting sudo permissions..."
sudo -v

echo "🔐 Installing with /opt structure (repo-compliant)..."

# ----------------------------
# 📦 System deps
# ----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl build-essential cmake git curl wget htop

# ----------------------------
# ⚡ GPU + CUDA detection
# ----------------------------
USE_CUDA=false

if command -v nvidia-smi &> /dev/null; then
    echo "🟢 NVIDIA GPU detected"

    if command -v nvcc &> /dev/null; then
        echo "✅ CUDA already installed"
        nvcc --version
        USE_CUDA=true
    else
        echo "⚠️ CUDA not found — installing..."

        # ----------------------------
        # CUDA install for WSL2
        # ----------------------------
        wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
        sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600

        wget https://developer.download.nvidia.com/compute/cuda/13.2.0/local_installers/cuda-repo-wsl-ubuntu-13-2-local_13.2.0-1_amd64.deb
        sudo dpkg -i cuda-repo-wsl-ubuntu-13-2-local_13.2.0-1_amd64.deb

        sudo cp /var/cuda-repo-wsl-ubuntu-13-2-local/cuda-*-keyring.gpg /usr/share/keyrings/

        sudo apt-get update
        sudo apt-get -y install cuda-toolkit-13-2

        # Verify installation
        if command -v nvcc &> /dev/null; then
            echo "✅ CUDA installed successfully"
            USE_CUDA=true
        else
            echo "❌ CUDA installation failed — falling back to CPU"
        fi
    fi
else
    echo "🧠 No GPU detected — using CPU"
fi

# ----------------------------
# 🧠 Install llama.cpp in /opt
# ----------------------------
if [ ! -d "$AI_OPT_DIR" ]; then
    echo "📥 Cloning llama.cpp into /opt..."
    sudo git clone https://github.com/ggerganov/llama.cpp.git "$AI_OPT_DIR"
fi

cd "$AI_OPT_DIR"

if [ "$USE_CUDA" = true ]; then
    echo "⚡ Building with CUDA"
    sudo cmake -B build -DGGML_CUDA=ON
else
    echo "🧠 Building CPU version"
    sudo cmake -B build
fi

sudo cmake --build build --config Release

# ----------------------------
# 🔐 Permissions (IMPORTANT)
# ----------------------------
echo "🔐 Setting permissions..."

sudo chmod -R 755 "$AI_OPT_DIR/build/bin/llama-server"

# Optional: make sure user can access
sudo chown -R $USER:$USER "$MODEL_DIR" 2>/dev/null || true

# ----------------------------
# 📁 Models (user space)
# ----------------------------
mkdir -p "$MODEL_DIR"
chmod 700 "$HOME/models"
chmod 700 "$MODEL_DIR"
cd "$MODEL_DIR"

echo ""
echo "📥 Model options:"
echo "1) Qwen3.5-9B-Q4_K_M.gguf"
echo "2) Skip"
read -p "Choose [1-2]: " choice

if [ "$choice" == "1" ]; then
    echo "⬇️ Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf
fi


# ----------------------------
# ✅ Done
# ----------------------------
echo ""
echo "🎉 Setup complete!"
cd "$HOME"
echo ""
echo "Please complete the hermes setup manually, doing:"
echo "hermes setup"
