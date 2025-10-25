#!/bin/bash

# Invalend V4 Contract Verification Script
# Base Sepolia Network using Blockscout

echo "=== Invalend V4 Contract Verification ==="
echo "Network: Base Sepolia (84532)"
echo "Explorer: https://base-sepolia.blockscout.com/"
echo ""

# Set RPC URL and Blockscout URL
RPC_URL="https://sepolia.base.org"
BLOCKSCOUT_URL="https://base-sepolia.blockscout.com/api"

# Contract addresses (Updated from latest deployment)
MOCK_USDC="0xc309D45d4119487b30205784efF9abACF20872c0"
MOCK_ETH="0x8379372caeE37abEdacA9925a3D4d5aad2975B35"
MOCK_BTC="0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9"
LENDING_POOL="0x3acFeeDAea433fc47f9000c3c1eb6F486dd58717"
COLLATERAL_MANAGER="0xF4624D5dc09047E1643F866925135E70c169822a"
RESTRICTED_WALLET_FACTORY="0xeba187f19417DbCDe5DcfF45B5f431c762EF862D"
LOAN_MANAGER="0x93f3766e8a7F7e15e8990406bdBa1247E3A3aCd2"

# Function to verify contract
verify_contract() {
    local name=$1
    local address=$2
    local contract_path=$3
    local constructor_args=$4
    
    echo "🔍 Verifying $name..."
    echo "Address: $address"
    echo "Contract: $contract_path"
    
    if [ -n "$constructor_args" ]; then
        forge verify-contract \
            --rpc-url $RPC_URL \
            $address \
            $contract_path \
            --verifier blockscout \
            --verifier-url $BLOCKSCOUT_URL \
            --constructor-args $constructor_args
    else
        forge verify-contract \
            --rpc-url $RPC_URL \
            $address \
            $contract_path \
            --verifier blockscout \
            --verifier-url $BLOCKSCOUT_URL
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ $name verified successfully!"
    else
        echo "❌ $name verification failed!"
    fi
    echo ""
}

echo "Starting verification process using Blockscout..."
echo ""

# 1. MockUSDC
verify_contract "MockUSDC" \
    $MOCK_USDC \
    "src/MockUSDC.sol:MockUSDC"

# 2. MockETH
verify_contract "MockETH" \
    $MOCK_ETH \
    "src/MockETH.sol:MockETH"

# 3. MockBTC
verify_contract "MockBTC" \
    $MOCK_BTC \
    "src/MockBTC.sol:MockBTC"

# 4. CollateralManager
verify_contract "CollateralManager" \
    $COLLATERAL_MANAGER \
    "src/CollateralManager.sol:CollateralManager" \
    "$(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000001")"

# 5. LendingPool
verify_contract "LendingPool" \
    $LENDING_POOL \
    "src/LendingPool.sol:LendingPool" \
    "$(cast abi-encode "constructor(address,address)" $MOCK_USDC "0x0000000000000000000000000000000000000001")"

# 6. RestrictedWalletFactory
verify_contract "RestrictedWalletFactory" \
    $RESTRICTED_WALLET_FACTORY \
    "src/RestrictedWalletFactory.sol:RestrictedWalletFactory" \
    "$(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000001")"

# 7. LoanManager
verify_contract "LoanManager" \
    $LOAN_MANAGER \
    "src/LoanManager.sol:LoanManager" \
    "$(cast abi-encode "constructor(address,address,address,address)" $LENDING_POOL $COLLATERAL_MANAGER $RESTRICTED_WALLET_FACTORY $MOCK_USDC)"

echo "=== Verification Complete ==="
echo "Check the results above for verification status"
echo "View contracts on Blockscout: https://base-sepolia.blockscout.com/"
echo ""
echo "Contract links:"
echo "MockUSDC: https://base-sepolia.blockscout.com/address/$MOCK_USDC"
echo "MockETH: https://base-sepolia.blockscout.com/address/$MOCK_ETH"
echo "MockBTC: https://base-sepolia.blockscout.com/address/$MOCK_BTC"
echo "LendingPool: https://base-sepolia.blockscout.com/address/$LENDING_POOL"
echo "CollateralManager: https://base-sepolia.blockscout.com/address/$COLLATERAL_MANAGER"
echo "RestrictedWalletFactory: https://base-sepolia.blockscout.com/address/$RESTRICTED_WALLET_FACTORY"
echo "LoanManager: https://base-sepolia.blockscout.com/address/$LOAN_MANAGER"

