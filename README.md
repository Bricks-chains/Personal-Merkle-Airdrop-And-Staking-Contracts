# Merkle Airdrop & staking contract
## Description
This project features an airdrop contract that uses Merkle trees to keep track of eligible users and distribute their tokens to them by proving that they are in fact part of the Merkle tree and are eligible for the airdrop. The token being sent to them is the Bricks token. The claim is a gasless transaction for the beneficiary since the gas is paid by another user calling claim on-behalf of the beneficiary who is eligible for the airdrop. Also, for the airdrop distribution to function properly, I used the EIP-191 standard for signed data alongside the EIP-712 standard for structured data by importing the OpenZeppelin EIP-712 contract.

Once a user is eligible for an airdrop, they receive the tokens, which can then be staked to earn interest over time. The interest rate is 9.46% APY, but I fragmented this interest into a percentage increase per second and used a linear growth model where interest increases linearly over time. The user can claim their entire accrued interest at any time and still have their staked balance continue to accumulate interest starting from the time the interest-claim action occurred. Users can also unstake a desired amount of their staked tokens and receive the interest for that unstaked amount simultaneously in a single transaction.

Let's dive deep into the project's core logic
------------------------------------------
## Features 
The features of this project are mainly for the airdrop contract and staking contract with both features functioning independently of each other.

### Airdrop contract features
- Merkle trees for tracking eligible users.
- Gasless airdrop distribution.
- Use of EIP-191 standard for signed data and EIP-712 standard for structured data.
### Staking contract features
- Stake mechanism that ensures users can stake any amount greater than zero and record the time of staking.
- Linear interest fragmented in percentage increase per second cumulatively rounding up to 9.46% APY.
- Separate claim mechanism where users can claim 100% of their accrued interest at any time and still have their staked balance accrue more interest starting from the time interest claim action took place.
- Unstake mechanism where users can unstake a desired amount of their staked token and get the interest for that unstake amount simultaneously all in one transaction.
## Project Architecture 
The project is divided into three main contracts.
- Bricks Token contract.
- Airdrop contract.
- Staking contract.

```
├── src
│   ├── AirdropStake.sol
│   └── BricksToken.sol
|   └── MerkleAirdrop.sol
├── script
|   |── target
|   |   ├── input.json
|   |   └── output.json
│   ├── DeployScript.s.sol
│   ├── GenerateInput.s.sol
│   ├── interactions.s.sol
│   ├── MakeMerkle.s.sol
├── test
│   ├── MerkleAirdrop.t.sol
|   └── StakingTest.t.sol
└── README.md
```
### Key Storages
#### key storages for the Airdrop contract
- `merkleRoot` - The root of the merkle tree. This is the end hash from combination of all leaf hashes.
- `s_hasClaimed` - Mapping of claimers to their claim status.
- `MESSAGE_TYPEHASH` - EIP-712 typehash for claim messages.
#### key storages for the Staking contract
- `INTEREST_RATE` - Interest per second (1e18 scaled).
- `PRECISION_FACTOR` - precision used for the interest rate.
- `s_userToAmountStaked` - Mapping of users to their staked amount.
- `s_userLastUpdatedTimestamp` - Mapping of users to their last updated time of activity causing a change in state like their balances or interest.
- `s_userToAccumulatedRewards` - Mapping of users to their accumulated rewards.

## Core Logic
Each contract has its own core math logic which is described in the respective contracts.

Airdrop contract logic
---
Claim requires:
1. A valid Merkle proof
2. A valid signature from the beneficiary (EIP-191 + EIP-712)

Signature validation:

```
(address recoveredSignature,,) = ECDSA.tryRecover(message, _v, _r, _s);
return recoveredSignature == signer;
```
This ensures the claim was authorized by the actual beneficiary.

Staking contract logic
---
In the staking contract there is a linear interest fragmented in percentage increase per second cumulatively rounding up to 9.46% APY. This was done by using the formula below
```
APY = (1 + (percentage increase per second)) ^ (time in seconds) - 1
```
Interest is computed using:
```
interest = P * R * T
```
where:
- `P` = principal
- `R` = interest rate per second
- `T` = time in seconds

Interest resets after claim or state-changing operations.

# Usage
Everything below will be an overview of how to interact with the project.
--------------------------

## Installation
To install the project use the following command.
```
git clone https://github.com/Bricks-chains/Personal-Merkle-Airdrop-And-Staking-Contracts
cd Personal-Merkle-Airdrop-And-Staking-Contracts
forge build
```
## Script
### GenerateInput
Creates the JSON input list of addresses + claim amounts and writes it to the target folder of the script folder.

### MakeMerkle
Generates a Merkle tree from the input file and writes the resulting root/output.json to the target folder.

### DeployScript
The deploy script contains helper functions to deploy the contracts.
To deploy the token, airdrop and staking contract you can use the following command.
```
forge script script/DeployScript.s.sol:DeployScript --rpc-url <YOUR_RPC_URL> --account <YOUR_KEYSTORE_NAME> --broadcast --verify --etherscan-api-key <YOUR_ETHERSCAN_API_KEY>
```

### Interactions

To interact with the airdrop contract you can use the following command
```
forge script script/interactions.s.sol:Interactions --rpc-url <YOUR_RPC_URL> --account <YOUR_KEYSTORE_NAME> --broadcast
```
To use the interaction contract the signature needed for the claim was generated on the CLI by using the following command
```
cast call <YOUR_AIRDROP_CONTRACT_ADDRESS> "getMessageHash(address, uint256)" <claimer address> <amount to claim> --rpc-url <YOUR_RPC_URL>
```
the claimer's address and amount to claim must be part of the Merkle tree.
To get the signature the claimer address must sign the message hash and the signature returned was used in the interactions file.
```
cast wallet sign --no-hash <MESSAGE_HASH> --account <YOUR_KEYSTORE_NAME>
```

## Testing
To test the contracts you can use this command
```
make test
```
The test for this project is in two different files one for the airdrop contract and one for the staking contract. 
```
|----------------------------+-----------------+-----------------+---------------+-----------------|
| src/AirdropStake.sol       | 96.30% (52/54)  | 95.83% (46/48)  | 75.00% (6/8)  | 100.00% (10/10) |
|----------------------------+-----------------+-----------------+---------------+-----------------|
| src/BricksToken.sol        | 100.00% (2/2)   | 100.00% (1/1)   | 100.00% (0/0) | 100.00% (1/1)   |
|----------------------------+-----------------+-----------------+---------------+-----------------|
| src/MerkleAirdrop.sol      | 69.57% (16/23)  | 76.19% (16/21)  | 0.00% (0/3)   | 66.67% (4/6)    |
|----------------------------+-----------------+-----------------+---------------+-----------------|
```
# Deployment
There is a Makefile that contains all the comands required to deploy the contracts on anvil and sepolia. This MakeFile was purposely created to make running long commands easier.

Note: When you want to deploy on Sepolia you need to use a private key stored using a keystore. Do not store your private key in a .env file.
------
#### Deploying Airdrop, Token And Staking Contract on Anvil
```
make deploy
```

#### Deploying Airdrop, Token And Staking Contract on Sepolia
```
make deploy ARGS='--network sepolia'
```

## References
- OpenZeppelin (ReentrancyGuard, ERC20, mocks)
- Foundry Book (scripting, testing patterns)
- foundry-devops tools

## License
MIT License
-----

# Author
Andrew Gideon (Bricks)
------
Twitter: [![Bricks Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/bricks_chains)
-----

