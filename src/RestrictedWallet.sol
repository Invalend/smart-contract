// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title RestrictedWallet - Smart Wallet for Invalend Protocol
 * @notice This is a PoC implementation for secure DeFi trading
 * @dev Built for hackathon demonstration - production ready with clean architecture
 */

/**
 * @title RestrictedWallet - Smart Wallet for Invalend Protocol
 * @notice This is a PoC implementation for secure DeFi trading
 * @dev Built for hackathon demonstration - production ready with clean architecture
 */
contract RestrictedWallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ STATE VARIABLES ============
    
    /// @notice Mapping of approved target contracts (e.g., Uniswap routers)
    mapping(address => bool) public approvedTargets;
    
    /// @notice Mapping of approved function selectors for enhanced security
    mapping(bytes4 => bool) public approvedSelectors;
    
    /// @notice Mapping of whitelisted tokens that can be traded
    mapping(address => bool) public whitelistedTokens;

    // ============ EVENTS ============
    
    /// @notice Emitted when a target contract is whitelisted or removed
    event TargetWhitelisted(address indexed target, bool approved);
    
    /// @notice Emitted when a function selector is approved or removed
    event SelectorWhitelisted(bytes4 indexed selector, bool approved);
    
    /// @notice Emitted when a token is whitelisted for trading
    event TokenWhitelisted(address indexed token, bool approved);
    
    /// @notice Emitted when a transaction is executed via the execute function
    event TransactionExecuted(address indexed target, bytes data);
    
    /// @notice Emitted when a successful trade is completed
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed router
    );

    // ============ CONSTRUCTOR ============

    // ============ CONSTRUCTOR ============
    
    /**
     * @notice Initialize the RestrictedWallet with owner and setup default configurations
     * @param _initialOwner The address that will own this wallet
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {
        _setupUniswapV3Selectors();
        // Note: Tokens must be added manually for security in PoC
    }

    // ============ TRADING FUNCTIONS ============

    // ============ TRADING FUNCTIONS ============

    /**
     * @notice Execute any whitelisted transaction (for advanced users)
     * @param target The contract to call
     * @param data The encoded function call data
     * @dev This is the most flexible function but requires manual encoding
     */
    function execute(address target, bytes calldata data) external onlyOwner nonReentrant {
        require(target != address(0), "Invalid target");
        require(approvedTargets[target], "Target not approved");
        
        if (data.length >= 4) {
            bytes4 selector = bytes4(data[:4]);
            require(approvedSelectors[selector], "Function not approved");
        }
        
        (bool success, ) = target.call(data);
        require(success, "Transaction failed");
        
        emit TransactionExecuted(target, data);
    }

    /**
     * @notice Swap exact amount of input tokens for output tokens (most common use case)
     * @param router Uniswap V3 Router address
     * @param tokenIn Input token address  
     * @param tokenOut Output token address
     * @param fee Pool fee tier (500, 3000, or 10000)
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMinimum Minimum amount of output tokens expected
     * @param deadline Transaction deadline timestamp
     * @return amountOut Actual amount of output tokens received
     */
    function swapExactInputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountOut) {
        return _swapExactInputSingle(
            router, tokenIn, tokenOut, fee, amountIn, amountOutMinimum, 0, deadline
        );
    }

    /**
     * @notice Swap exact amount of input tokens (with price limit - advanced)
     * @param router Uniswap V3 Router address
     * @param tokenIn Input token address  
     * @param tokenOut Output token address
     * @param fee Pool fee tier (500, 3000, or 10000)
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMinimum Minimum amount of output tokens expected
     * @param sqrtPriceLimitX96 Price limit (0 = no limit)
     * @param deadline Transaction deadline timestamp
     * @return amountOut Actual amount of output tokens received
     */
    function swapExactInputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountOut) {
        return _swapExactInputSingle(
            router, tokenIn, tokenOut, fee, amountIn, amountOutMinimum, sqrtPriceLimitX96, deadline
        );
    }

    /**
     * @notice Swap tokens for exact amount of output tokens (advanced use case)
     * @param router Uniswap V3 Router address
     * @param tokenIn Input token address
     * @param tokenOut Output token address  
     * @param fee Pool fee tier (500, 3000, or 10000)
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMaximum Maximum amount of input tokens willing to spend
     * @param deadline Transaction deadline timestamp
     * @return amountIn Actual amount of input tokens spent
     */
    function swapExactOutputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountIn) {
        return _swapExactOutputSingle(
            router, tokenIn, tokenOut, fee, amountOut, amountInMaximum, 0, deadline
        );
    }

    /**
     * @notice Swap tokens for exact amount of output tokens (with price limit)
     * @param router Uniswap V3 Router address
     * @param tokenIn Input token address
     * @param tokenOut Output token address  
     * @param fee Pool fee tier (500, 3000, or 10000)
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMaximum Maximum amount of input tokens willing to spend
     * @param sqrtPriceLimitX96 Price limit (0 = no limit)
     * @param deadline Transaction deadline timestamp
     * @return amountIn Actual amount of input tokens spent
     */
    function swapExactOutputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountIn) {
        return _swapExactOutputSingle(
            router, tokenIn, tokenOut, fee, amountOut, amountInMaximum, sqrtPriceLimitX96, deadline
        );
    }

    // ============ LOAN MANAGER FUNCTIONS ============

    // ============ LOAN MANAGER FUNCTIONS ============

    /**
     * @notice Return funds to LoanManager (for loan repayment or liquidation)
     * @param loanManager Address of the loan manager contract
     * @param token Token to return (typically USDC)
     * @dev Can be called by owner or loan manager for flexibility
     */
    function returnFunds(address loanManager, address token) external nonReentrant {
        require(msg.sender == owner() || msg.sender == loanManager, "Not authorized");
        require(loanManager != address(0), "Invalid loan manager");
        require(token != address(0), "Invalid token");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(loanManager, balance);
        }
    }

    /**
     * @notice Emergency fund return (only loan manager can call)
     * @param loanManager Address of the loan manager contract
     * @param token Token to return
     * @dev Stricter access control for emergency situations
     */
    function emergencyReturnFunds(address loanManager, address token) external {
        require(msg.sender == loanManager, "Only loan manager");
        require(loanManager != address(0), "Invalid loan manager");
        require(token != address(0), "Invalid token");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(loanManager, balance);
        }
    }

    // ============ OWNER WITHDRAWAL FUNCTIONS ============

    // ============ OWNER WITHDRAWAL FUNCTIONS ============

    /**
     * @notice Withdraw specific amount of tokens (after loan repaid)
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH");
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    /**
     * @notice Withdraw all tokens of a specific type (after loan repaid)
     * @param token Token address (address(0) for ETH)
     */
    function withdrawAll(address token) external onlyOwner nonReentrant {
        if (token == address(0)) {
            uint256 balance = address(this).balance;
            if (balance > 0) {
                payable(owner()).transfer(balance);
            }
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(owner(), balance);
            }
        }
    }

    // ============ CONFIGURATION FUNCTIONS ============

    // ============ CONFIGURATION FUNCTIONS ============

    /**
     * @notice Add approved target contract (e.g., Uniswap router)
     * @param target Contract address to approve
     */
    function addApprovedTarget(address target) external onlyOwner {
        require(target != address(0), "Invalid target");
        approvedTargets[target] = true;
        emit TargetWhitelisted(target, true);
    }

    /**
     * @notice Remove approved target contract
     * @param target Contract address to remove
     */
    function removeApprovedTarget(address target) external onlyOwner {
        approvedTargets[target] = false;
        emit TargetWhitelisted(target, false);
    }

    /**
     * @notice Add whitelisted token for trading
     * @param token Token address to whitelist
     */
    function addWhitelistedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        whitelistedTokens[token] = true;
        emit TokenWhitelisted(token, true);
    }

    /**
     * @notice Remove whitelisted token
     * @param token Token address to remove
     */
    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
        emit TokenWhitelisted(token, false);
    }

    /**
     * @notice Batch add multiple tokens (gas efficient for setup)
     * @param tokens Array of token addresses to whitelist
     */
    function addWhitelistedTokensBatch(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token");
            whitelistedTokens[tokens[i]] = true;
            emit TokenWhitelisted(tokens[i], true);
        }
    }

    /**
     * @notice Add approved function selector (for advanced use cases)
     * @param selector Function selector to approve
     */
    function addApprovedSelector(bytes4 selector) external onlyOwner {
        approvedSelectors[selector] = true;
        emit SelectorWhitelisted(selector, true);
    }

    /**
     * @notice Remove approved function selector
     * @param selector Function selector to remove
     */
    function removeApprovedSelector(bytes4 selector) external onlyOwner {
        approvedSelectors[selector] = false;
        emit SelectorWhitelisted(selector, false);
    }

    // ============ VIEW FUNCTIONS ============

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get token balance in this wallet
     * @param token Token address (address(0) for ETH)
     * @return balance Current balance
     */
    function getBalance(address token) external view returns (uint256 balance) {
        if (token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /**
     * @notice Check if target contract is approved
     * @param target Contract address to check
     * @return approved True if approved
     */
    function isTargetApproved(address target) external view returns (bool approved) {
        return approvedTargets[target];
    }

    /**
     * @notice Check if function selector is approved
     * @param selector Function selector to check
     * @return approved True if approved
     */
    function isSelectorApproved(bytes4 selector) external view returns (bool approved) {
        return approvedSelectors[selector];
    }

    /**
     * @notice Check if token is whitelisted for trading
     * @param token Token address to check
     * @return whitelisted True if whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool whitelisted) {
        return whitelistedTokens[token];
    }

    // ============ INTERNAL FUNCTIONS ============
    // ============ INTERNAL FUNCTIONS ============

    /**
     * @notice Setup approved selectors for Uniswap V3 trading
     * @dev Called during construction to enable trading functions
     */
    function _setupUniswapV3Selectors() internal {
        // Use interface selectors for type safety and maintainability
        approvedSelectors[ISwapRouter.exactInputSingle.selector] = true;
        approvedSelectors[ISwapRouter.exactOutputSingle.selector] = true;
        approvedSelectors[ISwapRouter.exactInput.selector] = true;
        approvedSelectors[ISwapRouter.exactOutput.selector] = true;
        
        // Also approve ERC20 approve for necessary token operations
        approvedSelectors[IERC20.approve.selector] = true;
    }

    /**
     * @notice Internal implementation of exactInputSingle swap
     * @dev Centralizes validation and swap logic for reusability
     */
    function _swapExactInputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        // Comprehensive validation
        require(router != address(0), "Invalid router");
        require(approvedTargets[router], "Router not approved");
        require(whitelistedTokens[tokenIn], "Input token not whitelisted");
        require(whitelistedTokens[tokenOut], "Output token not whitelisted");
        require(amountIn > 0, "Amount must be greater than 0");
        require(deadline >= block.timestamp, "Transaction expired");

        // Check sufficient balance
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));
        require(balance >= amountIn, "Insufficient token balance");

        // Setup approval
        IERC20(tokenIn).forceApprove(router, amountIn);

        // Execute swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        amountOut = ISwapRouter(router).exactInputSingle(params);
        
        // Clean up approval
        IERC20(tokenIn).forceApprove(router, 0);

        emit TradeExecuted(tokenIn, tokenOut, amountIn, amountOut, router);
    }

    /**
     * @notice Internal implementation of exactOutputSingle swap
     * @dev Centralizes validation and swap logic for reusability
     */
    function _swapExactOutputSingle(
        address router,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline
    ) internal returns (uint256 amountIn) {
        // Comprehensive validation
        require(router != address(0), "Invalid router");
        require(approvedTargets[router], "Router not approved");
        require(whitelistedTokens[tokenIn], "Input token not whitelisted");
        require(whitelistedTokens[tokenOut], "Output token not whitelisted");
        require(amountOut > 0, "Amount must be greater than 0");
        require(deadline >= block.timestamp, "Transaction expired");

        // Check sufficient balance
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));
        require(balance >= amountInMaximum, "Insufficient token balance");

        // Setup approval
        IERC20(tokenIn).forceApprove(router, amountInMaximum);

        // Execute swap
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: deadline,
            amountOut: amountOut,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        amountIn = ISwapRouter(router).exactOutputSingle(params);
        
        // Clean up approval
        IERC20(tokenIn).forceApprove(router, 0);

        emit TradeExecuted(tokenIn, tokenOut, amountIn, amountOut, router);
    }

    // ============ RECEIVE FUNCTIONS ============
    // ============ RECEIVE FUNCTIONS ============
    
    /// @notice Allow contract to receive ETH
    receive() external payable {}
    
    /// @notice Fallback function for any other calls
    fallback() external payable {}
} 