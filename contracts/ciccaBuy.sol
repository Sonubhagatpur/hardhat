// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return payable(msg.sender);
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(msg.sender);
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

contract BUYCICCA is Ownable {
    address public paymentWallet;

    uint256 public priceFeed;

    constructor() {
        paymentWallet = _msgSender();
        priceFeed = 100;
    }

    function changePaymentWallet(address _newPaymentWallet)
        external
        onlyOwner
        returns (bool)
    {
        require(_newPaymentWallet != address(0), "zero payment address");
        require(
            _newPaymentWallet != paymentWallet,
            "This address already setted"
        );
        paymentWallet = _newPaymentWallet;
        return true;
    }

    function changePriceFeed(uint256 _newPriceFeed)
        external
        onlyOwner
        returns (bool)
    {
        require(_newPriceFeed != 0, "Invalid price");
        priceFeed = _newPriceFeed;
        return true;
    }

    function withdraw(uint256 amount)
        external
        checkPartameter(_msgSender(), amount)
        onlyOwner
    {
        sendValue(_msgSender(), amount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    modifier checkPartameter(address _user, uint256 _amount) {
        require(_user != address(0), "receiver zero address");
        require(_amount > 0, "Invalid amount");
        _;
    }

    function sendValue(address recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "cicca Payment failed");
    }

    function buyCicca(address _recipient, uint256 _amount)
        external
        checkPartameter(_recipient, _amount)
        onlyOwner
    {
        uint256 ciccaAmount = (_amount * priceFeed) / 100;
        sendValue(_recipient, ciccaAmount);
    }

    receive() external payable {}
}
