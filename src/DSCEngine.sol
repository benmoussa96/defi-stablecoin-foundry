// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
@title DSCEngine
@author Ghaieth BEN MOUSSA (The Chain Genius)
@notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
@notice This contract is based on the MakerDAO DSS system. Our stablecoin is only different from DAI in that it has no governance, no fees, and is only backed by WETH and WBTC.
@dev The system is designed to be as minimal as possible and be pegged at 1 token == $1 at all times.
Our DSC system should always be "overcollateralized". At no point should the value of all collateral < the $ backed value of all the DSC.
This is a stablecoin with the properties:
- Exogenously Collateralized
- Dollar Pegged
- Algorithmically Stable
*/

contract DSCEngine {
    function depositCollateralAndMintDSC() external {}
    
    function redeemCollateralForDSC() external {}

    function depositCollateral() external {}
    
    function redeemCollateral() external {}

    function mintDSC() external {}
    
    function burnDSC() external {}
    
    function liquidate() external {}

    function getHealthFactor() external view {}
}