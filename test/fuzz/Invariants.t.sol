//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Handler} from "./Handler.t.sol";


contract Invariant is StdInvariant,Test {
    
        DeployDSC deploy;
        DSCEngine dsce;
        DecentralizedStableCoin dsc;
        HelperConfig config;
        Handler handler;

        address weth;
        address wbtc;


    function setUp() public {

        deploy = new DeployDSC();
        (dsc,dsce,config) = deploy.run();  
        (,,weth,wbtc,) = config.activeNetworkConfig(); 
        // targetContract(address(dsce));
        handler = new Handler(dsce,dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public  {
        uint256 totalsupply = dsc.totalSupply();
        uint256 totalwethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalwbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth,totalwethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc,totalwbtcDeposited);

        emit log_named_uint("weth value", wethValue);
        emit log_named_uint("wbtc value", wbtcValue); 
        emit log_named_uint("total supply", totalsupply);
        emit log_named_uint("times mint called", handler.timesMintCalled());
        assert(wethValue + wbtcValue >= totalsupply);

    }

    function invariants_gettersShouldNotRevert() public view {
        dsce.getCollateralTokens();
        dsce.getAccountCollateralValue(address(this));
        dsce.getAccountInformation(address(this));
        dsce.getUsdValue(weth,1e18);
        dsce.getTokenAmountFromUsd(weth,1e18);
    }



}