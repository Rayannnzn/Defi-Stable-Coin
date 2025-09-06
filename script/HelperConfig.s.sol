//SPDX-License-Identifier: MIT 

pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";  


contract HelperConfig is Script {

            // State Variables

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

       struct NetworkConfig{
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerkey;

       }

       NetworkConfig public activeNetworkConfig;



       constructor() {
            if(block.chainid == 11155111){
                activeNetworkConfig = getSepoliaEthConfig();
            }
            else{
                activeNetworkConfig = getAnvilEthConfig();
            }
       }

       function getSepoliaEthConfig() public view returns(NetworkConfig memory ){
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerkey: vm.envUint("PRIVATE_KEY")
            });

       }

       function getAnvilEthConfig() public returns(NetworkConfig memory){
            if(activeNetworkConfig.wethUsdPriceFeed != address(0)){
                return activeNetworkConfig;
            }

            console.log("Deploying Mocks");

            vm.startBroadcast();
            MockV3Aggregator ethPriceusd = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
            ERC20Mock wethmock = new ERC20Mock("WETH","WETH",msg.sender,1000e8);

            MockV3Aggregator btcPriceusd = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
            ERC20Mock wbtcmock = new ERC20Mock("WBTC","WBTC",msg.sender,1000e8);
            vm.stopBroadcast();


        return NetworkConfig({
            wethUsdPriceFeed: address(ethPriceusd),
            wbtcUsdPriceFeed: address(btcPriceusd),
            weth: address(wethmock),
            wbtc: address(wbtcmock),
            deployerkey: DEFAULT_ANVIL_KEY
            });

       }









}

