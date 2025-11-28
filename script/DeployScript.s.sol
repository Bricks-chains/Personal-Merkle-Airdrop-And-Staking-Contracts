// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BricksToken} from "../src/BricksToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {AirdropStake} from "../src/AirdropStake.sol";
import {Script} from "forge-std/Script.sol";

contract DeployScript is Script {
    bytes32 private merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public AMOUNT_TO_TRANSFER = 25e18 * 4;

    function run() external returns (BricksToken, MerkleAirdrop, AirdropStake) {
        return deployToken();
    }

    function deployToken() public returns (BricksToken, MerkleAirdrop, AirdropStake) {
        vm.startBroadcast();
        BricksToken token = new BricksToken();
        MerkleAirdrop merkleairdrop = new MerkleAirdrop(merkleRoot, IERC20(address(token)));
        AirdropStake staking = new AirdropStake(address(token));
        token.mint(address(merkleairdrop), AMOUNT_TO_TRANSFER);
        token.mint(address(staking), AMOUNT_TO_TRANSFER);
        vm.stopBroadcast();

        return (token, merkleairdrop, staking);
    }
}
