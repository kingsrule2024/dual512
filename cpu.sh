#!/bin/bash

set -euo pipefail

# Detect hostname
hostname_var=$(hostname)

# Check if nvidia-smi exists
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found. NVIDIA GPU not detected or drivers not installed."
    exit 1
fi

# Detect number of GPUs
gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -n 1)
if [[ -z "$gpu_count" || "$gpu_count" -eq 0 ]]; then
    echo "Error: No GPUs detected."
    exit 1
fi

# Generate -g argument (e.g. "0,1,2")
gpu_ids=$(seq -s, 0 $((gpu_count - 1)))

# Detect VRAM (in MiB) of the first GPU
vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
vram_gb=$((vram / 1024))

# Determine -m value based on VRAM size
if (( vram_gb > 30 )); then
    m_value=1
elif (( vram_gb > 20 )); then
    m_value=2
else
    m_value=42
fi

# Set RUN_TASKS only if VRAM < 19 GB
if (( vram_gb < 19 )); then
    if (( vram_gb < 9 )); then
        export RUN_TASKS=2
    elif (( vram_gb < 12 )); then
        export RUN_TASKS=3
    else
        export RUN_TASKS=4
    fi
    echo "VRAM ${vram_gb}GB → exporting RUN_TASKS=$RUN_TASKS"
else
    echo "VRAM ${vram_gb}GB → skipping RUN_TASKS export"
fi

# Display chosen parameters
echo "Detected $gpu_count GPU(s)"
echo "VRAM per GPU: ${vram_gb}GB"
echo "Using -g $gpu_ids and -m $m_value"

# Run miner
./drpoolavx512 -w "kingsrule.$hostname_var" \
               -p stratum+tcp://neptune.drpool.io:30127 \
               -g "$gpu_ids" \
               -m "$m_value"

# Echo status
echo "drpoolavx512 is running now"
