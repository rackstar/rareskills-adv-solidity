// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721,ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

contract NftRoyalty is ERC721Royalty, Ownable2Step {
    using BitMaps for BitMaps.BitMap;

    // Constants
    uint64 public constant MINT_PRICE = 3 * 10 ** 16;
    uint16 public constant MAX_ELEMENTS = 10000;
    uint16 public constant ROYALTY_BASIS_POINTS = 250; // 2.5%
    uint16 public constant DISCOUNT_DIVISOR = 2;

    // Immutable variables
    bytes32 public immutable merkleRoot;

    // State variables
    BitMaps.BitMap private claimed;
    uint16 private _tokenIdTracker;
    string public baseTokenURI;

    // Custom errors
    error MaxSupplyReached(uint256 maxSupply);
    error InsufficientPayment();
    error InvalidProof();
    error AlreadyClaimed(address account);
    error NoEthToWithdraw();
    error EthTransferFailed();

    constructor(string memory name, string memory symbol, bytes32 _merkleRoot)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        _setDefaultRoyalty(msg.sender, ROYALTY_BASIS_POINTS);
        merkleRoot = _merkleRoot;
    }

    /// @notice Mints the specified number of NFTs to the specified address.
    function mint(address to, uint256 count, bytes memory data) external payable {
        if (_tokenIdTracker + count > MAX_ELEMENTS) {
            revert MaxSupplyReached(MAX_ELEMENTS);
        }
        if (msg.value < count * MINT_PRICE) {
            revert InsufficientPayment();
        }
        _mintToken(to, count, data);
    }

    /// @notice Mints NFTs at a discount for whitelisted addresses.
    function discountMint(address to, uint256 count, bytes memory data, bytes32[] calldata proof) external payable {
        if (!isWhitelisted(to, proof)) {
            revert InvalidProof();
        }
        if (claimed.get(uint256(uint160(to)))) {
            revert AlreadyClaimed(to);
        }
        if (_tokenIdTracker + count > MAX_ELEMENTS) {
            revert MaxSupplyReached(MAX_ELEMENTS);
        }
        if (msg.value < ((count * MINT_PRICE) / DISCOUNT_DIVISOR)) {
            revert InsufficientPayment();
        }
        // Mark user as having claimed the discount
        claimed.set(uint256(uint160(to)));
        _mintToken(to, count, data);
    }

    /// @notice Checks if an address is whitelisted based on the Merkle proof.
    function isWhitelisted(address account, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    /// @notice Internal function to mint tokens.
    function _mintToken(address to, uint256 count, bytes memory data) internal {
        for (uint256 i = 0; i < count; i++) {
            uint256 id = _tokenIdTracker;
            _tokenIdTracker++;
            _safeMint(to, id, data);
        }
    }

    /// @notice Sets a new base URI for the token metadata.
    function setBaseURI(string memory newBaseTokenURI) external onlyOwner {
        baseTokenURI = newBaseTokenURI;
    }

    /// @notice Allows the owner to withdraw all ETH from the contract.
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
