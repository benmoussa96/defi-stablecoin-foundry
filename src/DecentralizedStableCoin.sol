// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Ghaieth BEN MOUSSA (The Chain Genius)
 * @notice This smart contract is the tokenized implementation of our DSCEngine stablecoin logic.
 * @dev Collateral: ETH or BTC, Minting: Algorithmic, Stability: Pegged to USD
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin_InvalidAmount();
    error DecentralizedStableCoin_InsufficientBalance();
    error DecentralizedStableCoin_InvalidAddress();

    constructor(address _initialOwner) ERC20("DecentralizedStableCoin", "DSC") Ownable(_initialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert DecentralizedStableCoin_InvalidAmount();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin_InsufficientBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin_InvalidAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin_InvalidAmount();
        }

        _mint(_to, _amount);
        return true;
    }
}
