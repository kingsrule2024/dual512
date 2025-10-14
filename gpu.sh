#!/bin/bash

set -euo pipefail

./miner --pubkey=3jdRadLZyw1FPCMdzM4KKcDXgk3EWeg4ZX9mfD8ZeGPJ8TAwpLHxrwTD97MmQ64KWHAQ4y41Au7T4881N1JzFG3SGRxj3SXgHRFLbHxdKHCYLWW31BaQuzCFecMciyhkMUPB --name=$(hostname) --label=Rental --threads-per-card=2

# Echo status
echo "gpu miner is running now'"
