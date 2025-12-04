#!/bin/bash

# Integration Test Script
# Tests all scripts and functions work together with current contracts

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════"
}

# Source environment
source .env

print_header "Integration Test Suite"

# Test 1: Contracts compile
print_info "Test 1: Checking if contracts compile..."
if forge build > /dev/null 2>&1; then
    print_success "Contracts compile successfully"
else
    print_error "Contracts failed to compile"
    exit 1
fi

# Test 2: All unit tests pass
print_info "Test 2: Running unit tests..."
TEST_OUTPUT=$(forge test 2>&1)
if echo "$TEST_OUTPUT" | grep -q "22 tests passed"; then
    print_success "All unit tests pass (22/22)"
else
    print_error "Some unit tests failed"
    exit 1
fi

# Test 3: Deploy.s.sol works
print_info "Test 3: Testing Deploy.s.sol script..."
if forge script script/Deploy.s.sol --rpc-url $RPC_URL_ANVIL --broadcast > /dev/null 2>&1; then
    DIAMOND_ADDR=$(cat broadcast/Deploy.s.sol/*/run-latest.json 2>/dev/null | jq -r '.transactions[] | select(.contractName == "Diamond") | .contractAddress' | head -1)
    if [ -n "$DIAMOND_ADDR" ] && [ "$DIAMOND_ADDR" != "null" ]; then
        print_success "Deploy.s.sol deploys Diamond: $DIAMOND_ADDR"
        export TEST_DIAMOND=$DIAMOND_ADDR
    else
        print_error "Failed to extract Diamond address"
        exit 1
    fi
else
    print_error "Deploy.s.sol script failed"
    exit 1
fi

# Test 4: DeployFactory.s.sol works
print_info "Test 4: Testing DeployFactory.s.sol script..."
if forge script script/DeployFactory.s.sol --rpc-url $RPC_URL_ANVIL --broadcast > /dev/null 2>&1; then
    FACTORY_ADDR=$(cat broadcast/DeployFactory.s.sol/*/run-latest.json 2>/dev/null | jq -r '.transactions[] | select(.contractName == "DiamondFactory") | .contractAddress' | head -1)
    if [ -n "$FACTORY_ADDR" ] && [ "$FACTORY_ADDR" != "null" ]; then
        print_success "DeployFactory.s.sol deploys Factory: $FACTORY_ADDR"
        export TEST_FACTORY=$FACTORY_ADDR
    else
        print_error "Failed to extract Factory address"
        exit 1
    fi
else
    print_error "DeployFactory.s.sol script failed"
    exit 1
fi

# Test 5: Diamond has correct facets
print_info "Test 5: Checking Diamond has all 4 facets..."
FACET_COUNT=$(cast call $TEST_DIAMOND "facetAddresses()(address[])" --rpc-url $RPC_URL | grep -o "0x" | wc -l)
if [ "$FACET_COUNT" -ge 4 ]; then
    print_success "Diamond has $FACET_COUNT facets (expected 4)"
    export INITIAL_FACET_COUNT=$FACET_COUNT
else
    print_error "Diamond has only $FACET_COUNT facets"
    exit 1
fi

# Test 6: Diamond Loupe functions work
print_info "Test 6: Testing Diamond Loupe facet..."
OWNER=$(cast call $TEST_DIAMOND "owner()(address)" --rpc-url $RPC_URL 2>/dev/null)
if [ -n "$OWNER" ] && [ "$OWNER" != "0x0000000000000000000000000000000000000000" ]; then
    print_success "Loupe facet works, owner: ${OWNER:0:10}..."
else
    print_error "Loupe facet failed"
    exit 1
fi

# Test 7: Factory creates Diamonds
print_info "Test 7: Testing Factory diamond deployment..."
DIAMOND_COUNT_BEFORE=$(cast call $TEST_FACTORY "getDiamondCount()(uint256)" --rpc-url $RPC_URL | awk '{print $1}')
if cast send $TEST_FACTORY "deployDiamondForSelf()(address)" --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1; then
    DIAMOND_COUNT_AFTER=$(cast call $TEST_FACTORY "getDiamondCount()(uint256)" --rpc-url $RPC_URL | awk '{print $1}')
    if [ "$DIAMOND_COUNT_AFTER" -gt "$DIAMOND_COUNT_BEFORE" ]; then
        print_success "Factory deployed Diamond (count: $DIAMOND_COUNT_BEFORE → $DIAMOND_COUNT_AFTER)"
    else
        print_error "Factory diamond count didn't increase"
        exit 1
    fi
else
    print_error "Factory deployment failed"
    exit 1
fi

# Test 8: Factory CLI works
print_info "Test 8: Testing factory-cli.sh..."
export FACTORY_ADDRESS=$TEST_FACTORY
COUNT_OUTPUT=$(./factory-cli.sh count 2>&1)
if echo "$COUNT_OUTPUT" | grep -q "Total Diamonds"; then
    print_success "factory-cli.sh works"
else
    print_error "factory-cli.sh failed"
    exit 1
fi

# Test 9: DeployFacet.s.sol works (add Aave V3)
print_info "Test 9: Testing DeployFacet.s.sol (Aave V3 addition)..."
export DIAMOND_ADDRESS=$TEST_DIAMOND
if forge script script/DeployFacet.s.sol --rpc-url $RPC_URL_ANVIL --broadcast > /dev/null 2>&1; then
    FACET_COUNT_AFTER=$(cast call $TEST_DIAMOND "facetAddresses()(address[])" --rpc-url $RPC_URL | grep -o "0x" | wc -l)
    if [ "$FACET_COUNT_AFTER" -gt "$INITIAL_FACET_COUNT" ]; then
        print_success "DeployFacet.s.sol added Aave V3 facet (count: $INITIAL_FACET_COUNT → $FACET_COUNT_AFTER)"
    else
        print_error "Aave V3 facet not added"
        exit 1
    fi
else
    print_error "DeployFacet.s.sol failed"
    exit 1
fi

# Test 10: CLI launches
print_info "Test 10: Testing cli.sh menu..."
CLI_OUTPUT=$(echo "0" | ./cli.sh 2>&1)
if echo "$CLI_OUTPUT" | grep -q "Diamond Contract CLI"; then
    print_success "cli.sh launches correctly"
else
    print_error "cli.sh failed to launch"
    exit 1
fi

print_header "All Integration Tests Passed! ✓"
echo ""
echo "Summary:"
echo "  - Diamond deployed: $TEST_DIAMOND"
echo "  - Factory deployed: $TEST_FACTORY"
echo "  - Facets: $FACET_COUNT_AFTER (including Aave V3)"
echo "  - All scripts functional"
echo "  - Unit tests: 22/22 passed"
echo ""
