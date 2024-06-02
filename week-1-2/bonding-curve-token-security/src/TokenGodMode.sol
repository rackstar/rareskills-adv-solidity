// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TokenGodMode is ERC20, Ownable2Step {

    constructor(uint256 initialSupply) ERC20("TokenSanction", "TKS") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    function godTransfer(address from, address to, uint256 value) public onlyOwner returns (bool) {
        _transfer(from, to, value);
        return true;
    }
}
