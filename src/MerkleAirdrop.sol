// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    struct AirdropMessage {
        address claimer;
        uint256 amount;
    }

    // address[] private claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_AirdropToken;
    mapping(address claimer => bool hasClaimed) private s_hasClaimed;
    bytes32 MESSAGE_TYPEHASH = keccak256("AidropMessage(address claimer, uint256 amount)");

    event Claim(address indexed claimer, uint256 amount);

    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = _merkleRoot;
        i_AirdropToken = _airdropToken;
    }

    function claim(address claimer, uint256 amount, bytes32[] calldata merkleProof, uint8 _v, bytes32 _r, bytes32 _s)
        external
    {
        // Implementation for claiming tokens using the Merkle proof
        // This is a placeholder for the actual logic
        if (s_hasClaimed[claimer] == true) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        if (!_isSignature(getMessageHash(claimer, amount), claimer, _v, _r, _s)) {
            revert MerkleAirdrop__InvalidSignature();
        }
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        s_hasClaimed[claimer] = true;
        emit Claim(claimer, amount);
        IERC20(i_AirdropToken).safeTransfer(claimer, amount);
    }

    function getMessageHash(address _claimer, uint256 _amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropMessage({claimer: _claimer, amount: _amount})))
        );
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_AirdropToken;
    }

    function _isSignature(bytes32 message, address signer, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        (address recoveredSignature,,) = ECDSA.tryRecover(message, _v, _r, _s);
        return recoveredSignature == signer;
    }
}
