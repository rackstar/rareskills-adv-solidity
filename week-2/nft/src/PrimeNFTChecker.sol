// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title PrimeNFTChecker
contract PrimeNFTChecker is Ownable2Step {
    ERC721Enumerable public nftCollection;

    constructor(address _nftCollection) Ownable(msg.sender) {
        nftCollection = ERC721Enumerable(_nftCollection);
    }

    /// @notice Checks if a number is prime.
    function _isPrime(uint256 number) internal pure returns (bool) {
        // 1 is not prime
        if (number < 2) return false;

        // Even numbers are not prime
        if ((number & 1) == 0) return false;

        // 2 and 3 are prime
        if (number < 4) return true;

        for (uint256 i = 5; i * i <= number; i++) {
            if (number % i == 0) {
                return false;
            }
        }

        return true;
    }

    /// @notice Returns the count of prime-numbered token IDs owned by the specified address.
    function countPrimeTokens(address owner) external view returns (uint256) {
        uint256 balance = nftCollection.balanceOf(owner);
        uint256 primeCount = 0;

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = nftCollection.tokenOfOwnerByIndex(owner, i);
            if (_isPrime(tokenId)) primeCount++;
        }

        return primeCount;
    }
}
