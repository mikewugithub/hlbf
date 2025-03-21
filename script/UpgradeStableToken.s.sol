// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IProxy {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function owner() external view returns (address);
    function implementation() external view returns (address);
}

contract UpgradeStableTokenScript is Script {
    address public constant MMF_MANAGER = 0xa34e3c98f7FF644835F193B3a4F8c31F1F95CAE2; // MMFManager proxy
    address public constant NEW_STABLE_TOKEN = 0x64544969ed7EBf5f083679233325356EbE738930;
    address public constant AUTHORITY = 0x20F3de7a58EA540Ba30F48603d502a34950cD14C; // RolesAuthority proxy
    address public constant FUND_ORACLE = 0xa83d79012cC1265436239293EB75071949028DFF;
    address public constant FUND_TOKEN = 0xA29e69B7192Fb03C5DA5B4A3935080291D3EdE23;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Pre-upgrade Checks ===");
        console.log("Deployer address:", deployer);
        console.log("MMFManager address:", MMF_MANAGER);
        console.log("New stable token address:", NEW_STABLE_TOKEN);
        
        // // Check current stable token
        // address currentStable = MMFManager(MMF_MANAGER).stable();
        // console.log("Current stable token:", currentStable);
        
        // // Verify new token implements IERC20Metadata
        // try IERC20Metadata(NEW_STABLE_TOKEN).decimals() returns (uint8 decimals) {
        //     console.log("New token decimals:", decimals);
        //     console.log("New token name:", IERC20Metadata(NEW_STABLE_TOKEN).name());
        //     console.log("New token symbol:", IERC20Metadata(NEW_STABLE_TOKEN).symbol());
        // } catch {
        //     revert("NEW_STABLE_TOKEN does not implement IERC20Metadata");
        // }

        // vm.startBroadcast(deployerPrivateKey);

        // MMFManager mmfManagerImpl = new MMFManager(
        //     FUND_TOKEN,    // Use proxy address for fundToken
        //     FUND_ORACLE,
        //     AUTHORITY,    // Use proxy address for authority
        //     deployer
        // );

        // // get the setstable function from the impl abi
        // bytes memory setStableData = abi.encodeWithSelector(MMFManager.setStable.selector, NEW_STABLE_TOKEN);

        // IProxy(MMF_MANAGER).upgradeToAndCall(address(mmfManagerImpl), setStableData);
        

        vm.stopBroadcast();
    }
} 