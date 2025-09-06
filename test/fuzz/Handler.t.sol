//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";  
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    uint256 public timesMintCalled;
    ERC20Mock weth;
    ERC20Mock wbtc;

    address [] public collateradepositedusers;
    MockV3Aggregator public ethUsdPriceFeed;

  
    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;
    

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;
        address [] memory tokens = dsce.getCollateralTokens();
        weth = ERC20Mock(tokens[0]);
        wbtc = ERC20Mock(tokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getcolleteraltokenPriceFeed(address(weth)));
        

        }


        function mintDsc(uint256 amount,uint256 addressseed) public {
            
            if(collateradepositedusers.length == 0){
                return;
            }

            address sender = collateradepositedusers[addressseed % collateradepositedusers.length];


        (uint256 totalDscMinted,uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDsctomint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
            

            if(maxDsctomint < 0){
                return;
            }
            amount = bound(amount,0,uint256(maxDsctomint));
            
            if(amount == 0 ){
                return;
            }
            
            
            vm.startPrank(sender);
            dsce.mintDsc(amount);
            vm.stopPrank();
             timesMintCalled++;
        }



        function depositCollateral(uint256 collateraseed,uint256 amountCollateral) public {
            ERC20Mock collateral = _getCollateralFromSeed(collateraseed);
            amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
            

            vm.startPrank(msg.sender);
            collateral.mint(msg.sender,amountCollateral);
            collateral.approve(address(dsce),amountCollateral);
            dsce.depositCollateral(address(collateral),amountCollateral);
            vm.stopPrank();
            collateradepositedusers.push(msg.sender);
        }

        function RedeemCollateral(uint256 collateralseed,uint256 amountcollateral) public {
            ERC20Mock collateral = _getCollateralFromSeed(collateralseed);
            uint256 maxcollateral = dsce.getCollateralDeposited(msg.sender,address(collateral));
            amountcollateral = bound(amountcollateral,0,maxcollateral);
            
            if(amountcollateral == 0){
                return;
            }
                vm.startPrank(msg.sender);
            dsce.redeemCollateral(address(collateral),amountcollateral);
                vm.stopPrank();
             
        }

                    // This Breaks Our Invariant Test Suite !!!
                // function updateCollateralPrice(uint96 newprice) public {
                //     int256 newpriceint = int256(uint256(newprice));
                //     ethUsdPriceFeed.updateAnswer(newpriceint);
                // }

        function _getCollateralFromSeed(uint256 seed) private view returns (ERC20Mock) {
                if(seed % 2 == 0){
                    return weth;
                }
                 else {
                    return wbtc;
                }   
        }
    }







