// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {TokenBC} from "../src/TokenBC.sol";
import "forge-std/console.sol";

contract TokenBCTest is Test {
    TokenBC token;
    address owner = address(1);
    address user = address(2);
    uint256 minAmountOut = 1 wei;

    function setUp() public {
        vm.startPrank(owner);
        token = new TokenBC("TokenBC", "TBC");
        vm.stopPrank();
    }

    function testBuyTokens() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // starting price / quatity of 3
        token.buy{value: 6}(3); // 1+2+3
        uint256 initialSupply = token.totalSupply();
        uint256 initialPrice = token.getPricePerToken(initialSupply);
        assertEq(token.balanceOf(user), 3);
        assertEq(initialSupply, 3);
        assertEq(initialPrice, 3);

        // buy 20 wei worth of tokens
        uint256 ethAmount = 20 wei;
        // why does the article below says 3 to 7 the cost is 20? (4+5+6+7 = 22)
        // https://medium.com/coinmonks/token-bonding-curves-explained-7a9332198e0e
        uint256 expectedTokenOut = 4; // 4+5+6+7 = 22
        uint256 tokensToMint = token.calculateTokensToMint(ethAmount);
        assertEq(tokensToMint, expectedTokenOut);

        token.buy{value: ethAmount}(expectedTokenOut);

        uint256 finalSupply = token.totalSupply();
        uint256 finalPrice = token.getPricePerToken(finalSupply);
        assertEq(token.balanceOf(user), 3 + expectedTokenOut);
        assertEq(finalPrice, 7);
        assertEq(finalPrice, 7);

        vm.stopPrank();
    }

    function testSellTokens() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        uint256 ethAmount = 8 wei;
        uint256 expectedTokens = token.calculateTokensToMint(ethAmount);

        token.buy{value: ethAmount}(4);

        uint256 initialPrice = token.getPricePerToken(token.totalSupply());

        assertEq(expectedTokens, 4); // 1+2+3+4 = 10
        assertEq(token.balanceOf(user), 4);

        uint256 tokensToSell = 4;
        uint256 expectedEth = token.calculateEthOut(tokensToSell);

        vm.warp(block.timestamp + 1 minutes + 1 seconds);
        token.sell(4, expectedEth);

        uint256 finalPrice = token.getPricePerToken(token.totalSupply());
        assertTrue(finalPrice < initialPrice, "Price did not decrease after selling");

        vm.stopPrank();
    }

    function testBuyTokensRevertZeroETH() public {
        vm.startPrank(user);
        vm.expectRevert(TokenBC.InsufficientPayment.selector);
        token.buy{value: 0}(minAmountOut);
        vm.stopPrank();
    }

    function testSellTokensRevertZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(TokenBC.InvalidAmount.selector);
        token.sell(0, minAmountOut);
        vm.stopPrank();
    }

    function testSellTokensRevertInsufficientBalance() public {
        vm.startPrank(user);
        vm.expectRevert(TokenBC.InsufficientTokenBalance.selector);
        token.sell(1 wei, minAmountOut);
        vm.stopPrank();
    }

    function testBuyTokensRevertMinAmountOutNotMet() public {
        uint256 ethAmount = 10 wei;

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        uint256 tokenOut = token.calculateTokensToMint(ethAmount);
        uint256 highMinAmountOut = tokenOut + 1 wei;
        vm.expectRevert(abi.encodeWithSelector(TokenBC.MinAmountOutNotMet.selector, tokenOut, highMinAmountOut));

        token.buy{value: ethAmount}(highMinAmountOut);

        vm.stopPrank();
    }

    function testSellTokensRevertMinAmountOutNotMet() public {
        uint256 ethAmount = 8 wei;
        uint256 tokensToSell = 4 wei;

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        token.buy{value: ethAmount}(minAmountOut);

        uint256 expectedEthOut = token.calculateEthOut(tokensToSell);
        uint256 highMinAmountOut = expectedEthOut + 1 wei;
        vm.expectRevert(abi.encodeWithSelector(TokenBC.MinAmountOutNotMet.selector, expectedEthOut, highMinAmountOut));
        vm.warp(block.timestamp + 1 minutes + 1 seconds);

        token.sell(tokensToSell, highMinAmountOut);

        vm.stopPrank();
    }
}
