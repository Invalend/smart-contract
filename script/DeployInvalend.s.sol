// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/MockUSDC.sol";
import "../src/LendingPool.sol";
import "../src/CollateralManager.sol";
import "../src/RestrictedWalletFactory.sol";
import "../src/RestrictedWallet.sol";
import "../src/LoanManager.sol";

contract DeployInvalend is Script {
    MockUSDC public mockUSDC;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    RestrictedWalletFactory public walletFactory;
    RestrictedWallet public walletImplementation;
    LoanManager public loanManager;

    function run() external {
        // Ambil private key langsung sebagai uint256
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Invalend PoC with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        /// Step 1: Deploy MockUSDC
        console.log("Deploying MockUSDC...");
        mockUSDC = new MockUSDC();
        console.log("MockUSDC deployed at:", address(mockUSDC));

        /// Step 2: Deploy RestrictedWallet Implementation
        console.log("Deploying RestrictedWallet Implementation...");
        walletImplementation = new RestrictedWallet(deployer);
        console.log(
            "RestrictedWallet Implementation deployed at:",
            address(walletImplementation)
        );

        /// Step 3: Calculate LoanManager address using CREATE2 or predict next nonce
        address predictedLoanManager = vm.computeCreateAddress(
            deployer,
            vm.getNonce(deployer) + 3
        );
        console.log("Predicted LoanManager address:", predictedLoanManager);

        /// Step 4: Deploy contracts with predicted LoanManager address
        console.log("Deploying CollateralManager...");
        collateralManager = new CollateralManager(
            predictedLoanManager
        );
        console.log(
            "CollateralManager deployed at:",
            address(collateralManager)
        );

        console.log("Deploying LendingPool...");
        lendingPool = new LendingPool(address(mockUSDC), predictedLoanManager);
        console.log("LendingPool deployed at:", address(lendingPool));

        console.log("Deploying RestrictedWalletFactory...");
        walletFactory = new RestrictedWalletFactory(predictedLoanManager);
        console.log(
            "RestrictedWalletFactory deployed at:",
            address(walletFactory)
        );

        /// Step 5: Deploy LoanManager
        console.log("Deploying LoanManager...");
        loanManager = new LoanManager(
            address(lendingPool),
            address(collateralManager),
            address(walletFactory),
            address(mockUSDC)
        );
        console.log("LoanManager deployed at:", address(loanManager));

        /// Step 6: Verify predicted address
        require(
            address(loanManager) == predictedLoanManager,
            "Address prediction failed"
        );
        console.log("Address prediction successful!");

        /// Step 7: Add initial liquidity to the pool
        console.log("Adding initial liquidity to LendingPool...");
        
        // Mint USDC to deployer for initial liquidity
        uint256 initialLiquidity = 1_000_000 * 1e6; // 1M USDC
        mockUSDC.mint(deployer, initialLiquidity);
        console.log("Minted", initialLiquidity / 1e6, "USDC to deployer");
        
        // Approve LendingPool to spend USDC
        mockUSDC.approve(address(lendingPool), initialLiquidity);
        
        // Add liquidity to the pool 
        lendingPool.deposit(initialLiquidity, deployer);
        console.log("Added", initialLiquidity / 1e6, "USDC to LendingPool");

        vm.stopBroadcast();

        /// Step 8: Display Summary
        displayDeploymentSummary();
        validateDeployment();
    }

    function displayDeploymentSummary() internal view {
        console.log("\n=== INVALEND DEPLOYMENT SUMMARY ===");
        console.log("MockUSDC:", address(mockUSDC));
        console.log("CollateralManager:", address(collateralManager));
        console.log("LendingPool:", address(lendingPool));
        console.log("RestrictedWalletFactory:", address(walletFactory));
        console.log("RestrictedWallet Impl:", address(walletImplementation));
        console.log("LoanManager:", address(loanManager));
    }

    function validateDeployment() internal view {
        console.log("\n=== VALIDATION ===");

        /// Validate MockUSDC
        require(mockUSDC.decimals() == 6, "MockUSDC decimals should be 6");
        console.log("MockUSDC validation passed");

        /// Validate pool liquidity
        require(
            lendingPool.getAvailableLiquidity() > 0,
            "Pool should have liquidity"
        );
        console.log("LendingPool validation passed");

        /// Test loan amount calculation
        uint256 testLoanAmount = 100_000 * 1e6; // 100k USDC
        require(
            loanManager.getRequiredMargin(testLoanAmount) == 20_000 * 1e6,
            "Margin calculation incorrect"
        );
        require(
            loanManager.getPoolFunding(testLoanAmount) == 80_000 * 1e6,
            "Pool funding calculation incorrect"
        );
        console.log("LoanManager calculation validation passed");

        console.log("All validations passed!");
    }
}
