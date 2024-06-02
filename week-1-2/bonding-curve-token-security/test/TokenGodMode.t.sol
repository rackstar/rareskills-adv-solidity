// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {TokenGodMode} from "../src/TokenGodMode.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenGodModeTest is Test {
    TokenGodMode token;
    address owner = address(1);
    address nonOwner = address(2);
    address user = address(3);
    address recipient = address(4);
    uint256 ONE_ETH = 1 * 10 ** 18;

    function setUp() public {
        vm.startPrank(owner);
        token = new TokenGodMode(1000 * ONE_ETH);
        token.transfer(user, 100 * ONE_ETH);
        vm.stopPrank();
    }

    function testOwnerCanGodTransfer() public {
        // owner can transfer tokens from another user
        vm.startPrank(owner);
        bool success = token.godTransfer(user, recipient, 10 * ONE_ETH);
        assertTrue(success);
        assertEq(token.balanceOf(user), 90 * ONE_ETH);
        assertEq(token.balanceOf(recipient), 10 * ONE_ETH);
        vm.stopPrank();
    }

    function testNonOwnerCannotGodTransfer() public {
        // nonOwner tries to transfer tokens from another user
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        token.godTransfer(user, recipient, 10 * ONE_ETH);
        vm.stopPrank();
    }
}
