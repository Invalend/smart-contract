#!/bin/bash

echo "=== Invalend V4 Contract Verification ==="
echo "Network: Base Sepolia (84532)"
echo "Scanner: https://sepolia.basescan.org/"
echo ""

RPC_URL="https://sepolia.base.org"
CHAIN_ID="84532"
ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY}"

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "❌ ETHERSCAN_API_KEY not set. Run:"
    echo "export ETHERSCAN_API_KEY=your_key"
    exit 1
fi

# Contract addresses (Updated from latest deployment)
MOCK_USDC="0xc309D45d4119487b30205784efF9abACF20872c0"
MOCK_ETH="0x8379372caeE37abEdacA9925a3D4d5aad2975B35"
MOCK_BTC="0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9"
LENDING_POOL="0x3acFeeDAea433fc47f9000c3c1eb6F486dd58717"
COLLATERAL_MANAGER="0xF4624D5dc09047E1643F866925135E70c169822a"
RESTRICTED_WALLET_FACTORY="0xeba187f19417DbCDe5DcfF45B5f431c762EF862D"
LOAN_MANAGER="0x93f3766e8a7F7e15e8990406bdBa1247E3A3aCd2"

function verify_contract() {
    local name=$1
    local address=$2
    local contract_path=$3
    local args=$4

    echo "🔍 $name ($address)"

    # Check if already verified
    local status=$(forge verify-check \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        $address \
        --chain-id $CHAIN_ID 2>/dev/null)

    if [[ $status == *"success"* ]]; then
        echo "✅ Already Verified! Skipping."
        echo ""
        return
    fi

    # Submit verification request
    if [ -n "$args" ]; then
        forge verify-contract \
            $address \
            $contract_path \
            --constructor-args $args \
            --chain-id $CHAIN_ID \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            --watch
    else
        forge verify-contract \
            $address \
            $contract_path \
            --chain-id $CHAIN_ID \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            --watch
    fi

    if [ $? -eq 0 ]; then
        echo "✅ Verified successfully!"
    else
        echo "❌ Verification failed!"
    fi

    echo ""
}

echo "Starting verification..."

verify_contract "MockUSDC" $MOCK_USDC "src/MockUSDC.sol:MockUSDC"
verify_contract "MockETH" $MOCK_ETH "src/MockETH.sol:MockETH"
verify_contract "MockBTC" $MOCK_BTC "src/MockBTC.sol:MockBTC"

verify_contract "CollateralManager" \
    $COLLATERAL_MANAGER \
    "src/CollateralManager.sol:CollateralManager" \
    "$(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000001")"

verify_contract "LendingPool" \
    $LENDING_POOL \
    "src/LendingPool.sol:LendingPool" \
    "$(cast abi-encode "constructor(address,address)" $MOCK_USDC "0x0000000000000000000000000000000000000001")"

verify_contract "RestrictedWalletFactory" \
    $RESTRICTED_WALLET_FACTORY \
    "src/RestrictedWalletFactory.sol:RestrictedWalletFactory" \
    "$(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000001")"

verify_contract "LoanManager" \
    $LOAN_MANAGER \
    "src/LoanManager.sol:LoanManager" \
    "$(cast abi-encode "constructor(address,address,address,address)" \
        $LENDING_POOL \
        $COLLATERAL_MANAGER \
        $RESTRICTED_WALLET_FACTORY \
        $MOCK_USDC)"

echo "=== All Verification Steps Completed ✅ ==="
