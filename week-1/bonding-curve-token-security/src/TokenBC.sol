// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

/// @title TokenBC - A simple ERC20 token with a linear bonding curve for minting and burning tokens
/// @dev A cooldown period is enforce between buy and sell to prevent sandwich attacks
/// @notice This contract allows users to buy and sell tokens according to a linear bonding curve
contract TokenBC is ERC20, Ownable2Step {
    uint256 public constant COOLDOWN_PERIOD = 1 minutes;
    mapping(address user => uint256 lastBuyTimestamp) private lastBuyTimestamp;

    event TokenBought(address indexed buyer, uint256 ethSpent, uint256 tokenReceived);
    event TokenSold(address indexed seller, uint256 tokenSold, uint256 ethReceived);

    error InsufficientPayment();
    error InvalidAmount();
    error InsufficientTokenBalance();
    error MinAmountOutNotMet(uint256 amountOut, uint256 minAmountOut);
    error InsufficientContractBalance();
    error EthTransferFailed();
    error CooldownNotElapsed(uint256 coolDownExpiry);

    /// @notice Constructor for the contract
    /// @param name The name of the ERC20 token
    /// @param symbol The symbol of the ERC20 token
    /// @dev Initializes the ERC20 token with the provided name and symbol, and sets the owner of the contract to the deployer
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    /// @notice Allows users to buy tokens by sending ETH
    /// @param _minAmountOut The minimum amount of tokens the user expects to receive
    /// @dev The function mints tokens based on the ETH sent and the linear bonding curve
    function buy(uint256 _minAmountOut) external payable {
        if (msg.value == 0) revert InsufficientPayment();

        uint256 tokensToMint = calculateTokensToMint({_ethToSell: msg.value});
        console.log("tokensToMint: ", tokensToMint);
        if (tokensToMint < _minAmountOut) revert MinAmountOutNotMet(tokensToMint, _minAmountOut);
        _mint(msg.sender, tokensToMint);

        lastBuyTimestamp[msg.sender] = block.timestamp;

        emit TokenBought(msg.sender, msg.value, tokensToMint);
    }

    /// @notice Allows users to sell tokens and receive ETH
    /// @dev A cooldown period is enforce between buy and sell to prevent sandwich attacks
    /// @param _amountToSell The amount of tokens the user wants to sell
    /// @param _minAmountOut The minimum amount of ETH the user expects to receive
    /// @dev The function burns tokens and sends ETH based on the linear bonding curve
    function sell(uint256 _amountToSell, uint256 _minAmountOut) external {
        if (_amountToSell == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < _amountToSell) revert InsufficientTokenBalance();

        // protect against sandwich attacks by enforcing a cooldown period between buy and sell
        uint256 coolDownExpiry = lastBuyTimestamp[msg.sender] + COOLDOWN_PERIOD;
        console.log("coolDownExpiry: ", coolDownExpiry);
        console.log("block.timestamp: ", block.timestamp);
        if (block.timestamp < coolDownExpiry) {
            revert CooldownNotElapsed(coolDownExpiry);
        }

        uint256 ethOut = calculateEthOut({_tokenToSell: _amountToSell});
        if (ethOut < _minAmountOut) revert MinAmountOutNotMet(ethOut, _minAmountOut);
        if (address(this).balance < ethOut) revert InsufficientContractBalance();

        _burn(msg.sender, _amountToSell);
        (bool ok,) = msg.sender.call{value: ethOut}("");
        if (ok == false) revert EthTransferFailed();

        // set storage back to 0 for gas refund
        lastBuyTimestamp[msg.sender] = 0;

        emit TokenSold(msg.sender, _amountToSell, ethOut);
    }

    /// @notice Calculates the amount of ETH to return for a given amount of tokens
    /// @param _tokenToSell The amount of tokens to sell
    /// @return The amount of ETH to return
    /// @dev Uses the trapezoid formula to calculate the area under the curve
    /// @dev A = 1/2 * (P0 + P1) * (Q1 - Q0)
    /// @dev A = 1/2 * (Q0 + Q1) * (Q1 - Q0) ~ since linear bonding curve (P=Q)
    /// @dev A = 1/2 * (Q1² - Q0²) ~ difference of of squares
    function calculateEthOut(uint256 _tokenToSell) public view returns (uint256) {
        uint256 currentSupply = totalSupply(); // Q1
        uint256 newSupply = currentSupply - _tokenToSell; // Q0
        uint256 currentSupplySquared = currentSupply ** 2;
        uint256 newSupplySquared = newSupply ** 2;

        console.log("-------calculateEthOut--------");
        console.log("currentSupply:", currentSupply);
        console.log("newSupply:", newSupply);
        console.log("currentSupplySquared:", currentSupplySquared);
        console.log("newSupplySquared:", newSupplySquared);
        console.log("------------------------------");

        // round up price for user by adding 1
        return (currentSupplySquared - newSupplySquared + 1) / 2;
    }

    /// @notice Calculates the number of tokens to mint for a given amount of ETH
    /// @param _ethToSell The amount of ETH to spend
    /// @return The number of tokens to mint
    /// @dev Uses the trapezoid formula to calculate the area under the curve and rounds down to favor the contract
    /// @dev A = 1/2 * (Q1² - Q0²) ~ difference of of squares (see calculateEthOut)
    /// @dev Q1² = A*2 + Q0²
    /// @dev Q1 = SQRT(A*2 + Q0²)
    function calculateTokensToMint(uint256 _ethToSell) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        // rounds down in favour of contract
        uint256 newSupply = Math.sqrt(_ethToSell * 2 + currentSupply * currentSupply);

        console.log("-------calculateTokensToMint-------");
        console.log("currentSupply:", currentSupply);
        console.log("newSupply:", newSupply);
        console.log("-----------------------------------");

        // tokenToMint is the Q delta
        return newSupply - currentSupply;
    }

    /// @notice Returns the price per token based on the quantity
    /// @param quantity The quantity of tokens
    /// @return The price per token
    function getPricePerToken(uint256 quantity) public pure returns (uint256) {
        return quantity;
    }
}
