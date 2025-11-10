#!/bin/bash
# =====================================================
#  drpoolavx512 Watchdog — Auto GPU/CPU Config & Restart Delay
# =====================================================

set -euo pipefail

# ------------------------------
# CPU and Worker Information
# ------------------------------
CPU_INFO=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
CPU_MODEL=$(echo "$CPU_INFO" | sed -E 's/(Intel|AMD)[^(]*//; s/[^A-Za-z0-9]//g')
ORDER_NUM=$(hostname)
WORKERNAME="${CPU_MODEL}_${ORDER_NUM}"
hostname_var=$(hostname)
echo "🧠 CPU worker name: $WORKERNAME"

# ------------------------------
# Configuration
# ------------------------------
APP="/root/drpoolavx512"                 # Full path to miner binary
WALLET="kingsrule.$hostname_var"
POOL="stratum+tcp://neptune.drpool.io:30127"
CHECK_INTERVAL=10                        # seconds between checks
RESTART_DELAY=30                         # delay before restart if miner stops
LOGFILE="/root/CPU_watch.log"

# ------------------------------
# GPU / CPU Detection
# ------------------------------
if command -v nvidia-smi &> /dev/null; then
    gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -n 1)
    if [[ -z "$gpu_count" || "$gpu_count" -eq 0 ]]; then
        echo "[WATCHDOG] No GPUs detected." | tee -a "$LOGFILE"
        gpu_count=0
    fi
else
    echo "[WATCHDOG] nvidia-smi not found. Skipping GPU detection." | tee -a "$LOGFILE"
    gpu_count=0
fi

# Generate GPU IDs (e.g. "0,1,2") if GPUs exist
if (( gpu_count > 0 )); then
    gpu_ids=$(seq -s, 0 $((gpu_count - 1)))
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
    vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
    vram_gb=$((vram / 1024))
else
    gpu_ids="0"
    gpu_name="None"
    vram_gb=0
fi

echo "[WATCHDOG] Detected GPU: $gpu_name | VRAM: ${vram_gb}GB | Count: $gpu_count" | tee -a "$LOGFILE"
echo "[WATCHDOG] Detected CPU: $CPU_MODEL" | tee -a "$LOGFILE"

# ------------------------------
# Determine -m and RUN_TASKS
# ------------------------------
m_value=42  # default

# ---- Special Case: RTX 4090 + Ryzen 7950X/7950X3D/9950X/9950X3D ----
if [[ "$gpu_name" == *"4090"* ]] && [[ "$CPU_MODEL" =~ (7950X|7950X3D|9950X|9950X3D) ]]; then
    m_value=42
    export RUN_TASKS=8
    echo "[WATCHDOG] Special config: RTX 4090 + $CPU_MODEL → -m 42, RUN_TASKS=8" | tee -a "$LOGFILE"

# ---- Normal GPU Config ----
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
        echo "[WATCHDOG] Low VRAM ${vram_gb}GB → RUN_TASKS=$RUN_TASKS" | tee -a "$LOGFILE"
    fi
else
    echo "[WATCHDOG] No GPU info, using default -g 0 -m 42" | tee -a "$LOGFILE"
fi

ARGS="-w $WALLET -p $POOL -g $gpu_ids -m $m_value"

echo "[WATCHDOG] Final launch args: $ARGS" | tee -a "$LOGFILE"

# ------------------------------
# Watchdog Loop
# ------------------------------
echo "[WATCHDOG] Starting watchdog for drpoolavx512..."
while true; do
    if pgrep -x "$(basename "$APP")" > /dev/null; then
        echo "[WATCHDOG] Miner is running." | tee -a "$LOGFILE"
    else
        echo "[WATCHDOG] Miner not running. Waiting $RESTART_DELAY seconds before restart..." | tee -a "$LOGFILE"
        sleep "$RESTART_DELAY"
        echo "[WATCHDOG] Restarting drpoolavx512..." | tee -a "$LOGFILE"
        $APP $ARGS &
    fi
    sleep "$CHECK_INTERVAL"
done
