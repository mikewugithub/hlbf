// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

// interfaces
import {ITokenPriceOracle} from "../../interfaces/ITokenPriceOracle.sol";
import {IAuthority} from "../../interfaces/IAuthority.sol";
import {IMintableBurnable} from "../../interfaces/IMintableBurnable.sol";
import {FundToken} from "../token/FundToken.sol";
// errors and constants
import "../../config/constants.sol";
import "../../config/errors.sol";
import {Role} from "../../config/roles.sol";

/**
 * @title   Money Market Fund Manager
 * @notice  This contract manages a Money Market Fund (MMF) that allows users to subscribe to and redeem
 *          fund tokens. The fund tokens (ytoken) represent shares in the underlying assets.
 * @dev     The contract handles:
 *          - Subscription: Users deposit stable coins to receive fund tokens
 *          - Redemption: Users burn fund tokens to receive stable coins
 *          - Fee management: Applies buy/sell fees for fund operations
 *          - Price oracle integration: Uses an oracle to determine token prices
 */
contract MMFManager is ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    /*///////////////////////////////////////////////////////////////
                        Constants & Immutables
    //////////////////////////////////////////////////////////////*/

    /// @notice Authority contract for role-based access control
    IAuthority public immutable authority;

    /// @notice The fund token (yield token) that represents shares in the fund
    FundToken public immutable ytoken;

    /// @notice Decimals of the fund token, stored to save gas
    uint8 private immutable _ytokenDecimals;

    /// @notice Price oracle for getting current token prices
    ITokenPriceOracle public immutable oracle;

    /// @notice Decimals of the oracle's price feed, stored to save gas
    uint8 private immutable _oracleDecimals;

    /// @notice Address that receives all fees from operations
    address public immutable feeRecipient;

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event Subscription(address indexed from, uint256 amount);
    event SubscriptionPending(address indexed from, uint256 amount);
    event Redemption(address indexed to, uint256 amount);
    event RedemptionPending(address indexed to, uint256 amount);
    event Transferred(address indexed recipient, address indexed token, uint256 amount);
    event FeesSet(uint256 buyFee, uint256 newBuyFee, uint256 sellFee, uint256 newSellFee);
    event StableSet(address indexed token);
    event OffchainSubscriptionFulfilled(address indexed recipient, uint256 amount);
    event OffchainRedemptionFulfilled(address indexed recipient, uint256 amount);

    /// @notice The stable coin used for deposits and withdrawals
    IERC20Metadata public stable;

    /// @notice Decimals of the stable coin, stored to save gas
    uint8 private stableDecimals;

    /// @notice Fee percentage applied during token purchases (in basis points, 18 decimals)
    uint256 public buyFee;

    /// @notice Fee percentage applied during token sales (in basis points, 18 decimals)
    uint256 public sellFee;

    /// @notice Whether subscription and redemption is instant
    bool public instantSubscription;

    /// @notice Whether redemption is instant
    bool public instantRedemption;

    /*///////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor 
     * @param _ytoken Address of the fund token contract
     * @param _oracle Address of the price oracle
     * @param _authority Address of the authority contract for access control
     * @param _feeRecipient Address that will receive fees
     */
    constructor(       
        address _ytoken,
        address _oracle,
        address _authority,
        address _feeRecipient) {

        if (_ytoken == address(0)) revert BadAddress();
        if (_oracle == address(0)) revert BadAddress();
        if (_authority == address(0)) revert BadAddress();
        if (_feeRecipient == address(0)) revert BadAddress();

        ytoken = FundToken(_ytoken);
        _ytokenDecimals = ytoken.decimals();
        
        oracle = ITokenPriceOracle(_oracle);
        _oracleDecimals = oracle.decimals();
        
        authority = IAuthority(_authority);
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Initializes the MMF Manager with required parameters

     * @param _buyFee Fee percentage for buying tokens (in basis points)
     * @param _sellFee Fee percentage for selling tokens (in basis points)
     */
    function initialize(
        address _owner,
        address _stable,
        uint256 _buyFee,
        uint256 _sellFee,
        bool _instantSubscription,
        bool _instantRedemption
    ) external initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        if (_stable == address(0)) revert BadAddress();
        stable = IERC20Metadata(_stable);
        stableDecimals = stable.decimals();

        buyFee = _buyFee;
        sellFee = _sellFee;
        instantSubscription = _instantSubscription;
        instantRedemption = _instantRedemption;
    }

    function setStable(address _token) external {
        _assertSystemAdmin();

        if (_token == address(0)) revert BadAddress();

        emit StableSet(_token);

        stable = IERC20Metadata(_token);
        stableDecimals = stable.decimals();
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*///////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/



    /**
     * @notice Helper function to check if user has System_Admin role
     * @dev Reverts if user does not have the role
     */
    function _assertSystemAdmin() internal view {
        if (!authority.doesUserHaveRole(msg.sender, Role.System_Admin)) revert NotPermissioned();
    }

    /**
     * @notice Allows system admin to update the buy and sell fees
     * @dev Fees are in basis points with 18 decimals (1e18 = 100%)
     * @param _buy New fee percentage for buying tokens
     * @param _sell New fee percentage for selling tokens
     */
    function setFees(uint256 _buy, uint256 _sell) external {
        _assertSystemAdmin();
        emit FeesSet(buyFee, _buy, sellFee, _sell);

        buyFee = _buy;
        sellFee = _sell;
    }

    /**
     * @notice Calculates the amount of fund tokens to mint for a given stable coin deposit
     * @dev The calculation process:
     *      1. Deducts the buy fee from the input amount
     *      2. Converts the stable coin amount to USD (2 decimals)
     *      3. Scales the amount to match fund token decimals
     *      4. Uses the oracle price to determine final token amount
     * @param _stableAmount Amount of stable coins being deposited
     * @return convertedAmount Amount of fund tokens to mint
     * @return fee Amount of fee taken in stable coins
     * @return price Current price from the oracle
     */
    function _calculateSubscriptionAmount(uint256 _stableAmount) internal view virtual returns (uint256 convertedAmount, uint256 fee, int256 price) {
        // deducting buy fee
        fee = _stableAmount.mulDivDown(buyFee, HUNDRED_PCT);
        _stableAmount -= fee;

        // rounding to USD decimals {2}
        uint256 usdAmount;
        if (stableDecimals > 2) usdAmount = _stableAmount / 10 ** (stableDecimals - 2);
        else if (stableDecimals < 2) usdAmount = _stableAmount * (10 ** (2 - stableDecimals));
        // first scaling to Yield Token decimals {6}
        usdAmount *= 10 ** (_ytokenDecimals - 2);

        (, price,,,) = oracle.latestRoundData();
        convertedAmount = usdAmount.mulDivDown(10 ** _oracleDecimals, uint256(price));
    }

    /**
     * @notice Calculates the amount of stable coins to return for a given amount of fund tokens
     * @dev The calculation process:
     *      1. Gets current price from oracle
     *      2. Converts fund tokens to stable coin amount
     *      3. Calculates and deducts the sell fee
     *      4. Scales the amount to match stable coin decimals
     * @param _amount Amount of fund tokens to redeem
     * @return payout Amount of stable coins to return
     * @return fee Amount of fee taken in stable coins
     * @return price Current price from the oracle
     */
    function _calculateRedeemAmount(uint256 _amount) internal view virtual returns (uint256 payout, uint256 fee, int256 price) {

        // current price in terms of USD
        (, price,,,) = oracle.latestRoundData();

        // convert token amount to stable coin amount
        payout = _amount.mulDivDown(uint256(price), 10 ** _oracleDecimals);
        fee = payout.mulDivDown(sellFee, HUNDRED_PCT);
        payout -= fee;
        // scale to stable 
        payout = payout.mulDivDown(10 ** stableDecimals, 10 ** _ytokenDecimals);
        fee = fee.mulDivDown(10 ** stableDecimals, 10 ** _ytokenDecimals);
    }

    /**
     * @notice Helper function to check if user has Investor_Whitelisted role
     * @param _user Address to check
     */
    function _assertWhitelisted(address _user) internal view {
        if (!authority.doesUserHaveRole(_user, Role.Investor_Whitelisted)) 
            revert NotPermissioned();
    }


    function _checkPermission() internal view {
        if (!authority.canCall(msg.sender, address(this), msg.sig))
            revert NotPermissioned();
    }


    /*///////////////////////////////////////////////////////////////
                            User Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows users to subscribe to the fund by depositing stable coins
     * @dev Process:
     *      1. Validates input and checks whitelist
     *      2. Calculates conversion amount and fees
     *      3. Transfers stable coins from user
     *      4. Mints fund tokens to recipient
     * @param _stableAmount Amount of stable coins to deposit
     * @return amount Amount of fund tokens minted
     */
    function subscribe(
        uint256 _stableAmount
    ) external nonReentrant returns (uint256 amount) {
        address _recipient = msg.sender;
        if (_stableAmount == 0) revert BadAmount();
        
        // Check the recipient is whitelisted
        _assertWhitelisted(_recipient);
        _checkPermission();
    
        (uint256 convertedAmount, uint256 fee, int256 price) = _calculateSubscriptionAmount(_stableAmount);

        IERC20(stable).safeTransferFrom(msg.sender, address(this), _stableAmount - fee);
        IERC20(stable).safeTransferFrom(msg.sender, feeRecipient, fee);
        
        if (instantSubscription) {
            // Mint tokens to recipient using the token's mint function
            IMintableBurnable(address(ytoken)).mint(_recipient, convertedAmount);
            emit Subscription(msg.sender, _stableAmount);

        } else {
            // Subscription should be handled by the issuer's backend.
            emit SubscriptionPending(msg.sender, _stableAmount);
        }

        
        return convertedAmount;
    }

    /**
     * @notice Allows users to subscribe to the fund offchain by fiat
     *      
     * @param _recipient Address to receive the fund tokens
     * @param _subscriptionAmount Amount of fund tokens to mint
     * @return amount Amount of fund tokens minted
     */
    function offchainSubscribe(
        address _recipient,
        uint256 _subscriptionAmount
    ) external nonReentrant returns (uint256 amount) {
        if (_subscriptionAmount == 0) revert BadAmount();
        _assertSystemAdmin();
        // Check the recipient is whitelisted
        _assertWhitelisted(_recipient);
    
        IMintableBurnable(address(ytoken)).mint(_recipient, _subscriptionAmount);
        emit OffchainSubscriptionFulfilled(_recipient, _subscriptionAmount);
        return _subscriptionAmount;
    }

    /**
     * @notice Allows users to redeem their fund tokens for stable coins
     * @dev Process:
     *      1. Validates input and checks whitelist
     *      2. Calculates redemption amount and fees
     *      3. Burns fund tokens from sender
     *      4. Transfers stable coins to recipient
     * @param _amount Amount of fund tokens to redeem
     * @return amount Amount of stable coins paid out
     */
    function redeem(
        uint256 _amount
    ) external nonReentrant returns (uint256 amount) {
        address _recipient = msg.sender;
        if (_amount == 0) revert BadAmount();

        // Check the recipient is whitelisted
        _assertWhitelisted(_recipient);
        _checkPermission();

        (uint256 payout, uint256 fee, int256 price) = _calculateRedeemAmount(_amount);
        if (price == 0) revert BadPrice();

        // Burn tokens from sender
        IMintableBurnable(address(ytoken)).burnFrom(msg.sender, _amount);

        if (instantRedemption) {
            // Check contract has enough stable coins
            if (IERC20(stable).balanceOf(address(this)) < payout) 
                revert InsufficientStableBalance();

            IERC20(stable).safeTransfer(_recipient, payout);
            emit Redemption(_recipient, amount);
        } else {
            // Redemption should be handled by the issuer's backend.
            emit RedemptionPending(_recipient, amount);
        }
        
        return payout;
    }

    /**
     * @notice Allows users to redeem their fund tokens for stable coins offchain by fiat
     * @param _recipient Address to burn the fund tokens
     * @param _amount Amount of fund tokens to redeem
     * @return amount Amount of stable coins paid out
     */
    function offchainRedeem(
        address _recipient,
        uint256 _amount
    ) external nonReentrant returns (uint256 amount) {
        if (_amount == 0) revert BadAmount();
        _assertSystemAdmin();
        _assertWhitelisted(_recipient);

        IMintableBurnable(address(ytoken)).burnFrom(msg.sender, _amount);
        emit OffchainRedemptionFulfilled(_recipient, _amount);
        return _amount;
    }


    /**
     * @notice Returns whether instant subscription is enabled
     * @return True if instant subscription is enabled, false otherwise
     */
    function isInstantSubscriptionOn() external view returns (bool) {
        return instantSubscription;
    }

    /**
     * @notice Returns whether instant redemption is enabled
     * @return True if instant redemption is enabled, false otherwise
     */
    function isInstantRedemptionOn() external view returns (bool) {
        return instantRedemption;
    }

    /**
     * @notice Allows system admin to update the instant subscription status
     * @param _instantSubscription True if instant subscription is enabled, false otherwise
     */
    function setInstantSubscription(bool _instantSubscription) external {
        _assertSystemAdmin();
        instantSubscription = _instantSubscription;
    }

    /**
     * @notice Allows system admin to update the instant redemption status
     * @param _instantRedemption True if instant redemption is enabled, false otherwise
     */
    function setInstantRedemption(bool _instantRedemption) external {
        _assertSystemAdmin();
        instantRedemption = _instantRedemption;
    }
 
}

