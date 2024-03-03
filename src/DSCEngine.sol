// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DSCEngine
 * @author Ghaieth BEN MOUSSA (The Chain Genius)
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system. Our stablecoin is only different from DAI in that it has no governance, no fees, and is only backed by WETH and WBTC.
 * @dev The system is designed to be as minimal as possible and be pegged at 1 token == $1 at all times.
 * Our DSC system should always be "overcollateralized". At no point should the value of all collateral < the $ backed value of all the DSC.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 */
contract DSCEngine is ReentrancyGuard {
    // Errors       //
    error DSCEngine_InvalidAmount();
    error DSCEngine_TokensAndPriceFeedsMustBeSameLength();
    error DSCEngine_TokenNotAllowed();
    error DSCEngine_TransferFailed();

    // Varaiables   //
    DecentralizedStableCoin private immutable i_DSCAddress;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // Events       //
    event collateralDEposited(address indexed user, address indexed token, uint256 indexed amount);

    // Modifiers    //
    modifier greaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine_InvalidAmount();
        }
        _;
    }

    modifier isTokenAllowed(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_TokenNotAllowed();
        }
        _;
    }

    // Functions    //
    constructor(address DSCAddress, address[] memory tokenAddresses, address[] memory priceFeedAddresses) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokensAndPriceFeedsMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
    }

    function depositCollateralAndMintDSC() external {}

    function redeemCollateralForDSC() external {}

    /**
     * @notice Follows CEI pattern
     * @param collateralAddress The address of the token to deposit as collateral
     * @param collateralAmount The amount of collateral to deposit
     */
    function depositCollateral(address collateralAddress, uint256 collateralAmount)
        external
        greaterThanZero(collateralAmount)
        isTokenAllowed(collateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][collateralAddress] += collateralAmount;
        emit collateralDEposited(msg.sender, collateralAddress, collateralAmount);

        bool success = IERC20(collateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    function redeemCollateral() external {}

    function mintDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
