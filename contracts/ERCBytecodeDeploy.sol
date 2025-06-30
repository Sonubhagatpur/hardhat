// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing OpenZeppelin's ReentrancyGuard
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenFactory is ReentrancyGuard {
    address public owner;
    
    // Deployment fees (in wei)
    uint256 public erc20DeploymentFee;
    uint256 public erc721DeploymentFee;
    
    // Token deployment tracking variables
    address[] public erc20TokenAddresses;
    uint256 public erc20TokenCount;

    address[] public erc721TokenAddresses;
    uint256 public erc721TokenCount;

    // Events
    event ERC20TokenCreated(address tokenAddress);
    event ERC721TokenCreated(address tokenAddress);
    event FeeTransferred(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);

    constructor(){
        owner = msg.sender;
    }

    // Modifier to restrict certain actions to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    // Function to deploy a contract using bytecode with constructor arguments
    function deployNewERC20Token(
        bytes memory bytecode,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address userAddress
    ) external payable nonReentrant returns (address) {
        require(decimals_ > 0, "Decimals must be greater than 0");
        require(userAddress != address(0), "Owner address cannot be the zero address");
        require(totalSupply_ > 0, "Total supply must be greater than 0");

        // Require that the sender has sent the correct deployment fee
        require(msg.value >= erc20DeploymentFee, "Insufficient deployment fee");

        // Refund excess fee (if any)
        if (msg.value > erc20DeploymentFee) {
            (bool success, ) = msg.sender.call{value: msg.value - erc20DeploymentFee}("");
            require(success, "Refund failed");
        }
        
        // Only transfer the fee to the owner if it's greater than 0
        if (erc20DeploymentFee > 0) {
            (bool successFeeTransfer, ) = owner.call{value: erc20DeploymentFee}("");
            require(successFeeTransfer, "Fee transfer failed");
            emit FeeTransferred(owner, erc20DeploymentFee);
        }

        // Prepare constructor arguments and encode them
        bytes memory constructorArgs = abi.encode(name_, symbol_, decimals_, totalSupply_, userAddress);

        // Combine bytecode and constructor arguments
        bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, constructorArgs);

        // Deploy the contract using the provided bytecode and constructor arguments
        address deployedAddress;
        assembly {
            let bytecodeSize := mload(bytecodeWithArgs)
            deployedAddress := create2(0, add(bytecodeWithArgs, 0x20), bytecodeSize, 0)
            if iszero(deployedAddress) {
                revert(0, 0)
            }
        }

        // Store the token's address and increase the token count
        erc20TokenAddresses.push(deployedAddress);
        erc20TokenCount += 1;

        // Emit event after contract deployment
        emit ERC20TokenCreated(deployedAddress);
        return deployedAddress;
    }

    // Similarly for ERC721 deploy function
    function deployNewERC721Token(
        bytes memory bytecode,
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI,
        address userAddress,
        uint256 _maxSupply,
        uint256 _maxMint,
        uint256 _mintRate
    ) external payable nonReentrant returns (address) {
        require(userAddress != address(0), "Owner address cannot be the zero address");

        // Require that the sender has sent the correct deployment fee
        require(msg.value >= erc721DeploymentFee, "Insufficient deployment fee");

        // Refund excess fee (if any)
        if (msg.value > erc721DeploymentFee) {
            (bool success, ) = msg.sender.call{value: msg.value - erc721DeploymentFee}("");
            require(success, "Refund failed");
        }

        // Only transfer the fee to the owner if it's greater than 0
        if (erc721DeploymentFee > 0) {
            (bool successFeeTransfer, ) = owner.call{value: erc721DeploymentFee}("");
            require(successFeeTransfer, "Fee transfer failed");
            emit FeeTransferred(owner, erc721DeploymentFee);
        }

        // Prepare constructor arguments and encode them
        bytes memory constructorArgs = abi.encode(name_, symbol_, baseTokenURI, userAddress, _maxSupply, _maxMint,_mintRate);

        // Combine bytecode and constructor arguments
        bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, constructorArgs);

        // Deploy the contract using the provided bytecode and constructor arguments
        address deployedAddress;
        assembly {
            let bytecodeSize := mload(bytecodeWithArgs)
            deployedAddress := create2(0, add(bytecodeWithArgs, 0x20), bytecodeSize, 0)
            if iszero(deployedAddress) {
                revert(0, 0)
            }
        }

        // Store the token's address and increase the token count
        erc721TokenAddresses.push(deployedAddress);
        erc721TokenCount += 1;

        // Emit event after contract deployment
        emit ERC721TokenCreated(deployedAddress);
        return deployedAddress;
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
    function setDeploymentFees(uint256 _erc20Fee, uint256 _erc721Fee) public onlyOwner {
        erc20DeploymentFee = _erc20Fee;
        erc721DeploymentFee = _erc721Fee;
    }

    // Function to withdraw funds from the contract (Only Owner can withdraw)
    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Function to get the list of ERC-20 token addresses
    function getErc20Tokens() public view returns (address[] memory) {
        return erc20TokenAddresses;
    }

    // Function to get the list of ERC-721 token addresses
    function getErc721Tokens() public view returns (address[] memory) {
        return erc721TokenAddresses;
    }
}