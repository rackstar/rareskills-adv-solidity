// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UntrustedEscrow} from "../src/UntrustedEscrow.sol"; // Assuming the contract is in the parent directory

contract UntrustedEscrowTest is Test {
    UntrustedEscrow escrow;
    ERC20Mock token;
    address buyer = address(1);
    address seller = address(2);
    uint256 amount = 1000;

    function setUp() public {
        escrow = new UntrustedEscrow();
        token = new ERC20Mock();

        token.mint(buyer, amount);
        token.mint(address(this), amount);

        vm.startPrank(buyer);
        token.approve(address(escrow), amount);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(buyer);
        vm.expectEmit(true, true, true, true);
        emit UntrustedEscrow.TokenDeposited(buyer, seller, address(token), amount);

        escrow.deposit(address(token), seller, amount);
        vm.stopPrank();

        assertEq(escrow.deposits(buyer, seller, address(token)), amount, "Deposit amount mismatch");
    }

    function testApproveWithdraw() public {
        vm.startPrank(buyer);
        escrow.deposit(address(token), seller, amount);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectEmit(true, true, true, true);
        emit UntrustedEscrow.WithdrawalApproved(buyer, seller, address(token));
        escrow.approveWithdraw(address(token), seller);
        vm.stopPrank();

        bool approved = escrow.approvals(buyer, seller, address(token));
        assertTrue(approved, "Approval status mismatch");
    }

    function testCancelDeposit() public {
        vm.startPrank(buyer);
        escrow.deposit(address(token), seller, amount);
        vm.expectEmit(true, true, true, true);
        emit UntrustedEscrow.DepositCancelled(buyer, seller, address(token));

        escrow.cancelDeposit(address(token), seller);
        vm.stopPrank();

        assertEq(token.balanceOf(buyer), amount, "Refund amount mismatch");
    }

    function testWithdrawAfter3Days() public {
        vm.startPrank(buyer);
        escrow.deposit(address(token), seller, amount);
        vm.stopPrank();

        // Advance time by 3 days
        vm.warp(block.timestamp + 3 days);

        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true);
        emit UntrustedEscrow.DepositWithdrawn(buyer, seller, address(token), amount);

        escrow.withdraw(address(token), buyer);
        vm.stopPrank();

        assertEq(token.balanceOf(seller), amount, "Withdrawn amount mismatch");
    }

    function testWithdrawBefore3DaysIfApproved() public {
        vm.startPrank(buyer);
        escrow.deposit(address(token), seller, amount);
        escrow.approveWithdraw(address(token), seller);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true);
        emit UntrustedEscrow.DepositWithdrawn(buyer, seller, address(token), amount);

        escrow.withdraw(address(token), buyer);
        vm.stopPrank();

        assertEq(token.balanceOf(seller), amount, "Withdrawn amount mismatch");
    }
}

// Mock ERC20 token for testing
contract ERC20Mock is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
