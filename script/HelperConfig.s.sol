//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000E8;
    int256 public constant BTC_USD_PRICE = 1000E8;
    uint256 public DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x690cC3A988F6c9C5F35713ad4175897b439eD3c6, // ETH / USD
            wbtcUsdPriceFeed: 0x1b6ea69a6E1aB7c91F07771952c601A7808C09b3,
            weth: 0xddc619Ee30Cf294C39E9259bF6fe90C71Bd8C331,
            wbtc: 0x8f3A5Fe8F2501ab9b50e4fEbD8D4eC10A94f904e,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock weth = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock wbtc = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();
        return
            NetworkConfig({
                wethUsdPriceFeed: address(ethUsdPriceFeed),
                wbtcUsdPriceFeed: address(btcUsdPriceFeed),
                weth: address(weth),
                wbtc: address(wbtc),
                deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
