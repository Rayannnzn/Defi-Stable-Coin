// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions




//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable,ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol"; 
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";        
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OraclelLib.sol";




/*
 * @title DSCEngine
 * @author Muhammad Rayan
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * Our DSC system should always be "overcollateralized". At no point should the value of all collateral < the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard{

                //////////////////////////
                    // Errors /
               ////////////////////////


error DSCEngine__NeedsMoreThanZero();
error DSCEngine__TokenAddressesAndPriceFeedeaddressesMustbeSameLength();
error DSCEngine__NotAllowedToken();
error DSCEngine__TransferFailed();
error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
error DSCEngine__MintFailed();
error DSCEngine__HealthFactorOK();
error DSCEngine__HealthFactorNotImproved();
error DSCEngine__CollateralAmoubtIsLow();
error DSCEngine__NotEnoughToken();
error DSCEngine__NotEnoughCollateralINAccount();
error OracleLib__StalePrice();

                    /////////////////////
                    // Types /
                    ///////////////////

        using OracleLib for AggregatorV3Interface;


                    /////////////////////
                    // State Variables /
                    ///////////////////

    uint256 public constant PRECESION = 1e18;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant LIQUIDATION_THREESHOLD = 50;
    uint256 public constant LIQUIDATION_PRECESION = 100;
    uint256 public constant HEALTH_FACTOR_THREESHOLD = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 10;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address tokenAddress => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping (address user => uint256 amountDscminted) private s_Dscminted;
    address [] private s_collateralTokens;


                    /////////////////////
                        // Events //
                    ///////////////////
    event CollateralDeposited(address indexed user,address indexed tokenaddress,uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemfrom,address indexed redeemto,address indexed tokenaddress,uint256 amount);

                    /////////////////////
                        // Modifiers /
                    ///////////////////
    modifier MorethanZero(uint256 amount) {
        if(amount <= 0){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token){
        if(s_priceFeeds[token] == address(0)){
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }




    constructor(address [] memory tokenaddresses,address [] memory pricefeeds,address dscaddress) {
        if(tokenaddresses.length != pricefeeds.length ){
            revert DSCEngine__TokenAddressesAndPriceFeedeaddressesMustbeSameLength();
        }
        for(uint256 i = 0; i < tokenaddresses.length; i++){
            s_priceFeeds[tokenaddresses[i]] = pricefeeds[i];
            s_collateralTokens.push(tokenaddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscaddress);
    }



                    ///////////////////////
                    // External Functions /
                   ///////////////////////



    /**
     *@param tokencollateraladdress The Address of the Token to be placed as Collateral.
     *@param collateralamount The Amount of Collateral to be deposited.
     *@param amountomint The Amount of DSC to be minted.
    * @notice This function deposits collateral and mints DSC in one transaction.
     */
    function depositCollateralandMintDsc(address tokencollateraladdress,uint256 collateralamount,uint256 amountomint) external {
        depositCollateral(tokencollateraladdress,collateralamount);
        mintDsc(amountomint);
    }

    

 /**
     * 
     * @param tokencollateraladdress The Address of the Token to be placed as Collateral.
     * @param collateralamount The Amount of Collateral to be deposited.
     */
function depositCollateral(address tokencollateraladdress,uint256 collateralamount) public MorethanZero(collateralamount) isAllowedToken (tokencollateraladdress) nonReentrant {
   
    s_collateralDeposited[msg.sender][tokencollateraladdress] += collateralamount; 
    emit CollateralDeposited(msg.sender,tokencollateraladdress,collateralamount);
    bool success = IERC20(tokencollateraladdress).transferFrom(msg.sender,address(this),collateralamount);

    if(!success){
        revert DSCEngine__TransferFailed();
    }

    }



        /**
     *@param burnamount The Amount of DSC to be burned.
     *@param tokencollateraladdress The Address of the Token to be redeemed as Collateral.
     *@param collateralamount The Amount of Collateral to be redeemed.
    * @notice This function burns DSC and redeems underlying collateral in one transaction.
     */
    function redeemCollateralforDsc(uint256 burnamount,address tokencollateraladdress,uint256 collateralamount) external {
        burnDsc(burnamount);
        redeemCollateral(tokencollateraladdress,collateralamount);
        // RedeemCollateral already checks Health Factor !!!
    }


      // in order to redeem collateral 
      // health factor must be over 1 after collateral is pulled..
      // DRY: Don't Repeat Yourself
      // CEI: Checks Effects Interactions Pattern
    function redeemCollateral(address tokencollateraladdress,uint256 collateralamount) public MorethanZero(collateralamount) nonReentrant {
        _redeemCollateral(msg.sender,msg.sender,tokencollateraladdress,collateralamount);
        _revertIfHealthFactorisBroken(msg.sender);
    }



    function mintDsc(uint256 amounttomint ) public MorethanZero(amounttomint) nonReentrant{


        (,uint256 totalCollateral) = _getAccountInformation(msg.sender);
        
        if(amounttomint > (totalCollateral / 2)){
            revert DSCEngine__CollateralAmoubtIsLow();
        }

        s_Dscminted[msg.sender] += amounttomint;
        _revertIfHealthFactorisBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender,amounttomint);

        if(!minted){
            revert DSCEngine__MintFailed();
        }

    }

    function burnDsc(uint256 amount) public MorethanZero(amount) {
        uint256 getDscMinted = s_Dscminted[msg.sender];
        if(getDscMinted < amount){
            revert DSCEngine__NotEnoughToken();
        }
        _burnDsc(amount,msg.sender,msg.sender);
        _revertIfHealthFactorisBroken(msg.sender);

    }


     // If we do start nearing undercollateralization, we need someone to liquidate positions
     // $100 ETH backing $50 DSC
    // $20 ETH back $50 DSC <- DSC isn't worth $1!!!
    // $75 backing $50 DSC
   // Liquidator take $75 backing and burns off the $50 DSC
  // If someone is almost undercollateralized, we will pay you to liquidate them!"
    /**
  * @param tokencollateraladdress The erc20 collateral to liquidate from the user.
  * @param user The user who has broken the health factor.Their _HealthFactor must be below the Minimum Health Factor.
  * @param debtToCover The Amount of DSC to be burned to improve the users health factor.
  * @notice This function allows anyone to liquidate a user that is undercollateralized
  * @notice you can partially liquidate a user.
  * @notice You will get a liquidation bonus for taking the users collateral.
  * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work.
  * @notice A known **bug** would be if the protocol were 100% or less collateralized, then we wouldn't be able to
  *  incentive the liquidators.
  * For example, if the price of the collateral plummeted before anyone could be liquidated.
  */
    function liquidate (address tokencollateraladdress,address user,uint256 debtToCover) external MorethanZero(debtToCover) nonReentrant{
        uint256 starttingHealthFactor = _HealthFactor(user);
        
        if(starttingHealthFactor > HEALTH_FACTOR_THREESHOLD){
            revert DSCEngine__HealthFactorOK();
        }
                     // This will get USD value in Eth/BTC form...   
        uint256 tokenAmountFromDEbt = getTokenAmountFromUsd(tokencollateraladdress,debtToCover);
        
        // Give liquidator 10% bonus for liquidating the user

        uint256 bonusCollateral = (tokenAmountFromDEbt * LIQUIDATION_BONUS) / LIQUIDATION_PRECESION;
        uint256 totalCollateralToRedeem = tokenAmountFromDEbt + bonusCollateral;
       _redeemCollateral(user,msg.sender,tokencollateraladdress,totalCollateralToRedeem);
        _burnDsc(debtToCover,user,msg.sender);

       uint256 endingHealthFactor = _HealthFactor(user);
        if(endingHealthFactor <= starttingHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorisBroken(msg.sender);
    }

    function getHealthFactor() external view {}












               /////////////////////////////
              // Private and Internal Functions //
              //////////////////////////////
        /**
         * 
         * 
         * @dev Low Level Internal Function, do not call unit function calling it is 
         * checking Health Factor being broken.
         */     
        function _burnDsc(uint256 burnDscamount,address onbehalfof,address dscFrom) private {
            s_Dscminted[onbehalfof] -= burnDscamount;
            bool success = i_dsc.transferFrom(dscFrom,address(this),burnDscamount);
            if(!success){
                revert DSCEngine__TransferFailed();
            }
            i_dsc.burn(burnDscamount);
        }



    function _redeemCollateral(address from,address to,address tokencollateraladdress,uint256 collateralamount) private {
        uint256 deposited = s_collateralDeposited[from][tokencollateraladdress];
        if(deposited < collateralamount){
            revert DSCEngine__NotEnoughCollateralINAccount();
        }
        s_collateralDeposited[from][tokencollateraladdress] -= collateralamount; 
        bool success = IERC20(tokencollateraladdress).transfer(to,collateralamount);
                emit CollateralRedeemed(from,to,tokencollateraladdress,collateralamount);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
        }



    function _getAccountInformation(address user) private view returns (uint256 TotalDscminted,uint256 CollateralValueinUsd){
        TotalDscminted = s_Dscminted[user];
        CollateralValueinUsd = getAccountCollateralValue(user);
    }


         // Check Health Factor (do they have Enough Collateral)
        // If Dont Revert...
    function _revertIfHealthFactorisBroken(address user) internal view {
            uint256 healthFactor = _HealthFactor(user);
            if(healthFactor < HEALTH_FACTOR_THREESHOLD){
                revert DSCEngine__BreaksHealthFactor(healthFactor);
            }          
    }
    
    /*
     *  Returns How close to a liquidation a user is...
     *  If a user goes below 1 they can get liquidated... 
     */     
        function _HealthFactor(address user) private view returns(uint256){
            if(s_Dscminted[user] == 0){
                return type(uint256).max;
            }
            //Total DSC Minted
            // Total Collateral Value in Usd
        (uint256 totalDscMinted,uint256 collateralValueInUsd) = _getAccountInformation(user);
                //   $(100 * 50) = 5000 / 100 = $50, So $50 Dollar can be used as Collateral

 uint256 collateralAdjustedforThreeshold = (collateralValueInUsd * LIQUIDATION_THREESHOLD ) / LIQUIDATION_PRECESION;
                               // Health Factor = $ (50 * 100) = 5000 / 50 = 100 
                               // 100 Here Means 1 Because Solidity Cant do decimals so !
        return (collateralAdjustedforThreeshold * PRECESION) / totalDscMinted;
        }







                /////////////////////////////
              // Public and External View Functions //
              //////////////////////////////

                    // Converts a USD amount in Token Form... 
                    // $50 = 0.025 ETH
        function getTokenAmountFromUsd(address tokenaddress,uint256 usdamount) public view returns(uint256){
            AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[tokenaddress]);
            (,int256 price,,,) = pricefeed.staleCheckLatestRoundData();
            // ($50e18) / ($2000e18) = 0.025 ETH
            return ((usdamount * PRECESION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
        }     


                    // Returns the Total Account's value of BTC/ETH in USD !!!
                    // 0.025 ETH = $50
        function getAccountCollateralValue(address user) public view returns(uint256 TotalCollateralValueinUsd){
                //loop through each collateral token,get the amount they have deposited,and map it 
                // to the price, to get the USD Value...
                for(uint256 i = 0; i < s_collateralTokens.length; i++ ){
                    address token = s_collateralTokens[i];
                    uint256 amount = s_collateralDeposited[user][token];
                    TotalCollateralValueinUsd += getUsdValue(token,amount);
                }
                return TotalCollateralValueinUsd;
        }

        
                    // Returns the total value of BTC/ETH in USD !!!
        function getUsdValue(address tokenaddress,uint256 amount) public view returns(uint256){
            AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[tokenaddress]);
            (,int256 price,,,) = pricefeed.staleCheckLatestRoundData();
            return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount / PRECESION);
        }

        function getAccountInformation(address user) external view returns(uint256 totalDscminted,uint256 collateraUsd){
            (totalDscminted,collateraUsd) = _getAccountInformation(user);
        }


        function getCollateralDeposited(address user,address token) external view returns(uint256){
            return s_collateralDeposited[user][token];
        }

        function getDSCMinted(address user) external view returns(uint256 totalDSCs){
            return s_Dscminted[user];
        }

        function getCollateralTokens() external view returns(address [] memory){
            return s_collateralTokens;
        }   

        function getcolleteraltokenPriceFeed(address token) external view returns(address){
            return s_priceFeeds[token];
        }


}



