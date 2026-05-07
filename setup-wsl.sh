#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Infrastructure for Hermes Agent — Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ----------------------------
#  Variables
# ----------------------------
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    if command -v getent &> /dev/null; then
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        REAL_HOME=$(eval echo ~$SUDO_USER)
    fi
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

HERMES_INSTALL_DIR="$REAL_HOME/.hermes"
AI_OPT_DIR="/opt/llamaCPP"
CAMOFOX_DIR="/opt/camofox"
CAMOFOX_DETECTION="no"
LLM_MODEL=""
WEB_UI_HERMES_DIR="$REAL_HOME/hermes-hudui"
CACHE_TYPE="q4_0"
NCMOE="no"

# Prompt for Model Directory
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Enter the directory for LLM models [default: $REAL_HOME/models]: " input_dir
MODEL_DIR="${input_dir:-$REAL_HOME/models}"

# Expand tilde if present
MODEL_DIR="${MODEL_DIR/#\~/$REAL_HOME}"

if [ ! -d "$MODEL_DIR" ]; then
    echo "Creating directory: $MODEL_DIR"
    mkdir -p "$MODEL_DIR"
else
    echo "Using existing directory: $MODEL_DIR"
fi

echo "Requesting sudo permissions..."
sudo -v

# Keep sudo alive
echo "Keep sudo alive while this script is installing everything"

while true; do sudo -n true; sleep 60; done 2>/dev/null &

echo ""

# Detect platform
PLATFORM="$(uname -s)"
case "$PLATFORM" in
    Darwin*)  OS="macos";;
    Linux*)   OS="linux";;
    *)        echo "✗ Unsupported platform: $PLATFORM"; exit 1;;
esac
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✔ Platform: $OS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$OS" == "linux" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y git curl build-essential cmake wget htop
elif [ "$OS" == "macos" ]; then
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Please install it from https://brew.sh/"
        exit 1
    fi
    brew update
    brew install git curl cmake wget htop node
fi

# ----------------------------
#  Install Hermes Agent
# ----------------------------
if ! command -v hermes &> /dev/null; then
    echo ""
    echo "Hermes Agent not found."
    read -p "Do you want to install Hermes Agent? (y/n): " install_hermes
    if [ "$install_hermes" == "y" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Installing Hermes Agent..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Hermes Agent already installed."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# ----------------------------
#  GPU detection
# ----------------------------
USE_CUDA=false
USE_METAL=false
echo ""

if [ "$OS" == "linux" ]; then
    if command -v nvidia-smi &> /dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "NVIDIA GPU detected"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if command -v nvcc &> /dev/null; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "CUDA already installed"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            nvcc --version
            USE_CUDA=true
        else
            read -p "CUDA not found. Do you want to install CUDA toolkit for WSL2? (y/n): " install_cuda
            if [ "$install_cuda" == "y" ]; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Installing CUDA..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
                sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
                wget https://developer.download.nvidia.com/compute/cuda/13.2.0/local_installers/cuda-repo-wsl-ubuntu-13-2-local_13.2.0-1_amd64.deb
                sudo dpkg -i cuda-repo-wsl-ubuntu-13-2-local_13.2.0-1_amd64.deb
                sudo cp /var/cuda-repo-wsl-ubuntu-13-2-local/cuda-*-keyring.gpg /usr/share/keyrings/
                sudo apt-get update
                sudo apt-get -y install cuda-toolkit-13-2
                if command -v nvcc &> /dev/null; then
                    echo "CUDA installed successfully"
                    USE_CUDA=true
                else
                    echo "ERROR: CUDA installation failed — falling back to CPU"
                fi
            else
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Skipping CUDA installation. Using CPU mode."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            fi
        fi
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "No GPU detected — using CPU"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
elif [ "$OS" == "macos" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "macOS detected — Using Metal for GPU acceleration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    USE_METAL=true
fi

# ----------------------------
#  Install llama.cpp in /opt
# ----------------------------
echo ""
if [ ! -d "$AI_OPT_DIR" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cloning llama.cpp into /opt..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sudo git clone https://github.com/ggerganov/llama.cpp.git "$AI_OPT_DIR"
fi

cd "$AI_OPT_DIR"

echo ""
SHOULD_BUILD=true
if [ -d "build" ]; then
    read -p "llama.cpp build directory already exists. Rebuild? (y/n): " rebuild_choice
    if [ "$rebuild_choice" != "y" ]; then
        SHOULD_BUILD=false
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Updating llama.cpp repository..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sudo git pull
    fi
fi

if [ "$SHOULD_BUILD" = true ]; then
    if [ "$USE_CUDA" = true ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Building with CUDA"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sudo cmake -B build -DGGML_CUDA=ON
    elif [ "$USE_METAL" = true ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Building with Metal"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sudo cmake -B build -DGGML_METAL=ON
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Building CPU version"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sudo cmake -B build
    fi
    sudo cmake --build build --config Release
else
    echo "Skipping llama.cpp build."
fi

# ----------------------------
#  Permissions (IMPORTANT)
# ----------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting permissions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "change permissions of $AI_OPT_DIR/build/bin/llama-server to 755"
sudo chmod -R 755 "$AI_OPT_DIR/build/bin/llama-server"
echo "done"
# Optional: make sure user can access
echo "change ownership of $MODEL_DIR to $REAL_USER:$REAL_USER"
sudo chown -R $REAL_USER:$REAL_USER "$MODEL_DIR" 2>/dev/null || true
echo "done"

# ----------------------------
#  Download Models (user space)
# ----------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Models (user space)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
mkdir -p "$MODEL_DIR"
chmod 700 "$MODEL_DIR"
cd "$MODEL_DIR"

echo ""
echo "Model options to download (from HuggingFace):"
[ ! -f "Qwen3.5-9B-Q4_K_M.gguf" ] && echo "1) Qwen3.5-9B-Q4_K_M.gguf (5.5 GB) (12GB GPU)"
[ ! -f "Qwen3.5-9B-Q5_K_M.gguf" ] && echo "2) Qwen3.5-9B-Q5_K_M.gguf (6.5 GB) (12-16GB GPU)"
[ ! -f "omnicoder-9b-q5_k_m.gguf" ] && echo "3) Omnicoder:9B-Q4_K_M.gguf (6.52 GB) (12GB GPU)"
[ ! -f "gemma-4-E4B-it-q4_k_m.gguf" ] && echo "4) Gemma4:E4B-Q4_K_M.gguf (4.98 GB) (8-12GB GPU)"
[ ! -f "Carnice-9b-Q6_K.gguf" ] && echo "5) Carnice-9b-GGUF-Q6_K.gguf (7.36 GB) (Fine-tuned for Hermes, 16GB GPU)"
[ ! -f "Carnice-9b-Q4_K_M.gguf" ] && echo "6) Carnice-9b-GGUF-Q4_K_M.gguf (6.50 GB) (Fine-tuned for Hermes, 12GB GPU)"
[ ! -f "Qwen3.6-35B-A3B-UD-Q4_K_S.gguf" ] && echo "7) Qwen3.6-35B-A3B-UD-Q4_K_S.gguf (20.9 GB) (8-16GB GPU, with KV cache offloading)"
[ ! -f "Qwen3.5-0.8B-Q4_K_M.gguf" ] && echo "8) Qwen3.5-0.8B-Q4_K_M.gguf (533 MB) (4GB GPU or as drafting model for Qwen models)"
echo "9) Skip"
read -p "Choose [1-9, default: 9]: " choice
choice=${choice:-9}

if [ "$choice" == "1" ] && [ ! -f "Qwen3.5-9B-Q4_K_M.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf
    LLM_MODEL="Qwen3.5-9B-Q4_K_M.gguf"
    CACHE_TYPE="q4_0"
fi

if [ "$choice" == "2" ] && [ ! -f "Qwen3.5-9B-Q5_K_M.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q5_K_M.gguf
    LLM_MODEL="Qwen3.5-9B-Q5_K_M.gguf"  
    CACHE_TYPE="q5_0"
fi

if [ "$choice" == "3" ] && [ ! -f "omnicoder-9b-q5_k_m.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/Tesslate/OmniCoder-9B-GGUF/resolve/main/omnicoder-9b-q5_k_m.gguf
    LLM_MODEL="omnicoder-9b-q5_k_m.gguf"
    CACHE_TYPE="q5_0"
fi

if [ "$choice" == "4" ] && [ ! -f "gemma-4-E4B-it-q4_k_m.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-q4_k_m.gguf
    LLM_MODEL="gemma-4-E4B-it-q4_k_m.gguf"
    CACHE_TYPE="q4_0"
fi

if [ "$choice" == "5" ] && [ ! -f "Carnice-9b-Q6_K.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/kai-os/Carnice-9b-GGUF/resolve/main/Carnice-9b-Q6_K.gguf
    LLM_MODEL="Carnice-9b-Q6_K.gguf"
    CACHE_TYPE="q8_0"
fi

if [ "$choice" == "6" ] && [ ! -f "Carnice-9b-Q4_K_M.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/kai-os/Carnice-9b-GGUF/resolve/main/Carnice-9b-Q4_K_M.gguf
    LLM_MODEL="Carnice-9b-Q4_K_M.gguf"
    CACHE_TYPE="q4_0"
fi

if [ "$choice" == "7" ] && [ ! -f "Qwen3.6-35B-A3B-UD-Q4_K_S.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf
    LLM_MODEL="Qwen3.6-35B-A3B-UD-Q4_K_S.gguf"
    CACHE_TYPE="q4_0"
    NCMOE="99"
fi

if [ "$choice" == "8" ] && [ ! -f "Qwen3.5-0.8B-Q4_K_M.gguf" ]; then
    echo "Downloading model..."
    wget https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf
    LLM_MODEL="Qwen3.5-0.8B-Q4_K_M.gguf"
    CACHE_TYPE="q4_0"
fi

# ----------------------------
#  Main Setup Done
# ----------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Main Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "$REAL_HOME"
echo ""

# ----------------------------
#  Install Camofox /opt/
# ----------------------------

if [ ! -d "$CAMOFOX_DIR" ]; then
    echo "Cloning camofox into /opt..."
    sudo git clone https://github.com/jo-inc/camofox-browser "$CAMOFOX_DIR"
    sudo chown -R $REAL_USER:$REAL_USER "$CAMOFOX_DIR"
    cd "$CAMOFOX_DIR"
    npm install && npm start > camofox.log 2>&1 &
    echo "Camofox will be running at http://localhost:9377"
    echo "to stop Camofox server run: sudo fuser -k 9377/tcp"
else
    echo "Camofox already installed"
    CAMOFOX_DETECTION="yes"
    sudo chown -R $REAL_USER:$REAL_USER "$CAMOFOX_DIR" 2>/dev/null || true
fi

if [ "$CAMOFOX_DETECTION" = "yes" ]; then
    if ps aux | grep -i "[c]amofox" > /dev/null; then
        echo "Camofox is already running."
    else
        echo "Do you want to start camofox browser server? (y/n)"
        read -p "Choose [y/n]: " choice
        if [ "$choice" == "y" ]; then
            sudo fuser -k 9377/tcp || true
            sleep 2
            cd "$CAMOFOX_DIR"
            npm start > camofox.log 2>&1 &
            echo "Camofox will be running at http://localhost:9377"
            echo "to stop Camofox server run: sudo fuser -k 9377/tcp"
        fi
    fi
fi

# ----------------------------
#  Start Llama.cpp server on localhost:8080 by default
# ----------------------------
echo ""
read -p "Do you want to start the llama.cpp server? (y/n)" start_llama
if [ "$start_llama" == "y" ]; then
    echo ""
    echo "Checking if there is a llama.cpp server running on localhost:8080..."
    sudo fuser -k 8080/tcp || true
    sleep 2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Model Selection for Server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # List models safely
    set +e
    echo "DEBUG: Checking $MODEL_DIR for models..."
    shopt -s nullglob
    models=("$MODEL_DIR"/*.gguf)
    shopt -u nullglob
    set -e

    if [ ${#models[@]} -eq 0 ]; then
        echo "No models found in $MODEL_DIR. Skipping server start."
    else
        echo "Available models in $MODEL_DIR:"
        for i in "${!models[@]}"; do
            echo "$((i+1))) $(basename "${models[$i]}")"
        done
        read -p "Select a model [1-${#models[@]}]: " model_idx
        
        # Validate selection
        if [[ "$model_idx" =~ ^[0-9]+$ ]] && [ "$model_idx" -ge 1 ] && [ "$model_idx" -le "${#models[@]}" ]; then
            SELECTED_MODEL="${models[$((model_idx-1))]}"
            SELECTED_BASENAME=$(basename "$SELECTED_MODEL")
            echo "Selected: $SELECTED_BASENAME"
            
            # Detect CACHE_TYPE based on filename
            if [[ "$SELECTED_BASENAME" == *"Q6"* ]]; then
                CACHE_TYPE="q8_0"
            elif [[ "$SELECTED_BASENAME" == *"Q5"* ]]; then
                CACHE_TYPE="q5_0"
            elif [[ "$SELECTED_BASENAME" == *"Q4"* ]]; then
                CACHE_TYPE="q4_0"
            else
                # Default to q4_0 if no match found and not previously set
                CACHE_TYPE="${CACHE_TYPE:-q4_0}"
            fi
            
            # Detect MoE based on filename
            MOE_FLAG=""
            THREADS_FLAG=""
            if [[ "$SELECTED_BASENAME" == *"A3B"* ]] || [[ "$SELECTED_BASENAME" == *"MoE"* ]] || [[ "$SELECTED_BASENAME" == *"moe"* ]]; then
                MOE_FLAG="-ncmoe 25"
                THREADS_FLAG="-t 12"
                echo "MoE model detected: adding $MOE_FLAG"
            fi
            
            DRAFT_FLAGS="--spec-type ngram-mod --spec-ngram-mod-n-max 12"
            read -p "Do you want to use a draft model? (y/n): " use_draft
            if [ "$use_draft" == "y" ]; then
                echo "Available models in $MODEL_DIR for draft:"
                for i in "${!models[@]}"; do
                    echo "$((i+1))) $(basename "${models[$i]}")"
                done
                read -p "Select a draft model [1-${#models[@]}]: " draft_idx
                if [[ "$draft_idx" =~ ^[0-9]+$ ]] && [ "$draft_idx" -ge 1 ] && [ "$draft_idx" -le "${#models[@]}" ]; then
                    SELECTED_DRAFT="${models[$((draft_idx-1))]}"
                    DRAFT_FLAGS="--model-draft $SELECTED_DRAFT --spec-draft-n-max 16"
                    echo "Selected draft model: $(basename "$SELECTED_DRAFT")"
                else
                    echo "Invalid draft selection. Proceeding without draft model."
                fi
            fi
            
            echo ""
            echo "Select Context Size for the model:"
            echo "1) 4k (4096)"
            echo "2) 8k (8192)"
            echo "3) 32k (32768)"
            echo "4) 64k (65536)"
            echo "5) 128k (131072) [Default]"
            echo "6) 256k (262144)"
            echo "7) 512k (524288)"
            echo "8) 1M (1048576)"
            read -p "Choose [1-8, default: 5]: " ctx_choice
            
            case "$ctx_choice" in
                1) CTX_SIZE="4096" ;;
                2) CTX_SIZE="8192" ;;
                3) CTX_SIZE="32768" ;;
                4) CTX_SIZE="65536" ;;
                5) CTX_SIZE="131072" ;;
                6) CTX_SIZE="262144" ;;
                7) CTX_SIZE="524288" ;;
                8) CTX_SIZE="1048576" ;;
                *) CTX_SIZE="131072" ;;
            esac
            echo "Selected Context Size: $CTX_SIZE"
            
            echo "Using Cache Type: $CACHE_TYPE"
            
            echo "Llama.cpp server will be running at http://localhost:8080"
            # Using AI_OPT_DIR variable for consistency
            $AI_OPT_DIR/build/bin/llama-server -m "$SELECTED_MODEL" -ngl 99 -c $CTX_SIZE -np 1 -fa on --cache-type-k $CACHE_TYPE --cache-type-v $CACHE_TYPE $MOE_FLAG $THREADS_FLAG -tb 24 --no-warmup $DRAFT_FLAGS --metrics --host 127.0.0.1 > llama-server.log 2>&1 &
            echo "Server started in background. Logs: llama-server.log"
            echo "To stop Llama server run: sudo fuser -k 8080/tcp \n or sudo pkill -f llama-server"
        else
            echo "Invalid selection. Skipping server start."
        fi
    fi
fi

# ----------------------------
#  Setup Hermes variables
# ----------------------------

echo ""
echo "Setup Hermes variables in order to use llama.cpp server? (y/n)"
read -p "Choose [y/N]: " hermesvariables

if [ "$hermesvariables" == "y" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Setting up Hermes variables..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    hermes config set OPENAI_BASE_URL http://localhost:8080/v1
    hermes config set OPENAI_API_KEY dummy
    #hermes config set LLM_MODEL $LLM_MODEL
fi

# ----------------------------
#  Enable Hermes API server
# ----------------------------

echo ""
echo "Enable Hermes API server on http://127.0.0.1:8642? (y/n)"
read -p "Choose [y/N]: " enable_api

if [ "$enable_api" == "y" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Enabling Hermes API server..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "API_SERVER_ENABLED=true" >> "$REAL_HOME/.hermes/.env"
    echo "API_SERVER_KEY=change-me-local-dev" >> "$REAL_HOME/.hermes/.env"
    echo "Hermes API server enabled in $REAL_HOME/.hermes/.env and running at http://127.0.0.1:8642"
    echo "REMEMBER: Change the API_SERVER_KEY manually for security."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Please complete the hermes setup manually, doing:"
echo "hermes setup"
echo "then, check the variables to change in the .env file: https://github.com/metantonio/hermes-wsl-ubuntu?tab=readme-ov-file#config"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
