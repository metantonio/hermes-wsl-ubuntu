#!/bin/bash

set -e

echo "Infrastructure for Hermes Agent — Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HERMES_INSTALL_DIR="$HOME/.hermes"
AI_OPT_DIR="/opt/llamaCPP"
MODEL_DIR="$HOME/models"
CAMOFOX_DIR="/opt/camofox"
CAMOFOX_DETECTION="no"
LLM_MODEL=""
WEB_UI_HERMES_DIR="$HOME/hermes-hudui"

echo "Requesting sudo permissions..."
sudo -v

# Keep sudo alive
echo "Keep sudo alive while this script is installing everything"

while true; do sudo -n true; sleep 60; done 2>/dev/null &

echo "Installing with /opt structure (repo-compliant)..."

# ----------------------------
#  System deps
# ----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl build-essential cmake git curl wget htop

# ----------------------------
#  Install Hermes Agent
# ----------------------------
if ! command -v hermes &> /dev/null; then
    echo ""
    echo "Hermes Agent not found."
    read -p "Do you want to install Hermes Agent? (y/n): " install_hermes
    if [ "$install_hermes" == "y" ]; then
        echo "Installing Hermes Agent..."
        curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
    fi
else
    echo "Hermes Agent already installed."
fi

# ----------------------------
#  GPU + CUDA detection
# ----------------------------
USE_CUDA=false

if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected"

    if command -v nvcc &> /dev/null; then
        echo "CUDA already installed"
        nvcc --version
        USE_CUDA=true
    else
        read -p "CUDA not found. Do you want to install CUDA toolkit for WSL2? (y/n): " install_cuda
        if [ "$install_cuda" == "y" ]; then
            echo "Installing CUDA..."
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
                echo "CUDA installed successfully"
                USE_CUDA=true
            else
                echo "ERROR: CUDA installation failed — falling back to CPU"
            fi
        else
            echo "Skipping CUDA installation. Using CPU mode."
        fi
    fi
else
    echo "No GPU detected — using CPU"
fi

# ----------------------------
#  Install llama.cpp in /opt
# ----------------------------
if [ ! -d "$AI_OPT_DIR" ]; then
    echo "Cloning llama.cpp into /opt..."
    sudo git clone https://github.com/ggerganov/llama.cpp.git "$AI_OPT_DIR"
fi

cd "$AI_OPT_DIR"

SHOULD_BUILD=true
if [ -d "build" ]; then
    read -p "llama.cpp build directory already exists. Rebuild? (y/n): " rebuild_choice
    if [ "$rebuild_choice" != "y" ]; then
        SHOULD_BUILD=false
    fi
fi

if [ "$SHOULD_BUILD" = true ]; then
    if [ "$USE_CUDA" = true ]; then
        echo "Building with CUDA"
        sudo cmake -B build -DGGML_CUDA=ON
    else
        echo "Building CPU version"
        sudo cmake -B build
    fi
    sudo cmake --build build --config Release
else
    echo "Skipping llama.cpp build."
fi

# ----------------------------
#  Permissions (IMPORTANT)
# ----------------------------
echo "Setting permissions..."

sudo chmod -R 755 "$AI_OPT_DIR/build/bin/llama-server"

# Optional: make sure user can access
sudo chown -R $USER:$USER "$MODEL_DIR" 2>/dev/null || true

# ----------------------------
#  Models (user space)
# ----------------------------
mkdir -p "$MODEL_DIR"
chmod 700 "$HOME/models"
chmod 700 "$MODEL_DIR"
cd "$MODEL_DIR"

echo ""
echo "Model options:"
echo "1) Qwen3.5-9B-Q4_K_M.gguf (5.5 GB) (12GB GPU)"
echo "2) Qwen3.5-9B-Q5_K_M.gguf (6.5 GB) (12-16GB GPU)"
echo "3) Omnicoder:9B-Q4_K_M.gguf (6.52 GB) (12GB GPU)"
echo "4) Gemma4:E4B-Q4_K_M.gguf (4.98 GB) (8-12GB GPU)"
echo "5) Carnice-9b-GGUF-Q6_K.gguf (7.36 GB) (Fine-tuned for Hermes, 16GB GPU)"
echo "6) Carnice-9b-GGUF-Q4_K_M.gguf (6.50 GB) (Fine-tuned for Hermes, 12GB GPU)"
echo "7) Skip"
read -p "Choose [1-7]: " choice

if [ "$choice" == "1" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf
    LLM_MODEL="Qwen3.5-9B-Q4_K_M.gguf"
fi

if [ "$choice" == "2" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q5_K_M.gguf
    LLM_MODEL="Qwen3.5-9B-Q5_K_M.gguf"  
fi

if [ "$choice" == "3" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/Tesslate/OmniCoder-9B-GGUF/resolve/main/omnicoder-9b-q5_k_m.gguf
    LLM_MODEL="omnicoder-9b-q5_k_m.gguf"
fi

if [ "$choice" == "4" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-q4_k_m.gguf
    LLM_MODEL="gemma-4-E4B-it-q4_k_m.gguf"
fi

if [ "$choice" == "5" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/kai-os/Carnice-9b-GGUF/resolve/main/Carnice-9b-Q6_K.gguf
    LLM_MODEL="Carnice-9b-Q6_K.gguf"
fi

if [ "$choice" == "6" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/kai-os/Carnice-9b-GGUF/resolve/main/Carnice-9b-Q4_K_M.gguf
    LLM_MODEL="Carnice-9b-Q4_K_M.gguf"
fi

# ----------------------------
#  Done
# ----------------------------
echo ""
echo "Setup complete!"
cd "$HOME"
echo ""

# ----------------------------
#  Install Camofox /opt/
# ----------------------------

if [ ! -d "$CAMOFOX_DIR" ]; then
    echo "Cloning camofox into /opt..."
    sudo git clone https://github.com/jo-inc/camofox-browser "$CAMOFOX_DIR"
    cd "$CAMOFOX_DIR"
    sudo npm install && npm start > camofox.log 2>&1 &
    echo "Camofox will be running at http://localhost:9377"
    echo "to stop Camofox server run: sudo fuser -k 9377/tcp"
else
    echo "Camofox already installed"
    CAMOFOX_DETECTION="yes"
fi

if [ "$CAMOFOX_DETECTION" = "yes" ]; then
    echo "Do you want to start camofox browser server? (y/n)"
    read -p "Choose [y/n]: " choice
    if [ "$choice" == "y" ]; then
        cd "$CAMOFOX_DIR"
        npm start > camofox.log 2>&1 &
        echo "Camofox will be running at http://localhost:9377"
        echo "to stop Camofox server run: sudo fuser -k 9377/tcp"
    fi
fi

# ----------------------------
#  Setup Hermes variables
# ----------------------------

echo ""
echo "Setup Hermes variables in order to use llama.cpp server? (y/n)"
read -p "Choose [y/N]: " hermesvariables

if [ "$hermesvariables" == "y" ]; then
    hermes config set OPENAI_BASE_URL http://localhost:8080/v1
    hermes config set OPENAI_API_KEY dummy
    hermes config set LLM_MODEL $LLM_MODEL
fi

# ----------------------------
#  Enable Hermes API server
# ----------------------------

echo ""
echo "Enable Hermes API server on http://127.0.0.1:8642? (y/n)"
read -p "Choose [y/N]: " enable_api

if [ "$enable_api" == "y" ]; then
    echo "API_SERVER_ENABLED=true" >> ~/.hermes/.env
    echo "API_SERVER_KEY=change-me-local-dev" >> ~/.hermes/.env
    echo "Hermes API server enabled in ~/.hermes/.env and running at http://127.0.0.1:8642"
    echo "REMEMBER: Change the API_SERVER_KEY manually for security."
fi

# ----------------------------
#  Install Web UI Hermes in ~/hermes-hudui will be on port 3001
# ----------------------------
echo ""
if [ ! -d "$WEB_UI_HERMES_DIR" ]; then
    echo "Cloning Web UI Hermes into ~/hermes-hudui..."
    sudo git clone https://github.com/joeynyc/hermes-hudui.git "$WEB_UI_HERMES_DIR"
    cd "$WEB_UI_HERMES_DIR"
    python3.11 -m venv venv
    source venv/bin/activate
    ./install.sh
    read -p "Do you want to start the web ui hermes? (y/n)" start_webui
    if [ "$start_webui" == "y" ]; then
        echo "Hermes HDUI will be running at http://localhost:3001"
        hermes-hudui
    fi
else
    echo "Web UI Hermes already installed"
    read -p "Do you want to start the web ui hermes? (y/n)" start_webui
    if [ "$start_webui" == "y" ]; then
        cd "$WEB_UI_HERMES_DIR"
        source venv/bin/activate
        echo "Hermes HDUI will be running at http://localhost:3001"
        hermes-hudui
    fi
fi



echo "Please complete the hermes setup manually, doing:"
echo "hermes setup"
echo "then, check the variables to change in the .env file: https://github.com/metantonio/hermes-wsl-ubuntu?tab=readme-ov-file#config"
