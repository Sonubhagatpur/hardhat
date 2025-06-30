// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
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

interface Aggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
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

contract BDIDPresale is Ownable, Pausable {
    IERC20 public token;
    IERC20 public usdt;

    address public paymentWallet;
    mapping(address => uint256) public deposits;
    uint256 public totalTokensSold;
    uint256 public tokenPrice = 100;

    Aggregator public aggregatorInterface;

    constructor() {
        paymentWallet = _msgSender();
        token = IERC20(0x8F7fb353667C49a5Fae413E2B2e2a5Cf6D036C7d);
        usdt = IERC20(0xF3437d26D7e30D968C1ACD7C3505Cc2ad1591802);
        aggregatorInterface = Aggregator(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
    }

    function pause() external onlyOwner returns (bool success) {
        _pause();
        return true;
    }

    function updateToken(address _token) public onlyOwner {
        require(_token != address(0), "Zero address");
        require(isContract(_token), "Not a token address");
        token = IERC20(_token);
    }

    function unpause() external onlyOwner returns (bool success) {
        _unpause();
        return true;
    }

    function changePaymentWallet(
        address _newPaymentWallet
    ) external onlyOwner returns (bool) {
        require(_newPaymentWallet != address(0), "zero payment address");
        require(
            _newPaymentWallet != paymentWallet,
            "This address already setted"
        );
        paymentWallet = _newPaymentWallet;
        return true;
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "contract balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    function sendValue(address recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Payment failed");
    }

    function withdrawTokens(address _token, uint256 amount) external onlyOwner {
        require(isContract(_token), "Invalid contract address");
        require(
            IERC20(_token).balanceOf(address(this)) >= amount,
            "Insufficient tokens"
        );
        IERC20(_token).transfer(_msgSender(), amount);
    }

    function importData(
        address[] calldata _addresses,
        uint256[] calldata _amount
    ) public onlyOwner {
        require(_addresses.length == _amount.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "Invalid address");
            deposits[_addresses[i]] += _amount[i];
        }
    }

    function isContract(address _addr) private view returns (bool iscontract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    modifier checkSaleState(uint256 amount) {
        require(amount > 0, "Invalid amount");
        _;
    }

    function buyWithUSDT(
        uint256 amount
    ) external checkSaleState(amount) whenNotPaused {
        uint256 numOfTokens = calculateToken(amount * 1e12);
        uint256 ourAllowance = usdt.allowance(_msgSender(), address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        usdt.transferFrom(_msgSender(), paymentWallet, amount);
        token.transfer(msg.sender, numOfTokens);
        // deposits[msg.sender] += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function buyWithETH()
        public
        payable
        checkSaleState(msg.value)
        whenNotPaused
    {
        uint256 ethToUsdt = (getLatestPrice() * msg.value) / 1e8;
        uint256 numOfTokens = calculateToken(ethToUsdt);
        sendValue(paymentWallet, msg.value);
        token.transfer(msg.sender, numOfTokens);
        // deposits[msg.sender] += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function calculateToken(uint256 _usdtAmount) public view returns (uint256) {
        uint256 numOfTokens = _usdtAmount * tokenPrice;
        return (numOfTokens / 100);
    }

    function ethBuyHelper(
        uint256 amount
    ) external view returns (uint256 numOfTokens) {
        uint256 ethToUsdt = (getLatestPrice() * amount) / 1e8;
        numOfTokens = calculateToken(ethToUsdt);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        return uint256(price);
    }

    function getTokenBalance() external view returns (uint256 tokenBalance) {
        tokenBalance = token.balanceOf(address(this));
    }

    receive() external payable {
        buyWithETH();
    }
}
