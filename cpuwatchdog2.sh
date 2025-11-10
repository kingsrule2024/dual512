#!/bin/bash
# =====================================================
# GPU Miner Launcher with Smart Auto-Config (CPU+GPU)
# =====================================================

# Load environment
source /etc/profile
[ -f ~/.bashrc ] && source ~/.bashrc

cd /root/ || exit 1
set -euo pipefail

# ==============================
# Requirements
# ==============================
require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' not found. Please install it."; exit 1; }
}

require screen

# ==============================
# Cleanup old miner sessions
# ==============================
echo "Cleaning up old miner_* screen sessions…"
OLD_SESSIONS=$(screen -ls | awk '/miner_/ {print $1}' || true)
if [[ -n "$OLD_SESSIONS" ]]; then
  for s in $OLD_SESSIONS; do
    echo "Attempting to kill $s"
    screen -S "$s" -X quit || true
  done
fi
screen -wipe >/dev/null || true

# Kill any miner processes outside screen
echo "Killing stray miner processes…"
pkill drpoolavx512 || true

# ==============================
# Detect Hostname / Worker
# ==============================
hostname_var=$(hostname)
CPU_INFO=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
CPU_MODEL=$(echo "$CPU_INFO" | sed -E 's/(Intel|AMD)[^(]*//; s/[^A-Za-z0-9]//g')
echo "🧠 CPU Model: $CPU_MODEL"
echo "💻 Hostname: $hostname_var"

# ==============================
# GPU Detection
# ==============================
gpu_ids="0"
gpu_name="None"
vram_gb=0
gpu_count=0

if command -v nvidia-smi &> /dev/null; then
    gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -n 1)
    if [[ -n "$gpu_count" && "$gpu_count" -gt 0 ]]; then
        gpu_ids=$(seq -s, 0 $((gpu_count - 1)))
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
        vram_gb=$((vram / 1024))
    fi
else
    echo "⚠️ nvidia-smi not found. Assuming no GPU."
fi

echo "🎮 GPU Detected: $gpu_name | Count: $gpu_count | VRAM: ${vram_gb}GB"

# ==============================
# Auto-config logic
# ==============================
m_value=42  # default
unset RUN_TASKS || true

# --- Special Case: RTX 4090 + Ryzen 7950X/7950X3D/9950X/9950X3D ---
if [[ "$gpu_name" == *"4090"* ]] && [[ "$CPU_MODEL" =~ (7950X|7950X3D|9950X|9950X3D) ]]; then
    m_value=42
    export RUN_TASKS=8
    echo "🔥 Special config: RTX 4090 + $CPU_MODEL → -m 42, RUN_TASKS=8"

# --- Normal GPU configuration ---
elif (( vram_gb > 0 )); then
    if (( vram_gb > 30 )); then
        m_value=1
    elif (( vram_gb > 20 )); then
        m_value=2
    else
        m_value=42
        if (( vram_gb < 9 )); then
            export RUN_TASKS=2
        elif (( vram_gb < 12 )); then
            export RUN_TASKS=3
        else
            export RUN_TASKS=4
        fi
        echo "⚙️ VRAM ${vram_gb}GB → RUN_TASKS=$RUN_TASKS"
    fi
else
    echo "Using default config: -g 0 -m 42"
fi

# ==============================
# Launch miner inside screen
# ==============================
SESSION_NAME="CPU_restarted"
MINER_CMD="./drpoolavx512 -w kingsrule.$hostname_var -p stratum+tcp://neptune.drpool.io:30127 -g $gpu_ids -m $m_value"

echo "🧩 Launch arguments:"
echo "  GPU IDs  : $gpu_ids"
echo "  -m Value : $m_value"
[[ -n "${RUN_TASKS:-}" ]] && echo "  RUN_TASKS: $RUN_TASKS"

echo "🚀 Starting gpuminer in screen session: $SESSION_NAME"
screen -dmS "$SESSION_NAME" bash -lc "$MINER_CMD"

echo "✅ drpoolavx512 is now running in screen session '$SESSION_NAME'"
