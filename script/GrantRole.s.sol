// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {RolesAuthority} from "../src/core/authority/RolesAuthority.sol";
import {Role} from "../src/config/roles.sol";

contract GrantRoleScript is Script {
    // Contract addresses
    address public constant AUTHORITY = 0x20F3de7a58EA540Ba30F48603d502a34950cD14C;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address userAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        RolesAuthority authority = RolesAuthority(address(AUTHORITY));
        
        // Setup roles in authority
        authority.setUserRole(userAddress, Role.Investor_Whitelisted, true);
        // authority.setUserRole(userAddress, Role.System_Admin, true);

        vm.stopBroadcast();
    }
} 