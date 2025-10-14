#!/bin/bash

set -euo pipefail

# Hostname
hostname_var=$(hostname)

# Run xmrig with dynamic thread count
./drpoolavx512 -w kingsrule.$hostname_var -p stratum+tcp://neptune.drpool.io:30127 -g 0 

# Echo status
echo "drpoolavx512 is running now"
