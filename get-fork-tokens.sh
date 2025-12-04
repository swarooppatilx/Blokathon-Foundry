#!/bin/bash

# Script to get tokens on Arbitrum fork for testing Aave
# This script impersonates whale addresses to transfer tokens to your test account

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Your test account (Anvil account #0)
RECIPIENT="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
RPC_URL="http://localhost:8545"

echo -e "${GREEN}Getting tokens on Arbitrum fork...${NC}"
echo ""

# USDC whale on Arbitrum: Binance hot wallet
USDC_WHALE="0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D"
USDC_TOKEN="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
USDC_AMOUNT="1000000000"  # 1,000 USDC (6 decimals)

echo -e "${YELLOW}1. Getting USDC...${NC}"
cast rpc anvil_impersonateAccount $USDC_WHALE --rpc-url $RPC_URL > /dev/null
cast send $USDC_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $USDC_AMOUNT \
    --rpc-url $RPC_URL \
    --from $USDC_WHALE \
    --unlocked > /dev/null
cast rpc anvil_stopImpersonatingAccount $USDC_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received 1,000 USDC${NC}"

# USDT whale
USDT_WHALE="0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D"
USDT_TOKEN="0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
USDT_AMOUNT="1000000000"  # 1,000 USDT (6 decimals)

echo -e "${YELLOW}2. Getting USDT...${NC}"
cast rpc anvil_impersonateAccount $USDT_WHALE --rpc-url $RPC_URL > /dev/null
cast send $USDT_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $USDT_AMOUNT \
    --rpc-url $RPC_URL \
    --from $USDT_WHALE \
    --unlocked > /dev/null 2>&1 || echo "USDT transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $USDT_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received USDT${NC}"

# WETH - we can just wrap ETH
WETH_TOKEN="0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
WETH_AMOUNT="5000000000000000000"  # 5 WETH (18 decimals)

echo -e "${YELLOW}3. Getting WETH...${NC}"
cast send $WETH_TOKEN \
    "deposit()" \
    --value $WETH_AMOUNT \
    --rpc-url $RPC_URL \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 > /dev/null
echo -e "${GREEN}✓ Wrapped 5 ETH to WETH${NC}"

# ARB whale
ARB_WHALE="0xF3FC178157fb3c87548bAA86F9d24BA38E649B58"  # Arbitrum Foundation
ARB_TOKEN="0x912CE59144191C1204E64559FE8253a0e49E6548"
ARB_AMOUNT="1000000000000000000000"  # 1,000 ARB (18 decimals)

echo -e "${YELLOW}4. Getting ARB...${NC}"
cast rpc anvil_impersonateAccount $ARB_WHALE --rpc-url $RPC_URL > /dev/null
cast send $ARB_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $ARB_AMOUNT \
    --rpc-url $RPC_URL \
    --from $ARB_WHALE \
    --unlocked > /dev/null 2>&1 || echo "ARB transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $ARB_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received ARB${NC}"

echo ""
echo -e "${GREEN}✅ Token setup complete!${NC}"
echo ""
echo "Your balances:"
echo -n "USDC: "
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "USDT: "
cast call $USDT_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "WETH: "
cast call $WETH_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "ARB:  "
cast call $ARB_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
