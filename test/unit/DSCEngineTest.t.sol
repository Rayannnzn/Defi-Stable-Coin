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


            function testDepositCollateralmappingAndEvent() public depositedCollateral{

              (uint256 totaldscminted,uint256 collateralInusd) = engine.getAccountInformation(USER);  
                uint256 expectedamount = DEPOSIT_BALANCE;
                uint256 actualamount = engine.getCollateralDeposited(USER,weth);
                uint256 mappingres = engine.getCollateralDeposited(USER,weth);
                assertEq(totaldscminted,0);
                assertEq(collateralInusd,40000e18);
                assertEq(expectedamount,actualamount);
                assertEq(mappingres,DEPOSIT_BALANCE);
            }


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
                vm.expectRevert();
                engine.mintDsc(60 ether);

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

                     uint256 remaining = engine.getCollateralDeposited(USER, weth);
                        assertEq(remaining, (DEPOSIT_BALANCE - 5 ether));
                    }

                    function testRedeemCollateralFailsIfTooMuch() public depositedCollateral {
                        vm.startPrank(USER);
                        vm.expectRevert();
                        engine.redeemCollateral(weth, DEPOSIT_BALANCE + 1 ether);
                        vm.stopPrank();
                    }



function testLiquidationWorks() public {
    // USER deposits 20 ETH at $2000 = $40k collateral
    vm.startPrank(USER);
    ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
    engine.depositCollateral(weth, 20 ether);

    uint256 userMintAmount = 18000e18; // borrow close to max
    engine.mintDsc(userMintAmount);
    vm.stopPrank();

    // Price crash: ETH from $2000 → $1000
    MockV3Aggregator(wethUsdPriceFeed).updateAnswer(1000e8);

    // Hacker setup
    vm.startPrank(HACKER);
    ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
    engine.depositCollateral(weth, 10 ether);
    engine.mintDsc(2000e18); // mint enough DSC to liquidate
    dsc.approve(address(engine), 2000e18);
    vm.stopPrank();

    // Check hacker’s wallet balance before liquidation
    uint256 hackerBalanceBefore = ERC20Mock(weth).balanceOf(HACKER);

    // Hacker liquidates USER
    vm.prank(HACKER);
    engine.liquidate(weth, USER, 2000e18);

    // Check hacker’s wallet balance after liquidation
    uint256 hackerBalanceAfter = ERC20Mock(weth).balanceOf(HACKER);

    assert(hackerBalanceAfter > hackerBalanceBefore); // ✅ should pass
}




            function testBurnDscFailsIfBurnAmountGreater() public depositedCollateral mintDsc{
                vm.startPrank(USER);
                dsc.approve(address(engine),MINTING_AMOUNT);
                vm.expectRevert(DSCEngine.DSCEngine__NotEnoughToken.selector);
                engine.burnDsc(MINTING_AMOUNT + 1 ether);
                vm.stopPrank();

            }


            function BurnDsc() public {
                vm.startPrank(USER);
                dsc.approve(address(engine),MINTING_AMOUNT);
                engine.burnDsc(MINTING_AMOUNT);
                vm.stopPrank();

                uint256 mappingcheck = engine.getDSCMinted(USER);
                (uint256 totaldscminted,) = engine.getAccountInformation(USER);
                    assertEq(totaldscminted,0);
                    assertEq(mappingcheck,0);
            }






            function testMintRevertsIfZeroAmount() public depositedCollateral {
    vm.startPrank(USER);
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.mintDsc(0);
    vm.stopPrank();
}

function testBurnRevertsIfZeroAmount() public depositedCollateral mintDsc {
    vm.startPrank(USER);
    dsc.approve(address(engine), MINTING_AMOUNT);
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.burnDsc(0);
    vm.stopPrank();
}

function testRedeemRevertsIfZeroAmount() public depositedCollateral {
    vm.startPrank(USER);
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.redeemCollateral(weth, 0);
    vm.stopPrank();
}

function testLiquidationFailsOnHealthyUser() public depositedCollateral mintDsc {
    vm.startPrank(HACKER);
    ERC20Mock(weth).approve(address(engine), STARTING_BALANCE);
    engine.depositCollateral(weth, 10 ether);
    engine.mintDsc(2000e18);
    dsc.approve(address(engine), 2000e18);

    vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
    engine.liquidate(weth, USER, 2000e18);
    vm.stopPrank();
}

function testLiquidationFailsIfZeroAmount() public depositedCollateral mintDsc {
    vm.startPrank(HACKER);
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.liquidate(weth, USER, 0);
    vm.stopPrank();
}


function testRedeemCollateralForDscWorks() public depositedCollateral mintDsc {
    // User has deposited and minted DSC
    vm.startPrank(USER);

    // Approve engine to burn user's DSC
    dsc.approve(address(engine), MINTING_AMOUNT);

    // Burn DSC and redeem collateral
    engine.redeemCollateralforDsc(MINTING_AMOUNT, weth, 5 ether);
    vm.stopPrank();

    // Check balances
    uint256 userCollateral = engine.getCollateralDeposited(USER, weth);
    uint256 userDebt = engine.getDSCMinted(USER);

    assertEq(userCollateral, DEPOSIT_BALANCE - 5 ether, "Collateral not redeemed correctly");
    assertEq(userDebt, 0, "DSC not burned");
}



function testRedeemCollateralFailsIfNotEnoughBalance() public depositedCollateral {
    vm.startPrank(USER);

    // Try to redeem more collateral than deposited
    vm.expectRevert(DSCEngine.DSCEngine__NotEnoughCollateralINAccount.selector);
    engine.redeemCollateral(weth, DEPOSIT_BALANCE + 1 ether);

    vm.stopPrank();
}


                
















        


            



}
