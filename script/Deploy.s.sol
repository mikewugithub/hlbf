// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {FundToken} from "../src/core/token/FundToken.sol";
import {IAuthority} from "../src/interfaces/IAuthority.sol";

contract DeployScript is Script {
    // Configuration values
    address public constant MOCK_AUTHORITY = address(1); // Replace with actual authority address
    address public constant MOCK_ORACLE = address(2); // Replace with actual oracle address
    address public constant MOCK_STABLE = address(3); // Replace with actual stablecoin address
    address public constant FEE_RECIPIENT = address(4); // Replace with actual fee recipient

    function run() external {
        // Fetch deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy FundToken
        FundToken fundToken = new FundToken(MOCK_AUTHORITY);
        
        // Initialize FundToken
        fundToken.initialize(
            "Test Fund Token",  // name
            "TFT"              // symbol
        );

        // 2. Deploy MMFManager with constructor parameters
        MMFManager mmfManager = new MMFManager(
            address(fundToken),    // _ytoken
            MOCK_ORACLE,          // _oracle
            MOCK_AUTHORITY,       // _authority
            FEE_RECIPIENT,        // _feeRecipient
            MOCK_STABLE          // _stable
        );
        
        // Initialize MMFManager with initialize parameters
        mmfManager.initialize(
            address(this),        // _owner
            1e16,                // _buyFee (1%)
            1e16,                // _sellFee (1%)
            true,                // _instantSubscription
            true                 // _instantRedemption
        );

        // 3. Set MMFManager as minter and burner in FundToken
        fundToken.setMinterAndBurner(
            address(mmfManager),  // minter
            address(mmfManager)   // burner
        );

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("FundToken deployed at:", address(fundToken));
        console.log("MMFManager deployed at:", address(mmfManager));
    }
} 