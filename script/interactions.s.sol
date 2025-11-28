// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract ClaimAirdrop is Script {
    error ClaimAirdrop__InvalidSignatureLength();

    address public constant CLAIMER_ADDRESS =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    bytes32 public constant MERKLE_PROOF_1 =
        0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad;
    bytes32 public constant MERKLE_PROOF_2 =
        0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    uint256 public constant AMOUNT_TO_CLAIM = 25e18;
    bytes private SIGNATURE =
        hex"de7950108fab1dcdb182e97bb2cc3c265cb2af94f7ed8d93174edcd29d4ca3b62d63d551090d6195a269016aa2ad6b849c2daae0e0b38a2c7a9733647a5910421b";

    bytes32[] public merkleProof = [MERKLE_PROOF_1, MERKLE_PROOF_2];

    function claimAirdrop(address merkleAirdrop) public {
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(merkleAirdrop).claim(
            CLAIMER_ADDRESS,
            AMOUNT_TO_CLAIM,
            merkleProof,
            v,
            r,
            s
        );
        vm.stopBroadcast();
    }

    function splitSignature(
        bytes memory signature
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (signature.length != 65) {
            revert ClaimAirdrop__InvalidSignatureLength();
        }
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }

    function run() public {
        address mostRecent = DevOpsTools.get_most_recent_deployment(
            "MerkleAirdrop",
            block.chainid
        );

        claimAirdrop(mostRecent);
    }
}
