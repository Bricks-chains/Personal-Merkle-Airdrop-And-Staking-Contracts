// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BricksToken} from "./BricksToken.sol";

/**
 * @title AirdropStake
 * @author Andrew Gideon(Bricks)
 * @notice This contract allows users to stake BRK tokens received from an airdrop and earn interest over time.
 * @dev The contract uses a linear interest model and keeps track of each user's staked amount and accumulated rewards.
 * for the unstaking mechanism, users can unstake a portion of their staked tokens along with the proportional rewards earned all in one transaction.
 * The interest rate is defined as a constant and is applied per second. The accrued rewards can be claimed separately using the claimInterest function.
 * All token transfers are handled using the BricksToken contract.
 */
contract AirdropStake {
    error AirdropStake__CantStakeLessThanZero();
    error AirdropStake__SakingFailed();
    error AirdropStake__NoStakeNoRewardsToClaim();
    error AirdropStake__YouHaveNothingStaked();
    error AirdropStake__UnstakeAmountGreaterThanStaked();
    error AirdropStake__NoInterestAccruedForClaim();

    uint256 private constant INTEREST_RATE = 3e9; // the interest rate per second for 1e18 offset
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userToAmountStaked;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    mapping(address => uint256) private s_userToAccumulatedRewards;
    BricksToken private immutable i_brk;

    // Events
    event staked(address user, uint256 stakeAmount);
    event InterestClaimed(address user, uint256 interest);
    event TokenUnstaked(address user, uint256 interest, uint256 unstakeAmount);

    constructor(address _bricksAddress) {
        i_brk = BricksToken(_bricksAddress);
    }

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert AirdropStake__CantStakeLessThanZero();
        }
        _;
    }

    /**
     * @param _amount The amount a user is willing to stake
     * @notice Stakes BRK tokens and updates the user's accumulated interest.
     * updates the state of the user's staked amount and transfers the tokens from the user to the contract.
     */
    function stake(uint256 _amount) external moreThanZero(_amount) {
        _updateInterest(msg.sender);
        s_userToAmountStaked[msg.sender] += _amount;
        (bool success) = i_brk.transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert AirdropStake__SakingFailed();
        }
        emit staked(msg.sender, _amount);
    }

    /**
     * @param _amount The amount a user is willing to unstake
     * @notice Unstakes BRK tokens along with proportional rewards earned.
     * updates the state of the user's staked amount and accumulated rewards, and transfers the unstaked tokens and rewards back
     * to the user in one transaction.
     */
    function unstake(uint256 _amount) external moreThanZero(_amount) {
        if (s_userToAmountStaked[msg.sender] == 0) {
            revert AirdropStake__YouHaveNothingStaked();
        }
        if (_amount > s_userToAmountStaked[msg.sender]) {
            revert AirdropStake__UnstakeAmountGreaterThanStaked();
        }
        _updateInterest(msg.sender);

        uint256 totalRewards = s_userToAccumulatedRewards[msg.sender];
        uint256 reward = (totalRewards * _amount) / s_userToAmountStaked[msg.sender];
        uint256 amountPlusReward = (_amount + reward);
        s_userToAmountStaked[msg.sender] -= _amount;
        s_userToAccumulatedRewards[msg.sender] -= reward;
        i_brk.transfer(msg.sender, amountPlusReward);
        emit TokenUnstaked(msg.sender, reward, _amount);
    }

    /**
     * @notice Claims accumulated interest rewards for the user.
     * updates the user's accumulated rewards and transfers them to the user.
     * This function can only be called if the user has staked tokens previously.
     * The reward is the total accumulated rewards up to the point of claiming.
     */
    function claimInterest() external {
        if (s_userToAmountStaked[msg.sender] == 0) {
            revert AirdropStake__NoStakeNoRewardsToClaim();
        }
        _updateInterest(msg.sender);
        if (s_userToAccumulatedRewards[msg.sender] == 0) {
            revert AirdropStake__NoInterestAccruedForClaim();
        }
        uint256 reward = s_userToAccumulatedRewards[msg.sender];
        s_userToAccumulatedRewards[msg.sender] = 0;
        i_brk.transfer(msg.sender, reward);
        emit InterestClaimed(msg.sender, reward);
    }

    /**
     * @param _user The address of the user whose interest needs to be updated
     * @notice Updates the accumulated interest for a user based on the time elapsed since the last update.
     * calculates the interest earned since the last update and adds it to the user's accumulated rewards.
     * updates the last updated timestamp to the current block timestamp.
     */
    function _updateInterest(address _user) internal {
        uint256 amount = s_userToAmountStaked[_user];
        if (s_userToAmountStaked[_user] != 0) {
            uint256 reward = (amount * _calculateAccumulatedInterestPerUser(_user)) / PRECISION_FACTOR;
            s_userToAccumulatedRewards[_user] += reward;
            s_userLastUpdatedTimestamp[_user] = block.timestamp;
        } else {
            s_userToAccumulatedRewards[_user] += 0;
            s_userLastUpdatedTimestamp[_user] = block.timestamp;
        }
    }

    /**
     * @param _user The address of the user for whom to calculate accumulated interest
     * @return The accumulated interest for the user based on the time elapsed since the last update
     * @notice Calculates the accumulated interest for a user based on the time elapsed since their last update.
     * uses a linear interest model to compute the interest earned over time.
     */
    function _calculateAccumulatedInterestPerUser(address _user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        uint256 linearInterest = (INTEREST_RATE * timeElapsed);
        return linearInterest;
    }

    function getstakedBalance(address _user) external view returns (uint256) {
        return s_userToAmountStaked[_user];
    }

    function getRewardsBalance(address _user) external view returns (uint256) {
        uint256 amount = s_userToAccumulatedRewards[_user];
        return amount;
    }

    function getlastUpdatedTimestamp(address _user) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[_user];
    }
}
