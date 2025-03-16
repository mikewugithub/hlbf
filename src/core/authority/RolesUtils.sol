// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Role} from "../../config/roles.sol";

library RolesUtil {
    /**
     * @dev checks if userRole has role
     */
    function doesHaveRole(bytes32 userRoles, Role role) internal pure returns (bool) {
        return (uint256(userRoles) >> uint8(role)) & 1 != 0;
    }

    /**
     * @dev checks if role has capability
     */
    function doesHaveCapability(bytes32 capabilities, Role role) internal pure returns (bool) {
        return (uint256(capabilities) >> uint8(role)) & 1 != 0;
    }
}
