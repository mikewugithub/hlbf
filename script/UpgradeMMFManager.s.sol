// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {console} from "forge-std/console.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
interface IProxy {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function owner() external view returns (address);
    function implementation() external view returns (address);
}


contract UpgradeAuthorityScript is Script {
    // Contract addresses
    address public constant MMF_MANAGER_PROXY = 0x1AFC9E0230cD4358c167E83e64C3A8312eA8581F; // Current proxy address
    address public constant UNDERLYING_STABLE = 0x64544969ed7EBf5f083679233325356EbE738930; // Fixed checksum


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        // // check the current owner of the proxy
        // address currentOwner = IProxy(MMF_MANAGER_PROXY).owner();
        // console.log("Current owner:", currentOwner);
        // console.log("Deployer:", deployer);
        // require(currentOwner == deployer, "Deployer must be the owner to upgrade");
        
        // Deploy new implementation
        MMFManager newImplementation = new MMFManager(
            address(0x8c9CF15ea9BEA93E5Aaa5533cE57b37F025eae29),
            address(0xa83d79012cC1265436239293EB75071949028DFF),
            address(0x079DBcB0f93bfc1295af73bF357208A1DF0C3e69),
            deployer
        );
        console.log("New implementation:", address(newImplementation));

        bytes memory mmfManagerInitData = abi.encodeWithSelector(
            MMFManager.initialize.selector,
            deployer,                   // _owner
            UNDERLYING_STABLE,
            1e16,                       // _buyFee (1%)
            1e16,                       // _sellFee (1%)
            true,                       // _instantSubscription
            true                        // _instantRedemption
        );

        // Simple upgrade without initialization
        IProxy(MMF_MANAGER_PROXY).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();
    }
} 