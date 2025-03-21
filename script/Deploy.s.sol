// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MMFManager} from "../src/core/manager/MMFManager.sol";
import {FundToken} from "../src/core/token/FundToken.sol";
import {RolesAuthority} from "../src/core/authority/RolesAuthority.sol";
import {Role} from "../src/config/roles.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    // Configuration values
    address public constant FUND_ORACLE = 0xa83d79012cC1265436239293EB75071949028DFF; // Fixed checksum
    address public constant UNDERLYING_STABLE = 0x64544969ed7EBf5f083679233325356EbE738930; // Fixed checksum
    address public constant FEE_RECIPIENT = 0x2D1a9871C0948b85Ab02A8c3f72C17D5733F3734; // Fixed checksum

    function run() external {
        // Fetch deployer private key and address from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy RolesAuthority implementation and proxy
        RolesAuthority authorityImpl = new RolesAuthority();
        bytes memory authorityInitData = abi.encodeWithSelector(
            RolesAuthority.initialize.selector,
            deployer
        );
        ERC1967Proxy authorityProxy = new ERC1967Proxy(
            address(authorityImpl),
            authorityInitData
        );
        RolesAuthority authority = RolesAuthority(address(authorityProxy));
        
        // Setup roles in authority
        authority.setUserRole(deployer, Role.System_Admin, true);

        // 2. Deploy FundToken implementation and proxy
        FundToken fundTokenImpl = new FundToken(address(authority));
        bytes memory fundTokenInitData = abi.encodeWithSelector(
            FundToken.initialize.selector,
            deployer,
            "Test Fund Token",
            "TFT",
            address(deployer),
            address(deployer),
            18
        );
        ERC1967Proxy fundTokenProxy = new ERC1967Proxy(
            address(fundTokenImpl),
            fundTokenInitData
        );
        FundToken fundToken = FundToken(address(fundTokenProxy));
        
        // 3. Deploy MMFManager implementation and proxy
        MMFManager mmfManagerImpl = new MMFManager(
            address(fundTokenProxy),    // Use proxy address for fundToken
            FUND_ORACLE,
            address(authorityProxy),    // Use proxy address for authority
            deployer
        );
        bytes memory mmfManagerInitData = abi.encodeWithSelector(
            MMFManager.initialize.selector,
            deployer,                   // _owner
            UNDERLYING_STABLE,
            1e16,                       // _buyFee (1%)
            1e16,                       // _sellFee (1%)
            true,                       // _instantSubscription
            true                        // _instantRedemption
        );
        ERC1967Proxy mmfManagerProxy = new ERC1967Proxy(
            address(mmfManagerImpl),
            mmfManagerInitData
        );
        
        // 4. Set MMFManager proxy as minter and burner in FundToken
        fundToken.setMinterAndBurner(
            address(mmfManagerProxy),  // Use proxy address
            address(mmfManagerProxy)
        );

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("RolesAuthority Implementation:", address(authorityImpl));
        console.log("RolesAuthority Proxy:", address(authorityProxy));
        console.log("FundToken Implementation:", address(fundTokenImpl));
        console.log("FundToken Proxy:", address(fundTokenProxy));
        console.log("MMFManager Implementation:", address(mmfManagerImpl));
        console.log("MMFManager Proxy:", address(mmfManagerProxy));
        console.log("Deployer address:", deployer);
    }
} 