// SPDX-License=Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

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
    uint256 public constant STARTING_BALANCE = 10 ether;

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
        ERC20Mock(weth).approve(address(dsc), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidAmount.selector);
        engine.depositCollateralAndMintDSC(weth, 0, DSC_AMOUNT);
        vm.stopPrank();
    }

    function testRevertIfCollateralNotSupported() public {
        ERC20Mock randomToken = new ERC20Mock("RANDOM", "RANDOM", USER, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralNotSupported.selector);
        engine.depositCollateralAndMintDSC(address(randomToken), COLLATERAL_AMOUNT, DSC_AMOUNT);
        vm.stopPrank();
    }
}
