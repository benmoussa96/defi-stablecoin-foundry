// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {console} from "forge-std/console.sol";

contract OpenInvariantsTests is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;

    address ethPriceFeed;
    address btcPriceFeed;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (config, dsc, engine) = deployer.run();
        (ethPriceFeed, btcPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        targetContract(address(engine));
    }

    function invariant_protocolMustHaveMoreCollateralThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();

        uint256 depositedWETH = ERC20Mock(weth).balanceOf(address(engine));
        uint256 depositedWBTC = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getCollateralValueInUSD(weth, depositedWETH);
        uint256 wbtcValue = engine.getCollateralValueInUSD(wbtc, depositedWBTC);

        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);
        console.log("totalSupply: %s", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }
}
