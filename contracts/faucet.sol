// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract Faucet is Ownable {
    uint256 public distributionAmount;

    mapping(address => uint256) public lastDistributionTime;

    constructor() {
        distributionAmount = 10 ether;
    }

    function requestFaucet(address user) external {
        require(
            lastDistributionTime[user] + (1 days) < block.timestamp,
            "You can only request once per day."
        );

        uint256 balance = address(this).balance;
        require(
            balance >= distributionAmount,
            "Insufficient balance in the faucet."
        );

        lastDistributionTime[user] = block.timestamp;

        payable(user).transfer(distributionAmount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance >= amount, "Insufficient balance in the faucet.");

        payable(owner()).transfer(amount);
    }

    // Function to update the distribution amount (only callable by the owner)
    function updateDistributionAmount(uint256 newAmount) external onlyOwner {
        distributionAmount = newAmount;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
