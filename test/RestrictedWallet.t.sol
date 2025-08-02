// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RestrictedWallet.sol";
import "../src/MockUSDC.sol";

contract RestrictedWalletTest is Test {
    RestrictedWallet public wallet;
    MockUSDC public mockUSDC;
    
    address public owner;
    address public user1;
    address public uniswapRouter;
    
    // Test constants
    uint256 constant MINT_AMOUNT = 10000 * 10**6; // 10,000 USDC
    uint256 constant TRANSFER_AMOUNT = 1000 * 10**6; // 1,000 USDC
    
    // Events untuk testing
    event TargetWhitelisted(address indexed target, bool approved);
    event SelectorWhitelisted(bytes4 indexed selector, bool approved);
    event TokenWhitelisted(address indexed token, bool approved);
    event TransactionExecuted(address indexed target, bytes data);
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed router
    );
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        uniswapRouter = makeAddr("uniswapRouter");
        
        // Deploy MockUSDC
        mockUSDC = new MockUSDC();
        
        // Deploy RestrictedWallet
        wallet = new RestrictedWallet(owner);
        
        // Mint USDC for testing
        mockUSDC.mint(address(wallet), MINT_AMOUNT);
        mockUSDC.mint(owner, MINT_AMOUNT);
        
        // Add some ETH to wallet
        vm.deal(address(wallet), 10 ether);
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public view {
        assertEq(wallet.owner(), owner);
        
        // Check pre-approved Uniswap V3 selectors
        assertTrue(wallet.isSelectorApproved(0x414bf389)); // exactInputSingle
        assertTrue(wallet.isSelectorApproved(0xdb3e2198)); // exactOutputSingle
        assertTrue(wallet.isSelectorApproved(0xc04b8d59)); // exactInput
        assertTrue(wallet.isSelectorApproved(0xf28c0498)); // exactOutput
    }
    
    // ============ EXECUTE FUNCTION TESTS ============
    
    function testExecuteFailsWithUnapprovedTarget() public {
        bytes memory callData = abi.encodeWithSelector(0x414bf389, "test");
        
        vm.expectRevert("Target not approved");
        vm.prank(owner);
        wallet.execute(uniswapRouter, callData);
    }
    
    function testExecuteFailsWithUnapprovedSelector() public {
        // Setup: approve target but not selector
        vm.prank(owner);
        wallet.addApprovedTarget(uniswapRouter);
        
        bytes memory callData = abi.encodeWithSelector(0x12345678, "test"); // random selector
        
        vm.expectRevert("Function not approved");
        vm.prank(owner);
        wallet.execute(uniswapRouter, callData);
    }
    
    function testExecuteOnlyOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        wallet.execute(uniswapRouter, "");
    }
    
    function testExecuteInvalidTarget() public {
        vm.expectRevert("Invalid target");
        vm.prank(owner);
        wallet.execute(address(0), "");
    }
    
    // ============ WITHDRAW TESTS ============
    
    function testWithdrawUSDCSuccess() public {
        uint256 ownerBalanceBefore = mockUSDC.balanceOf(owner);
        uint256 walletBalanceBefore = mockUSDC.balanceOf(address(wallet));
        
        vm.prank(owner);
        wallet.withdraw(address(mockUSDC), TRANSFER_AMOUNT);
        
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore + TRANSFER_AMOUNT);
        assertEq(mockUSDC.balanceOf(address(wallet)), walletBalanceBefore - TRANSFER_AMOUNT);
    }
    
    function testWithdrawETHSuccess() public {
        uint256 ownerBalanceBefore = owner.balance;
        uint256 walletBalanceBefore = address(wallet).balance;
        
        vm.prank(owner);
        wallet.withdraw(address(0), 1 ether);
        
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
        assertEq(address(wallet).balance, walletBalanceBefore - 1 ether);
    }
    
    function testWithdrawOnlyOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        wallet.withdraw(address(mockUSDC), TRANSFER_AMOUNT);
    }
    
    function testWithdrawZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        vm.prank(owner);
        wallet.withdraw(address(mockUSDC), 0);
    }
    
    function testWithdrawAllUSDC() public {
        uint256 walletBalance = mockUSDC.balanceOf(address(wallet));
        uint256 ownerBalanceBefore = mockUSDC.balanceOf(owner);
        
        vm.prank(owner);
        wallet.withdrawAll(address(mockUSDC));
        
        assertEq(mockUSDC.balanceOf(address(wallet)), 0);
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore + walletBalance);
    }
    
    function testWithdrawAllETH() public {
        uint256 walletBalance = address(wallet).balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.prank(owner);
        wallet.withdrawAll(address(0));
        
        assertEq(address(wallet).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + walletBalance);
    }
    
    // ============ ADMIN FUNCTIONS TESTS ============
    
    function testAddApprovedTargetSuccess() public {
        vm.expectEmit(true, false, false, true);
        emit TargetWhitelisted(uniswapRouter, true);
        
        vm.prank(owner);
        wallet.addApprovedTarget(uniswapRouter);
        
        assertTrue(wallet.isTargetApproved(uniswapRouter));
    }
    
    function testAddApprovedTargetOnlyOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        wallet.addApprovedTarget(uniswapRouter);
    }
    
    function testAddApprovedTargetInvalidAddress() public {
        vm.expectRevert("Invalid target");
        vm.prank(owner);
        wallet.addApprovedTarget(address(0));
    }
    
    function testRemoveApprovedTarget() public {
        // Setup: add target first
        vm.prank(owner);
        wallet.addApprovedTarget(uniswapRouter);
        
        vm.expectEmit(true, false, false, true);
        emit TargetWhitelisted(uniswapRouter, false);
        
        vm.prank(owner);
        wallet.removeApprovedTarget(uniswapRouter);
        
        assertFalse(wallet.isTargetApproved(uniswapRouter));
    }
    
    function testAddApprovedSelectorSuccess() public {
        bytes4 newSelector = 0x12345678;
        
        vm.expectEmit(true, false, false, true);
        emit SelectorWhitelisted(newSelector, true);
        
        vm.prank(owner);
        wallet.addApprovedSelector(newSelector);
        
        assertTrue(wallet.isSelectorApproved(newSelector));
    }
    
    function testRemoveApprovedSelector() public {
        bytes4 selector = 0x414bf389; // Pre-approved selector
        
        vm.expectEmit(true, false, false, true);
        emit SelectorWhitelisted(selector, false);
        
        vm.prank(owner);
        wallet.removeApprovedSelector(selector);
        
        assertFalse(wallet.isSelectorApproved(selector));
    }
    
    // ============ VIEW FUNCTIONS TESTS ============
    
    function testGetBalanceUSDC() public view {
        uint256 balance = wallet.getBalance(address(mockUSDC));
        assertEq(balance, MINT_AMOUNT);
    }
    
    function testGetBalanceETH() public view {
        uint256 balance = wallet.getBalance(address(0));
        assertEq(balance, 10 ether);
    }
    
    function testIsTargetApproved() public {
        assertFalse(wallet.isTargetApproved(uniswapRouter));
        
        vm.prank(owner);
        wallet.addApprovedTarget(uniswapRouter);
        
        assertTrue(wallet.isTargetApproved(uniswapRouter));
    }
    
    function testIsSelectorApproved() public view {
        // Check pre-approved selectors
        assertTrue(wallet.isSelectorApproved(0x414bf389)); // exactInputSingle
        assertFalse(wallet.isSelectorApproved(0x12345678)); // random selector
    }
    
    // ============ RECEIVE/FALLBACK TESTS ============
    
    function testReceiveETH() public {
        uint256 balanceBefore = address(wallet).balance;
        
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        
        assertTrue(success);
        assertEq(address(wallet).balance, balanceBefore + 1 ether);
    }
    
    // ============ FUZZ TESTS ============
    
    function testFuzzWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINT_AMOUNT);
        
        uint256 ownerBalanceBefore = mockUSDC.balanceOf(owner);
        
        vm.prank(owner);
        wallet.withdraw(address(mockUSDC), amount);
        
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore + amount);
        assertEq(mockUSDC.balanceOf(address(wallet)), MINT_AMOUNT - amount);
    }

    // ============ WHITELISTED TOKENS TESTS ============
    
    function testAddWhitelistedToken() public {
        assertFalse(wallet.isTokenWhitelisted(address(mockUSDC)));
        
        vm.expectEmit(true, false, false, true);
        emit TokenWhitelisted(address(mockUSDC), true);
        
        vm.prank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        
        assertTrue(wallet.isTokenWhitelisted(address(mockUSDC)));
    }
    
    function testAddWhitelistedTokenOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        wallet.addWhitelistedToken(address(mockUSDC));
    }
    
    function testAddWhitelistedTokenInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid token");
        wallet.addWhitelistedToken(address(0));
    }
    
    function testRemoveWhitelistedToken() public {
        // First add token
        vm.prank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        assertTrue(wallet.isTokenWhitelisted(address(mockUSDC)));
        
        // Then remove it
        vm.expectEmit(true, false, false, true);
        emit TokenWhitelisted(address(mockUSDC), false);
        
        vm.prank(owner);
        wallet.removeWhitelistedToken(address(mockUSDC));
        
        assertFalse(wallet.isTokenWhitelisted(address(mockUSDC)));
    }
    
    function testAddWhitelistedTokensBatch() public {
        address token1 = makeAddr("token1");
        address token2 = makeAddr("token2");
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;
        
        vm.prank(owner);
        wallet.addWhitelistedTokensBatch(tokens);
        
        assertTrue(wallet.isTokenWhitelisted(token1));
        assertTrue(wallet.isTokenWhitelisted(token2));
    }

    // ============ TRADING TESTS ============
    
    function testSwapExactInputSingleSuccess() public {
        address tokenOut = makeAddr("tokenOut");
        uint24 fee = 3000;
        uint256 amountIn = 1000 * 10**6; // 1000 USDC
        uint256 amountOutMinimum = 990 * 10**18; // Expect ~990 tokenOut
        uint256 expectedAmountOut = 1000 * 10**18;
        
        // Setup: whitelist tokens and router
        vm.startPrank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        wallet.addWhitelistedToken(tokenOut);
        wallet.addApprovedTarget(uniswapRouter);
        vm.stopPrank();
        
        // Mock router response
        vm.mockCall(
            uniswapRouter,
            abi.encodeWithSelector(0x414bf389), // exactInputSingle
            abi.encode(expectedAmountOut)
        );
        
        vm.expectEmit(true, true, false, true);
        emit TradeExecuted(address(mockUSDC), tokenOut, amountIn, expectedAmountOut, uniswapRouter);
        
        vm.prank(owner);
        uint256 result = wallet.swapExactInputSingle(
            uniswapRouter,
            address(mockUSDC),
            tokenOut,
            fee,
            amountIn,
            amountOutMinimum,
            0, // sqrtPriceLimitX96
            block.timestamp + 300
        );
        
        assertEq(result, expectedAmountOut);
    }
    
    function testSwapExactInputSingleFailsWithUnwhitelistedTokenIn() public {
        address tokenOut = makeAddr("tokenOut");
        
        // Setup: only whitelist tokenOut and router
        vm.startPrank(owner);
        wallet.addWhitelistedToken(tokenOut);
        wallet.addApprovedTarget(uniswapRouter);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Input token not whitelisted");
        wallet.swapExactInputSingle(
            uniswapRouter,
            address(mockUSDC), // Not whitelisted
            tokenOut,
            3000,
            1000 * 10**6,
            990 * 10**18,
            0,
            block.timestamp + 300
        );
    }
    
    function testSwapExactInputSingleFailsWithUnwhitelistedTokenOut() public {
        address tokenOut = makeAddr("tokenOut");
        
        // Setup: only whitelist tokenIn and router
        vm.startPrank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        wallet.addApprovedTarget(uniswapRouter);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Output token not whitelisted");
        wallet.swapExactInputSingle(
            uniswapRouter,
            address(mockUSDC),
            tokenOut, // Not whitelisted
            3000,
            1000 * 10**6,
            990 * 10**18,
            0,
            block.timestamp + 300
        );
    }
    
    function testSwapExactInputSingleFailsWithUnapprovedRouter() public {
        address tokenOut = makeAddr("tokenOut");
        
        // Setup: whitelist tokens but not router
        vm.startPrank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        wallet.addWhitelistedToken(tokenOut);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Router not approved");
        wallet.swapExactInputSingle(
            uniswapRouter, // Not approved
            address(mockUSDC),
            tokenOut,
            3000,
            1000 * 10**6,
            990 * 10**18,
            0,
            block.timestamp + 300
        );
    }
    
    function testSwapExactInputSingleFailsWithExpiredDeadline() public {
        address tokenOut = makeAddr("tokenOut");
        
        // Setup
        vm.startPrank(owner);
        wallet.addWhitelistedToken(address(mockUSDC));
        wallet.addWhitelistedToken(tokenOut);
        wallet.addApprovedTarget(uniswapRouter);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Transaction expired");
        wallet.swapExactInputSingle(
            uniswapRouter,
            address(mockUSDC),
            tokenOut,
            3000,
            1000 * 10**6,
            990 * 10**18,
            0,
            block.timestamp - 1 // Expired deadline
        );
    }
} 