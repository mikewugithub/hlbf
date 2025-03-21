// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "./ERC20.sol";
import {IMintableBurnable} from "../../interfaces/IMintableBurnable.sol";
import {IAuthority} from "../../interfaces/IAuthority.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import "../../config/errors.sol";
import {Role} from "../../config/roles.sol";

/**
 * @title FundToken
 * @dev A basic ERC20 token with minting and burning capabilities
 */
contract FundToken is Initializable, ERC20, IMintableBurnable, OwnableUpgradeable, UUPSUpgradeable {

    IAuthority public immutable authority;

    /// @notice The address that has permission to mint tokens
    address public minter;
    /// @notice The address that has permission to burn tokens
    address public burner;

    /// @notice The number of decimals for the token
    uint256 internal _decimals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address authority_)  ERC20() {
        if (authority_ == address(0)) revert();
        authority = IAuthority(authority_);
        _disableInitializers();
    }


    /**
     * @dev Initializes the contract with token name, symbol and initial settings
     * @param _owner The initial owner of the contract
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param minter_ The initial minter address
     * @param burner_ The initial burner address
     * @param decimals_ The number of decimals for the token
     */
    function initialize(
        address _owner,
        string memory name_,
        string memory symbol_,
        address minter_,
        address burner_,
        uint8 decimals_
    ) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        // Initialize ERC20 state
        name = name_;
        symbol = symbol_;
        
        // Initialize FundToken state
        minter = minter_;
        burner = burner_;
        _decimals = decimals_;
        
        // Validate addresses
        if (minter_ == address(0)) revert();
        if (burner_ == address(0)) revert();
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev set the minter and burner addresses
     * @param minter_ The address that will have minting permissions
     * @param burner_ The address that will have burning permissions
     */
    function setMinterAndBurner(address minter_, address burner_) external {
        if (!authority.doesUserHaveRole(msg.sender, Role.System_Admin)) revert NotPermissioned();
        minter = minter_;
        burner = burner_;
    }

    /**
     * @dev Modifier to check if caller is the minter
     */
    modifier onlyMinter() {
        if (msg.sender != minter) revert("FundToken: caller is not the minter");
        _;
    }

    /**
     * @dev Modifier to check if caller is the burner
     */
    modifier onlyBurner() {
        if (msg.sender != burner) revert("FundToken: caller is not the burner");
        _;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `to`
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /**
     * @dev Burns `amount` tokens from the account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external onlyBurner {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burns `amount` tokens from `from` address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external onlyBurner {
        _burn(from, amount);
    }

    function decimals() public view returns (uint8) {
        return uint8(_decimals);
    }

}
