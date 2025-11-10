#!/bin/bash

set -euo pipefail

# Detect hostname
hostname_var=$(hostname)

# Check GPU availability
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found. NVIDIA GPU not detected or drivers not installed."
    exit 1
fi

# Detect CPU
cpu_model=$(lscpu | grep "Model name" | sed 's/Model name:[ \t]*//')

# Detect number of GPUs
gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -n 1)
if [[ -z "$gpu_count" || "$gpu_count" -eq 0 ]]; then
    echo "Error: No GPUs detected."
    exit 1
fi

# Generate -g argument (e.g. "0,1,2")
gpu_ids=$(seq -s, 0 $((gpu_count - 1)))

# Detect first GPU name and VRAM
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
vram_gb=$((vram / 1024))

echo "Detected CPU: $cpu_model"
echo "Detected GPU: $gpu_name"
echo "VRAM: ${vram_gb}GB | GPU Count: $gpu_count"

# Default -m value
m_value=42

# ---- SPECIAL CASE: RTX 4090 + High-end Ryzen CPUs ----
if [[ "$gpu_name" == *"4090"* ]] && \
   [[ "$cpu_model" =~ (7950X|7950X3D|9950X|9950X3D) ]]; then
    m_value=42
    export RUN_TASKS=8
    echo "Special config applied: RTX 4090 + $cpu_model → -m 42, RUN_TASKS=8"

# ---- NORMAL CONFIGURATION ----
else
    if (( vram_gb > 30 )); then
        m_value=1
    elif (( vram_gb > 20 )); then
        m_value=2
    else
        m_value=42
        # Set RUN_TASKS for low VRAM GPUs
        if (( vram_gb < 9 )); then
            export RUN_TASKS=2
        elif (( vram_gb < 12 )); then
            export RUN_TASKS=3
        else
            export RUN_TASKS=4
        fi
        echo "VRAM ${vram_gb}GB → RUN_TASKS=$RUN_TASKS"
    fi
fi

# Show summary
echo "Using -g $gpu_ids and -m $m_value"

# Run miner
./drpoolavx512 -w "kingsrule.$hostname_var" \
               -p stratum+tcp://neptune.drpool.io:30127 \
               -g "$gpu_ids" \
               -m "$m_value"

echo "drpoolavx512 is running now"
