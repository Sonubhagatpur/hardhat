// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
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

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
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

contract EcoAiCoinPresale is Ownable, Pausable {
    IERC20 public token;
    IERC20 public usdt;
    uint256 public rate;
    uint256 public totalsupply;
    uint256 public presaleEndTime;
    address public paymentWallet;
    uint256 public minper = 10;
    uint256 public maxper = 30;
    uint256 public startTime = block.timestamp;
    uint256 public soldtokens;
    uint256 public usdtRaised;
    Aggregator public aggregatorInterface;

    struct user {
        uint256 amount;
        uint256 tokenBalance;
    }

    mapping(address => user) public users;

    constructor() {
        paymentWallet = 0x75239AFc9CaDcd1F50A2B9BdDBeB4744631AB280;
        token = IERC20(0xF8908E926ECe87ebEBc63FC9c34Fe5FC0076d3d6);
        usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        aggregatorInterface = Aggregator(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        totalsupply = 600000000 ether;
        rate = 125;
        presaleEndTime = block.timestamp + 180 days;
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        return uint256(price);
    }

    function sendValue(address recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Payment failed");
    }

    function buyWithETH() external payable {
        bool _checksale = checkPresale();
        require(!_checksale, "presale end");
        
        uint256 ethToUsdt = (getLatestPrice() * msg.value) / 1e8;
        uint256 numOfTokens = calculateToken(ethToUsdt);
        sendValue(paymentWallet, msg.value);
        soldtokens += numOfTokens;
        usdtRaised += ethToUsdt;
        users[msg.sender].amount += ethToUsdt;
        users[msg.sender].tokenBalance += numOfTokens;
    }

    function buyWithUSDT(uint256 amount) external payable {
        bool _checksale = checkPresale();
        require(!_checksale, "presale end");
        uint256 ourAllowance = usdt.allowance(_msgSender(), address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        uint256 numOfTokens = calculateToken(amount * 1e12);

        usdt.transferFrom(_msgSender(), paymentWallet, amount);

        soldtokens +=  numOfTokens;
        usdtRaised += amount;
        users[msg.sender].amount += amount;
        users[msg.sender].tokenBalance += numOfTokens;
    }

    function checkPresale() public view returns (bool) {
        uint256 minPercentage = (totalsupply * minper) / 100;
        uint256 maxPercentage = (totalsupply * maxper) / 100;
        if (soldtokens >= minPercentage && soldtokens <= maxPercentage && block.timestamp >= presaleEndTime) {
            return true;
        } else if (
            soldtokens >= minPercentage && block.timestamp >= presaleEndTime
        ) {
            return true;
        } else {
            return false;
        }
    }

    function ClaimToken() external  {
        bool _checksale = checkPresale();
        require(_checksale, "presale not end");
        require(
            users[msg.sender].tokenBalance > 0,
            "No contribution to withdraw"
        );

        uint256 tokensToWithdraw = users[msg.sender].tokenBalance;

        token.transfer(msg.sender, tokensToWithdraw);
        users[msg.sender].tokenBalance = 0;
    }

    function calculateToken(uint256 _amount) public view returns (uint256) {
        uint256 numOfTokens = (_amount * 10000) / rate;
        return (numOfTokens);
    }

    function usdtBuyHelper(uint256 amount)
        external
        view
        returns (uint256 numOfTokens)
    {
        numOfTokens = calculateToken(amount * 1e12);
    }

    function ethBuyHelper(uint256 amount)
        external
        view
        returns (uint256 numOfTokens)
    {
        uint256 ethToUsdt = (getLatestPrice() * amount) / 1e8;
        numOfTokens = calculateToken(ethToUsdt);
    }

    function AdminWithdrawalUnSoldToken() external onlyOwner {
        uint256 unsoldTokens = token.balanceOf(address(this));
        token.transfer(owner(), unsoldTokens);
    }

    function AdminWithdrawalFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient Balance");
        sendValue(paymentWallet, balance);
        
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


    function getTokenBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getUsdtBalance() public view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getEthBalance() public view returns (uint256 ETH) {
        ETH = address(this).balance;
        return ETH;
    }

    function setRate(uint256 _rate) public onlyOwner {
        rate = _rate;
    }

    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        totalsupply = _totalSupply;
    }

    function setPresaleEndDays(uint256 _days) public  onlyOwner{
        presaleEndTime = (1 days * _days) + startTime;
    }

    function setMinPercentage(uint256 _minPer) public onlyOwner{       
        require(_minPer < maxper," min percentage should be lesser than max percentage");
        minper = _minPer;
    }

    
    function setMaxPercentage(uint256 _maxper) public onlyOwner{
        require(_maxper<100,"percentage should be lesser than 100");      
        maxper = _maxper;
    }

    receive() external payable {}
}