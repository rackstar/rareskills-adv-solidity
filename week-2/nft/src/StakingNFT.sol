// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {StakingRewardToken} from "./StakingRewardToken.sol";

/// @title StakingNFT Contract
/// @notice This contract allows users to stake their ERC721 NFTs to earn ERC20 rewards.
contract StakingNFT is IERC721Receiver, Ownable2Step {
    StakingRewardToken public rewardToken;
    IERC721 public stakingToken;

    uint40 public lastRewardTimestamp;
    uint40 public deployTimestamp;
    uint128 public constant ONE_DAY = 1 days;

    uint256 public accRewardPerToken;
    uint256 public totalSupply;
    uint256 public rewardRate = 10 ether; // 10 tokens per 24 hours

    mapping(uint256 tokenId => address staker) public stakes;
    mapping(address user => uint256 rewardDebtPerToken) public userRewardDebt;
    mapping(address user => uint256 stakedTokens) public userStakedTokens;

    constructor(address _rewardToken, IERC721 _stakingToken) Ownable(msg.sender) {
        rewardToken = StakingRewardToken(_rewardToken);
        stakingToken = _stakingToken;
        lastRewardTimestamp = uint40(block.timestamp);
        deployTimestamp = uint40(block.timestamp);
    }

    error NotOwner();
    error NoRewardsToClaim();
    error WrongNFT(address caller);

    /// @notice Handles the staking of the NFT
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        _updatePool();

        if (msg.sender != address(stakingToken)) {
            revert WrongNFT(msg.sender);
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), tokenId);
        stakes[tokenId] = from;

        totalSupply++;
        userStakedTokens[msg.sender]++;

        uint256 daysElapsed = block.timestamp - deployTimestamp / ONE_DAY;
        userRewardDebt[msg.sender] += daysElapsed * accRewardPerToken;
        return this.onERC721Received.selector;
    }

    /// @notice Withdraws a staked NFT and claims rewards.
    function withdraw(uint256 tokenId) external {
        _updatePool();

        if (stakes[tokenId] != msg.sender) {
            revert NotOwner();
        }

        // Calculate and update rewards before adjusting values for withdrawal
        uint256 reward = _earned(msg.sender);

        delete stakes[tokenId];
        totalSupply--;
        userStakedTokens[msg.sender]--;

        stakingToken.safeTransferFrom(address(this), msg.sender, tokenId);
        rewardToken.mint(msg.sender, reward);

        uint256 daysElapsed = block.timestamp - deployTimestamp / ONE_DAY;
        userRewardDebt[msg.sender] = userStakedTokens[msg.sender] * accRewardPerToken * daysElapsed;
    }

    /// @notice Claims the earned rewards without withdrawing staked tokens.
    function claim() external {
        _updatePool();

        uint256 reward = _earned(msg.sender);
        if (reward == 0) {
            revert NoRewardsToClaim();
        }

        rewardToken.mint(msg.sender, reward);

        // Update the user's reward debt after claiming rewards
        uint256 daysElapsed = block.timestamp - deployTimestamp / ONE_DAY;
        userRewardDebt[msg.sender] = userStakedTokens[msg.sender] * accRewardPerToken * daysElapsed;
    }

    /// @notice Updates the reward variables.
    function _updatePool() internal {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        uint256 tokenSupplyStaked = totalSupply;
        if (tokenSupplyStaked == 0) {
            lastRewardTimestamp = uint40(block.timestamp);
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
        uint256 rewardToMint = (timeElapsed * rewardRate) / ONE_DAY;
        accRewardPerToken += (rewardToMint * 1 ether) / tokenSupplyStaked;
        lastRewardTimestamp = uint40(block.timestamp);
    }

    /// @notice Calculates the earned rewards for an account.
    function _earned(address account) internal view returns (uint256) {
        uint256 stakedTokens = userStakedTokens[account];
        uint256 daysElapsed = block.timestamp - deployTimestamp / ONE_DAY;
        return ((stakedTokens * accRewardPerToken * daysElapsed) - userRewardDebt[account]) / 1 ether;
    }

    /// @notice Sets the reward rate.
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }
}
