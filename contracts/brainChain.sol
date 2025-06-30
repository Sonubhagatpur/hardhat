// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

contract Presale is Ownable, Pausable {
    IBEP20 public token;
    IBEP20 public usdt;

    uint256 public maxTokensToBuy;
    uint256 public totalTokensSold;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public currentStep;

    Aggregator public aggregatorInterface;

    event MaxTokensUpdated(
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );

    constructor() {
        token = IBEP20(0x297C5C7d7a87D29F5aa0A1FFbEc02729bd3A6863);
        usdt = IBEP20(0x4aEbB95f517f2992ea5697AC2808CB2e5Ad43D66);
        aggregatorInterface = Aggregator(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
        setRounds();
        maxTokensToBuy = 25000 ether;
        startTime = block.timestamp;
        endTime = block.timestamp + 730 days;
    }

    struct round {
        uint256 amount;
        uint256 rate;
        uint256 bonus;
        uint256 soldToken;
    }

    round[] public rounds;

    function setRounds() private {
        rounds.push(
            round({amount: 50 * 1e6 ether, rate: 2000, bonus: 25, soldToken: 0})
        );
        rounds.push(
            round({amount: 75 * 1e6 ether, rate: 1250, bonus: 15, soldToken: 0})
        );
        rounds.push(
            round({amount: 100 * 1e6 ether, rate: 1000, bonus: 0, soldToken: 0})
        );
    }

    function setcurrentStep(uint256 step) external onlyOwner {
        round storage setRound = rounds[step];
        require(step < rounds.length, "Invalid rounds Id");
        require(step != currentStep, "This round is already active");
        uint256 ourAllowance = token.allowance(_msgSender(), address(this));
        require(
            setRound.amount <= ourAllowance,
            "Make sure to add enough allowance"
        );
        token.transferFrom(_msgSender(), address(this), setRound.amount);
        currentStep = step;
    }

    function updateRounds(
        uint256 step,
        uint256 amount,
        uint256 rate,
        uint256 bonus
    ) external onlyOwner {
        require(step < rounds.length, "Invalid rounds Id");
        require(amount > 0 || rate > 0 || bonus > 0, "Invalid value");
        round storage setRound = rounds[step];
        if (amount > 0) setRound.amount = amount;
        if (rate > 0) setRound.rate = rate;
        if (bonus > 0) setRound.bonus = bonus;
    }

    function changeMaxTokensToBuy(uint256 _maxTokensToBuy) external onlyOwner {
        require(_maxTokensToBuy > 0, "Zero max tokens to buy value");
        maxTokensToBuy = _maxTokensToBuy;
        emit MaxTokensUpdated(maxTokensToBuy, _maxTokensToBuy, block.timestamp);
    }

    function changeSaleStartTime(uint256 _startTime) external onlyOwner {
        require(block.timestamp <= _startTime, "Sale time in past");
        startTime = _startTime;
    }

    function changeSaleEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime > startTime, "Invalid endTime");
        endTime = _endTime;
    }

    function pause() external onlyOwner returns (bool success) {
        _pause();
        return true;
    }

    function unpause() external onlyOwner returns (bool success) {
        _unpause();
        return true;
    }

    function withdrawBNB() public onlyOwner {
        require(address(this).balance > 0, "contract balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawTokens(address _token, uint256 amount) external onlyOwner {
        require(isContract(_token), "Invalid contract address");
        require(
            IBEP20(_token).balanceOf(address(this)) >= amount,
            "Insufficient tokens"
        );
        IBEP20(_token).transfer(_msgSender(), amount);
    }

    function isContract(address _addr) private view returns (bool iscontract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    modifier checkSaleState(uint256 amount) {
        require(startTime <= block.timestamp, "ICO not start");
        require(endTime >= block.timestamp, "ICO end");
        require(amount > 0, "Invalid amount");
        _;
    }

    function buyWithUSDT(uint256 amount)
        external
        checkSaleState(amount)
        whenNotPaused
    {
        uint256 numOfTokens = calculateToken(amount);
        require(numOfTokens <= maxTokensToBuy, "max tokens buy");
        uint256 ourAllowance = usdt.allowance(_msgSender(), address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        usdt.transferFrom(_msgSender(), address(this), amount);
        token.transfer(_msgSender(), numOfTokens);
        bonusToken(numOfTokens);
        rounds[currentStep].soldToken += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function buyWithBNB()
        external
        payable
        checkSaleState(msg.value)
        whenNotPaused
    {
        uint256 bnbToUsdt = (getLatestPrice() * msg.value) / 1e8;
        uint256 numOfTokens = calculateToken(bnbToUsdt);
        require(numOfTokens <= maxTokensToBuy, "max tokens buy");
        token.transfer(_msgSender(), numOfTokens);
        bonusToken(numOfTokens);
        rounds[currentStep].soldToken += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function bonusToken(uint256 amount) private {
        round memory rounded = rounds[currentStep];
        uint256 bonus = (amount * rounded.bonus) / 100;
        if (bonus > 0) token.transfer(_msgSender(), bonus);
    }

    function calculateToken(uint256 _usdtAmount) public view returns (uint256) {
        uint256 numOfTokens = _usdtAmount * rounds[currentStep].rate;
        return (numOfTokens / 100);
    }

    function bnbBuyHelper(uint256 amount)
        external
        view
        returns (uint256 numOfTokens)
    {
        uint256 bnbToUsdt = (getLatestPrice() * amount) / 1e8;
        numOfTokens = calculateToken(bnbToUsdt);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        return uint256(price);
    }

    function getTokenBalance() public view returns (uint256 tokenBalance) {
        tokenBalance = token.balanceOf(address(this));
    }

    function getUsdtBalance() public view returns (uint256 usdtBalance) {
        usdtBalance = usdt.balanceOf(address(this));
    }

    function getBnbBalance() public view returns (uint256 BNB) {
        BNB = address(this).balance;
    }

    function totalRounds() public view returns (uint256 _rounds) {
        _rounds = rounds.length;
    }

    receive() external payable {}
}
