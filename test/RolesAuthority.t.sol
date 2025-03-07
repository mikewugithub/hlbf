// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RolesAuthority} from "../src/core/authority/RolesAuthority.sol";

contract MockTarget {
    function foo() external pure returns (bool) {
        return true;
    }

    function bar() external pure returns (bool) {
        return true;
    }
}

contract RolesAuthorityTest is Test {
    RolesAuthority auth;
    MockTarget target;
    
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    bytes4 constant FOO_SIG = MockTarget.foo.selector;
    bytes4 constant BAR_SIG = MockTarget.bar.selector;

    function setUp() public {
        auth = new RolesAuthority();
        auth.initialize(owner);
        target = new MockTarget();
        
        // Give this contract (owner) the System_Admin role
        auth.setUserRole(owner, Role.System_Admin, true);
    }

    /*//////////////////////////////////////////////////////////////
                        Initialization Tests
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        RolesAuthority newAuth = new RolesAuthority();
        newAuth.initialize(owner);
        assertEq(newAuth.owner(), owner);
    }

    function testCannotInitializeWithZeroAddress() public {
        RolesAuthority newAuth = new RolesAuthority();
        vm.expectRevert(BadAddress.selector);
        newAuth.initialize(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        Role Management Tests
    //////////////////////////////////////////////////////////////*/

    function testSetUserRole() public {
        auth.setUserRole(user1, Role.System_Admin, true);
        assertTrue(auth.doesUserHaveRole(user1, Role.System_Admin));
    }

    function testRemoveUserRole() public {
        auth.setUserRole(user1, Role.System_Admin, true);
        auth.setUserRole(user1, Role.System_Admin, false);
        assertFalse(auth.doesUserHaveRole(user1, Role.System_Admin));
    }

    function testSetUserRoleBatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        Role[] memory roles = new Role[](2);
        roles[0] = Role.Investor_Basic;
        roles[1] = Role.Investor_Basic;

        bool[] memory enabled = new bool[](2);
        enabled[0] = true;
        enabled[1] = true;

        auth.setUserRoleBatch(users, roles, enabled);

        assertTrue(auth.doesUserHaveRole(user1, Role.Investor_Basic));
        assertTrue(auth.doesUserHaveRole(user2, Role.Investor_Basic));
    }

    /*//////////////////////////////////////////////////////////////
                        Capability Tests
    //////////////////////////////////////////////////////////////*/

    function testSetPublicCapability() public {
        auth.setPublicCapability(address(target), FOO_SIG, true);
        assertTrue(auth.isCapabilityPublic(address(target), FOO_SIG));
        assertTrue(auth.canCall(user1, address(target), FOO_SIG));
    }

    function testSetRoleCapability() public {
        auth.setRoleCapability(Role.Investor_Basic, address(target), FOO_SIG, true);
        auth.setUserRole(user1, Role.Investor_Basic, true);
        
        assertTrue(auth.doesRoleHaveCapability(Role.Investor_Basic, address(target), FOO_SIG));
        assertTrue(auth.canCall(user1, address(target), FOO_SIG));
    }

    /*//////////////////////////////////////////////////////////////
                        Ownership Tests
    //////////////////////////////////////////////////////////////*/

    function testTransferOwnership() public {
        auth.transferOwnership(user1);
        assertEq(auth.owner(), user1);
    }

    function testCannotTransferOwnershipIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(Unauthorized.selector);
        auth.transferOwnership(user2);
    }

    /*//////////////////////////////////////////////////////////////
                        Pause Tests
    //////////////////////////////////////////////////////////////*/

    function testPause() public {
        auth.pause();
        vm.expectRevert(Unauthorized.selector);
        auth.canCall(user1, address(target), FOO_SIG);
    }

    function testUnpause() public {
        auth.pause();
        auth.unpause();
        
        // Set up a valid capability to test
        auth.setPublicCapability(address(target), FOO_SIG, true);
        assertTrue(auth.canCall(user1, address(target), FOO_SIG));
    }

    /*//////////////////////////////////////////////////////////////
                        Authorization Tests
    //////////////////////////////////////////////////////////////*/

    function testOnlyOwnerCanSetSystemFundAdmin() public {
        // Should succeed when called by owner
        auth.setUserRole(user1, Role.System_FundAdmin, true);
        assertTrue(auth.doesUserHaveRole(user1, Role.System_FundAdmin));

        // Should fail when called by non-owner
        vm.prank(user2);
        vm.expectRevert(Unauthorized.selector);
        auth.setUserRole(user1, Role.System_FundAdmin, true);
    }

    function testCannotCallWithoutPermission() public {
        assertFalse(auth.canCall(user1, address(target), FOO_SIG));
    }

    function testInvalidArrayLength() public {
        address[] memory users = new address[](2);
        Role[] memory roles = new Role[](1);
        bool[] memory enabled = new bool[](2);

        vm.expectRevert(InvalidArrayLength.selector);
        auth.setUserRoleBatch(users, roles, enabled);
    }
} 