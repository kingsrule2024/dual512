#!/bin/bash
# ==============================
# Get GPU worker name
# ==============================
GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
GPU_MODEL=$(echo "$GPU_INFO" | sed -E 's/^(NVIDIA |nvidia )//; s/(GeForce |geforce )//; s/(RTX |rtx )//; s/[Ss][Uu][Pp][Ee][Rr]/S/; s/ //g')
ORDER_NUM=$(hostname)
WORKERNAME="${GPU_MODEL}_${ORDER_NUM}"
echo "🎮 GPU worker name: $WORKERNAME"

# ==============================
# Config
# ==============================
APP="/root/miner"   # full path to miner binary
# Append workername to wallet
WALLET="3jdRadLZyw1FPCMdzM4KKcDXgk3EWeg4ZX9mfD8ZeGPJ8TAwpLHxrwTD97MmQ64KWHAQ4y41Au7T4881N1JzFG3SGRxj3SXgHRFLbHxdKHCYLWW31BaQuzCFecMciyhkMUPB"
ARGS="--pubkey $WALLET --name=$(hostname) --label=Rental --threads-per-card=2"
CHECK_INTERVAL=10                # seconds between checks
LOGFILE="/root/GPU_watch.log"

# ==============================
# Loop
# ==============================
echo "[WATCHDOG] Starting watchdog for GPU miner..."
while true; do
    if pgrep -x "$(basename "$APP")" > /dev/null; then
        echo "[WATCHDOG] Miner is running." | tee -a "$LOGFILE"
    else
        echo "[WATCHDOG] Miner not running. Starting..." | tee -a "$LOGFILE"
        $APP $ARGS &
    fi
    sleep $CHECK_INTERVAL
done