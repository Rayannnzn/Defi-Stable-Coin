<div align="center">

# 🪙 DEFI-STABLE-COIN  

*Empowering Stable, Secure, Decentralized Finance Innovation*  

![Last Commit](https://img.shields.io/github/last-commit/Rayannnzn/Defi-Stable-Coin?style=flat&color=blue) ![Solidity](https://img.shields.io/badge/Solidity-96.8%25-blue?logo=solidity) ![Languages](https://img.shields.io/github/languages/count/Rayannnzn/Defi-Stable-Coin?color=blue)  


---

**Built with the tools and technologies:**  

![Foundry](https://img.shields.io/badge/Foundry-Ethereum-blue?style=for-the-badge) 

![Markdown](https://img.shields.io/badge/Markdown-000000?style=for-the-badge&logo=markdown) ![TOML](https://img.shields.io/badge/TOML-orange?style=for-the-badge) ![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white) 


 

</div>

---

## 📑 Table of Contents  

- [Overview](#overview)  
- [Getting Started](#getting-started)  
  - [Prerequisites](#prerequisites)  
- [Smart Contracts](#-smart-contracts)  
- [Testing Infrastructure](#-testing-infrastructure)  
- [Foundry Settings](#️-foundry-settings)  
- [Core Concepts](#-core-concepts-tested)  
- [Resources](#-resources)  
- [Connect](#-connect)  

---

# 🔹 Overview  

This project is a **Foundry-based invariant testing setup** for a decentralized stablecoin protocol:  

- **DSCEngine** → Core logic for deposits, redemptions, and minting.  
- **DecentralizedStableCoin (DSC)** → ERC20-compliant stablecoin, always backed by collateral.  
- **Mocks (WETH & WBTC)** → For fuzzing and arbitrary testing.  
- **HelperConfig & DeployDSC** → Deployment and configuration utilities.  

The system is rigorously tested with **fuzzing + stateful invariant testing** to ensure **solvency and safety** at all times.  

---

## 🔹 Smart Contracts
⚙️ DSCEngine

Handles collateral deposits & withdrawals.

Manages DSC minting/burning.

Enforces system solvency rules.

## 💵 DecentralizedStableCoin (DSC)

ERC20-compliant stablecoin.

Minted when collateral is locked, burned on repayment.

Always fully collateralized.

## 🧪 Collateral Tokens (Mocks)

ERC20Mock for WETH & WBTC in tests.

Allows arbitrary minting for fuzzing.

## 🛠️ HelperConfig & DeployDSC

Provides token addresses & config.

Deployment scripts for DSCEngine + DSC.

## 🧪 Testing Infrastructure

🛠 Foundry (forge-std)

Test → Base for unit/invariant tests.

StdInvariant → Fuzzing harness & utilities.

console → Debugging logs.

## 🎯 Handler Contract

Defines stateful user actions for fuzzing:

depositCollateral

redeemCollateral

Ensures proper minting, approvals, and system safety.

## 🔒 Invariant Contract

Invariant: “The total USD value of collateral in the system must always be ≥ DSC supply.”

Random sequences of actions are tested.

Guarantees protocol remains solvent under arbitrary behavior.

## ⚙️ Foundry Settings

runs → Number of fuzzing campaigns.

depth → Actions per campaign.

fails_on_revert → Treat reverts as safety checks.

## 📚 Core Concepts Tested

Collateralization → DSC must always be backed.

Reverts as Safety → Prevents over-minting & over-withdrawals.

Stateful Fuzzing → Randomized multi-step testing.

Invariant Properties → Solvency is never broken.





## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
