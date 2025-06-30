// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
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
        _setOwner(0x3a70e20f92F61F90E6603C8ddBD863328eA5Bb5c);
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

contract CXCPresale is Ownable, Pausable {
    IERC20 public token;
    IERC20 public usdt;

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
        token = IERC20(0xDe6275Ea2DD7566397f01dd7A9C9D710FB7F1C9e);
        usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        aggregatorInterface = Aggregator(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        maxTokensToBuy = 25000 ether;
        startTime = block.timestamp;
        endTime = block.timestamp + 730 days;
        setRounds();
    }

    struct round {
        uint256 amount;
        uint256 rate;
        uint256 soldToken;
    }

    struct user {
        uint256 amount;
        uint256 remaining;
        uint256 buyTime;
        uint256 checkTime;
        uint256 quarter;
    }
    mapping(address => user[]) public deposits;

    round[] public rounds;

    function setRounds() private {
        rounds.push(round({amount: 25000000 ether, rate: 3030, soldToken: 0}));
        rounds.push(round({amount: 40000000 ether, rate: 2500, soldToken: 0}));
        rounds.push(round({amount: 10000000 ether, rate: 1739, soldToken: 0}));
    }

    function setcurrentStep(uint256 step) public onlyOwner {
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
        uint256 rate
    ) external onlyOwner {
        require(step < rounds.length, "Invalid rounds Id");
        require(amount > 0 || rate > 0, "Invalid value");
        round storage setRound = rounds[step];
        if (amount > 0) setRound.amount = amount;
        if (rate > 0) setRound.rate = rate;
    }

    function changeMaxTokensToBuy(uint256 _maxTokensToBuy) external onlyOwner {
        require(_maxTokensToBuy > 0, "Zero max tokens to buy value");
        maxTokensToBuy = _maxTokensToBuy;
        emit MaxTokensUpdated(maxTokensToBuy, _maxTokensToBuy, block.timestamp);
    }

    function changeSaleStartTime(uint256 _startTime) external onlyOwner {
        require(block.timestamp < _startTime, "Sale time in past");
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

    function withdrawETH() public onlyOwner {
        require(address(this).balance > 0, "contract balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawTokens(address _token, uint256 amount) external onlyOwner {
        require(isContract(_token), "Invalid contract address");
        require(
            IERC20(_token).balanceOf(address(this)) >= amount,
            "Insufficient tokens"
        );
        IERC20(_token).transfer(_msgSender(), amount);
    }

    function isContract(address _addr) private view returns (bool iscontract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    modifier checkSaleState(uint256 amount) {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Invalid time for buying"
        );
        require(amount > 0, "Invalid amount");
        _;
    }

    modifier checkClaimTime(uint256 id) {
        user memory users = deposits[_msgSender()][id];
        require(users.remaining > 0, "You have no remaining tokens");
        require(
            block.timestamp > users.checkTime + 91.31 days,
            "claim time not reached yet"
        );
        _;
    }

    function removeId(uint256 indexnum) internal {
        for (uint256 i = indexnum; i < deposits[_msgSender()].length - 1; i++) {
            deposits[_msgSender()][i] = deposits[_msgSender()][i + 1];
        }
        deposits[_msgSender()].pop();
    }

    function buyWithUSDT(
        uint256 amount
    ) external checkSaleState(amount) whenNotPaused {
        uint256 numOfTokens = calculateToken(amount * 1e12);
        require(numOfTokens <= maxTokensToBuy, "max tokens buy");
        uint256 ourAllowance = usdt.allowance(_msgSender(), address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        uint256 instantTokens = (numOfTokens * 20) / 100;
        uint256 remaingTokens = numOfTokens - instantTokens;
        usdt.transferFrom(_msgSender(), address(this), amount);
        token.transfer(_msgSender(), instantTokens);
        deposits[_msgSender()].push(
            user(
                numOfTokens,
                remaingTokens,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        rounds[currentStep].soldToken += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function buyWithETH()
        external
        payable
        checkSaleState(msg.value)
        whenNotPaused
    {
        uint256 ethToUsdt = (getLatestPrice() * msg.value) / 1e8;
        uint256 numOfTokens = calculateToken(ethToUsdt);
        require(numOfTokens <= maxTokensToBuy, "max tokens buy");
        uint256 instantTokens = (numOfTokens * 20) / 100;
        token.transfer(_msgSender(), instantTokens);
        uint256 remaingTokens = numOfTokens - instantTokens;
        deposits[_msgSender()].push(
            user(
                numOfTokens,
                remaingTokens,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        rounds[currentStep].soldToken += numOfTokens;
        totalTokensSold += numOfTokens;
    }

    function claim(uint256 id) external checkClaimTime(id) {
        require(id < deposits[_msgSender()].length, "Not enough records");
        user storage users = deposits[_msgSender()][id];
        uint256 quartersTokens = (users.amount * 10) / 100;
        token.transfer(_msgSender(), quartersTokens);
        users.remaining = users.remaining - quartersTokens;
        users.checkTime = block.timestamp;
        users.quarter += 1;
        if (users.quarter == 8) {
            removeId(id);
        }
    }

    function getContractBalacne() public view returns (uint256 cxc) {
        return token.balanceOf(address(this));
    }

    function calculateToken(uint256 _usdtAmount) public view returns (uint256) {
        uint256 numOfTokens = _usdtAmount * rounds[currentStep].rate;
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

    function getCxcBalance() public view returns (uint256 cxcBalance) {
        cxcBalance = token.balanceOf(address(this));
    }

    function getUsdtBalance() public view returns (uint256 cxcBalance) {
        cxcBalance = usdt.balanceOf(address(this));
    }

    function getEthBalance() public view returns (uint256 ETH) {
        ETH = address(this).balance;
    }

    function totalRounds() public view returns (uint256 _rounds) {
        _rounds = rounds.length;
    }

    function userDepositIndex(address _user) public view returns (uint256) {
        return deposits[_user].length;
    }

    receive() external payable {}
}
