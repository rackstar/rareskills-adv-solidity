// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title StakingRewardToken
contract StakingRewardToken is ERC20, Ownable2Step {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    /// @notice Mints new tokens to the specified address.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
