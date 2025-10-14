#!/bin/bash

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
# Start gpuminer in screen
# ==============================

# Hostname
hostname_var=$(hostname)

SESSION_NAME="CPU_restarted"
MINER_CMD="./drpoolavx512 -w kingsrule.$hostname_var -p stratum+tcp://neptune.drpool.io:30127 -g 0"

echo "Starting gpuminer in screen session: $SESSION_NAME"
screen -dmS "$SESSION_NAME" bash -lc "$MINER_CMD"

echo "✅ drpoolavx512 is running now in screen session '$SESSION_NAME'"
