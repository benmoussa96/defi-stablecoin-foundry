// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public priceFeedAddresses;
    address[] public collateralAddresses;

    function run() external returns (HelperConfig, DecentralizedStableCoin, DSCEngine) {
        HelperConfig config = new HelperConfig();
        (address ethPriceFeed, address btcPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        priceFeedAddresses = [ethPriceFeed, btcPriceFeed];
        collateralAddresses = [weth, wbtc];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(address(dsc), priceFeedAddresses, collateralAddresses);
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (config, dsc, engine);
    }
}
