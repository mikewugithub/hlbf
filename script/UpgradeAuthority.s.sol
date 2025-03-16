// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {RolesAuthority} from "../src/core/authority/RolesAuthority.sol";
import {console} from "forge-std/console.sol";

interface IProxy {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function owner() external view returns (address);
    function implementation() external view returns (address);
}

contract UpgradeAuthorityScript is Script {
    // Contract addresses
    address public constant AUTHORITY_PROXY = 0x20F3de7a58EA540Ba30F48603d502a34950cD14C; // Current proxy address
    
    // ERC1967 storage slot for implementation
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Check ownership before attempting upgrade
        address currentOwner = IProxy(AUTHORITY_PROXY).owner();
        console.log("Current owner:", currentOwner);
        console.log("Deployer:", deployer);
        
        require(currentOwner == deployer, "Deployer must be the owner to upgrade");

        // Check current implementation
        address currentImpl = address(uint160(uint256(vm.load(AUTHORITY_PROXY, IMPLEMENTATION_SLOT))));
        console.log("Current implementation:", currentImpl);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        RolesAuthority newImplementation = new RolesAuthority();
        console.log("New implementation:", address(newImplementation));

        // Make sure new implementation is different from current
        require(address(newImplementation) != currentImpl, "New implementation same as current");

        // Simple upgrade without initialization
        IProxy(AUTHORITY_PROXY).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();
    }
} 