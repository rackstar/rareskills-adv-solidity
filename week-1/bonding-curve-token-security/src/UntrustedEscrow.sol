// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Untrusted Escrow Contract
/// @notice This contract allows buyers to deposit ERC20 tokens into escrow for sellers and manage withdrawals.
/// @dev Implements safe transfer of ERC20 tokens and protects against reentrancy attacks.
contract UntrustedEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address buyer => mapping(address seller => mapping(address token => uint256))) public deposits;
    mapping(address buyer => mapping(address seller => mapping(address token => bool))) public approvals;
    mapping(address buyer => mapping(address seller => mapping(address token => uint256))) public depositTimestamps;

    /// @dev Emitted when tokens are deposited into the escrow by `deposit`.
    /// @param buyer The address of the buyer who deposited the tokens.
    /// @param seller The address of the seller for whom the tokens are deposited.
    /// @param token The address of the ERC20 token.
    /// @param amount The amount of tokens deposited.
    event TokenDeposited(address indexed buyer, address indexed seller, address token, uint256 amount);

    /// @dev Emitted when a withdrawal is approved by the buyer by `approveWithdraw`.
    /// @param buyer The address of the buyer who approved the withdrawal.
    /// @param seller The address of the seller who will withdraw the tokens.
    /// @param token The address of the ERC20 token.
    event WithdrawalApproved(address indexed buyer, address indexed seller, address token);

    /// @dev Emitted when a deposit is cancelled by the buyer by `cancelDeposit`.
    /// @param buyer The address of the buyer who cancelled the deposit.
    /// @param seller The address of the seller for whom the tokens were deposited.
    /// @param token The address of the ERC20 token.
    event DepositCancelled(address indexed buyer, address indexed seller, address token);

    /// @dev Emitted when a deposit is withdrawn by the seller by `withdraw`.
    /// @param buyer The address of the buyer who deposited the tokens.
    /// @param seller The address of the seller who withdrew the tokens.
    /// @param token The address of the ERC20 token.
    /// @param amount The amount of tokens withdrawn.
    event DepositWithdrawn(address indexed buyer, address indexed seller, address token, uint256 amount);

    error NotAuthorizedOrNoDepositFound();
    error ZeroAmount();
    error ZeroAddress();
    error WithdrawNotAllowed();

    /// @dev Ensures only the buyer can call the function.
    /// @param _token The address of the ERC20 token.
    /// @param _seller The address of the seller.
    modifier onlyBuyer(address _token, address _seller) {
        if (deposits[msg.sender][_seller][_token] == 0) {
            revert NotAuthorizedOrNoDepositFound();
        }
        _;
    }

    /// @dev Ensures only the seller can call the function.
    /// @param _token The address of the ERC20 token.
    /// @param _buyer The address of the buyer.
    modifier onlySeller(address _token, address _buyer) {
        if (deposits[_buyer][msg.sender][_token] == 0) {
            revert NotAuthorizedOrNoDepositFound();
        }
        _;
    }

    /// @notice Deposits ERC20 tokens into escrow for the specified seller.
    /// @dev Emits a TokenDeposited event.
    /// @param _token The address of the ERC20 token to be deposited.
    /// @param _seller The address of the seller for whom the tokens are deposited.
    /// @param _amount The amount of tokens to deposit.
    function deposit(address _token, address _seller, uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();
        if (_token == address(0) || _seller == address(0)) revert ZeroAddress();

        IERC20 token = IERC20(_token);

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = token.balanceOf(address(this));

        // check the actual amount transferred in case it is a fee-on-transfer token
        uint256 actualAmount = balanceAfter - balanceBefore;

        deposits[msg.sender][_seller][_token] = actualAmount;
        depositTimestamps[msg.sender][_seller][_token] = block.timestamp;

        emit TokenDeposited(msg.sender, _seller, _token, actualAmount);
    }

    /// @notice Approves the withdrawal of deposited tokens by the specified seller.
    /// @dev Emits a WithdrawalApproved event.
    /// @param _token The address of the ERC20 token to be withdrawn.
    /// @param _seller The address of the seller who will withdraw the tokens.
    function approveWithdraw(address _token, address _seller) external onlyBuyer(_token, _seller) {
        if (_token == address(0) || _seller == address(0)) revert ZeroAddress();

        approvals[msg.sender][_seller][_token] = true;

        emit WithdrawalApproved(msg.sender, _seller, _token);
    }

    /// @notice Cancels the deposit and returns the tokens to the buyer.
    /// @dev Emits a DepositCancelled event and is protected against reentrancy.
    /// @param _token The address of the ERC20 token to be cancelled.
    /// @param _seller The address of the seller for whom the tokens were deposited.
    function cancelDeposit(address _token, address _seller) external onlyBuyer(_token, _seller) nonReentrant {
        if (_token == address(0) || _seller == address(0)) revert ZeroAddress();

        uint256 depositAmount = deposits[msg.sender][_seller][_token];

        // Reset values
        deposits[msg.sender][_seller][_token] = 0;
        approvals[msg.sender][_seller][_token] = false;
        depositTimestamps[msg.sender][_seller][_token] = 0;

        // Transfer the deposit back to the buyer
        IERC20 token = IERC20(_token);
        token.safeTransfer(msg.sender, depositAmount);

        emit DepositCancelled(msg.sender, _seller, _token);
    }

    /// @notice Withdraws the deposited tokens by the seller if approved or if 3 days have passed.
    /// @dev Emits a DepositWithdrawn event and is protected against reentrancy.
    /// @param _token The address of the ERC20 token to be withdrawn.
    /// @param _buyer The address of the buyer who deposited the tokens.
    function withdraw(address _token, address _buyer) external onlySeller(_token, _buyer) nonReentrant {
        if (_token == address(0) || _buyer == address(0)) revert ZeroAddress();

        // Only allow withdrawal if it's approved by the buyer OR it's been more than 3 days since the deposit
        bool approved = approvals[_buyer][msg.sender][_token];
        bool pastThreeDays = block.timestamp >= depositTimestamps[_buyer][msg.sender][_token] + 3 days;
        if (!approved && !pastThreeDays) {
            revert WithdrawNotAllowed();
        }

        uint256 depositAmount = deposits[_buyer][msg.sender][_token];

        // Reset values
        deposits[_buyer][msg.sender][_token] = 0;
        approvals[_buyer][msg.sender][_token] = false;
        depositTimestamps[_buyer][msg.sender][_token] = 0;

        // Transfer the deposit payment to seller
        IERC20 token = IERC20(_token);
        token.safeTransfer(msg.sender, depositAmount);

        emit DepositWithdrawn(_buyer, msg.sender, _token, depositAmount);
    }
}
