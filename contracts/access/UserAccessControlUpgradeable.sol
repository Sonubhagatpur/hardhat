// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OperatorAccessControlUpgradeable.sol";

abstract contract UserAccessControlUpgradeable is Initializable, OperatorAccessControlUpgradeable {
    mapping(address => bool) private whitelistedUsers;

    event UserWhitelisted(address indexed user);
    event UserRemovedFromWhitelist(address indexed user);

    error NotWhitelistedUser();
    error AlreadyWhitelistedUser();
    error ZeroAddressNotAllowed();

    modifier onlyWhitelistedUser() {
        if (!whitelistedUsers[msg.sender]) revert NotWhitelistedUser();
        _;
    }

    function __UserAccessControl_init() internal onlyInitializing {
        __OperatorAccessControl_init();
    }

    function whitelistUser(address user) external onlyAdminOrOperator {
        _whitelistUser(user);
    }

    function removeWhitelistedUser(address user) external onlyAdminOrOperator {
        _removeWhitelistedUser(user);
    }

    function whitelistMultipleUsers(address[] calldata users) external onlyAdminOrOperator {
        for (uint256 i = 0; i < users.length; i++) {
            _whitelistUser(users[i]);
        }
    }

    function removeMultipleWhitelistedUsers(address[] calldata users) external onlyAdminOrOperator {
        for (uint256 i = 0; i < users.length; i++) {
            _removeWhitelistedUser(users[i]);
        }
    }

    function isUserWhitelisted(address user) public view returns (bool) {
        return whitelistedUsers[user];
    }

    function _whitelistUser(address user) internal {
        if (user == address(0)) revert ZeroAddressNotAllowed();
        if (whitelistedUsers[user]) revert AlreadyWhitelistedUser();
        whitelistedUsers[user] = true;
        emit UserWhitelisted(user);
    }

    function _removeWhitelistedUser(address user) internal {
        if (!whitelistedUsers[user]) revert NotWhitelistedUser();
        whitelistedUsers[user] = false;
        emit UserRemovedFromWhitelist(user);
    }
}
