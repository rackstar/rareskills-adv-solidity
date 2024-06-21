// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721,ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract NftEnumeration is ERC721Enumerable, Ownable2Step {
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    string public baseTokenURI;

    error MaxSupplyReached(uint256 maxSupply);
    error InsufficientPayment();
    error NoEthToWithdraw();
    error EthTransferFailed();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        baseTokenURI = "https://nft-enumeration.com/nft/";
    }

    /// @notice Mints the specified number of NFTs to the specified address.
    /// @param to The address to mint the NFT to.
    /// @param count The number of NFTs to mint.
    function mint(address to, uint256 count) external payable {
        uint currentSupply = totalSupply();
        if (currentSupply + count > MAX_SUPPLY) {
            revert MaxSupplyReached(MAX_SUPPLY);
        }
        if (msg.value < count * MINT_PRICE) {
            revert InsufficientPayment();
        }

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = currentSupply + 1;
            currentSupply++;
            _safeMint(to, tokenId);
        }
    }

    /// @notice Sets a new base URI for the token metadata.
    /// @param newBaseTokenURI The new base URI for the token metadata.
    function setBaseURI(string memory newBaseTokenURI) external onlyOwner {
        baseTokenURI = newBaseTokenURI;
    }

    /// @notice Returns the base URI for the token metadata.
    /// @return The base URI as a string.
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /// @notice Allows the owner to withdraw all ETH from the contract.
    /// @dev Can only be called by the owner.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert NoEthToWithdraw();
        }
        (bool success,) = owner().call{value: balance}("");
        if (!success) {
            revert EthTransferFailed();
        }
    }
}
