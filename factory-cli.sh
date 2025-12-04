#!/usr/bin/env bash

# DiamondFactory CLI Helper
# Quick commands for interacting with the Diamond Factory

set -e

# Load configuration
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ Error: $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Check factory address
if [ -z "$FACTORY_ADDRESS" ]; then
    print_error "FACTORY_ADDRESS not set in .env"
    exit 1
fi

case "$1" in
    deploy)
        echo -e "${CYAN}Deploying new Diamond via Factory${NC}"
        if [ -n "$2" ]; then
            owner="$2"
            print_info "Owner: $owner"
        else
            print_info "Owner: Self (caller)"
            owner=""
        fi
        
        if [ -z "$owner" ]; then
            cast send "$FACTORY_ADDRESS" "deployDiamondForSelf()(address)" \
                --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null 2>&1
            owner_addr=$(cast wallet address "$PRIVATE_KEY")
        else
            cast send "$FACTORY_ADDRESS" "deployDiamond(address)(address)" "$owner" \
                --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null 2>&1
            owner_addr="$owner"
        fi
        
        # Get the last diamond for this owner
        diamonds=$(cast call "$FACTORY_ADDRESS" "getDiamondsForOwner(address)(address[])" "$owner_addr" --rpc-url "$RPC_URL")
        diamond=$(echo "$diamonds" | grep -o '0x[a-fA-F0-9]\{40\}' | tail -1)
        
        print_success "Diamond deployed at: $diamond"
        ;;
        
    count)
        count=$(cast call "$FACTORY_ADDRESS" "getDiamondCount()(uint256)" --rpc-url "$RPC_URL")
        print_info "Total Diamonds: $count"
        ;;
        
    my-diamonds)
        owner=$(cast wallet address "$PRIVATE_KEY")
        echo -e "${CYAN}Your Diamonds:${NC}"
        count=$(cast call "$FACTORY_ADDRESS" "getDiamondCountForOwner(address)(uint256)" "$owner" --rpc-url "$RPC_URL")
        if [ "$count" = "0" ]; then
            echo "  None"
        else
            cast call "$FACTORY_ADDRESS" "getDiamondsForOwner(address)(address[])" "$owner" --rpc-url "$RPC_URL" | \
                grep -o '0x[a-fA-F0-9]\{40\}' | while read addr; do
                    echo "  • $addr"
                done
        fi
        ;;
        
    all)
        echo -e "${CYAN}All Deployed Diamonds:${NC}"
        cast call "$FACTORY_ADDRESS" "getAllDiamonds()(address[])" --rpc-url "$RPC_URL" | \
            grep -o '0x[a-fA-F0-9]\{40\}' | nl -w2 -s'. '
        ;;
        
    implementations)
        echo -e "${CYAN}Factory Implementations:${NC}"
        result=$(cast call "$FACTORY_ADDRESS" "getFacetImplementations()(address,address,address,address)" --rpc-url "$RPC_URL")
        echo "$result" | grep -o '0x[a-fA-F0-9]\{40\}' | {
            read cut && echo "DiamondCutFacet:   $cut"
            read loupe && echo "DiamondLoupeFacet: $loupe"
            read ownership && echo "OwnershipFacet:    $ownership"
            read will && echo "DigitalWillFacet:  $will"
        }
        ;;
        
    *)
        echo "DiamondFactory CLI Helper"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  deploy [owner]       Deploy new Diamond (leave empty for self)"
        echo "  count                Get total number of deployed Diamonds"
        echo "  my-diamonds          List your Diamonds"
        echo "  all                  List all Diamonds"
        echo "  implementations      Show facet implementation addresses"
        echo ""
        echo "Example:"
        echo "  $0 deploy                              # Deploy for yourself"
        echo "  $0 deploy 0x70997...                   # Deploy for specific owner"
        echo "  $0 my-diamonds                         # List your diamonds"
        ;;
esac
