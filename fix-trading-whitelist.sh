#!/bin/bash

echo "=== Fix Trading Whitelist Issue ==="
echo "This script will help whitelist tokens for trading"
echo ""

# Check if user address is provided
if [ -z "$USER_ADDRESS" ]; then
    echo "❌ USER_ADDRESS not set"
    echo "Usage: USER_ADDRESS=<your_address> ./fix-trading-whitelist.sh"
    echo ""
    echo "Example:"
    echo "USER_ADDRESS=0x1234567890123456789012345678901234567890 ./fix-trading-whitelist.sh"
    exit 1
fi

echo "User Address: $USER_ADDRESS"
echo ""

# Step 1: Get user's RestrictedWallet address
echo "🔍 Step 1: Getting user's RestrictedWallet address..."
RESTRICTED_WALLET=$(forge script script/GetUserRestrictedWallet.s.sol --rpc-url https://sepolia.base.org --sig 'run()' | grep "RestrictedWallet Address:" | cut -d: -f2 | xargs)

if [ -z "$RESTRICTED_WALLET" ] || [ "$RESTRICTED_WALLET" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ No active RestrictedWallet found for user"
    echo "User needs to create a loan first to get a RestrictedWallet"
    echo ""
    echo "To create a loan:"
    echo "1. Go to the frontend"
    echo "2. Connect your wallet"
    echo "3. Create a loan to get your RestrictedWallet"
    exit 1
fi

echo "✅ Found RestrictedWallet: $RESTRICTED_WALLET"
echo ""

# Step 2: Whitelist tokens
echo "🔍 Step 2: Whitelisting tokens for RestrictedWallet..."
RESTRICTED_WALLET_ADDRESS=$RESTRICTED_WALLET forge script script/WhitelistTokensBatch.s.sol --rpc-url https://sepolia.base.org --broadcast

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Tokens whitelisted successfully!"
    echo ""
    echo "=== Trading Should Now Work ==="
    echo "Your RestrictedWallet now has the following tokens whitelisted:"
    echo "- USDC: 0xc309D45d4119487b30205784efF9abACF20872c0"
    echo "- ETH: 0x8379372caeE37abEdacA9925a3D4d5aad2975B35"
    echo "- BTC: 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9"
    echo ""
    echo "You can now try trading again in the frontend!"
else
    echo "❌ Failed to whitelist tokens"
    echo "Please check the error messages above"
fi
