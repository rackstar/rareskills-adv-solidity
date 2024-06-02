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
        token = new TokenSanctions(1000 * ONE_ETH);
        token.transfer(user, 100 * ONE_ETH);
        token.transfer(bannedUser, 50 * ONE_ETH);
        vm.stopPrank();
    }

    function testBannedUserCannotSendTokens() public {
        vm.startPrank(owner);
        token.banUser(bannedUser);
        vm.stopPrank();

        // Banned user tries to transfer tokens
        vm.startPrank(bannedUser);
        vm.expectRevert(TokenSanctions.UserBanned.selector);
        token.transfer(recipient, 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testBannedUserCannotReceiveTokens() public {
        vm.startPrank(owner);
        token.banUser(bannedUser);
        vm.stopPrank();

        // User tries to transfer tokens to banned user
        vm.startPrank(user);
        vm.expectRevert(TokenSanctions.UserBanned.selector);
        token.transfer(bannedUser, 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testBannedUserCannotApproveTokens() public {
        vm.startPrank(owner);
        token.banUser(bannedUser);
        vm.stopPrank();

        // Banned user tries to approve tokens
        vm.startPrank(bannedUser);
        vm.expectRevert(TokenSanctions.UserBanned.selector);
        token.approve(spender, 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testTransferFromFailsIfSenderOrReceiverIsBanned() public {
        vm.startPrank(user);
        token.approve(spender, 10 * ONE_ETH);
        vm.stopPrank();

        // Owner bans the recipient
        vm.startPrank(owner);
        token.banUser(recipient);
        vm.stopPrank();

        // Spender tries to transfer tokens to the banned recipient
        vm.startPrank(spender);
        vm.expectRevert(TokenSanctions.UserBanned.selector);
        token.transferFrom(user, recipient, 10 * ONE_ETH);
        vm.stopPrank();

        // Owner bans the user
        vm.startPrank(owner);
        token.banUser(user);
        vm.stopPrank();

        // Spender tries to transfer tokens from the banned user
        vm.startPrank(spender);
        vm.expectRevert(TokenSanctions.UserBanned.selector);
        token.transferFrom(user, recipient, 10 * ONE_ETH);
        vm.stopPrank();
    }
}
