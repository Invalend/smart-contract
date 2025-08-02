// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RestrictedWallet.sol";

/**
 * @title SetupWhitelistedTokens
 * @notice Script to setup whitelisted tokens and approved targets for RestrictedWallet
 */
contract SetupWhitelistedTokens is Script {
    
    // Arbitrum mainnet addresses
    address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant UNISWAP_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    
    // Token addresses on Arbitrum
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // Get the deployed RestrictedWallet address
        address walletAddress = vm.envAddress("RESTRICTED_WALLET_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RestrictedWallet wallet = RestrictedWallet(payable(walletAddress));
        
        console.log("Setting up RestrictedWallet at:", walletAddress);
        console.log("Deployer:", deployerAddress);
        
        // Setup approved targets (Uniswap V3 contracts)
        console.log("\n=== Setting up approved targets ===");
        wallet.addApprovedTarget(UNISWAP_V3_ROUTER);
        console.log("Added Uniswap V3 Router:", UNISWAP_V3_ROUTER);
        
        wallet.addApprovedTarget(UNISWAP_V3_QUOTER);
        console.log("Added Uniswap V3 Quoter:", UNISWAP_V3_QUOTER);
        
        // Setup whitelisted tokens
        console.log("\n=== Setting up whitelisted tokens ===");
        address[] memory tokens = new address[](6);
        tokens[0] = USDC;
        tokens[1] = USDT;
        tokens[2] = WETH;
        tokens[3] = WBTC;
        tokens[4] = DAI;
        tokens[5] = ARB;
        
        wallet.addWhitelistedTokensBatch(tokens);
        
        console.log("Added USDC:", USDC);
        console.log("Added USDT:", USDT);
        console.log("Added WETH:", WETH);
        console.log("Added WBTC:", WBTC);
        console.log("Added DAI:", DAI);
        console.log("Added ARB:", ARB);
        
        // Verify setup
        console.log("\n=== Verification ===");
        console.log("UNISWAP_V3_ROUTER approved:", wallet.isTargetApproved(UNISWAP_V3_ROUTER));
        console.log("USDC whitelisted:", wallet.isTokenWhitelisted(USDC));
        console.log("WETH whitelisted:", wallet.isTokenWhitelisted(WETH));
        console.log("exactInputSingle selector approved:", wallet.isSelectorApproved(0x414bf389));
        
        vm.stopBroadcast();
        
        console.log("\n=== Setup Complete ===");
        console.log("RestrictedWallet is now ready for trading!");
    }
    
    function setupTestnet() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address walletAddress = vm.envAddress("RESTRICTED_WALLET_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RestrictedWallet wallet = RestrictedWallet(payable(walletAddress));
        
        console.log("Setting up testnet configuration...");
        
        // Arbitrum Sepolia testnet addresses (example)
        address testnetRouter = 0x0E24c03E7D11b7e1Ea6eC5D6B60c25d0e3F65F59; // Example
        address testnetUSDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;   // Example
        
        // Add testnet targets and tokens
        wallet.addApprovedTarget(testnetRouter);
        wallet.addWhitelistedToken(testnetUSDC);
        
        console.log("Testnet setup complete!");
        
        vm.stopBroadcast();
    }
}
