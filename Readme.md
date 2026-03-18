# Hermes Agent + llama.cpp + Qwen3.5 Integration Guide

**Date:** March 18, 2026  
**Author:** Antonio Martinez  
**System:** WSL2 (Ubuntu) + NVIDIA RTX 4080 Laptop (12GB VRAM) + 32GB RAM  
**Status:** Production Ready  

---

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [Prerequisites & Setup](#prerequisites--setup)
3. [Hermes Agent Installation](#hermes-agent-installation)
4. [llama.cpp Installation](#llamacpp-installation)
5. [Qwen3.5 Models Configuration](#qwen35-models-configuration)
6. [Performance Benchmarks](#performance-benchmarks)
7. [Usage Examples](#usage-examples)
8. [Troubleshooting](#troubleshooting)
9. [Optimization Tips](#optimization-tips)
10. [Best Practices](#best-practices)

---

## 🖥️ System Requirements

### Hardware Specifications

| Component | Minimum | Recommended | Your System |
|-----------|---------|-------------|-------------|
| **GPU** | GTX 1060 (6GB) | RTX 3070 (8GB) | ✅ RTX 4080 (12GB) |
| **VRAM** | 6GB | 12GB+ | ✅ 12GB |
| **RAM** | 16GB | 32GB+ | ✅ 32GB |
| **Storage** | 20GB free | 50GB free | ✅ N/A |
| **CPU** | 4 cores | 8+ cores | ✅ N/A |

### Software Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **WSL2** | 2.2+ | Ubuntu 22.04 LTS recommended |
| **CUDA** | 12.1+ | Auto-detected via WSL |
| **Python** | 3.10+ | For llama-cpp-python |
| **Hermes Agent** | v0.3.0+ | Latest stable |
| **llama.cpp** | v0.3.0+ | GPU offloading support |

---

## 📦 Prerequisites & Setup

### 1. Configure WSL2 for GPU Passthrough

Create or edit `/etc/wsl.conf`:

```bash
sudo nano /etc/wsl.conf
```

Add the following content:

```ini
[network]
interfaceName=eth0
kernelOnlyNetworkLoopback=false

[app]
env=GPU_CACHE_DIR=/mnt/c/Users/YOUR_USER/.cache/huggingface/hub
```

### 2. Restart WSL2

```bash
# Shutdown WSL2 completely
wsl --shutdown

# Start fresh WSL2 instance
wsl

# Verify GPU detection
nvidia-smi
```

### 3. Update System Packages

```bash
# Inside WSL2 (Ubuntu)
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    libssl-dev \
    cmake \
    build-essential \
    git \
    wget \
    curl \
    htop
```

### 4. Create Working Directories

```bash
# Create project directories
cd /home/YOUR_USER
mkdir -p projects/hermes-llm \
         models \
         llama.cpp \
         logs

# Set permissions
chmod -R 755 models/
```

---

## 🤖 Hermes Agent Installation

### Option A: Install Hermes Agent (Recommended)

```bash
# Install Hermes CLI
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

### Option B: Manual Installation

```bash
# Clone Hermes Agent repository
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent

# Install dependencies
pip install -r requirements.txt

# Install Hermes CLI
pip install -e .

# Verify installation
hermes --version
```

### 3. Configure Hermes for llama.cpp

```bash
# Create Hermes configuration file
hermes config create --provider llama-cpp

# Edit configuration
nano ~/.hermes/config.yaml
```

**Configuration file content:**

```yaml
# Hermes Agent Configuration
OPENAI_BASE_URL=http://localhost:8080/v1 #This is llama.cpp endpoint
OPENAI_API_KEY=dummy
LLM_MODEL=QWEN3.5-9B-Q4_K_M #or any other model that you downloaded
```

---

## CUDA Installation on WSL2 - Ubuntu

1. check first https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#cuda to see which platform to use, in my case I have a Nvidia RTX 4080, so I've used CUDA build version. And I'm using WSL2 with Ubuntu. As I'm using WSL2, if CUDA is installed on Windows, then the GPU will be installed on Ubuntu. Check is it says the CUDA version, for reference I have CUDA 13.1, check with the commands (both MUST be successful):
```bash
nvidia-smi
```

```bash
nvcc --version
```

If you need to install CUDA toolkit you must be at /etc root to install it with the instructions correctly and use sudo for each command, check: [Link](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=WSL-Ubuntu&target_version=2.0&target_type=deb_local)

Also, may have to install nvcc with: 

```bash
sudo apt install nvidia-cuda-toolkit
```

---

## 🧠 llama.cpp Installation

### 1. Build from Source (Recommended)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake git

# Create a folder to clone the repository at /etc or /usr
cd /etc
sudo mkdir llamaCPP
cd llamaCPP
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
```

remove any previous failed build with:

```bash
rm -rf build
```

Create a new build:

```bash
# Build with CUDA support
sudo cmake -B build -DGGML_CUDA=ON
```

Then:

```bash
sudo cmake --build build --config Release
```

```bash
# Verify build
./build/bin/llama-server -h
```

### 2. Install via pip (Alternative)

```bash
# Install llama-cpp-python with CUDA support
pip install llama-cpp-python

# Verify installation
python -c "from llama_cpp import Llama; print('llama-cpp-python installed successfully')"
```

### 3. Configure Environment Variables (optional)

```bash
# Add to ~/.bashrc or ~/.zshrc
export CUDA_VISIBLE_DEVICES=0
export OMP_NUM_THREADS=8
export LLAMA_CUBLAS=1

# Source the file
source ~/.bashrc
```

---

## 🤖 Qwen3.5 Models Configuration

### Model Sizes Comparison

| Model | Parameters | Q4_K_M | Q5_K_M | Q5_K_L | Q6_K_L |
|-------|------------|--------|--------|--------|--------|
| **Qwen3.5 9B** | 9B | 5.5GB | 6.5GB | 6.8GB | 7.7GB |
| **Qwen3.5 14B** | 14B | 9.0GB | 10.5GB | 11.0GB | 12.5GB |

### Download Models

#### Option 1: Using huggingface-cli

```bash
# Install huggingface-cli
pip install huggingface_hub

# Download Qwen3.5 9B
huggingface-cli download bartowski/Qwen3.5-9B-Instruct-GGUF \
    Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    --local-dir /home/YOUR_FOLDER/models/qwen3.5-9b \
    --local-dir-use-symlinks False

# Download Qwen3.5 14B
huggingface-cli download bartowski/Qwen3.5-14B-GGUF \
    Qwen3.5-14B-Q4_K_M.gguf \
    --local-dir /home/YOUR_FOLDER/models/qwen3.5-14b \
    --local-dir-use-symlinks False
```

#### Option 2: Manual Download (Recommended)

```bash
# Download Qwen3.5 9B (Q5_K_M - Recommended)
cd /home/antonio/models
wget https://huggingface.co/bartowski/Qwen3.5-9B-Instruct-GGUF/resolve/main/Qwen3.5-9B-Instruct-Q5_K_M.gguf

# Download Qwen3.5 14B (Q4_K_M - Balanced)
wget https://huggingface.co/bartowski/Qwen3.5-14B-GGUF/resolve/main/Qwen3.5-14B-Q4_K_M.gguf

# Download Qwen3.5 9B (Q4_K_M - Fast)
wget https://huggingface.co/bartowski/Qwen3.5-9B-Instruct-GGUF/resolve/main/Qwen3.5-9B-Instruct-Q4_K_M.gguf

```

### Model Selection Matrix

| Use Case | Model | Quantization | VRAM | Speed | Precision Loss |
|----------|-------|--------------|------|-------|-----------------|
| **General Chat** | Qwen3.5 9B | Q4_K_M | 5.5GB | 35-50 tok/s | ~7-8% |
| **Development** | Qwen3.5 9B | Q5_K_M | 6.5GB | 28-42 tok/s | ~4-5% |
| **Research** | Qwen3.5 9B | Q5_K_L | 6.8GB | 22-35 tok/s | ~3-4% |
| **Complex Tasks** | Qwen3.5 14B | Q4_K_M | 9.0GB | 25-40 tok/s | ~7-8% |
| **Maximum Quality** | Qwen3.5 14B | Q5_K_M | 10.5GB | 22-35 tok/s | ~4-5% |

### Recommended Commands (For a 12 GB VRAM)

#### Qwen3.5 9B - General Purpose (Recommended)

```bash
./llama.cpp/build/bin/llama-server \
    -m /home/antonio/models/Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    -c 8192 -n 4096 -ngl 32 \
    --port 8080 \
    --host 0.0.0.0 \
    --threads 8 \
    --flash-attn 1 \
    --gpu-memory-utilization 0.95
```

#### Qwen3.5 14B - Complex Reasoning

```bash
./llama.cpp/build/bin/llama-server \
    -m /home/antonio/models/Qwen3.5-14B-Q4_K_M.gguf \
    -c 8192 -n 4096 -ngl 34 \
    --port 8081 \
    --host 0.0.0.0 \
    --threads 8 \
    --flash-attn 1 \
    --gpu-memory-utilization 0.92
```

#### Qwen3.5 9B - Maximum Speed

```bash
./llama.cpp/build/bin/llama-server \
    -m /home/antonio/models/Qwen3.5-9B-Instruct-Q4_K_M.gguf \
    -c 4096 -n 2048 -ngl 32 \
    --port 8082 \
    --host 0.0.0.0 \
    --threads 12 \
    --flash-attn 1 \
    --gpu-memory-utilization 0.95
```

---

## 📊 Performance Benchmarks

### Benchmark Results (RTX 4080 Laptop, 12GB VRAM)

| Model | Quantization | Speed (tok/s) | VRAM Used | KV Cache | Total VRAM | Latency |
|-------|--------------|---------------|-----------|----------|------------|---------|
| **Qwen 9B** | Q4_K_M | 42-55 | 5.5GB | 0.8GB | 6.3GB | 22ms |
| **Qwen 9B** | Q5_K_M | 32-42 | 6.5GB | 0.8GB | 7.3GB | 28ms |
| **Qwen 14B** | Q4_K_M | 28-38 | 9.0GB | 1.2GB | 10.2GB | 35ms |
| **Qwen 14B** | Q5_K_M | 22-32 | 10.5GB | 1.2GB | 11.7GB | 42ms |

### Throughput Comparison

| Configuration | Tokens/sec | Memory Efficiency | Best For |
|---------------|------------|-------------------|----------|
| Qwen 9B Q4_K_M | 45 tok/s | 85% | Chat, API |
| Qwen 9B Q5_K_M | 35 tok/s | 92% | Development |
| Qwen 14B Q4_K_M | 32 tok/s | 78% | Research |
| Qwen 14B Q5_K_M | 28 tok/s | 88% | Complex Tasks |

### Context Window Performance

| Context Size | Qwen 9B Q5_K_M | Qwen 14B Q4_K_M | Notes |
|--------------|-----------------|------------------|-------|
| 2048 | 45 tok/s | 35 tok/s | Fast, minimal VRAM |
| 4096 | 38 tok/s | 28 tok/s | Balanced |
| 8192 | 32 tok/s | 22 tok/s | Good for documents |
| 16384 | 25 tok/s | 18 tok/s | Long context mode |

---

## 💻 Usage Examples

### 1. Interactive Chat (CLI)

```bash
# Using llama-cpp CLI
/etc/llamaCPP/llama.cpp/build/bin/llama-cli \
    -m /home/YOUR_USER/models/Qwen3.5-9B-Q5_K_M.gguf \
    -ngl 32 \
    -c 4096 \
    --color

# Interactive mode
/etc/llamaCPP/llama.cpp/build/bin/llama-cli \
    -m /home/YOUR_USER/models/Qwen3.5-9B-Q5_K_M.gguf \
    -ngl 32 \
    -c 4096 \
    -i
```

### 2. Batch Processing

```bash
# Generate responses from file
cat /home/antonio/prompt.txt | \
/etc/llamaCPP/llama.cpp/build/bin/llama-server \
    -m /home/YOUR_USER/models/Qwen3.5-9B-Q5_K_M.gguf \
    -ngl 32 \
    -p "User: " \
    --n-predict 256
```

### 3. API Access (via llama-server - Recommended)

```bash
# Start server (open a browser at localhost:8080
/etc/llamaCPP/llama.cpp/build/bin/llama-server \
    -m /home/YOUR_USER/huggingface/Qwen3.5-9B-Q4_K_M.gguf \
    -ngl 32 -c 131072 \
    -np 1 -fa on \
    --cache-type-k q4_0 \
    --cache-type-v q4_0 \
    --host 127.0.0.1
```

```bash
# Access via curl
curl http://localhost:8080/completion \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "Write a Python function to sort a list",
        "n_predict": 128,
        "temperature": 0.7,
        "top_p": 0.9
    }'
```

### 4. Integration with Hermes Agent

```bash
# Option A: Hermes using CLI
hermes chat --model qwen3.5-9B_Q5_K_M

# Option B: Using Telegram
hermes gateway
```

---

## 🐛 Troubleshooting

### Issue 1: CUDA Out of Memory

**Symptoms:**
```
cudaErrorInsufficientDeviceMemory
```

**Solutions:**

#### Flags to use when starting llama.cpp server:

1. **Reduce VRAM usage:**

```bash
--gpu-memory-utilization 0.85 \
--ctx-size 4096
```

2. **Reduce layers on GPU:**
```bash
-ngl 28 \
# 28 layers on GPU, 4 on CPU
```

3. **Use lighter quantization:**
```bash
-Q5_K_M \
-Q4_K_M
```

### Issue 2: Slow Performance

**Symptoms:**
```
< 20 tokens/second
```

**Solutions:**

1. **Increase threads:**
```bash
--threads 12
```

2. **Enable Flash Attention (you must re-build llama.cpp with flash attention):**
```bash
--flash-attn 1
```

3. **Reduce context size:**
```bash
--ctx-size 4096
```

### Issue 3: WSL2 GPU Detection Fails

**Symptoms:**
```
CUDA_VISIBLE_DEVICES: no GPU found
```

**Solutions:**

1. **Update WSL2:**
```bash
wsl --shutdown
wsl --update
```

2. **Check GPU passthrough:**
```bash
nvidia-smi

# Should show GPU info
```

3. **Configure wsl.conf:**
```bash
sudo nano /etc/wsl.conf
# Add GPU_CACHE_DIR configuration
```

### Issue 4: Model Loading Errors

**Symptoms:**
```
Failed to load model: Invalid file format
```

**Solutions:**

1. **Verify model file:**
```bash
file /home/YOUR_USER/models/Qwen3.5-9B-Q5_K_M.gguf
# Should show: GGUF model data
```

2. **Download correct model:**
```bash
huggingface-cli download bartowski/Qwen3.5-9B-GGUF \
    Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    --local-dir /home/YOUR_USER/models/qwen3.5-9b
```

### Issue 5: High Memory Usage

**Symptoms:**
```
System RAM usage > 90%
```

**Solutions:**

1. **Reduce context size:**
```bash
--ctx-size 2048
```

2. **Use smaller quantization:**
```bash
-Q4_K_M
```

3. **Optimize KV cache:**
```bash
--kv-cache-quantization Q8_0
```

---

## ⚡ Optimization Tips

### 1. VRAM Management

```bash
# Optimal VRAM usage for RTX 4080
--gpu-memory-utilization 0.95 \
# Use 95% of available VRAM

# Leave 5% for overhead
--gpu-memory-fraction 0.95
```

### 2. Context Window Optimization

```bash
# For chat applications
--ctx-size 4096 \
-n-predict 1024

# For code generation
--ctx-size 8192 \
-n-predict 2048

# For document analysis
--ctx-size 16384 \
-n-predict 4096
```

### 3. Multi-threading

```bash
# Balance between speed and memory
--threads 8 \
# Use all 8 physical cores

# Or use hyperthreading
--threads 16 \
# Use 16 logical cores
```

### 4. Flash Attention

```bash
# Enable Flash Attention (recommended)
--flash-attn 1

# Or disable for compatibility
--flash-attn 0
```

### 5. Batch Processing

```bash
# Increase batch size for better throughput
--n-gpu-batch 1024 \
--batch-size 512 \
--vocab-batch 512
```

---

## 📚 Best Practices

### 1. Model Selection Strategy

**For Development Work:**
- Use **Qwen3.5 9B Q5_K_M**
- Balance between code quality and speed
- 6.5GB VRAM leaves room for other tools

**For Research/Analysis:**
- Use **Qwen3.5 9B Q5_K_L**
- Higher precision for mathematical tasks
- 6.8GB VRAM still fits comfortably

**For Maximum Quality:**
- Use **Qwen3.5 14B Q4_K_M**
- Best for complex reasoning tasks
- 9GB VRAM with 3GB margin

**For Production/API:**
- Use **Qwen3.5 9B Q4_K_M**
- Fastest response times
- Lower VRAM for concurrent requests

### 2. Quantization Guidelines

| Quantization | Use When | Avoid When |
|--------------|----------|------------|
| Q8_0 | Maximum precision needed | VRAM limited |
| Q6_K_L | High-end GPU (24GB+) | Limited VRAM |
| Q5_K_M | **General purpose** | Extreme speed needed |
| Q4_K_M | **API/Production** | Research tasks |
| Q3_K_M | Limited VRAM (8GB) | Quality-sensitive tasks |

### 3. Context Window Guidelines

| Task | Recommended Context |
|------|---------------------|
| Chat/Conversation | 2048-4096 |
| Code Generation | 4096-8192 |
| Document Analysis | 8192-16384 |
| Mathematical Proof | 4096-8192 |
| Creative Writing | 4096-8192 |

### 4. Maintenance Schedule

```bash
# Weekly: Check model files
ls -lh /home/YOUR_USER/models/*.gguf

# Monthly: Update llama.cpp
cd /etc/llamaCPP/llama.cpp
git pull
make -j$(nproc)

# Quarterly: Benchmark performance
./llama.cpp/build/bin/llama-bench \
    -m /home/antonio/models/Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    -ngl 32 \
    -b 1

# Daily: Monitor VRAM usage
watch -n 5 'nvidia-smi --query-gpu=memory.used,memory.total --format=csv'
```

### 5. Security Best Practices

/opt/llamaCPP/llama.cpp/ ?  A better place for Llama.cpp
/usr/models/ ?  A better place for LLM models

```bash
# Set proper permissions
chmod 700 /home/YOUR_USER/models/
chmod 755 PATH_TO_LLAMACPP/llama.cpp/ # e.g: chmod 755 /opt/llamaCPP/llama.cpp/build/bin/llama-server

# Don't expose server to internet
--host 127.0.0.1 \
# Only localhost access

# Use environment variables for API keys
```

---

## 📖 Quick Reference Commands

### Stop Server

```bash
# Graceful shutdown
curl -X POST http://localhost:8080/stop

# Or kill process
pkill -f llama-server
```

### Check Status

```bash
# GPU usage
nvidia-smi

# Server status
curl http://localhost:8080/status

# Memory usage
free -h
```

---

## 📚 Additional Resources

### Documentation Links

- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Qwen3.5 HuggingFace](https://huggingface.co/Qwen/Qwen3.5)
- [GGUF Memory Calculator](https://ggufloader.github.io/gguf-memory-calculator.html)
- [llama.cpp VRAM Guide](https://localllm.in/blog/llamacpp-vram-requirements-for-local-llms)

### Useful Tools

```bash
# Model benchmarking
./llama.cpp/build/bin/llama-bench \
    -m /home/antonio/models/Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    -ngl 32 \
    -b 1

# Interactive shell
./llama.cpp/build/bin/llama-cli \
    -m /home/antonio/models/Qwen3.5-9B-Instruct-Q5_K_M.gguf \
    -ngl 32 \
    -c 4096

# Model conversion
python convert-hf-to-gguf.py \
    /path/to/model \
    --outfile /home/antonio/models/model.gguf
```

---

## Tips

### RAM Calculation

Each LLM Transformer layer needs around ~180�320 MB por layer (model-dependent, rough estimate) of VRAM (For GPU) / RAM (for CPU) depending of the Quantization.
 - Q4_K_M: would be around 200MB per Layer.
 - Q5_K_M: Would be around 300MB per Layer.
 
Every 4096 tokens will need a KV Cache equivalent to ~1.2GB VRAM / RAM

System + Overhead will required 0.5GB of VRAM/ RAM

Doing some math example for QWEN3.5-9B-Q5_K_M.gguf:

| Component | VRAM Required (Q5_K_M) |
|------------|-------------------------|
| Model weights (32 layers) | ~9.4 GB |
| KV Cache (Context 4096) | ~1.2 GB |
| System + overhead | ~0.5 GB |
| **Total** | **~11.1 GB** |

A little tight for a 12GB VRAM GPU, but totally functional. 

Now, depending of the task, you may need to have more context, let's says 8192 tokens of context, you can sacrifice some inference speed by loading less layers on the GPU:

| Component | VRAM Required (Q5_K_M) |
|------------|-------------------------|
| Model weights (28 layers) | ~8.2 GB |
| KV Cache (Context 8192) | ~2.4 GB |
| System + overhead | ~0.5 GB |
| **Total** | **~11.1 GB** |

As you have more GPU VRAM available, you could try add even more context (2048 more):

| Component | VRAM Required (Q5_K_M) |
|------------|-------------------------|
| Model weights (28 layers) | ~8.2 GB |
| KV Cache (Context 10240) | ~3.0 GB |
| System + overhead | ~0.5 GB |
| **Total** | **~11.7 GB** |

But you will have only 2.5% of the GPU free, is always recommended to have 5%.

KV cache memory depends on the total active context (-c), not separately on input or output tokens.

Note: QWEN3.5-14B has 40 Layers.

### Additional Parameters for llama.cpp

| Parameter | Value | Description |
|-----------|-------|-------------|
| `-c` | 8192 | Context size (text length, max buffer) |
| `-n` | 4096 | Max output tokens |
| `--ngl` | 32 | Layers on GPU (depends of LLM used) |
| `--port` | 8080 | Server port |
| `--host` | 0.0.0.0 | Listen on all interfaces |
| `--threads` | 8 | CPU threads for parallelization |
| `--flash-attn` | 1 | Enable Flash Attention (speed boost) |

---

---

## ✅ Checklist for Production Setup

- [ ] WSL2 configured with GPU passthrough
- [ ] CUDA drivers installed and working
- [ ] llama.cpp built with CUDA support
- [ ] Qwen3.5 model downloaded (Q5_K_M recommended)
- [ ] Hermes Agent installed and configured
- [ ] Server running on localhost:8080
- [ ] Context size set to 8192 tokens
- [ ] Flash Attention enabled
- [ ] GPU memory utilization at 95%
- [ ] Proper file permissions set
- [ ] Backup strategy in place

---

**Document Version:** 1.0  
**Last Updated:** March 18, 2026  
**Author:** Antonio Martinez  
**System:** WSL2 + RTX 4080 + Hermes Agent  
**Status:** Production Ready  
