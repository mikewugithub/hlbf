// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {FundToken} from "../src/core/token/FundToken.sol";
import {RolesAuthority} from "../src/core/authority/RolesAuthority.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracle} from "./mocks/MockOracle.sol";
import {Role} from "../src/config/roles.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";

contract MMFManagerTest is Test {
    MMFManager public manager;
    MMFManager public managerImplementation;
    MockERC20 public stable;
    FundToken public yToken;
    FundToken public yTokenImplementation;
    MockOracle public oracle;
    RolesAuthority public authority;
    RolesAuthority public authorityImplementation;
    
    address public owner = address(1);
    address public feeRecipient = address(2);
    address public user = address(3);
    
    uint256 constant DEFAULT_BUY_FEE = 0.01e18; // 1%
    uint256 constant DEFAULT_SELL_FEE = 0.01e18; // 1%

    function setUp() public {
        // Deploy mock contracts first
        stable = new MockERC20("Stable", "USDC", 6);
        oracle = new MockOracle();

        // Deploy RolesAuthority implementation
        authorityImplementation = new RolesAuthority();
        
        // Prepare initialization data for authority proxy
        bytes memory authorityInitData = abi.encodeWithSelector(
            RolesAuthority.initialize.selector,
            owner
        );

        // Deploy and initialize authority proxy
        ERC1967Proxy authorityProxy = new ERC1967Proxy(
            address(authorityImplementation),
            authorityInitData
        );
        
        // Cast proxy to RolesAuthority
        authority = RolesAuthority(address(authorityProxy));

        // Setup initial roles
        vm.startPrank(owner);
        authority.setUserRole(owner, Role.System_Admin, true);
        authority.setUserRole(user, Role.Investor_Whitelisted, true);
        authority.setRoleCapability(Role.Investor_Whitelisted, address(manager), 
            MMFManager.subscribe.selector, true);
        vm.stopPrank();

        // Deploy FundToken implementation
        yTokenImplementation = new FundToken(address(authority));
        
        // Prepare initialization data for FundToken proxy
        bytes memory fundTokenInitData = abi.encodeWithSelector(
            FundToken.initialize.selector,
            owner,
            "Test Fund Token",
            "TFT",
            owner,  // initial minter
            owner,  // initial burner
            18
        );

        // Deploy and initialize FundToken proxy
        ERC1967Proxy yTokenProxy = new ERC1967Proxy(
            address(yTokenImplementation),
            fundTokenInitData
        );
        
        // Cast proxy to FundToken
        yToken = FundToken(address(yTokenProxy));

        // Deploy MMFManager implementation
        managerImplementation = new MMFManager(
            address(yToken),
            address(oracle),
            address(authority),
            feeRecipient
        );

        // Prepare initialization data for MMFManager proxy
        bytes memory managerInitData = abi.encodeWithSelector(
            MMFManager.initialize.selector,
            owner,
            address(stable),
            DEFAULT_BUY_FEE,
            DEFAULT_SELL_FEE,
            true,  // instant subscription
            true   // instant redemption
        );

        // Deploy and initialize MMFManager proxy
        ERC1967Proxy managerProxy = new ERC1967Proxy(
            address(managerImplementation),
            managerInitData
        );

        // Cast proxy to MMFManager
        manager = MMFManager(address(managerProxy));

        // Set manager as minter and burner for yToken
        vm.startPrank(owner);
        yToken.setMinterAndBurner(address(manager), address(manager));
        vm.stopPrank();

        // Setup user permissions and approvals
        vm.startPrank(user);
        stable.approve(address(manager), type(uint256).max);
        yToken.approve(address(manager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(owner);
        authority.setRoleCapability(Role.Investor_Whitelisted, address(managerProxy), 
            MMFManager.subscribe.selector, true);
        authority.setRoleCapability(Role.Investor_Whitelisted, address(managerProxy), 
            MMFManager.redeem.selector, true);
        vm.stopPrank();
    }

    function testConstructor() public {
        assertEq(address(manager.ytoken()), address(yToken));
        assertEq(address(manager.oracle()), address(oracle));
        assertEq(address(manager.authority()), address(authority));
        assertEq(address(manager.feeRecipient()), feeRecipient);

        console.log("manager.stable().addreess", address(manager.stable()));

    }

    function testInitialize() public {
        assertEq(address(manager.stable()), address(stable));
        assertEq(manager.buyFee(), DEFAULT_BUY_FEE);
        assertEq(manager.sellFee(), DEFAULT_SELL_FEE);
    }

    function testSetFees() public {
        uint256 newBuyFee = 0.02e18;
        uint256 newSellFee = 0.03e18;

        vm.startPrank(owner);
        manager.setFees(newBuyFee, newSellFee);
        vm.stopPrank();

        assertEq(manager.buyFee(), newBuyFee);
        assertEq(manager.sellFee(), newSellFee);
    }

    function testSetFeesUnauthorized() public {
        vm.startPrank(user);
        vm.expectRevert();
        manager.setFees(0.02e18, 0.03e18);
        vm.stopPrank();
    }

    function testSubscribe() public {
        uint256 stableBalance = 10e6;
        // Mint stable coins to user
        stable.mint(user, stableBalance);
        // Set oracle price to $1
        oracle.setPrice(1e8);

        uint256 subscribeAmount = 1e6; // 100 USDC
        
        vm.startPrank(user);
        uint256 tokensReceived = manager.subscribe(
            subscribeAmount
        );
        vm.stopPrank();

        // Expected tokens received should be 99.99 (100 - 0.01% fee)
        assertEq(tokensReceived, 99e16);
        assertEq(yToken.balanceOf(user), 99e16);
        assertEq(stable.balanceOf(user), 9e6);
    }

    function testSubscribeForUnwhitelisted() public {
        // Remove whitelist from user
        vm.startPrank(owner);
        authority.setUserRole(user, Role.Investor_Whitelisted, false);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        manager.subscribe(
            100e6
        );
        vm.stopPrank();
    }

    function testRedeem() public {
        // Set oracle price to $1
        oracle.setPrice(1e8);

        uint256 redeemAmount = 100e18; // 100 tokens
        
        // Need to mint tokens to user first
        vm.startPrank(address(manager));
        yToken.mint(user, redeemAmount);
        stable.mint(address(manager), 1000000e6);
        vm.stopPrank();
        
        vm.startPrank(user);
        uint256 stableReceived = manager.redeem(
            redeemAmount
        );
        vm.stopPrank();

        // Expected stable received should be 99.99 (100 - 0.01% fee)
        assertEq(stableReceived, 99.99e6);
        assertEq(stable.balanceOf(user), 99.99e6);
        assertEq(yToken.balanceOf(user), 0);
    }

    function testRedeemToUnwhitelisted() public {
        // Remove whitelist from recipient
        vm.startPrank(owner);
        authority.setUserRole(user, Role.Investor_Whitelisted, false);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        manager.redeem(
            100e6
        );
        vm.stopPrank();
    }
}
