// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract Context {
    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract Pausable is Context {
    event Paused(address account);

    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract PalmICO is Ownable, Pausable {
    address public paymentWallet;
    address public developerWallet;
    uint256 public referralPercentage; // Percentage for referral rewards, e.g., 1000 for 10%
    mapping(address => bool) public isExits;

    enum CurrencyType {
        Native,
        Token
    }

    struct Deposit {
        CurrencyType currencyType;
        uint256 amount;
        address token;
    }
    mapping(address => Deposit[]) public deposits;
    mapping(address => bool) public isSupportedToken;

    event DepositMade(
        address indexed user,
        CurrencyType currencyType,
        uint256 amount
    );
    event ReferralReward(
        address indexed referrer,
        address indexed user,
        uint256 amount
    );
    event ReferralPercentageUpdated(uint256 newPercentage);
    event PaymentWalletUpdated(address newPaymentWallet);
    event DeveloperWalletUpdated(address newDeveloperWallet);
    event PurchaseMade(
        address indexed user,
        CurrencyType currencyType,
        uint256 amount
    );
    event SaleMade(address indexed user, address token, uint256 amount);

    constructor() {
        paymentWallet = _msgSender();
        developerWallet = _msgSender();
        isSupportedToken[0xe41E2BD1F843B78663e71D1852623d735072a190] = true;
    }

    modifier onlyOwnerOrDeveloper() {
        require(
            _msgSender() == owner() || _msgSender() == developerWallet,
            "Caller is not the owner or developer wallet"
        );
        _;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient Amount");
        _sendValue(payable(_msgSender()), _amount);
    }

    function withdrawTokens(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(_token != address(0), "Token address is null");
        IERC20 token = IERC20(_token);
        require(
            _amount > 0 && token.balanceOf(address(this)) >= _amount,
            "Amount should not be zero or more than contract balance"
        );
        token.transfer(_msgSender(), _amount);
    }

    function _sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transaction failed");
    }

    function buy(
        address _token,
        address _referralAddress,
        uint256 _amount
    ) public payable whenNotPaused {
        address referrer = isExits[_referralAddress]
            ? _referralAddress
            : address(0);
        uint256 amount = msg.value > 0 ? msg.value : _amount;
        uint256 referralAmount = (amount * referralPercentage) / 10000; // Assuming percentage is in basis points (e.g., 1000 = 10%)
        uint256 seventyPercentage = ((amount - referralAmount) * 70) / 100;

        CurrencyType currencyType = msg.value > 0
            ? CurrencyType.Native
            : CurrencyType.Token;

        if (msg.value > 0) {
            _sendValue(payable(paymentWallet), seventyPercentage);
            if (referrer != address(0)) {
                _sendValue(payable(referrer), referralAmount);
                emit ReferralReward(referrer, _msgSender(), referralAmount);
            }
        } else {
            require(isSupportedToken[_token], "Token not supported");
            IERC20 token = IERC20(_token);
            token.transferFrom(
                _msgSender(),
                address(this),
                amount - seventyPercentage
            );
            token.transferFrom(_msgSender(), paymentWallet, seventyPercentage);
            if (referrer != address(0)) {
                token.transferFrom(_msgSender(), referrer, referralAmount);
                emit ReferralReward(referrer, _msgSender(), referralAmount);
            }
        }

        // Record the deposit history
        deposits[_msgSender()].push(
            Deposit({currencyType: currencyType, amount: amount, token: _token})
        );
        emit PurchaseMade(_msgSender(), currencyType, amount);
    }

    function setPaymentWallet(address _paymentWallet) external onlyOwner {
        paymentWallet = _paymentWallet;
        emit PaymentWalletUpdated(_paymentWallet);
    }

    function setDeveloperWallet(address _developerWallet) external onlyOwner {
        developerWallet = _developerWallet;
        emit DeveloperWalletUpdated(_developerWallet);
    }

    function setReferralPercentage(
        uint256 _referralPercentage
    ) external onlyOwner {
        require(_referralPercentage <= 10000, "Referral percentage too high"); // Max 100%
        referralPercentage = _referralPercentage;
        emit ReferralPercentageUpdated(_referralPercentage);
    }

    function sell(
        address _token,
        address userAddress,
        uint256 _amount
    ) public payable onlyOwnerOrDeveloper {
        if (msg.value > 0) {
            require(
                address(this).balance >= msg.value,
                "Insufficient contract balance for sale"
            );
            _sendValue(payable(userAddress), msg.value);
        } else {
            require(isSupportedToken[_token], "Token not supported");
            IERC20 token = IERC20(_token);
            require(
                token.balanceOf(address(this)) >= _amount,
                "Insufficient contract token balance for sale"
            );
            token.transfer(userAddress, _amount);
        }
        emit SaleMade(userAddress, _token, _amount);
    }
}
