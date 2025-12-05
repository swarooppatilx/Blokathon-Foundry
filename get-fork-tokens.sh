#!/bin/bash

# Script to get tokens on Arbitrum fork for testing Aave
# This script impersonates whale addresses to transfer tokens to your test account
# Usage: ./get-fork-tokens.sh [ADDRESS]
# If no address provided, uses Anvil default account #0

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Your test account (Anvil account #0 by default, or custom address)
RECIPIENT="${1:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
RPC_URL="http://localhost:8545"

echo -e "${GREEN}Getting tokens on Arbitrum fork...${NC}"
echo -e "${BLUE}Recipient: $RECIPIENT${NC}"
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

# ARB whale - using a different whale with confirmed balance
ARB_WHALE="0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D"  # Binance hot wallet
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
    --unlocked > /dev/null 2>&1 && echo -e "${GREEN}✓ Received 1,000 ARB${NC}" || {
        # Try alternative whale
        ARB_WHALE_ALT="0x3e313a12d0e343e6e1f7c2b6b62229da60331b41"
        cast rpc anvil_stopImpersonatingAccount $ARB_WHALE --rpc-url $RPC_URL > /dev/null
        cast rpc anvil_impersonateAccount $ARB_WHALE_ALT --rpc-url $RPC_URL > /dev/null
        cast send $ARB_TOKEN \
            "transfer(address,uint256)" \
            $RECIPIENT \
            $ARB_AMOUNT \
            --rpc-url $RPC_URL \
            --from $ARB_WHALE_ALT \
            --unlocked > /dev/null 2>&1 && echo -e "${GREEN}✓ Received 1,000 ARB${NC}" || echo -e "${YELLOW}⚠ Could not get ARB (whale balance insufficient)${NC}"
        cast rpc anvil_stopImpersonatingAccount $ARB_WHALE_ALT --rpc-url $RPC_URL > /dev/null
    }
cast rpc anvil_stopImpersonatingAccount $ARB_WHALE --rpc-url $RPC_URL > /dev/null 2>&1

# Send ETH for gas (if recipient is not the default Anvil account)
RECIPIENT_LOWER=$(echo "$RECIPIENT" | tr '[:upper:]' '[:lower:]')
DEFAULT_ACCOUNT_LOWER="0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

if [ "$RECIPIENT_LOWER" != "$DEFAULT_ACCOUNT_LOWER" ]; then
    ETH_AMOUNT="100000000000000000000"  # 100 ETH
    echo -e "${YELLOW}4a. Sending ETH for gas...${NC}"
    cast send $RECIPIENT \
        --value $ETH_AMOUNT \
        --rpc-url $RPC_URL \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 > /dev/null
    echo -e "${GREEN}✓ Sent 100 ETH for gas${NC}"
fi

# DAI whale
DAI_WHALE="0xd85E038593d7A098614721EaE955EC2022B9B91B"  # GMX treasury
DAI_TOKEN="0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
DAI_AMOUNT="5000000000000000000000"  # 5,000 DAI (18 decimals)

echo -e "${YELLOW}5. Getting DAI...${NC}"
cast rpc anvil_impersonateAccount $DAI_WHALE --rpc-url $RPC_URL > /dev/null
cast send $DAI_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $DAI_AMOUNT \
    --rpc-url $RPC_URL \
    --from $DAI_WHALE \
    --unlocked > /dev/null 2>&1 || echo "DAI transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $DAI_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received DAI${NC}"

# LINK whale
LINK_WHALE="0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530"  # Chainlink
LINK_TOKEN="0xf97f4df75117a78c1A5a0DBb814Af92458539FB4"
LINK_AMOUNT="100000000000000000000"  # 100 LINK (18 decimals)

echo -e "${YELLOW}6. Getting LINK...${NC}"
cast rpc anvil_impersonateAccount $LINK_WHALE --rpc-url $RPC_URL > /dev/null
cast send $LINK_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $LINK_AMOUNT \
    --rpc-url $RPC_URL \
    --from $LINK_WHALE \
    --unlocked > /dev/null 2>&1 || echo "LINK transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $LINK_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received LINK${NC}"

# WBTC whale
WBTC_WHALE="0x489ee077994B6658eAfA855C308275EAd8097C4A"  # Gate.io
WBTC_TOKEN="0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
WBTC_AMOUNT="10000000"  # 0.1 WBTC (8 decimals)

echo -e "${YELLOW}7. Getting WBTC...${NC}"
cast rpc anvil_impersonateAccount $WBTC_WHALE --rpc-url $RPC_URL > /dev/null
cast send $WBTC_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $WBTC_AMOUNT \
    --rpc-url $RPC_URL \
    --from $WBTC_WHALE \
    --unlocked > /dev/null 2>&1 || echo "WBTC transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $WBTC_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received WBTC${NC}"

# UNI whale
UNI_WHALE="0x1A9C8182C09F50C8318d769245beA52c32BE35BC"  # Uniswap treasury
UNI_TOKEN="0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0"
UNI_AMOUNT="500000000000000000000"  # 500 UNI (18 decimals)

echo -e "${YELLOW}8. Getting UNI...${NC}"
cast rpc anvil_impersonateAccount $UNI_WHALE --rpc-url $RPC_URL > /dev/null
cast send $UNI_TOKEN \
    "transfer(address,uint256)" \
    $RECIPIENT \
    $UNI_AMOUNT \
    --rpc-url $RPC_URL \
    --from $UNI_WHALE \
    --unlocked > /dev/null 2>&1 || echo "UNI transfer failed (whale may not have balance)"
cast rpc anvil_stopImpersonatingAccount $UNI_WHALE --rpc-url $RPC_URL > /dev/null
echo -e "${GREEN}✓ Received UNI${NC}"

echo ""
echo -e "${GREEN}✅ Token setup complete!${NC}"
echo ""
echo "Your balances:"
echo -n "ETH:  "
cast balance $RECIPIENT --rpc-url $RPC_URL
echo -n "USDC: "
cast call $USDC_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "USDT: "
cast call $USDT_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "WETH: "
cast call $WETH_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "ARB:  "
cast call $ARB_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "DAI:  "
cast call $DAI_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "LINK: "
cast call $LINK_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "WBTC: "
cast call $WBTC_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
echo -n "UNI:  "
cast call $UNI_TOKEN "balanceOf(address)(uint256)" $RECIPIENT --rpc-url $RPC_URL
