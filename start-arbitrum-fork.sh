#!/bin/bash

# Script to start Anvil with Arbitrum fork for Aave V3 testing
# This allows you to test Aave V3 integration on a forked Arbitrum network

echo "Starting Anvil with Arbitrum fork..."
echo "This will allow Aave V3 operations to work properly."
echo ""
echo "Press Ctrl+C to stop Anvil"
echo ""

anvil --fork-url https://arb1.arbitrum.io/rpc \
      --chain-id 31337 \
      --block-time 1 \
      --host 0.0.0.0 \
      --allow-origin "*"

