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
    // ERRORS       //
    error DSCEngine__InvalidAmount();
    error DSCEngine__CollateralTokensAndPriceFeedsMustBeSameLength();
    error DSCEngine__CollateralNotSupported(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HeathFactorOk();
    error DSCEngine__HeathFactorNotImproved();
    error DSCEngine__HeathFactorBroken(uint256 userHealthFactor);

    // EVENTS       //
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    // VARIABLES   //
    uint256 private constant PRECISION = 1e18;
    uint256 private constant FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    DecentralizedStableCoin private immutable i_DSC;

    address[] private s_collateralTokens;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_CollateralDeposited;
    mapping(address user => uint256 amount) private s_DSCMinted;

    // MODIFIERS    //
    modifier greaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__InvalidAmount();
        }
        _;
    }

    modifier isCollateralSupported(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__CollateralNotSupported(token);
        }
        _;
    }

    // CONSTRUCTOR    //
    constructor(address DSCAddress, address[] memory priceFeedAddresses, address[] memory collateralAddresses) {
        if (collateralAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__CollateralTokensAndPriceFeedsMustBeSameLength();
        }

        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(collateralAddresses[i]);
        }

        i_DSC = DecentralizedStableCoin(DSCAddress);
    }

    // EXTERNAL FUNCTIONS    //
    /**
     * @notice This function will deposite your collateral & mint DSC in one transaction
     * @notice Follows CEI pattern
     * @param collateralAddress The address of the token to deposit as collateral
     * @param collateralAmount The amount of collateral to deposit
     * @param amountDSCToMint The amount of of DecentralizedStableCoin to mint
     */
    function depositCollateralAndMintDSC(address collateralAddress, uint256 collateralAmount, uint256 amountDSCToMint)
        external
    {
        depositCollateral(collateralAddress, collateralAmount);
        mintDSC(amountDSCToMint);
    }

    /**
     * @notice This function will redeem your collateral & burn DSC in one transaction
     * @notice Follows CEI pattern
     * @param collateralAddress The address of the token to deposit as collateral
     * @param collateralAmount The amount of collateral to deposit
     * @param amountDSCToBurn The amount of of DecentralizedStableCoin to burn
     */
    function redeemCollateralAndBurnDSC(address collateralAddress, uint256 collateralAmount, uint256 amountDSCToBurn)
        external
    {
        burnDSC(amountDSCToBurn);
        redeemCollateral(collateralAddress, collateralAmount);
        _checkHealthFactor(msg.sender);
    }

    /**
     * @notice Follows CEI: Checks, Effects, Interactions
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the users funds
     * @notice This function assumes the protocol will be roughly 200% overcollateralized in order for this to work
     * If the protocol were collaterlized at 100% or less, we wouldn't be able to incentivize the liquidators
     * Example: if the price of the collateral plummeted before anyone could be liquidated
     * @param collateralAddress The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want  to burn to improve the users healt factor
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        greaterThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HeathFactorOk();
        }

        uint256 collateralToLiquidate = getCollateralValueInUSD(collateralAddress, debtToCover);
        uint256 bonusCollateral = (collateralToLiquidate * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateral = collateralToLiquidate + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateralAddress, totalCollateral);
        _burnDSC(user, msg.sender, debtToCover);

        if (_healthFactor(user) <= startingHealthFactor) {
            revert DSCEngine__HeathFactorNotImproved();
        }
    }

    // PUBLIC FUNCTIONS
    /**
     * @notice Follows CEI pattern
     * @param collateralAddress The address of the token to deposit as collateral
     * @param collateralAmount The amount of collateral to deposit
     */
    function depositCollateral(address collateralAddress, uint256 collateralAmount)
        public
        greaterThanZero(collateralAmount)
        isCollateralSupported(collateralAddress)
        nonReentrant
    {
        s_CollateralDeposited[msg.sender][collateralAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralAddress, collateralAmount);

        bool success = IERC20(collateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @param amountDSCToMint The amount of DecentralizedStableCoint to mint
     */
    function mintDSC(uint256 amountDSCToMint) public greaterThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;

        _checkHealthFactor(msg.sender);

        bool isMintSuccess = i_DSC.mint(msg.sender, amountDSCToMint);
        
        if (!isMintSuccess) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @notice Follows CEI pattern
     * @param collateralAddress The address of the token to redeem as collateral
     * @param collateralAmount The amount of collateral to redeem
     */
    function redeemCollateral(address collateralAddress, uint256 collateralAmount)
        private
        greaterThanZero(collateralAmount)
        isCollateralSupported(collateralAddress)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, collateralAddress, collateralAmount);
        _checkHealthFactor(msg.sender);
    }

    /**
     * @param amountDSCToBurn The amount of DecentralizedStableCoint to burn
     */
    function burnDSC(uint256 amountDSCToBurn) private greaterThanZero(amountDSCToBurn) nonReentrant {
        _burnDSC(msg.sender, msg.sender, amountDSCToBurn);
    }

    // PRIVATE & INTERNAL VIEW FUNCTIONS    //
    /**
     * @param from The address of the original holder of the collateral
     * @param to The address of the user who will receive the collateral
     * @param collateralAddress The address of the token to redeem as collateral
     * @param collateralAmount The amount of collateral to redeem
     */
    function _redeemCollateral(address from, address to, address collateralAddress, uint256 collateralAmount) private {
        s_CollateralDeposited[from][collateralAddress] -= collateralAmount;
        emit CollateralRedeemed(from, to, collateralAddress, collateralAmount);

        bool success = IERC20(collateralAddress).transfer(to, collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @param amountDSCToBurn The amount of DecentralizedStableCoint to burn
     */
    function _burnDSC(address from, address to, uint256 amountDSCToBurn) private {
        s_DSCMinted[from] -= amountDSCToBurn;
        bool success = i_DSC.transferFrom(to, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        i_DSC.burn(amountDSCToBurn);
    }

    function _getAccountInfo(address user) private view returns (uint256 totalDSCMinted, uint256 collateralUSD) {
        totalDSCMinted = s_DSCMinted[user];
        collateralUSD = getAccountCollateralUSD(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralUSD) = _getAccountInfo(user);
        if (totalDSCMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _checkHealthFactor(address user) private view {
        uint256 userHealthFactor = _healthFactor((user));
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HeathFactorBroken(userHealthFactor);
        }
    }

    // EXTERNAL & PUBLIC VIEW FUNCTIONS    //
    function getAccountCollateralUSD(address user) public view returns (uint256 collateralUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 collateralAmount = s_CollateralDeposited[user][token];
            collateralUSD += getCollateralValueInUSD(token, collateralAmount);
        }

        return collateralUSD;
    }

    function getCollateralValueInUSD(address token, uint256 collateralAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * FEED_PRECISION) * collateralAmount) / PRECISION;
    }

    function getUSDValueInCollateral(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (usdAmount * PRECISION) / (uint256(price) * FEED_PRECISION);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getAccountInfo(address user) external view returns (uint256 totalDSCMinted, uint256 collateralUSD) {
        (totalDSCMinted, collateralUSD) = _getAccountInfo(user);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getFeedPrecision() external pure returns (uint256) {
        return FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }
}
