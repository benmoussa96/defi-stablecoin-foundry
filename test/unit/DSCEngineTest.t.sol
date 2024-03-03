// SPDX-License=Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

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
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (config, dsc, engine) = deployer.run();
        (ethPriceFeed, btcPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();
    }

    // Price Tests
    function testUSDValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUSD = 45000e18; // 15e18 * $3000/ETH = 45,000e18
        uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }
}
