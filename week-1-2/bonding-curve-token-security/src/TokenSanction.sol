// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TokenSanctions is ERC20, Ownable2Step {
    error UserBanned();

    mapping(address user => bool) sanctionedUsers;

    constructor(uint256 initialSupply) ERC20("TokenSanction", "TKS") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    function banUser(address user) external onlyOwner {
        sanctionedUsers[user] = true;
    }

    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        if (sanctionedUsers[_msgSender()] || sanctionedUsers[to]) {
            revert UserBanned();
        }
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        if (sanctionedUsers[_msgSender()] || sanctionedUsers[spender]) {
            revert UserBanned();
        }
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        if (sanctionedUsers[from] || sanctionedUsers[to]) {
            revert UserBanned();
        }
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }
}
