// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OwnableUpgradeable.sol";

abstract contract OperatorAccessControlUpgradeable is Initializable, OwnableUpgradeable {
    mapping(address => bool) private isOperatorMap;
    address[] private operatorList;

    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    modifier onlyOperator() {
        require(isOperatorMap[msg.sender], "Caller is not an operator");
        _;
    }

    modifier onlyAdminOrOperator() {
        require(msg.sender == owner() || isOperatorMap[msg.sender], "Not admin or operator");
        _;
    }

    function __OperatorAccessControl_init() internal onlyInitializing {
        __Ownable_init();
    }

    function addOperator(address operator) external onlyOwner {
        _addOperator(operator);
    }

    function _addOperator(address operator) internal {
        require(operator != address(0), "Invalid address");
        require(!isOperatorMap[operator], "Already an operator");

        isOperatorMap[operator] = true;
        operatorList.push(operator);

        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        require(isOperatorMap[operator], "Not an operator");

        isOperatorMap[operator] = false;

        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operatorList[i] == operator) {
                operatorList[i] = operatorList[operatorList.length - 1];
                operatorList.pop();
                break;
            }
        }

        emit OperatorRemoved(operator);
    }

    function isOperator(address account) public view returns (bool) {
        return isOperatorMap[account];
    }

    function getOperators() external view returns (address[] memory) {
        return operatorList;
    }
}
