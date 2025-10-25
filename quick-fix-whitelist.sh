#!/bin/bash

echo "=== Quick Fix for Trading Whitelist ==="
echo ""

# Check if user address is provided
if [ -z "$1" ]; then
    echo "Usage: ./quick-fix-whitelist.sh <USER_ADDRESS>"
    echo "Example: ./quick-fix-whitelist.sh 0x1234567890123456789012345678901234567890"
    exit 1
fi

USER_ADDRESS=$1
echo "User Address: $USER_ADDRESS"
echo ""

# Get RestrictedWallet address
echo "🔍 Getting RestrictedWallet address..."
RESTRICTED_WALLET=$(forge script script/GetUserRestrictedWallet.s.sol --rpc-url https://sepolia.base.org --sig 'run()' 2>/dev/null | grep "RestrictedWallet Address:" | cut -d: -f2 | xargs)

if [ -z "$RESTRICTED_WALLET" ] || [ "$RESTRICTED_WALLET" = "0x0000000000000000000000000000000000000000" ]; then
    echo "❌ No active RestrictedWallet found"
    echo "Please create a loan first in the frontend"
    exit 1
fi

echo "✅ RestrictedWallet: $RESTRICTED_WALLET"
echo ""

# Whitelist tokens
echo "🔍 Whitelisting tokens..."
RESTRICTED_WALLET_ADDRESS=$RESTRICTED_WALLET forge script script/WhitelistTokensBatch.s.sol --rpc-url https://sepolia.base.org --broadcast

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Tokens whitelisted successfully!"
    echo "Trading should now work in the frontend!"
else
    echo "❌ Failed to whitelist tokens"
fi
