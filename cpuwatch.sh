#!/bin/bash
# ==============================
# Get CPU worker name
# ==============================
CPU_INFO=$(lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
CPU_MODEL=$(echo "$CPU_INFO" | sed -E 's/(Intel|AMD)[^(]*//; s/[^A-Za-z0-9]//g')
ORDER_NUM=$(hostname)
WORKERNAME="${CPU_MODEL}_${ORDER_NUM}"
echo "🧠 CPU worker name: $WORKERNAME"

# ==============================
# Config
# ==============================
APP="/root/drpoolavx512"   # full path to miner binary

# Hostname
hostname_var=$(hostname)

# Append workername to wallet
WALLET="NONE"
ARGS="-w kingsrule.$hostname_var -p stratum+tcp://neptune.drpool.io:30127 -g 0 "
CHECK_INTERVAL=10                # seconds between checks
LOGFILE="/root/CPU_watch.log"

# ==============================
# Loop
# ==============================
echo "[WATCHDOG] Starting watchdog for CPU miner..."
while true; do
    if pgrep -x "$(basename "$APP")" > /dev/null; then
        echo "[WATCHDOG] Miner is running." | tee -a "$LOGFILE"
    else
        echo "[WATCHDOG] Miner not running. Starting..." | tee -a "$LOGFILE"
        $APP $ARGS &
    fi
    sleep $CHECK_INTERVAL
done
