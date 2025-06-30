// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function decimals() external view returns (uint8);
}

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

contract MiPay is Ownable {
    uint256 public nativeFees = 100;
    uint256 public tokenFees = 1;
    uint256 public otherTokenFees = 10;
    address public usdt = 0x4aEbB95f517f2992ea5697AC2808CB2e5Ad43D66;

    function setNativeFees(uint256 _taxFees) external onlyOwner {
        require(_taxFees < 5000, "Max fees");
        nativeFees = _taxFees;
    }

    function setTokenFees(uint256 _taxFees) external onlyOwner {
        tokenFees = _taxFees;
    }

    function setOtherTokenFees(uint256 _taxFees) external onlyOwner {
        otherTokenFees = _taxFees;
    }

    function withdraw() external onlyOwner returns (bool) {
        require(getBnbBalance() > 0, "Insufficient contract balances");
        (bool success, ) = owner().call{value: getBnbBalance()}("");
        require(success, "BNB Payment failed");
        return success;
    }

    function withdrawTokens(address _token) external onlyOwner returns (bool) {
        require(getTokenBalance(_token) > 0, "Insufficient contract balances");
        bool success = tokenInstance(_token).transfer(
            owner(),
            getTokenBalance(_token)
        );
        require(success, "USDT Payment failed");
        return success;
    }

    function sendValue(address recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "BNB Payment failed");
    }

    function transactionFees(address _receipient, uint256 amount)
        external
        onlyOwner
    {
        sendValue(_receipient, amount);
    }

    function send(address payable recipient)
        external
        payable
        checkParameter(recipient, msg.value)
    {
        uint256 tax = (msg.value * nativeFees) / 10000;
        sendValue(recipient, (msg.value - tax));
    }

    function transfer(
        address _token,
        address recipient,
        uint256 amount
    ) external checkParameter(recipient, amount) {
        require(
            tokenInstance(_token).balanceOf(_msgSender()) >= amount,
            "Insufficient amount"
        );
        uint256 ourAllowance = tokenInstance(_token).allowance(
            _msgSender(),
            address(this)
        );
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        if (_token != usdt) {
            tokenFees = otherTokenFees;
        }
        uint256 decimal = tokenInstance(_token).decimals();
        uint256 taxAmount = tokenFees * 10**decimal;
        tokenInstance(_token).transferFrom(
            _msgSender(),
            recipient,
            amount - taxAmount
        );
        if (tokenFees > 0)
            tokenInstance(_token).transferFrom(
                _msgSender(),
                address(this),
                taxAmount
            );
    }

    modifier checkParameter(address _address, uint256 amount) {
        require(_address != address(0), "trnasfer to the zero address");
        require(amount > 0, "Invalid amount");
        _;
    }

    function getBnbBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(address _token) public view returns (uint256) {
        return tokenInstance(_token).balanceOf(address(this));
    }

    function isContract(address _addr) public view returns (bool iscontract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function tokenInstance(address _token) private view returns (IBEP20) {
        require(isContract(_token), "Invalid token Address");
        return IBEP20(_token);
    }

    receive() external payable {}
}
