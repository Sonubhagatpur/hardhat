// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ERC20Token.sol";

contract Factory {
    address public owner;
    
    // Deployment fees (in wei)
    uint256 public erc20DeploymentFee;
    
    // Token deployment tracking variables
    address[] public erc20TokenAddresses;
    uint256 public erc20TokenCount;

    // Events
    event ERC20TokenCreated(address tokenAddress);
    event FeeTransferred(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);

    // Modifier to restrict certain actions to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor(uint256 _erc20DeploymentFee) {
        owner = msg.sender;
        erc20DeploymentFee = _erc20DeploymentFee;
    }

    // Function to deploy new ERC20 token with deployment fee
    function deployNewERC20Token(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint256 initialSupply,
        address userAddress
    ) public payable returns (address) {
        // Ensure the required deployment fee is sent
        require(msg.value >= erc20DeploymentFee, "Incorrect deployment fee sent");
        uint256 leftFees = msg.value - erc20DeploymentFee;

        // Deploy the new ERC20 token
        ERC20Token t = new ERC20Token(name, symbol, decimals, initialSupply, userAddress);

        // Store the token's address and increase the token count
        erc20TokenAddresses.push(address(t));
        erc20TokenCount += 1;

        emit ERC20TokenCreated(address(t));

        // Transfer the deployment fee to the owner
        if(leftFees > 0 ) payable(msg.sender).transfer(leftFees);
        if(erc20DeploymentFee > 0) payable(owner).transfer(erc20DeploymentFee);

        emit FeeTransferred(owner, erc20DeploymentFee);

        return address(t);
    }    

    // Function to transfer ownership
    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // Function to update deployment fee (Only Owner can update the fee)
    function setDeploymentFees(uint256 _erc20Fee) public onlyOwner {
        erc20DeploymentFee = _erc20Fee;
    }

    // Function to withdraw funds from the contract (Only Owner can withdraw)
    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Function to get the list of ERC-20 token addresses
    function getErc20Tokens() public view returns (address[] memory) {
        return erc20TokenAddresses;
    }

}