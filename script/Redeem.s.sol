// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {console} from "forge-std/console.sol";

contract RedeemScript is Script {
    // Contract addresses
    address public constant MMF_MANAGER = address(0x1AFC9E0230cD4358c167E83e64C3A8312eA8581F); // Replace with actual MMFManager address
    address public constant FUND_TOKEN = 0x8c9CF15ea9BEA93E5Aaa5533cE57b37F025eae29; // Replace with actual ytoken address
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address redeemer = vm.addr(deployerPrivateKey);
        
        // Get token decimals
        uint8 tokenDecimals = IERC20Metadata(FUND_TOKEN).decimals();
        console.log("Token decimals:", tokenDecimals);
        
        // Amount to redeem (adjust based on actual decimals)
        uint256 redeemAmount = 1 * (10 ** tokenDecimals); // Adjust the first number for how many tokens you want
        
        // Check if the token contract exists and is valid
        uint256 balance = IERC20(FUND_TOKEN).balanceOf(redeemer);
        console.log("Redeemer ytoken balance:", balance);
        console.log("Redeem amount:", redeemAmount);
        
        if (balance < redeemAmount) {
            console.log("ERROR: Insufficient balance");
            console.log("Need:", redeemAmount);
            console.log("Have:", balance);
            revert("Insufficient balance");
        }

        vm.startBroadcast(deployerPrivateKey);
        
        // First approve the MMFManager to spend your ytokens
        IERC20(FUND_TOKEN).approve(MMF_MANAGER, redeemAmount);
        
        // Check allowance
        uint256 currentAllowance = IERC20(FUND_TOKEN).allowance(redeemer, MMF_MANAGER);
        console.log("Current allowance:", currentAllowance);
        
        // print out the balance of the redeemer before redemption
        console.log("Redeemer ytoken balance before:", IERC20(FUND_TOKEN).balanceOf(redeemer));

        // Redeem the tokens
        MMFManager(MMF_MANAGER).redeem(redeemAmount);

        // print out the balance after redemption
        console.log("Redeemer ytoken balance after:", IERC20(FUND_TOKEN).balanceOf(redeemer));

        vm.stopBroadcast();
    }
} 