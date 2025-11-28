// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BricksToken} from "src/BricksToken.sol";
import {AirdropStake} from "src/AirdropStake.sol";
import {Test, console2} from "forge-std/Test.sol";

contract StakingTest is Test {
    BricksToken private bricks;
    AirdropStake private airdropStake;
    address private user = makeAddr("user");

    function setUp() public {
        bricks = new BricksToken();
        airdropStake = new AirdropStake(address(bricks));
        bricks.mint(user, 1000e18);
        bricks.mint(address(airdropStake), 10000e18);
        vm.prank(user);
        bricks.approve(address(airdropStake), type(uint256).max);
    }

    modifier stake() {
        vm.prank(user);
        airdropStake.stake(500e18);
        _;
    }

    //////////////////
    //  Test Stake  //
    //////////////////
    function testStake() public stake {
        uint256 stakedAmount = airdropStake.getstakedBalance(user);
        assertEq(stakedAmount, 500e18);
    }

    function testStakeZeroReverts() public {
        vm.prank(user);
        vm.expectRevert(AirdropStake.AirdropStake__CantStakeLessThanZero.selector);
        airdropStake.stake(0);
    }

    function testStakingUpdatesLastUpdatedTimestamp() public stake {
        uint256 lastUpdatedTimestamp = airdropStake.getlastUpdatedTimestamp(user);
        assertEq(lastUpdatedTimestamp, block.timestamp);
    }

    function testUserContractActuallyGetsStakedFunds() public stake {
        uint256 contractBalance = bricks.balanceOf(address(airdropStake));
        assertEq(contractBalance, 10500e18);
    }

    function testEventEmittedOnStake() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit AirdropStake.staked(user, 500e18);
        airdropStake.stake(500e18);
    }

    ////////////////////////
    // Test ClaimInterest //
    ////////////////////////
    function testClaimInterest() public stake {
        vm.warp(block.timestamp + 365 days); // Simulate 365 days passing

        vm.prank(user);
        airdropStake.stake(500e18);
        uint256 rewardBefore = airdropStake.getRewardsBalance(user);
        vm.prank(user);
        airdropStake.claimInterest();
        uint256 rewardAfter = airdropStake.getRewardsBalance(user);
        assertEq(rewardAfter, 0);
        console2.log("Accumulated Rewards after 365 days:", rewardBefore);
        assertEq(rewardBefore, 47304000000000000000); // ~9.46% of 500e18 for 365 days
    }

    function testCantClaimInterestWithoutStake() public {
        vm.prank(user);
        vm.expectRevert(AirdropStake.AirdropStake__NoStakeNoRewardsToClaim.selector);
        airdropStake.claimInterest();
    }

    function testClaimRevertsIfNoInterestAccrued() public stake {
        vm.prank(user);
        vm.expectRevert(AirdropStake.AirdropStake__NoInterestAccruedForClaim.selector);
        airdropStake.claimInterest();
    }

    function testRewardIsStillAccurateForMultipleClaims() public stake {
        vm.warp(block.timestamp + 365 days); // Simulate 365 days passing

        vm.prank(user);
        airdropStake.claimInterest();
        uint256 rewardAfterFirstClaim = airdropStake.getRewardsBalance(user);
        assertEq(rewardAfterFirstClaim, 0);

        vm.warp(block.timestamp + 365 days); // Simulate another 365 days passing

        vm.prank(user);
        airdropStake.claimInterest();
        uint256 rewardAfterSecondClaim = airdropStake.getRewardsBalance(user);
        assertEq(rewardAfterSecondClaim, 0);
    }

    function testUserGetsReward() public stake {
        vm.warp(block.timestamp + 365 days);
        uint256 userBalanceMinusStake = bricks.balanceOf(user);
        console2.log("user balance minus stake:", userBalanceMinusStake);

        vm.prank(user);
        airdropStake.claimInterest();
        uint256 totalUserBalanceAFterClaim = bricks.balanceOf(user);
        assertEq(totalUserBalanceAFterClaim, userBalanceMinusStake + 47304000000000000000);
    }

    ///////////////////
    // Test Unstake //
    //////////////////
    function testUnstakeWorks() public stake {
        vm.warp(block.timestamp + 365 days);

        vm.prank(user);
        airdropStake.unstake(500e18);
        uint256 userRewardsAfterUnstake = airdropStake.getRewardsBalance(user);
        uint256 userStakeAfterUnstake = airdropStake.getstakedBalance(user);
        assertEq(userRewardsAfterUnstake, 0);
        assertEq(userStakeAfterUnstake, 0);

        uint256 userTotalBalanceInWallet = bricks.balanceOf(user);
        assertEq(userTotalBalanceInWallet, 1000e18 + 47304000000000000000);
    }

    function testUserCantUnstakeWithoutStakingRewards() public {
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(AirdropStake.AirdropStake__YouHaveNothingStaked.selector);
        airdropStake.unstake(500e18);
    }

    function testRevertIfUnstakeAmountIsMoreThanStake() public stake {
        vm.warp(block.timestamp + 365 days);

        vm.prank(user);
        vm.expectRevert(AirdropStake.AirdropStake__UnstakeAmountGreaterThanStaked.selector);
        airdropStake.unstake(1000e18);
    }
}
