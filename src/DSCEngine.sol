// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine_MintFailed();
    error DSCEngine_HeathFactorBroken(uint256 userHealthFactor);

    // Varaiables   //
    uint256 private constant PRECISION = 1e18;
    uint256 private constant FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralized
    uint256 private constant THRESHOLD_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    DecentralizedStableCoin private immutable i_DSC;

    address[] private s_collateralTokens;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amount) private s_DSCMinted;

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

    // Constructor    //
    constructor(address DSCAddress, address[] memory priceFeedAddresses, address[] memory tokenAddresses) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokensAndPriceFeedsMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_DSC = DecentralizedStableCoin(DSCAddress);
    }

    // External Functions    //

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

    /**
     *
     * @param amountDSCToMint The amount of DecentralizedStableCoint to mint
     */
    function mintDSC(uint256 amountDSCToMint) external greaterThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;

        _checkHealthFactor(msg.sender);

        bool isMintSuccess = i_DSC.mint(msg.sender, amountDSCToMint);
        if (!isMintSuccess) {
            revert DSCEngine_MintFailed();
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    // Private & Internal View Functions    //
    function _getAccountInfo(address user) private view returns (uint256 totalDSCMinted, uint256 collateralUSD) {
        totalDSCMinted = s_DSCMinted[user];
        collateralUSD = getAccountCollateralUSD(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralUSD) = _getAccountInfo(user);
        uint256 collateralAdjustedForThreshold = (collateralUSD * LIQUIDATION_THRESHOLD) / THRESHOLD_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _checkHealthFactor(address user) private view {
        uint256 userHealthFactor = _healthFactor((user));
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_HeathFactorBroken(userHealthFactor);
        }
    }

    // External & Public View Functions    //
    function getAccountCollateralUSD(address user) public view returns (uint256 collateralUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            collateralUSD += getUSDValue(token, amount);
        }

        return collateralUSD;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * FEED_PRECISION) * amount) / PRECISION;
    }
}
