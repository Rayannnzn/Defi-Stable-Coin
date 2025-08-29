//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_CHECK = 1 ether;
    uint256 public constant COLLATERAL_BALANCE = 10 ether;
    uint256 public constant LOW_COLLATERAL = 0.025 ether;
    uint256 public constant ERC20_BALANCE = 100 ether;
    uint256 public constant DEPOSIT_BALANCE = 20 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant MINTING_AMOUNT = 1 ether;
    address wrongtoken = 0x7E7B45b08F68EC69A99AAb12e42FcCB078e10094;
    uint256 collateralfake = 1 ether;
}

contract DSCEngineTest is Test,CodeConstants{
    
    event CollateralDeposited(address indexed user,address indexed tokenaddress,uint256 indexed amount);

    DeployDSC deploy;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerkey;

    address USER = makeAddr("user");
    address HACKER = makeAddr("hacker");


    function setUp() public {

    deploy = new DeployDSC();
    (dsc,engine,config) = deploy.run();

   (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerkey) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER,ERC20_BALANCE);
        ERC20Mock(weth).mint(HACKER,ERC20_BALANCE);
        
    }

                    ///////////////////
                    // Price Feeds ///
                    ///////////////////

        function testPriceFeeds() public{

            uint256 ethamount =  15e18;
            uint256 expectedusd = 30000e18;
            uint256 actualusd = engine.getUsdValue(weth,ethamount);
            
            assertEq(actualusd,expectedusd);

            
        }



                          ///////////////////
                        // Constructor Tests  ///
                        ///////////////////

                        address [] tokenaddress;
                        address [] pricefeedaddress;
                    function testRevertIfTokenaddressLengthNotMatch() public {
                        tokenaddress.push(weth);
                        pricefeedaddress.push(wethUsdPriceFeed);
                        pricefeedaddress.push(wbtcUsdPriceFeed);
                        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedeaddressesMustbeSameLength.selector);
                        new DSCEngine(tokenaddress,pricefeedaddress,address(dsc));
                    }
                



                          ///////////////////
                        // Price Tests   ///
                        ///////////////////

                    function testgetTokenAmountFromUsd() public {
                uint256 expectedAmount = 0.025 ether; // 1 ETH = 1e18
                uint256 amountusd = 50e18;   // $2000 in 18-decimal scaling
                uint256 actualAmount = engine.getTokenAmountFromUsd(weth, amountusd);

                assertEq(expectedAmount, actualAmount);

                    }


                        ///////////////////
                        // Deposit Collateral ///
                        ///////////////////

        
            function testDepositCollateral() public {
                
                vm.startPrank(USER);
                ERC20Mock(weth).approve(address(engine),COLLATERAL_BALANCE);
                
                vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
                engine.depositCollateral(weth,0);
                vm.stopPrank();
                      
                
            }

            function testDepositCollateralRevertForWrongToken() public {
                    ERC20Mock rantoken = new ERC20Mock("RAN","RAN",USER,DEPOSIT_BALANCE);
                    vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
                    vm.prank(USER);
                    engine.depositCollateral(address(rantoken),collateralfake);

            }

            modifier depositedCollateral(){
                vm.startPrank(USER);
                ERC20Mock(weth).approve(address(engine),STARTING_BALANCE);
                engine.depositCollateral(weth,DEPOSIT_BALANCE);
                vm.stopPrank();
                _;
            }


            modifier mintDsc() {
           vm.startPrank(USER);
                
                engine.mintDsc(MINTING_AMOUNT);
                vm.stopPrank();
                _;

            }


            // function testDepositCollateralmappingAndEvent() public depositedCollateral{

            //   (uint256 totaldscminted,uint256 collateralInusd) = engine.getAccountInformation(USER);  
            //     uint256 expectedamount = DEPOSIT_BALANCE;
            //     uint256 actualamount = engine.getCollateralDeposited(USER,weth);
            //     uint256 mappingres = engine.getCollateralDeposited(USER,weth);
            //     assertEq(totaldscminted,0);
            //     assertEq(collateralInusd,20000e18);
            //     assertEq(expectedamount,actualamount);
            //     assertEq(mappingres,DEPOSIT_BALANCE);
            // }


            function testEventDepositCollateral() public {
                    vm.startPrank(USER);
                ERC20Mock(weth).approve(address(engine),STARTING_BALANCE);
                vm.expectEmit(true,true,true,true);
                emit DSCEngine.CollateralDeposited(USER,weth,DEPOSIT_BALANCE);

                engine.depositCollateral(weth,DEPOSIT_BALANCE);

                vm.stopPrank();
            }

            function testMintDsc() public depositedCollateral{
                vm.startPrank(USER);
                
                engine.mintDsc(MINTING_AMOUNT);
                vm.stopPrank();
                uint256 mappingcheck = engine.getDSCMinted(USER);

        (uint256 totaldscminted,) = engine.getAccountInformation(USER);
                    assertEq(totaldscminted,MINTING_AMOUNT);
                    assertEq(mappingcheck,MINTING_AMOUNT);
                    
            }

            function testMintDscFailsifCollateralLow() public {
                //uint256 mintamount = 1 ether;  
                vm.startPrank(USER);
                ERC20Mock(weth).approve(address(engine),STARTING_BALANCE);
                engine.depositCollateral(weth,0.025 ether);
               // vm.expectRevert();
                engine.mintDsc(0.01 ether);

                vm.stopPrank();

            }

            
            function testDepositCollateralAndMintInOneTx() public {
                    vm.startPrank(USER);

                    ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);

                    engine.depositCollateralandMintDsc(weth, DEPOSIT_BALANCE, MINTING_AMOUNT);
                            vm.stopPrank();
                    (uint256 totalMinted, uint256 collateralInUsd) = engine.getAccountInformation(USER);

                    assertEq(totalMinted, MINTING_AMOUNT);
                    assertEq(collateralInUsd, 40000e18); // assuming $2000 ETH price
                    
                    }


                    function testRedeemCollateral() public depositedCollateral {
                        vm.startPrank(USER);
                        engine.redeemCollateral(weth, 5 ether);
                        vm.stopPrank();

                    //  uint256 remaining = engine.getCollateralDeposited(USER, weth);
                    //     assertEq(remaining, (DEPOSIT_BALANCE - 5 ether));
                    }

                    function testRedeemCollateralFailsIfTooMuch() public depositedCollateral {
                        vm.startPrank(USER);
                        vm.expectRevert();
                        engine.redeemCollateral(weth, DEPOSIT_BALANCE + 1);
                        vm.stopPrank();
                    }

            //         modifier depositedCollateral(){
            //     vm.startPrank(USER);
            //     ERC20Mock(weth).approve(address(engine),STARTING_BALANCE);
            //     engine.depositCollateral(weth,20 ether);
            //     vm.stopPrank();
            //     _;
            // }


            function testRedeemCollateralForDsc() public depositedCollateral mintDsc {
            vm.startPrank(USER);
            engine.redeemCollateralforDsc(MINTING_AMOUNT, weth, 5 ether);
            vm.stopPrank();

            uint256 remainingCollateral = engine.getCollateralDeposited(USER, weth);
            uint256 minted = engine.getDSCMinted(USER);

            assertEq(minted, 0);
            //assertEq(remainingCollateral, DEPOSIT_BALANCE - 5 ether);
}




// function testLiquidationWorks() public depositedCollateral mintDsc {
//     // Simulate price crash: set WETH price to $100
//     MockV3Aggregator(wethUsdPriceFeed).updateAnswer(100e8);

//     vm.startPrank(HACKER);
//     ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);

//     // liquidator covers user debt
//     dsc.mint(HACKER, MINTING_AMOUNT);
//     dsc.approve(address(engine), MINTING_AMOUNT);

//     engine.liquidate(weth, USER, MINTING_AMOUNT);
//     vm.stopPrank();

//     uint256 liquidatorCollateral = engine.getCollateralDeposited(HACKER, weth);
//     assertGt(liquidatorCollateral, 0, "Liquidator should receive collateral bonus");
// }




// function testBurnDscReducesBalance() public depositedCollateral mintDsc {
//     vm.startPrank(USER);
//     dsc.approve(address(engine), MINTING_AMOUNT);
//     engine.burnDsc(MINTING_AMOUNT);
//     vm.stopPrank();

//     uint256 minted = engine.getDSCMinted(USER);
//     assertEq(minted, 0);
// }





// function testMintRevertsIfHealthFactorBroken() public depositedCollateral {
//     vm.startPrank(USER);
//     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
//     engine.mintDsc(100 ether); // way too high
//     vm.stopPrank();
// }



// function testGetters() public depositedCollateral mintDsc {
//     (uint256 minted, uint256 collateralUsd) = engine.getAccountInformation(USER);

//     assertEq(minted, MINTING_AMOUNT);
//     assertEq(collateralUsd, 20000e18);

//     assertEq(engine.getCollateralDeposited(USER, weth), DEPOSIT_BALANCE);
//     assertEq(engine.getDSCMinted(USER), MINTING_AMOUNT);
// }















































                
                // uint256 public constant STARTING_BALANCE = 100 ether;
                // uint256 public constant DEPOSIT_BALANCE = 20 ether;

            // function testliquidationSeizeCollateral() public {
            //     // USER
            //     vm.startPrank(USER);
            //     ERC20Mock(weth).approve(address(engine),STARTING_BALANCE);
            //     engine.depositCollateral(weth,STARTING_BALANCE);
            //     engine.mintDsc(500 ether);
            //     vm.stopPrank();

            //     // HACKER
            //     vm.startPrank(HACKER);
            //     ERC20Mock(weth).approve(address(engine),0.1 ether);
            //     engine.depositCollateral(weth,0.1 ether);
            //     engine.mintDsc(10 ether);
            //     vm.stopPrank();

            //         MockV3Aggregator(wethUsdPriceFeed).updateAnswer(100e8); // ETH = $100
 

            //     vm.startPrank(USER);
            //     engine._cheatredeemCollateral(HACKER,USER,weth,0.05 ether);
            //     engine.liquidate(weth,HACKER,10 ether);
            //     vm.stopPrank();


            // }











        


            



}
