// SPDX-License=Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    address ethPriceFeed;
    address btcPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant DSC_AMOUNT = 10000 ether;
    uint256 public constant STARTING_BALANCE = 50 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (config, dsc, engine) = deployer.run();
        (ethPriceFeed, btcPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
    }

    // CONSTRUCTOR TESTS
    address[] public priceFeedAddresses;
    address[] public collateralAddresses;

    function testRevertsIfTokensAndPriceFeedsLengthDoesNotMatch() public {
        priceFeedAddresses.push(ethPriceFeed);
        priceFeedAddresses.push(btcPriceFeed);
        collateralAddresses.push(weth);

        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokensAndPriceFeedsMustBeSameLength.selector);
        new DSCEngine(address(dsc), priceFeedAddresses, collateralAddresses);
    }

    // PRICE TESTS
    function testGetCollateralValueInUSD() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUSD = 30000e18; // 15e18 * $2000/ETH = 60,000e18
        uint256 actualUSD = engine.getCollateralValueInUSD(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }

    function testGetUSDValueInCollateral() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedETH = 0.05 ether; // 100 / $2000/ETH = 0.05
        uint256 actualETH = engine.getUSDValueInCollateral(weth, usdAmount);
        assertEq(expectedETH, actualETH);
    }

    // DEPOSIT TESTS
    function testRevertIfZeroCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidAmount.selector);
        engine.depositCollateralAndMintDSC(weth, 0, 0);
        vm.stopPrank();
    }

    function testRevertIfCollateralNotSupported() public {
        ERC20Mock randomToken = new ERC20Mock("RANDOM", "RANDOM", USER, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralNotSupported.selector);
        engine.depositCollateralAndMintDSC(address(randomToken), COLLATERAL_AMOUNT, 0);
        vm.stopPrank();
    }

    // DEPOSIT WITHOUT MINT TESTS
    modifier depositCollateralOnly() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositCollateralOnly {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateralOnly {
        (uint256 totalDSCMinted, uint256 collateralUSD) = engine.getAccountInfo(USER);

        uint256 expectedDSCMinted = 0;
        uint256 expectedCollateralUSD = engine.getCollateralValueInUSD(weth, COLLATERAL_AMOUNT);

        assertEq(totalDSCMinted, expectedDSCMinted);
        assertEq(collateralUSD, expectedCollateralUSD);
    }

    // MINT TESTS
    function testRevertIfZeroMintAmount() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidAmount.selector);
        engine.mintDSC(0);
        vm.stopPrank();
    }

    function testRevertIfMintBreaksHealthFactor() public depositCollateralOnly {
        (, int256 price,,,) = MockV3Aggregator(ethPriceFeed).latestRoundData();
        // uint256 totalDSCToMint = DSC_AMOUNT + 1;
        uint256 totalDSCToMint =
            (COLLATERAL_AMOUNT * (uint256(price) * engine.getFeedPrecision())) / engine.getPrecision();
        uint256 expectedHealthFactor = (
            (engine.getCollateralValueInUSD(weth, COLLATERAL_AMOUNT) * engine.getLiquidationThreshold())
                / engine.getLiquidationPrecision()
        ) * engine.getPrecision() / totalDSCToMint;

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HeathFactorBroken.selector, expectedHealthFactor));
        engine.mintDSC(totalDSCToMint);
        vm.stopPrank();
    }

    function testCanMintDSC() public depositCollateralOnly {
        vm.startPrank(USER);
        engine.mintDSC(DSC_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, DSC_AMOUNT);
    }

    // DEPOSIT AND MINT TESTS
    modifier depositCollateralAndMintDSC() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositCollateralAndMintDSC {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, DSC_AMOUNT);
    }

    function testCanDepositCollateralAndMintDSCAndGetAccountInfo() public depositCollateralAndMintDSC {
        (uint256 totalDSCMinted, uint256 collateralUSD) = engine.getAccountInfo(USER);

        uint256 expectedDSCMinted = DSC_AMOUNT;
        uint256 expectedCollateralUSD = engine.getCollateralValueInUSD(weth, COLLATERAL_AMOUNT);

        assertEq(totalDSCMinted, expectedDSCMinted);
        assertEq(collateralUSD, expectedCollateralUSD);
    }

    // function testCanRedeemCollateralAndGetAccountInfo() public depositCollateralAndMintDSC {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
    //     engine.redeemCollateralAndBurnDSC(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
    //     vm.stopPrank();

    //     (uint256 totalDSCMinted, uint256 collateralUSD) = engine.getAccountInfo(USER);

    //     uint256 expectedDSCMinted = 0;
    //     uint256 expectedCollateralUSD = 0;

    //     assertEq(totalDSCMinted, expectedDSCMinted);
    //     assertEq(collateralUSD, expectedCollateralUSD);
    // }
}
