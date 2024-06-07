// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "../src/TokenSanction.sol";

contract TokenSanctionsTest is Test {
    TokenSanctions token;
    address owner = address(1);
    address user = address(2);
    address bannedUser = address(3);
    address spender = address(4);
    address recipient = address(5);
    uint256 ONE_ETH = 1 * 10 ** 18;

    function setUp() public {
        vm.startPrank(owner);
        token = new TokenSanctions(1000 * ONE_ETH, "TokenSanctions", "TKS");
        token.transfer(user, 100 * ONE_ETH);
        token.transfer(bannedUser, 50 * ONE_ETH);
        vm.stopPrank();
    }

    function testBannedUserCannotSendTokens() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserBanned(bannedUser);
        token.ban(bannedUser);
        vm.stopPrank();

        // Banned user tries to transfer tokens
        vm.startPrank(bannedUser);
        vm.expectRevert(TokenSanctions.UserBannedError.selector);
        token.transfer(recipient, 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testUnBannedUserCanSendTokensAgain() public {
        uint256 transferAmount = 10 * ONE_ETH;
        uint256 balanceBefore = token.balanceOf(bannedUser);
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserBanned(bannedUser);
        token.ban(bannedUser);
        vm.stopPrank();

        // Banned user tries to transfer tokens
        vm.startPrank(bannedUser);
        vm.expectRevert(TokenSanctions.UserBannedError.selector);
        token.transfer(recipient, transferAmount);
        vm.stopPrank();

        // unban user should be able to transfer tokens
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserUnbanned(bannedUser);
        token.unban(bannedUser);
        vm.stopPrank();

        vm.startPrank(bannedUser);
        token.transfer(recipient, transferAmount);
        vm.stopPrank();

        uint256 bannedUserBalanceAfter = token.balanceOf(bannedUser);
        uint256 recipientBalanceAfter = token.balanceOf(recipient);

        assertEq(
            bannedUserBalanceAfter, balanceBefore - transferAmount, "Balance of user should decrease by transfer amount"
        );
        assertEq(
            recipientBalanceAfter,
            recipientBalanceBefore + transferAmount,
            "Balance of recipient should increase by transfer amount"
        );
    }

    function testBannedUserCannotReceiveTokens() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserBanned(bannedUser);
        token.ban(bannedUser);
        vm.stopPrank();

        // User tries to transfer tokens to banned user
        vm.startPrank(user);
        vm.expectRevert(TokenSanctions.UserBannedError.selector);
        token.transfer(bannedUser, 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testTransferFromFailsIfSenderOrReceiverIsBanned() public {
        vm.startPrank(user);
        token.approve(spender, 10 * ONE_ETH);
        vm.stopPrank();

        // Owner bans the recipient
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserBanned(recipient);
        token.ban(recipient);
        vm.stopPrank();

        // Spender tries to transfer tokens to the banned recipient
        vm.startPrank(spender);
        vm.expectRevert(TokenSanctions.UserBannedError.selector);
        token.transferFrom(user, recipient, 10 * ONE_ETH);
        vm.stopPrank();

        // Owner bans the user
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokenSanctions.UserBanned(user);
        token.ban(user);
        vm.stopPrank();

        // Spender tries to transfer tokens from the banned user
        vm.startPrank(spender);
        vm.expectRevert(TokenSanctions.UserBannedError.selector);
        token.transferFrom(user, recipient, 10 * ONE_ETH);
        vm.stopPrank();
    }
}
