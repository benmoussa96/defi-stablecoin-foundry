// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public priceFeedAddresses;
    address[] public tokenAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig config = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        priceFeedAddresses = [wethPriceFeed, wbtcPriceFeed];
        tokenAddresses = [weth, wbtc];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(msg.sender);
        DSCEngine engine = new DSCEngine(address(dsc), priceFeedAddresses, tokenAddresses);
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc, engine);
    }
}
