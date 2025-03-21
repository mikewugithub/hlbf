// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {Role} from "../../config/roles.sol";
import {RolesUtil} from "./RolesUtils.sol";

import {IAuthority} from "../../interfaces/IAuthority.sol";

import "../../config/errors.sol";

/// @notice Role based Authority that supports up to 256 roles.
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/authorities/RolesAuthority.sol)
contract RolesAuthority is IAuthority, Initializable, UUPSUpgradeable {
    using RolesUtil for bytes32;
    /*///////////////////////////////////////////////////////////////
                         Immutables
    //////////////////////////////////////////////////////////////*/

    address public owner;

    bool private _paused;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);

    event PublicCapabilityUpdated(address indexed target, bytes4 indexed functionSig, bool enabled);

    event RoleCapabilityUpdated(uint8 indexed role, address indexed target, bytes4 indexed functionSig, bool enabled);

    event Paused(address account);

    event Unpaused(address account);

    /*///////////////////////////////////////////////////////////////
                            Initializer
    //////////////////////////////////////////////////////////////*/

    function initialize(address _owner) external initializer {
        if (_owner == address(0)) revert BadAddress();

        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bytes32) public getUserRoles;

    mapping(address => mapping(bytes4 => bool)) public isCapabilityPublic;

    mapping(address => mapping(bytes4 => bytes32)) public getRolesWithCapability;

    function doesUserHaveRole(address user, Role role) public view virtual returns (bool) {
        if (_paused) revert Unauthorized();

        return getUserRoles[user].doesHaveRole(role);
    }

    function doesRoleHaveCapability(Role role, address target, bytes4 functionSig) public view virtual returns (bool) {
        if (_paused) revert Unauthorized();

        return getRolesWithCapability[target][functionSig].doesHaveCapability(role);
    }

    /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function canCall(address user, address target, bytes4 functionSig) public view virtual override returns (bool) {
        if (_paused) revert Unauthorized();

        return isCapabilityPublic[target][functionSig]
            || bytes32(0) != getUserRoles[user] & getRolesWithCapability[target][functionSig];
    }

    /*//////////////////////////////////////////////////////////////
                   ROLE CAPABILITY CONFIGURATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function _assertOwner() internal view {
        if (msg.sender != owner) revert Unauthorized();
    }

    function _isSystemAdmin() internal view returns (bool) {
        return doesUserHaveRole(msg.sender, Role.System_Admin);
    }

    function _assertSystemAdmin() internal view {
        if (!_isSystemAdmin()) revert Unauthorized();
    }

    function _assertPermissions() internal view {
        if (!_isSystemAdmin()) {
            if (!canCall(msg.sender, address(this), msg.sig)) revert Unauthorized();
        }
    }

    function setPublicCapability(address target, bytes4 functionSig, bool enabled) public virtual {
        _assertPermissions();

        isCapabilityPublic[target][functionSig] = enabled;

        emit PublicCapabilityUpdated(target, functionSig, enabled);
    }

    function setRoleCapability(Role role, address target, bytes4 functionSig, bool enabled) public virtual {
        role == Role.System_Admin ? _assertOwner() : _assertPermissions();

        if (enabled) {
            getRolesWithCapability[target][functionSig] |= bytes32(1 << uint8(role));
        } else {
            getRolesWithCapability[target][functionSig] &= ~bytes32(1 << uint8(role));
        }

        emit RoleCapabilityUpdated(uint8(role), target, functionSig, enabled);
    }

    /*//////////////////////////////////////////////////////////////
                       USER ROLE ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _setUserRole(address user, Role role, bool enabled) internal virtual {
        if (enabled) {
            getUserRoles[user] |= bytes32(1 << uint8(role));
        } else {
            getUserRoles[user] &= ~bytes32(1 << uint8(role));
        }

        emit UserRoleUpdated(user, uint8(role), enabled);
    }

    function setUserRole(address user, Role role, bool enabled) public virtual {
        if (role == Role.System_Admin) _assertOwner();
        
        _setUserRole(user, role, enabled);
    }


    function setUserRoleBatch(address[] memory users, Role[] memory roles, bool[] memory enabled) public virtual {
        _assertPermissions();

        uint256 length = users.length;
        if (length == 0 || length != roles.length || length != enabled.length) revert InvalidArrayLength();

        for (uint256 i; i < length;) {
            _setUserRole(users[i], roles[i], enabled[i]);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses
     * @dev reverts on any check of permissions preventing any movement of funds
     *      between vault, auction, and option protocol
     */
    function pause() public {
        _assertPermissions();

        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses
     */
    function unpause() public {
        _assertOwner();

        _paused = false;
        emit Unpaused(msg.sender);

    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public {
        _assertOwner();

        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }

    /*///////////////////////////////////////////////////////////////
                    Override Upgrade Permission
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Upgradable by the owner.
     *
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override {
        _assertOwner();
    }
}