// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BricksToken} from "../src/BricksToken.sol";
import {DeployScript} from "script/DeployScript.s.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {AirdropStake} from "../src/AirdropStake.sol";

contract MerkleAirdropTest is Test, ZkSyncChainChecker {
    BricksToken public token;
    MerkleAirdrop public merkleAirdrop;
    AirdropStake public staking;
    DeployScript public deployer;
    address public user;
    uint256 public userKey;
    address public payee;
    uint256 public constant AMOUNT_TO_CLAIM = 25e18;
    uint256 public constant AMOUNT_TO_SEND = AMOUNT_TO_CLAIM * 4;

    bytes32 public merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    bytes32 proof1 = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proof2 = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public merkleProof = [proof1, proof2];

    function setUp() public {
        if (isZkSyncChain()) {
            deployer = new DeployScript();
            (token, merkleAirdrop, staking) = deployer.deployToken();
        } else {
            token = new BricksToken();
            merkleAirdrop = new MerkleAirdrop(merkleRoot, token);
            token.mint(token.owner(), AMOUNT_TO_SEND);
            token.transfer(address(merkleAirdrop), AMOUNT_TO_SEND);
            (user, userKey) = makeAddrAndKey("user");
            payee = makeAddr("payee");
        }
    }

    function testClaim() public {
        uint256 initialBalance = token.balanceOf(user);
        console2.log("Initial user Balance:", initialBalance / 1e18);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, merkleAirdrop.getMessageHash(user, AMOUNT_TO_CLAIM));

        vm.prank(payee);
        merkleAirdrop.claim(user, AMOUNT_TO_CLAIM, merkleProof, v, r, s);
        uint256 endingBalance = token.balanceOf(user);
        console2.log("User Ending Balance:", endingBalance / 1e18);

        assertEq(endingBalance - initialBalance, AMOUNT_TO_CLAIM);
    }
}
