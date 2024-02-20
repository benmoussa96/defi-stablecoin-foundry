// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
@title DecentralizedStableCoin
@author Ghaieth BEN MOUSSA (The Chain Genius)
@notice This smart contract is the tokenized implementation of our DSCEngine stablecoin logic.
@dev Collateral: ETH or BTC, Minting: Algorithmic, Stability: Pegged to USD
 */

contract DecentralizedStableCoin is ERC20Burnable{
}
