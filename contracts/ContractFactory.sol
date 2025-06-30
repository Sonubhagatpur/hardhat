// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenFactory11 {

    uint256 public deploymentFee;  // Fee for deployment

    // Event to log the deployment of new contracts
    event ContractDeployed(address indexed newContractAddress);

    // Function to deploy a contract using bytecode with constructor arguments
    function deployUsingBytecode(
        bytes memory bytecode,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address owner_
    ) external payable returns (address) {
        // Require that the sender has sent the correct deployment fee
        require(msg.value >= deploymentFee, "Insufficient deployment fee");

        // Refund excess fee (if any)
        if (msg.value > deploymentFee) {
            payable(msg.sender).transfer(msg.value - deploymentFee);
        }

        // Prepare constructor arguments and encode them
        bytes memory constructorArgs = abi.encode(name_, symbol_, decimals_, totalSupply_, owner_);

        // Combine bytecode and constructor arguments
        bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, constructorArgs);

        // Deploy the contract using the provided bytecode and constructor arguments
        address deployedAddress;
        assembly {
            // Deploy the contract with bytecode and constructor arguments
            let bytecodeSize := mload(bytecodeWithArgs)

            // Deploy the contract using `create2` (deterministic deployment)
            deployedAddress := create2(0, add(bytecodeWithArgs, 0x20), bytecodeSize, 0)
            // Check if the contract creation was successful
            if iszero(deployedAddress) {
                revert(0, 0)
            }
        }

        // Emit event after contract deployment
        emit ContractDeployed(deployedAddress);
        return deployedAddress;
    }

    // Function to withdraw the collected fees
    function withdrawFees() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Set deployment fee (only for the contract owner)
    function setDeploymentFee(uint256 _fee) external {
        deploymentFee = _fee;
    }
}
