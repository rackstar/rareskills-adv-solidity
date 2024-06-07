// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title TokenSanctions
/// @notice ERC20 token with user sanctions functionality
/// @dev Inherits from OpenZeppelin's ERC20, Ownable, and Ownable2Step contracts
contract TokenSanctions is ERC20, Ownable2Step {
    /// @dev Emitted when a user is banned by the owner
    /// @param user The address of the user that was banned
    event UserBanned(address indexed user);

    /// @dev Emitted when a user is unbanned by the owner
    /// @param user The address of the user that was unbanned
    event UserUnbanned(address indexed user);

    error UserBannedError();

    /// @dev Save a little bit of gas by using uint256 instead of bool
    mapping(address user => uint256) sanctionedUsers;

    /// @notice Constructor to mint initial supply and set token details
    /// @param initialSupply The initial supply of the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(uint256 initialSupply, string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Ban a user from transferring or receiving tokens
    /// @param user The address of the user to be banned
    function ban(address user) external onlyOwner {
        sanctionedUsers[user] = 1;
        emit UserBanned(user);
    }

    /// @notice Unban a user allowing them to transfer or receive tokens
    /// @param user The address of the user to be unbanned
    function unban(address user) external onlyOwner {
        sanctionedUsers[user] = 0;
        emit UserUnbanned(user);
    }

    /// @notice Transfer tokens to another address
    /// @param to The address to transfer to
    /// @param value The amount to be transferred
    /// @return success True if the transfer was successful
    function transfer(address to, uint256 value) public override returns (bool success) {
        if (sanctionedUsers[msg.sender] == 1 || sanctionedUsers[to] == 1) {
            revert UserBannedError();
        }
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    /// @notice Transfer tokens from one address to another using allowance
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param value The amount to be transferred
    /// @return success True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
        if (sanctionedUsers[from] == 1 || sanctionedUsers[to] == 1) {
            revert UserBannedError();
        }
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }
}
