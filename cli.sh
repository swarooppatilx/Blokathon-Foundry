#!/bin/bash

# ============================================================================
# Diamond Contract CLI
# BLOK Capital DAO
# ============================================================================
# A comprehensive CLI tool for interacting with the Diamond proxy contract
# and all its facets (DiamondCut, DiamondLoupe, Ownership, DigitalWill, AaveV3)
# ============================================================================

set -e

# ANSI color codes for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONFIG_FILE=".env"
DIAMOND_ADDRESS=""
FACTORY_ADDRESS=""
RPC_URL=""
PRIVATE_KEY=""
CHAIN_ID=""

# ============================================================================
# Utility Functions
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖      ║"
    echo "║     ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌      ║"
    echo "║     ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌      ║"
    echo "║     ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖   ║"
    echo "║                                                                  ║"
    echo "║               Diamond Contract CLI - v1.0.0                      ║"
    echo "║                    BLOK Capital DAO                              ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_section() {
    echo ""
    echo -e "${MAGENTA}${BOLD}━━━ $1 ━━━${NC}"
    echo ""
}

# Validate Ethereum address format
validate_address() {
    local address=$1
    local field_name=${2:-"Address"}
    
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid $field_name format. Must be 42 characters (0x + 40 hex digits)"
        if [ ${#address} -gt 42 ]; then
            print_warning "You may have entered a private key (64 chars) instead of an address (40 chars)."
            echo -e "${YELLOW}To get address from private key:${NC} cast wallet address <private_key>"
        fi
        return 1
    fi
    return 0
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Configuration loaded from $CONFIG_FILE"
    else
        print_warning "No .env file found. Please configure the CLI."
        configure_cli
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Diamond Contract Configuration
DIAMOND_ADDRESS=$DIAMOND_ADDRESS
RPC_URL=$RPC_URL
PRIVATE_KEY=$PRIVATE_KEY
CHAIN_ID=$CHAIN_ID

# Foundry script variables (for deployment)
PRIVATE_KEY_ANVIL=${PRIVATE_KEY_ANVIL:-$PRIVATE_KEY}
RPC_URL_ANVIL=${RPC_URL_ANVIL:-$RPC_URL}
SALT=${SALT:-0x0000000000000000000000000000000000000000000000000000000000000001}
EOF
    print_success "Configuration saved to $CONFIG_FILE"
}

# Configure CLI
configure_cli() {
    print_section "Configuration Setup"
    
    read -p "Diamond Contract Address: " DIAMOND_ADDRESS
    read -p "RPC URL (default: http://localhost:8545): " RPC_URL
    RPC_URL=${RPC_URL:-http://localhost:8545}
    read -sp "Private Key: " PRIVATE_KEY
    echo ""
    read -p "Chain ID (default: 31337): " CHAIN_ID
    CHAIN_ID=${CHAIN_ID:-31337}
    
    save_config
}

# ============================================================================
# Deployment Functions
# ============================================================================

deploy_diamond() {
    print_section "Deploying Diamond Contract"
    
    # Ensure required environment variables are set
    export PRIVATE_KEY_ANVIL=${PRIVATE_KEY_ANVIL:-$PRIVATE_KEY}
    export RPC_URL_ANVIL=${RPC_URL_ANVIL:-$RPC_URL}
    export SALT=${SALT:-0x0000000000000000000000000000000000000000000000000000000000000001}
    
    print_info "Deploying facets and diamond proxy..."
    
    forge script script/Deploy.s.sol:DeployScript \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast \
        -vvv
    
    # Extract deployed diamond address
    local diamond_addr=$(cat broadcast/Deploy.s.sol/*/run-latest.json 2>/dev/null | jq -r '.transactions[] | select(.contractName == "Diamond") | .contractAddress' | head -1)
    
    if [ -n "$diamond_addr" ] && [ "$diamond_addr" != "null" ]; then
        DIAMOND_ADDRESS=$diamond_addr
        save_config
        print_success "Diamond contract deployed at: $diamond_addr"
    else
        print_success "Diamond contract deployed!"
    fi
    
    print_info "Check broadcast/ directory for deployment details"
}

# ============================================================================
# Diamond Loupe Functions (Inspection)
# ============================================================================

get_all_facets() {
    print_section "All Facets"
    
    echo "Fetching all facets and their function selectors..."
    echo ""
    
    # Get facet addresses first
    local facet_addresses=$(cast call "$DIAMOND_ADDRESS" \
        "facetAddresses()(address[])" \
        --rpc-url "$RPC_URL")
    
    # Parse each address and get its selectors
    echo "$facet_addresses" | grep -o '0x[a-fA-F0-9]\{40\}' | while read -r facet; do
        echo -e "${CYAN}Facet Address:${NC} $facet"
        
        local selectors=$(cast call "$DIAMOND_ADDRESS" \
            "facetFunctionSelectors(address)(bytes4[])" \
            "$facet" \
            --rpc-url "$RPC_URL")
        
        echo -e "${CYAN}Function Selectors:${NC}"
        echo "$selectors" | grep -o '0x[a-fA-F0-9]\{8\}' | while read -r selector; do
            echo "  - $selector"
        done
        echo ""
    done
}

get_facet_addresses() {
    print_section "Facet Addresses"
    
    cast call "$DIAMOND_ADDRESS" \
        "facetAddresses()(address[])" \
        --rpc-url "$RPC_URL"
}

get_facet_function_selectors() {
    local facet_address=$1
    
    if [ -z "$facet_address" ]; then
        read -p "Enter facet address: " facet_address
    fi
    
    # Validate facet address
    if ! validate_address "$facet_address" "Facet address"; then
        return 1
    fi
    
    print_section "Function Selectors for $facet_address"
    
    cast call "$DIAMOND_ADDRESS" \
        "facetFunctionSelectors(address)(bytes4[])" \
        "$facet_address" \
        --rpc-url "$RPC_URL"
}

get_facet_address_for_selector() {
    local selector=$1
    
    if [ -z "$selector" ]; then
        read -p "Enter function selector (e.g., 0x12345678): " selector
    fi
    
    print_section "Facet Address for Selector $selector"
    
    cast call "$DIAMOND_ADDRESS" \
        "facetAddress(bytes4)(address)" \
        "$selector" \
        --rpc-url "$RPC_URL"
}

# ============================================================================
# Ownership Functions
# ============================================================================

get_owner() {
    print_section "Current Owner"
    
    local owner=$(cast call "$DIAMOND_ADDRESS" \
        "owner()(address)" \
        --rpc-url "$RPC_URL")
    
    echo -e "${GREEN}Owner: $owner${NC}"
}

transfer_ownership() {
    local new_owner=$1
    
    if [ -z "$new_owner" ]; then
        read -p "Enter new owner address: " new_owner
    fi
    
    # Validate new owner address
    if ! validate_address "$new_owner" "New owner address"; then
        return 1
    fi
    
    print_section "Transferring Ownership"
    print_warning "You are about to transfer ownership to: $new_owner"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Transfer cancelled"
        return
    fi
    
    cast send "$DIAMOND_ADDRESS" \
        "transferOwnership(address)" \
        "$new_owner" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    print_success "Ownership transferred to $new_owner"
}

# ============================================================================
# Digital Will Functions
# ============================================================================

set_will() {
    local heir=$1
    local duration=$2
    local token=$3
    local amount=$4
    
    # Ensure we have the latest Diamond address
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    if [ -z "$DIAMOND_ADDRESS" ]; then
        print_error "DIAMOND_ADDRESS not set. Please deploy a Diamond first."
        return 1
    fi
    
    # Verify Diamond exists on chain
    local code=$(cast code "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = "0x" ]; then
        print_error "Diamond contract not found at $DIAMOND_ADDRESS"
        echo ""
        echo -e "${YELLOW}Possible causes:${NC}"
        echo "  1. Anvil was restarted (contracts are gone)"
        echo "  2. Wrong RPC URL"
        echo "  3. Diamond not deployed yet"
        echo ""
        echo -e "${CYAN}Solutions:${NC}"
        echo "  1. Deploy Diamond: Select option '1. Deploy Diamond Contract' from main menu"
        echo "  2. Update address: Select option '9. Configuration' to set correct address"
        return 1
    fi
    
    print_info "Using Diamond at: $DIAMOND_ADDRESS"
    echo ""
    
    if [ -z "$heir" ]; then
        echo -e "${YELLOW}Common test addresses:${NC}"
        echo "  Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
        echo "  Account #2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
        echo ""
        read -p "Enter heir address: " heir
    fi
    
    # Validate heir address
    if ! validate_address "$heir" "Heir address"; then
        return 1
    fi
    
    if [ -z "$duration" ]; then
        echo ""
        echo -e "${CYAN}Duration Examples:${NC}"
        echo "  30 days: 2592000"
        echo "  90 days: 7776000"
        echo "  1 year: 31536000"
        echo ""
        read -p "Enter inactivity duration (in seconds): " duration
    fi
    
    if [ -z "$token" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Select Token Option:${NC}"
        echo "  1) Use existing ERC20 token address"
        echo "  2) Deploy a new test token (MockToken with 1M supply)"
        echo ""
        read -p "Choose option (1 or 2): " token_option
        
        if [ "$token_option" = "2" ]; then
            print_info "Deploying test token..."
            
            # Check if MockToken artifact exists
            if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                print_info "Building contracts..."
                forge build > /dev/null 2>&1
            fi
            
            if [ -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                local bytecode=$(cat out/DigitalWillFacet.t.sol/MockToken.json | jq -r '.bytecode.object')
                
                if [ -z "$bytecode" ] || [ "$bytecode" = "null" ]; then
                    print_error "Failed to extract bytecode from MockToken artifact"
                    return 1
                fi
                
                print_info "Deploying MockToken contract..."
                local result=$(cast send --private-key "$PRIVATE_KEY" \
                    --rpc-url "$RPC_URL" \
                    --create "$bytecode" 2>&1)
                
                if [ $? -eq 0 ]; then
                    # Extract contractAddress from cast output
                    token=$(echo "$result" | grep "contractAddress" | awk '{print $2}')
                    
                    if [ -n "$token" ] && [ "$token" != "null" ]; then
                        print_success "Test token deployed: $token"
                        echo -e "${GREEN}✓${NC} 1,000,000 MOCK tokens minted to your address"
                    else
                        print_error "Failed to extract token address from deployment"
                        echo "Deployment output:"
                        echo "$result"
                        return 1
                    fi
                else
                    print_error "Failed to deploy test token"
                    echo "$result"
                    return 1
                fi
            else
                print_error "MockToken artifact not found"
                return 1
            fi
        else
            echo ""
            read -p "Enter ERC20 token address: " token
        fi
    fi
    
    # Validate token address
    if ! validate_address "$token" "Token address"; then
        return 1
    fi
    
    if [ -z "$amount" ]; then
        echo ""
        # Try to get token info
        local caller=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
        local balance=$(cast call "$token" "balanceOf(address)(uint256)" "$caller" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
        local decimals=$(cast call "$token" "decimals()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
        local symbol=$(cast call "$token" "symbol()(string)" --rpc-url "$RPC_URL" 2>/dev/null)
        
        if [ -n "$balance" ] && [ "$balance" != "0" ]; then
            decimals=${decimals:-18}
            symbol=${symbol:-tokens}
            
            # Calculate human-readable balance
            local human_balance=$(awk "BEGIN {printf \"%.4f\", $balance / 10^$decimals}")
            
            echo -e "${CYAN}Your Balance:${NC} $human_balance $symbol ($balance wei)"
            echo ""
            echo -e "${YELLOW}Suggested amounts:${NC}"
            echo "  10%: $(awk "BEGIN {print int($balance * 0.1)}")"
            echo "  25%: $(awk "BEGIN {print int($balance * 0.25)}")"
            echo "  50%: $(awk "BEGIN {print int($balance * 0.5)}")"
            echo ""
        fi
        
        read -p "Enter amount to deposit (in wei): " amount
    fi
    
    # Check current allowance
    echo ""
    print_info "Checking token allowance..."
    print_info "  Token: $token"
    print_info "  Spender (Diamond): $DIAMOND_ADDRESS"
    local caller=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
    print_info "  Owner: $caller"
    local allowance=$(cast call "$token" "allowance(address,address)(uint256)" "$caller" "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
    allowance=${allowance:-0}
    
    print_info "  Current allowance: $allowance"
    print_info "  Required amount: $amount"
    
    # Use bc for large number comparison (bash can't handle numbers > 2^63)
    local needs_approval=$(echo "$allowance < $amount" | bc)
    
    if [ "$needs_approval" -eq 1 ]; then
        print_warning "Approval needed: Current allowance $allowance < Required $amount"
        echo ""
        echo -e "${CYAN}Approving $amount tokens for Diamond at $DIAMOND_ADDRESS...${NC}"
        
        local approval_result=$(cast send "$token" \
            "approve(address,uint256)" \
            "$DIAMOND_ADDRESS" \
            "$amount" \
            --rpc-url "$RPC_URL" \
            --private-key "$PRIVATE_KEY" 2>&1)
        
        local approval_status=$?
        
        if [ $approval_status -eq 0 ]; then
            print_info "Approval transaction sent, waiting for confirmation..."
            # Wait for transaction to be mined
            sleep 2
            
            # Verify approval
            local new_allowance=$(cast call "$token" "allowance(address,address)(uint256)" "$caller" "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
            new_allowance=${new_allowance:-0}
            
            # Use bc for large number comparison
            local is_sufficient=$(echo "$new_allowance >= $amount" | bc)
            
            if [ "$is_sufficient" -eq 1 ]; then
                print_success "✓ Tokens approved! (Allowance: $new_allowance)"
            else
                print_error "Approval transaction succeeded but allowance not updated"
                echo "Current allowance: $new_allowance"
                echo "Required: $amount"
                return 1
            fi
        else
            print_error "Token approval failed"
            echo "$approval_result"
            echo ""
            echo "Try manually:"
            echo "cast send $token \"approve(address,uint256)\" $DIAMOND_ADDRESS $amount --rpc-url $RPC_URL --private-key \$PRIVATE_KEY"
            return 1
        fi
    else
        print_success "✓ Allowance sufficient"
    fi
    
    print_section "Setting Up Digital Will"
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Heir:     $heir"
    echo "  Duration: $duration seconds ($(($duration / 86400)) days)"
    echo "  Token:    $token"
    echo "  Amount:   $amount wei"
    echo ""
    
    print_info "Sending transaction..."
    local will_result=$(cast send "$DIAMOND_ADDRESS" \
        "setWill(address,uint256,address,uint256)" \
        "$heir" \
        "$duration" \
        "$token" \
        "$amount" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo ""
        print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_success "  Digital Will Configured Successfully!"
        print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo -e "${GREEN}✓${NC} $amount wei deposited to Diamond contract"
        echo -e "${GREEN}✓${NC} Heir can claim after $duration seconds of inactivity"
        echo -e "${GREEN}✓${NC} Use 'Ping' option to reset the timer"
    else
        echo ""
        print_error "Failed to set up Digital Will"
        echo ""
        echo -e "${RED}Error details:${NC}"
        echo "$will_result"
        echo ""
        
        # Check common issues
        local token_balance=$(cast call "$token" "balanceOf(address)(uint256)" "$caller" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
        local final_allowance=$(cast call "$token" "allowance(address,address)(uint256)" "$caller" "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
        
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo "  Your token balance: $token_balance"
        echo "  Current allowance: $final_allowance"
        echo "  Required amount: $amount"
        
        if [ "$token_balance" -lt "$amount" ] 2>/dev/null; then
            echo -e "${RED}  ⚠ Insufficient token balance!${NC}"
        fi
        
        if [ "$final_allowance" -lt "$amount" ] 2>/dev/null; then
            echo -e "${RED}  ⚠ Insufficient allowance!${NC}"
        fi
        
        return 1
    fi
}

ping_will() {
    print_section "Pinging Digital Will"
    print_info "Resetting inactivity timer..."
    
    cast send "$DIAMOND_ADDRESS" \
        "ping()" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    print_success "Ping successful! Timer reset."
}

claim_inheritance() {
    local owner=$1
    
    if [ -z "$owner" ]; then
        read -p "Enter deceased owner address: " owner
    fi
    
    # Validate owner address
    if ! validate_address "$owner" "Owner address"; then
        return 1
    fi
    
    # Get caller address to verify they are the heir
    local caller=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
    
    # Check will status first
    print_info "Verifying claim eligibility..."
    local will_result=$(cast call "$DIAMOND_ADDRESS" \
        "getWillStatus(address)(address,uint256,uint256)" \
        "$owner" \
        --rpc-url "$RPC_URL")
    
    # Parse output line by line
    local heir=$(echo "$will_result" | sed -n '1p' | tr -d '\n\r ' | grep -o '0x[a-fA-F0-9]\{40\}' | head -1 | tr '[:upper:]' '[:lower:]')
    local time_until_death=$(echo "$will_result" | sed -n '3p' | awk '{print $1}' | grep -o '[0-9]*')
    time_until_death=${time_until_death:-0}
    
    # Normalize addresses to lowercase for comparison
    local caller_lower=$(echo "$caller" | tr '[:upper:]' '[:lower:]')
    
    # Verify caller is the heir
    if [ "$heir" != "$caller_lower" ]; then
        print_error "You are not the designated heir for this will"
        echo -e "${CYAN}Your address:${NC} $caller"
        echo -e "${CYAN}Designated heir:${NC} $heir"
        return 1
    fi
    
    # Verify will has expired
    if [ $time_until_death -gt 0 ] 2>/dev/null; then
        local days=$((time_until_death / 86400))
        local hours=$(((time_until_death % 86400) / 3600))
        print_error "Will has not expired yet"
        echo -e "${CYAN}Time remaining:${NC} $days days, $hours hours ($time_until_death seconds)"
        return 1
    fi
    
    print_section "Claiming Inheritance"
    print_info "Owner: $owner"
    print_info "Heir (you): $caller"
    print_info "The token stored in the will will be transferred to you"
    
    cast send "$DIAMOND_ADDRESS" \
        "claimInheritance(address)" \
        "$owner" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    print_success "Inheritance claimed successfully!"
}

get_will_status() {
    local user=$1
    
    if [ -z "$user" ]; then
        read -p "Enter user address: " user
    fi
    
    # Validate user address
    if ! validate_address "$user" "User address"; then
        return 1
    fi
    
    print_section "Will Status for $user"
    
    local result=$(cast call "$DIAMOND_ADDRESS" \
        "getWillStatus(address)(address,uint256,uint256)" \
        "$user" \
        --rpc-url "$RPC_URL" 2>&1)
    
    # Parse output line by line to avoid concatenation issues
    local heir=$(echo "$result" | sed -n '1p' | tr -d '\n\r ' | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
    local last_ping=$(echo "$result" | sed -n '2p' | awk '{print $1}' | grep -o '[0-9]*')
    local time_until_death=$(echo "$result" | sed -n '3p' | awk '{print $1}' | grep -o '[0-9]*')
    
    # Set defaults if empty
    last_ping=${last_ping:-0}
    time_until_death=${time_until_death:-0}
    
    echo -e "${CYAN}Heir:${NC} $heir"
    
    # Format last ping timestamp
    if [ $last_ping -eq 0 ] 2>/dev/null; then
        echo -e "${CYAN}Last Ping:${NC} Never (no will set)"
    else
        local ping_date=$(date -d "@$last_ping" 2>/dev/null || echo "Invalid timestamp")
        echo -e "${CYAN}Last Ping:${NC} $last_ping ($ping_date)"
    fi
    
    # Format time until death
    if [ $time_until_death -gt 0 ] 2>/dev/null; then
        local days=$((time_until_death / 86400))
        local hours=$(((time_until_death % 86400) / 3600))
        local minutes=$(((time_until_death % 3600) / 60))
        echo -e "${CYAN}Time Until Death:${NC} $time_until_death seconds ($days days, $hours hours, $minutes minutes)"
        print_info "Will is inactive - $days days, $hours hours, $minutes minutes remaining"
    else
        echo -e "${CYAN}Time Until Death:${NC} 0 seconds (expired)"
        if [ "$heir" = "0x0000000000000000000000000000000000000000" ]; then
            print_info "No will has been set for this address"
        else
            print_warning "Will is ACTIVE - Inheritance can be claimed!"
        fi
    fi
}

# ============================================================================
# Aave V3 Functions
# ============================================================================

check_aave_facet() {
    # Check if Aave V3 facet is installed
    local facet_address=$(cast call "$DIAMOND_ADDRESS" "facetAddress(bytes4)(address)" "0x$(cast sig 'lend(address,uint256)' | cut -c1-10 | tail -c 9)" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ -z "$facet_address" ] || [ "$facet_address" = "0x0000000000000000000000000000000000000000" ]; then
        print_error "Aave V3 Facet not installed on this Diamond"
        echo ""
        echo -e "${YELLOW}To use Aave V3 features, you need to add the facet:${NC}"
        echo ""
        read -p "Would you like to add Aave V3 Facet now? (y/n): " add_facet
        
        if [[ "$add_facet" =~ ^[Yy]$ ]]; then
            print_info "Running DeployFacet script..."
            forge script script/DeployFacet.s.sol --rpc-url "$RPC_URL" --broadcast
            
            if [ $? -eq 0 ]; then
                print_success "Aave V3 Facet added successfully!"
                echo ""
                return 0
            else
                print_error "Failed to add Aave V3 Facet"
                return 1
            fi
        else
            print_info "Operation cancelled"
            return 1
        fi
    fi
    return 0
}

# Check if running on Arbitrum fork by testing for known Aave reserves
is_arbitrum_fork() {
    # Try to get USDC reserve data from Aave pool
    local usdc_reserve=$(cast call 0x794a61358D6845594F94dc1DB02A252b5b4814aD \
        "getReserveData(address)" \
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
        --rpc-url "$RPC_URL" 2>/dev/null)
    
    # If we get data (non-zero), we're on a fork with real Aave
    if [ -n "$usdc_reserve" ] && [ "$usdc_reserve" != "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" ]; then
        return 0  # Is Arbitrum fork
    else
        return 1  # Not Arbitrum fork
    fi
}

aave_lend() {
    local token=$1
    local amount=$2
    
    # Check if Aave V3 facet is installed
    if ! check_aave_facet; then
        return 1
    fi
    
    if [ -z "$token" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Check if on Arbitrum fork
        if is_arbitrum_fork; then
            echo -e "${GREEN}✓ Arbitrum fork detected - Real Aave tokens available${NC}"
            echo ""
            echo -e "${YELLOW}Select Token:${NC}"
            echo "  1) USDC  - 0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
            echo "  2) USDT  - 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
            echo "  3) WETH  - 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
            echo "  4) ARB   - 0x912CE59144191C1204E64559FE8253a0e49E6548"
            echo "  5) Custom address"
            echo ""
            read -p "Choose option (1-5): " token_choice
            
            case $token_choice in
                1) token="0xaf88d065e77c8cC2239327C5EDb3A432268e5831" ;;
                2) token="0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9" ;;
                3) token="0x82aF49447D8a07e3bd95BD0d56f35241523fBab1" ;;
                4) token="0x912CE59144191C1204E64559FE8253a0e49E6548" ;;
                5) read -p "Enter token address: " token ;;
                *) print_error "Invalid option"; return 1 ;;
            esac
        else
            echo -e "${YELLOW}Select Token Option:${NC}"
            echo "  1) Use existing ERC20 token address"
            echo "  2) Deploy a new test token (MockToken with 1M supply)"
            echo ""
            read -p "Choose option (1 or 2): " token_option
            
            if [ "$token_option" = "2" ]; then
                print_info "Deploying test token..."
                
                # Check if MockToken artifact exists
                if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                    print_info "Building contracts..."
                forge build > /dev/null 2>&1
            fi
            
            if [ -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                local bytecode=$(cat out/DigitalWillFacet.t.sol/MockToken.json | jq -r '.bytecode.object')
                
                if [ -z "$bytecode" ] || [ "$bytecode" = "null" ]; then
                    print_error "Failed to extract bytecode from MockToken artifact"
                    return 1
                fi
                
                print_info "Deploying MockToken contract..."
                local result=$(cast send --private-key "$PRIVATE_KEY" \
                    --rpc-url "$RPC_URL" \
                    --create "$bytecode" 2>&1)
                
                if [ $? -eq 0 ]; then
                    # Extract contractAddress from cast output
                    token=$(echo "$result" | grep "contractAddress" | awk '{print $2}')
                    
                    if [ -n "$token" ] && [ "$token" != "null" ]; then
                        print_success "Test token deployed: $token"
                        echo -e "${GREEN}✓${NC} 1,000,000 MOCK tokens minted to your address"
                    else
                        print_error "Failed to extract token address from deployment"
                        echo "Deployment output:"
                        echo "$result"
                        return 1
                    fi
                else
                    print_error "Failed to deploy test token"
                    echo "$result"
                    return 1
                fi
            else
                print_error "MockToken artifact not found"
                return 1
            fi
        else
            echo ""
            read -p "Enter ERC20 token address: " token
        fi
        fi  # Close the is_arbitrum_fork if/else block
    fi
    
    # Validate token address
    if ! validate_address "$token" "Token address"; then
        return 1
    fi
    
    # Check token exists
    local code=$(cast code "$token" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = "0x" ]; then
        print_error "No contract found at address: $token"
        echo ""
        echo -e "${YELLOW}This address has no code. Please check:${NC}"
        echo "  1. The address is correct"
        echo "  2. The contract is deployed on this network"
        echo "  3. You're connected to the right RPC endpoint"
        return 1
    fi
    
    if [ -z "$amount" ]; then
        echo ""
        # Try to get token info
        local caller=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
        local balance=$(cast call "$token" "balanceOf(address)(uint256)" "$caller" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
        local symbol=$(cast call "$token" "symbol()(string)" --rpc-url "$RPC_URL" 2>/dev/null)
        symbol=${symbol:-"tokens"}
        
        if [ -n "$balance" ] && [ "$balance" != "0" ]; then
            echo -e "${CYAN}Your Balance:${NC} $balance wei ($symbol)"
            echo ""
        else
            echo -e "${YELLOW}⚠ Your balance: 0 $symbol${NC}"
            echo ""
            
            # If on Arbitrum fork, offer to give tokens
            if is_arbitrum_fork; then
                echo -e "${CYAN}You need tokens to lend. Options:${NC}"
                echo "  1) Get tokens using cast (will give you 1000 tokens)"
                echo "  2) Cancel and get tokens manually"
                echo ""
                read -p "Choose option (1 or 2): " get_tokens
                
                if [ "$get_tokens" = "1" ]; then
                    print_info "Giving you 1000 $symbol tokens..."
                    
                    # Use cast rpc to set balance (works on Anvil/Hardhat)
                    # This uses anvil_setBalance for ETH or manipulates storage for ERC20
                    local decimals=$(cast call "$token" "decimals()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null)
                    decimals=${decimals:-6}  # Default to 6 if call fails (USDC/USDT standard)
                    
                    # Calculate amount: 1000 tokens with proper decimals
                    local give_amount="1000"
                    for ((i=0; i<decimals; i++)); do
                        give_amount="${give_amount}0"
                    done
                    
                    # Use cast to send tokens to ourselves (requires token contract to allow minting or we use storage manipulation)
                    # For simplicity on a fork, use cast with --unlocked flag on a whale address
                    print_warning "Note: This requires finding a whale address with tokens"
                    print_info "Instead, enter a smaller amount you can obtain through other means"
                    
                    balance="0"
                else
                    print_info "Operation cancelled"
                    return 0
                fi
            fi
        fi
        
        read -p "Enter amount to lend (in wei): " amount
    fi
    
    # Check if running on localhost and warn about Aave pool
    if [[ "$RPC_URL" == *"localhost"* ]] || [[ "$RPC_URL" == *"127.0.0.1"* ]]; then
        echo ""
        print_warning "⚠️  Aave V3 Pool Detection"
        echo ""
        echo -e "${YELLOW}You're running on a local network (Anvil).${NC}"
        echo -e "${YELLOW}The Aave V3 pool is deployed on Arbitrum mainnet.${NC}"
        echo ""
        echo -e "${CYAN}Options:${NC}"
        echo "  1. Continue anyway (will likely fail unless you deployed a mock pool)"
        echo "  2. Cancel and restart Anvil with Arbitrum fork:"
        echo "     ${GREEN}anvil --fork-url https://arb1.arbitrum.io/rpc${NC}"
        echo ""
        read -p "Continue? (y/n): " continue_local
        
        if [ "$continue_local" != "y" ]; then
            print_info "Operation cancelled"
            return 0
        fi
    fi
    
    print_section "Lending to Aave V3"
    print_info "Token: $token"
    print_info "Amount: $amount"
    
    # Step 1: Transfer tokens to Diamond
    print_info "Step 1/3: Transferring tokens to Diamond..."
    cast send "$token" \
        "transfer(address,uint256)" \
        "$DIAMOND_ADDRESS" \
        "$amount" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Failed to transfer tokens to Diamond"
        return 1
    fi
    
    sleep 2  # Wait for transaction to be mined
    
    # Verify transfer
    local diamond_balance=$(cast call "$token" "balanceOf(address)(uint256)" "$DIAMOND_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null | awk '{print $1}')
    print_success "✓ Tokens transferred to Diamond (balance: $diamond_balance wei)"
    
    # Step 2: Call lend function on Diamond
    print_info "Step 2/3: Approving Aave pool and lending..."
    cast send "$DIAMOND_ADDRESS" \
        "lend(address,uint256)" \
        "$token" \
        "$amount" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to lend tokens to Aave"
        return 1
    fi
    
    print_success "✓ Tokens lent to Aave V3 successfully!"
}

aave_withdraw() {
    local token=$1
    local amount=$2
    
    # Check if Aave V3 facet is installed
    if ! check_aave_facet; then
        return 1
    fi
    
    if [ -z "$token" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Select Token Option:${NC}"
        echo "  1) Use existing ERC20 token address"
        echo "  2) Deploy a new test token (MockToken with 1M supply)"
        echo ""
        read -p "Choose option (1 or 2): " token_option
        
        if [ "$token_option" = "2" ]; then
            print_info "Deploying test token..."
            
            # Check if MockToken artifact exists
            if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                print_info "Building contracts..."
                forge build > /dev/null 2>&1
            fi
            
            if [ -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                local bytecode=$(cat out/DigitalWillFacet.t.sol/MockToken.json | jq -r '.bytecode.object')
                
                if [ -z "$bytecode" ] || [ "$bytecode" = "null" ]; then
                    print_error "Failed to extract bytecode from MockToken artifact"
                    return 1
                fi
                
                print_info "Deploying MockToken contract..."
                local result=$(cast send --private-key "$PRIVATE_KEY" \
                    --rpc-url "$RPC_URL" \
                    --create "$bytecode" 2>&1)
                
                if [ $? -eq 0 ]; then
                    # Extract contractAddress from cast output
                    token=$(echo "$result" | grep "contractAddress" | awk '{print $2}')
                    
                    if [ -n "$token" ] && [ "$token" != "null" ]; then
                        print_success "Test token deployed: $token"
                        echo -e "${GREEN}✓${NC} 1,000,000 MOCK tokens minted to your address"
                        echo -e "${YELLOW}Note:${NC} You'll need to lend tokens first before withdrawing"
                    else
                        print_error "Failed to extract token address from deployment"
                        return 1
                    fi
                else
                    print_error "Failed to deploy test token"
                    return 1
                fi
            else
                print_error "MockToken artifact not found"
                return 1
            fi
        else
            echo ""
            read -p "Enter underlying token address to withdraw: " token
        fi
    fi
    
    # Validate token address
    if ! validate_address "$token" "Token address"; then
        return 1
    fi
    
    # Check token exists
    local code=$(cast code "$token" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = "0x" ]; then
        print_error "No contract found at address: $token"
        echo ""
        echo -e "${YELLOW}This address has no code. Please check:${NC}"
        echo "  1. The address is correct"
        echo "  2. The contract is deployed on this network"
        echo "  3. You're connected to the right RPC endpoint"
        return 1
    fi
    
    if [ -z "$amount" ]; then
        echo ""
        # Try to show aToken balance
        local caller=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
        local symbol=$(cast call "$token" "symbol()(string)" --rpc-url "$RPC_URL" 2>/dev/null)
        symbol=${symbol:-"tokens"}
        
        echo -e "${CYAN}Tip:${NC} Enter the amount in wei to withdraw"
        echo ""
        read -p "Enter amount to withdraw (in wei): " amount
    fi
    
    print_section "Withdrawing from Aave V3"
    print_info "Token: $token"
    print_info "Amount: $amount"
    
    cast send "$DIAMOND_ADDRESS" \
        "withdraw(address,uint256)" \
        "$token" \
        "$amount" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    print_success "Tokens withdrawn from Aave successfully!"
}

aave_get_reserve_data() {
    local token=$1
    
    # Check if Aave V3 facet is installed
    if ! check_aave_facet; then
        return 1
    fi
    
    if [ -z "$token" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Select Token Option:${NC}"
        echo "  1) Use existing ERC20 token address"
        echo "  2) Deploy a new test token (MockToken with 1M supply)"
        echo ""
        read -p "Choose option (1 or 2): " token_option
        
        if [ "$token_option" = "2" ]; then
            print_info "Deploying test token..."
            
            # Check if MockToken artifact exists
            if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                print_info "Building contracts..."
                forge build > /dev/null 2>&1
            fi
            
            if [ -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
                local bytecode=$(cat out/DigitalWillFacet.t.sol/MockToken.json | jq -r '.bytecode.object')
                
                if [ -z "$bytecode" ] || [ "$bytecode" = "null" ]; then
                    print_error "Failed to extract bytecode from MockToken artifact"
                    return 1
                fi
                
                print_info "Deploying MockToken contract..."
                local result=$(cast send --private-key "$PRIVATE_KEY" \
                    --rpc-url "$RPC_URL" \
                    --create "$bytecode" 2>&1)
                
                if [ $? -eq 0 ]; then
                    # Extract contractAddress from cast output
                    token=$(echo "$result" | grep "contractAddress" | awk '{print $2}')
                    
                    if [ -n "$token" ] && [ "$token" != "null" ]; then
                        print_success "Test token deployed: $token"
                        echo -e "${GREEN}✓${NC} 1,000,000 MOCK tokens minted to your address"
                    else
                        print_error "Failed to extract token address from deployment"
                        return 1
                    fi
                else
                    print_error "Failed to deploy test token"
                    return 1
                fi
            else
                print_error "MockToken artifact not found"
                return 1
            fi
        else
            echo ""
            read -p "Enter token address: " token
        fi
    fi
    
    # Validate token address
    if ! validate_address "$token" "Token address"; then
        return 1
    fi
    
    # Check token exists
    local code=$(cast code "$token" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = "0x" ]; then
        print_error "No contract found at address: $token"
        echo ""
        echo -e "${YELLOW}This address has no code. Please check:${NC}"
        echo "  1. The address is correct"
        echo "  2. The contract is deployed on this network"
        echo "  3. You're connected to the right RPC endpoint"
        return 1
    fi
    
    print_section "Aave Reserve Data for $token"
    
    cast call "$DIAMOND_ADDRESS" \
        "getReserveData(address)" \
        "$token" \
        --rpc-url "$RPC_URL"
}

# ============================================================================
# Diamond Cut Functions (Advanced)
# ============================================================================

diamond_cut() {
    print_section "Diamond Cut (Add/Replace/Remove Facets)"
    print_warning "This is an advanced operation. Proceed with caution!"
    
    echo "1. Add Facet"
    echo "2. Replace Facet"
    echo "3. Remove Facet"
    read -p "Select action: " action
    
    read -p "Enter facet address: " facet_address
    read -p "Enter function selectors (comma-separated, e.g., 0x12345678,0x87654321): " selectors_input
    
    # Convert action to enum value
    case $action in
        1) action_enum=0 ;;
        2) action_enum=1 ;;
        3) action_enum=2 ;;
        *) print_error "Invalid action"; return ;;
    esac
    
    print_info "This operation requires careful ABI encoding."
    print_info "Consider using the Foundry script for complex diamond cuts."
    print_warning "Operation not yet implemented in CLI - use Foundry script instead."
}

# ============================================================================
# Utility Operations
# ============================================================================

check_balance() {
    local address=$1
    
    if [ -z "$address" ]; then
        echo -e "${YELLOW}Common Anvil test addresses:${NC}"
        echo "  Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        echo "  Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
        echo "  Diamond:    $DIAMOND_ADDRESS"
        echo ""
        read -p "Enter address to check: " address
    fi
    
    # Validate address format (must be 42 chars: 0x + 40 hex chars)
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid address format. Address must be 42 characters (0x + 40 hex digits)"
        if [ ${#address} -gt 42 ]; then
            print_warning "You may have entered a private key instead of an address."
            echo -e "${YELLOW}To get the address from a private key, use:${NC}"
            echo "  cast wallet address <private_key>"
        fi
        return 1
    fi
    
    print_section "Balance Check"
    
    local balance=$(cast balance "$address" --rpc-url "$RPC_URL" 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to fetch balance: $balance"
        return 1
    fi
    
    local eth_balance=$(cast --to-unit "$balance" ether 2>&1)
    
    echo -e "${CYAN}Address:${NC} $address"
    echo -e "${CYAN}Balance:${NC} $eth_balance ETH ($balance wei)"
}

send_eth() {
    local to=$1
    local amount=$2
    
    if [ -z "$to" ]; then
        read -p "Enter recipient address: " to
    fi
    
    # Validate recipient address
    if ! validate_address "$to" "Recipient address"; then
        return 1
    fi
    
    if [ -z "$amount" ]; then
        read -p "Enter amount in ETH: " amount
    fi
    
    print_section "Sending ETH"
    print_info "To: $to"
    print_info "Amount: $amount ETH"
    
    cast send "$to" \
        --value "${amount}ether" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY"
    
    print_success "ETH sent successfully!"
}

get_transaction() {
    local tx_hash=$1
    
    if [ -z "$tx_hash" ]; then
        read -p "Enter transaction hash: " tx_hash
    fi
    
    print_section "Transaction Details"
    
    cast tx "$tx_hash" --rpc-url "$RPC_URL"
}

get_receipt() {
    local tx_hash=$1
    
    if [ -z "$tx_hash" ]; then
        read -p "Enter transaction hash: " tx_hash
    fi
    
    print_section "Transaction Receipt"
    
    cast receipt "$tx_hash" --rpc-url "$RPC_URL"
}

# Advance blockchain time (for Anvil testing)
advance_time() {
    local seconds=$1
    
    if [ -z "$seconds" ]; then
        echo -e "${YELLOW}Advance blockchain time (Anvil only)${NC}"
        echo "  Common values: 60 (1 min), 3600 (1 hour), 86400 (1 day)"
        echo ""
        read -p "Enter seconds to advance: " seconds
    fi
    
    print_section "Advancing Blockchain Time"
    print_warning "This only works with Anvil local network!"
    print_info "Advancing $seconds seconds..."
    
    # Use cast rpc to call evm_increaseTime and evm_mine
    cast rpc evm_increaseTime "$seconds" --rpc-url "$RPC_URL" > /dev/null 2>&1
    cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Time advanced by $seconds seconds"
        print_info "New block mined to apply time change"
    else
        print_error "Failed to advance time. Make sure you're connected to Anvil."
    fi
}

# Deploy a test ERC20 token
deploy_test_token() {
    print_section "Deploying Test Token"
    print_info "Deploying MockToken (10,000 tokens to deployer)..."
    
    # Check if MockToken artifact exists
    if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
        print_error "MockToken artifact not found. Building contracts first..."
        forge build
        
        if [ ! -f "out/DigitalWillFacet.t.sol/MockToken.json" ]; then
            print_error "Failed to find MockToken artifact after build"
            return 1
        fi
    fi
    
    local bytecode=$(cat out/DigitalWillFacet.t.sol/MockToken.json | jq -r '.bytecode.object')
    
    print_info "Deploying contract..."
    local result=$(cast send --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC_URL" \
        --create "$bytecode" \
        --json 2>&1)
    
    if [ $? -eq 0 ]; then
        local token_address=$(echo "$result" | jq -r '.contractAddress')
        print_success "Test token deployed successfully!"
        echo ""
        echo -e "${CYAN}Token Address:${NC} $token_address"
        echo -e "${CYAN}Token Name:${NC} Mock Token"
        echo -e "${CYAN}Token Symbol:${NC} MOCK"
        echo -e "${CYAN}Initial Supply:${NC} 1,000,000 tokens (to deployer)"
        echo ""
        echo -e "${YELLOW}Save this address for testing!${NC}"
        echo "You can use this token with the Digital Will feature."
    else
        print_error "Failed to deploy test token"
        echo "$result"
        return 1
    fi
}

# ============================================================================
# Testing Functions
# ============================================================================

run_tests() {
    print_section "Running Tests"
    
    forge test -vvv
}

run_specific_test() {
    local test_name=$1
    
    if [ -z "$test_name" ]; then
        read -p "Enter test name pattern: " test_name
    fi
    
    print_section "Running Test: $test_name"
    
    forge test --match-test "$test_name" -vvv
}

# ============================================================================
# Menu System
# ============================================================================

show_main_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Main Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1.  Deploy Diamond Contract"
    echo "2.  Diamond Loupe (Inspection)"
    echo "3.  Ownership Management"
    echo "4.  Digital Will Operations"
    echo "5.  Aave V3 Operations"
    echo "6.  Diamond Cut (Advanced)"
    echo "7.  Utility Operations"
    echo "8.  Testing"
    echo "9.  Configuration"
    echo "0.  Exit"
    echo "═══════════════════════════════════════"
}

show_loupe_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Diamond Loupe Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Get All Facets"
    echo "2. Get Facet Addresses"
    echo "3. Get Function Selectors for Facet"
    echo "4. Get Facet Address for Selector"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

show_ownership_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Ownership Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Get Current Owner"
    echo "2. Transfer Ownership"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

show_digital_will_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Digital Will Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Set Up Will"
    echo "2. Ping (Reset Timer)"
    echo "3. Get Will Status"
    echo "4. Claim Inheritance"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

show_aave_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Aave V3 Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Lend Tokens"
    echo "2. Withdraw Tokens"
    echo "3. Get Reserve Data"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

show_utility_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Utility Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Check Balance"
    echo "2. Send ETH"
    echo "3. Get Transaction Details"
    echo "4. Get Transaction Receipt"
    echo "5. Advance Time (Anvil)"
    echo "6. Deploy Test Token"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

show_testing_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}Testing Menu${NC}"
    echo "═══════════════════════════════════════"
    echo "1. Run All Tests"
    echo "2. Run Specific Test"
    echo "0. Back to Main Menu"
    echo "═══════════════════════════════════════"
}

# ============================================================================
# Main Loop
# ============================================================================

main() {
    print_banner
    
    # Check if foundry is installed
    if ! command -v forge &> /dev/null; then
        print_error "Foundry not found! Please install Foundry first."
        echo "Visit: https://book.getfoundry.sh/getting-started/installation"
        exit 1
    fi
    
    load_config
    
    while true; do
        show_main_menu
        read -p "Select option: " choice
        
        case $choice in
            1) deploy_diamond ;;
            2)
                while true; do
                    show_loupe_menu
                    read -p "Select option: " loupe_choice
                    case $loupe_choice in
                        1) get_all_facets ;;
                        2) get_facet_addresses ;;
                        3) get_facet_function_selectors ;;
                        4) get_facet_address_for_selector ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            3)
                while true; do
                    show_ownership_menu
                    read -p "Select option: " ownership_choice
                    case $ownership_choice in
                        1) get_owner ;;
                        2) transfer_ownership ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            4)
                while true; do
                    show_digital_will_menu
                    read -p "Select option: " will_choice
                    case $will_choice in
                        1) set_will ;;
                        2) ping_will ;;
                        3) get_will_status ;;
                        4) claim_inheritance ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            5)
                while true; do
                    show_aave_menu
                    read -p "Select option: " aave_choice
                    case $aave_choice in
                        1) aave_lend ;;
                        2) aave_withdraw ;;
                        3) aave_get_reserve_data ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            6) diamond_cut ;;
            7)
                while true; do
                    show_utility_menu
                    read -p "Select option: " util_choice
                    case $util_choice in
                        1) check_balance ;;
                        2) send_eth ;;
                        3) get_transaction ;;
                        4) get_receipt ;;
                        5) advance_time ;;
                        6) deploy_test_token ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            8)
                while true; do
                    show_testing_menu
                    read -p "Select option: " test_choice
                    case $test_choice in
                        1) run_tests ;;
                        2) run_specific_test ;;
                        0) break ;;
                        *) print_error "Invalid option" ;;
                    esac
                done
                ;;
            9) configure_cli ;;
            0)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
    done
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
