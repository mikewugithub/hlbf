// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {console} from "forge-std/console.sol";


contract SubscribeScript is Script {
    // Contract addresses
    address public constant MMF_MANAGER = address(0x1AFC9E0230cD4358c167E83e64C3A8312eA8581F); // Replace with actual MMFManager address
    address public constant STABLE_TOKEN = 0x64544969ed7EBf5f083679233325356EbE738930; // Replace with actual stable token address
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address subscriber = vm.addr(deployerPrivateKey);
        
        // Check MMFManager's stable token configuration
        address configuredStable = address(MMFManager(MMF_MANAGER).stable());
        console.log("MMFManager's configured stable token:", configuredStable);
        console.log("Script's STABLE_TOKEN:", STABLE_TOKEN);
        
        // check MMFManager's ytoken address
        address configuredYToken = address(MMFManager(MMF_MANAGER).ytoken());
        console.log("MMFManager's configured ytoken:", configuredYToken);
        console.log("Script's Y Token:", configuredYToken);

        // check MMFManager's oracle address
        address configuredOracle = address(MMFManager(MMF_MANAGER).oracle());
        console.log("MMFManager's configured oracle:", configuredOracle);
        console.log("Script's ORACLE:", configuredOracle);

        // check MMFManager's authority address
        address configuredAuthority = address(MMFManager(MMF_MANAGER).authority());
        console.log("MMFManager's configured authority:", configuredAuthority);
        console.log("Script's AUTHORITY:", configuredAuthority);

        if (configuredStable != STABLE_TOKEN) {
            console.log("WARNING: Configured stable token doesn't match script's STABLE_TOKEN!");
        }
        
        // Get token decimals
        uint8 tokenDecimals = IERC20Metadata(STABLE_TOKEN).decimals();
        console.log("Token decimals:", tokenDecimals);
        
        // Amount to subscribe (adjust based on actual decimals)
        uint256 subscribeAmount = 1 * (10 ** tokenDecimals); // Adjust the first number for how many tokens you want
        
        // Check if the token contract exists and is valid
        uint256 balance = IERC20(STABLE_TOKEN).balanceOf(subscriber);
        console.log("Subscriber balance:", balance);
        console.log("Subscribe amount:", subscribeAmount);
        
        vm.startBroadcast(deployerPrivateKey);
        // First approve the MMFManager to spend your stable tokens
        IERC20(STABLE_TOKEN).approve(MMF_MANAGER, subscribeAmount);
        
        // Check allowance
        uint256 currentAllowance = IERC20(STABLE_TOKEN).allowance(subscriber, MMF_MANAGER);
        console.log("Current allowance:", currentAllowance);
        
        if (balance < subscribeAmount) {
            console.log("ERROR: Insufficient balance");
            console.log("Need:", subscribeAmount);
            console.log("Have:", balance);
            revert("Insufficient balance");
        }

        
        // print out the balance of the subscriber
        console.log("Subscriber balance:", IERC20(STABLE_TOKEN).balanceOf(subscriber));

        // Subscribe to the fund
        MMFManager(MMF_MANAGER).subscribe(subscribeAmount);

        vm.stopBroadcast();
    }
} 