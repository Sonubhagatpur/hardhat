// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
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

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

contract PalmStaking is Ownable, Pausable, ReentrancyGuard {
    uint256 public referralPercentage = 10;
    uint256 public referralMinAmount;

    struct StakePlans {
        uint256 apy;
        uint256 duration;
    }

    struct Invest {
        uint256 planIndex;
        uint256 amount;
        uint256 depositTime;
        uint256 lastWithdrawTime;
        uint256 rewardWithdrawalTime;
        uint256 remainingTime;
        uint256 withdrawRewards;
        bool isUnstake;
    }

    StakePlans[] public plansData;
    mapping(address => Invest[]) public investments;
    mapping(address => address) private referralAddress;
    mapping(address => uint256) private _referralRewards;
    mapping(address => uint256) public totalRewardsWithdrawn;
    mapping(address => bool) public rewardsManagers;
    address[] private rewardsManagerList;
    uint256 public rewardsManagerCount;

    mapping(uint256 => uint256[]) public minTimeWithdrawRewards;

    event Gifted(address indexed from, address indexed to, uint256 amount);
    event Staked(
        address indexed user,
        uint256 indexed amount,
        uint256 duration,
        uint256 rewardTime,
        uint256 timestamp
    );
    event RewardsClaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 timestamp,
        uint256 remainingTime,
        uint256 depositTime
    );
    event Unstaked(
        address indexed user,
        uint256 indexed amount,
        uint256 rewards,
        uint256 totalRewards,
        uint256 timestamp,
        uint256 depositTime
    );
    event ReferralRewardIssued(
        address indexed referrer,
        address indexed referred,
        uint256 referralAmount,
        uint256 depositTime
    );
    event StakePlanUpdated(
        uint256 indexed planIndex,
        uint256 newApy,
        uint256 newDuration
    );

    event UserAddressChanged(address indexed oldUser, address indexed newUser);

    constructor(
        uint[] memory values,
        uint[] memory values1,
        uint[] memory values2
    ) {
        referralMinAmount = 1000 ether;
        setRewardsManagerActive(
            0x9cdB5bC7d2C2fEa59F7D7aCA0e58D299eb4CE1a6,
            true
        );
        plansData.push(StakePlans(3000, 182.64 days));
        plansData.push(StakePlans(4000, 243.52 days));
        plansData.push(StakePlans(6000, 334.84 days));
        setMinTimeWithdrawRewards(0, values);
        setMinTimeWithdrawRewards(1, values1);
        setMinTimeWithdrawRewards(2, values2);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMinTimeWithdrawRewards(
        uint256 planIndex,
        uint[] memory values
    ) public {
        require(planIndex < plansData.length, "Invalid plan index");
        minTimeWithdrawRewards[planIndex] = values;
    }

    function updateStakePlan(
        uint256 planIndex,
        uint256 newApy,
        uint256 newDuration
    ) external onlyOwner {
        require(planIndex < plansData.length, "Invalid plan index");
        require(newDuration > 0, "Duration must be greater than 0");

        StakePlans storage plan = plansData[planIndex];
        if (newApy > 0) plan.apy = newApy;
        plan.duration = newDuration;

        emit StakePlanUpdated(planIndex, newApy, newDuration);
    }

    function updateReferralMinAmount(
        uint256 _referralMinAmount
    ) external onlyOwner {
        referralMinAmount = _referralMinAmount;
    }

    function updateReferralPercentage(
        uint256 _newPercentage
    ) external onlyOwner {
        require(
            _newPercentage < 80,
            "New referral percentage must be less than 80"
        );
        referralPercentage = _newPercentage;
    }

    function setRewardsManagerActive(
        address _rewardsManager,
        bool _isActive
    ) public onlyOwner {
        require(_rewardsManager != address(0), "address cannot be zero");
        bool isExisting = rewardsManagers[_rewardsManager];

        if (_isActive && !isExisting) {
            rewardsManagers[_rewardsManager] = true;
            rewardsManagerList.push(_rewardsManager);
            rewardsManagerCount++;
        }

        if (!_isActive && isExisting) {
            rewardsManagers[_rewardsManager] = false;
            removeRewardsManager(_rewardsManager);
            rewardsManagerCount--;
        }
    }

    function removeRewardsManager(address _rewardsManager) internal {
        for (uint256 i = 0; i < rewardsManagerList.length; i++) {
            if (rewardsManagerList[i] == _rewardsManager) {
                rewardsManagerList[i] = rewardsManagerList[
                    rewardsManagerList.length - 1
                ];
                rewardsManagerList.pop();
                break;
            }
        }
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

    function changeUserAddress(
        address oldUser,
        address newUser
    ) external onlyOwner {
        require(
            oldUser != newUser,
            "New address must be different from old address"
        );
        require(newUser != address(0), "Zero address");
        uint256 investmentsCount = userIndex(oldUser);
        require(investmentsCount > 0, "No investments found for old user");

        for (uint256 i = 0; i < investmentsCount; i++) {
            Invest memory userInvestments = investments[oldUser][i];

            investments[newUser].push(
                Invest({
                    planIndex: userInvestments.planIndex,
                    amount: userInvestments.amount,
                    depositTime: userInvestments.depositTime,
                    lastWithdrawTime: userInvestments.lastWithdrawTime,
                    rewardWithdrawalTime: userInvestments.rewardWithdrawalTime,
                    remainingTime: userInvestments.remainingTime,
                    withdrawRewards: userInvestments.withdrawRewards,
                    isUnstake: userInvestments.isUnstake
                })
            );
        }

        delete investments[oldUser];

        emit UserAddressChanged(oldUser, newUser);
    }

    function _sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transaction failed");
    }

    function stake(
        uint256 planIndex,
        uint256 _minTimeWithdrawReward,
        address _referralAddress
    ) external payable nonReentrant {
        _handleStake(
            msg.sender,
            planIndex,
            _minTimeWithdrawReward,
            _referralAddress
        );
    }

    function giftStake(
        address _to,
        uint256 planIndex,
        uint256 _minTimeWithdrawReward,
        address _referralAddress
    ) external payable nonReentrant {
        require(_to != address(0), "Cannot gift to the zero address");
        _handleStake(_to, planIndex, _minTimeWithdrawReward, _referralAddress);
        emit Gifted(msg.sender, _to, msg.value);
    }

    function _handleStake(
        address _userAddress,
        uint256 planIndex,
        uint256 _minTimeWithdrawReward,
        address _referralAddress
    ) internal whenNotPaused {
        require(planIndex < plansData.length, "Invalid plan index");
        require(msg.value > 0, "Stake amount must be greater than 0");
        require(
            minTimeWithdrawRewards[planIndex].length > _minTimeWithdrawReward,
            "Invalid Rewards process time index"
        );
        uint256 minTimeWithdrawReward = minTimeWithdrawRewards[planIndex][
            _minTimeWithdrawReward
        ];

        investments[_userAddress].push(
            Invest({
                planIndex: planIndex,
                amount: msg.value,
                depositTime: block.timestamp,
                lastWithdrawTime: block.timestamp,
                rewardWithdrawalTime: minTimeWithdrawReward,
                remainingTime: plansData[planIndex].duration,
                withdrawRewards: 0,
                isUnstake: false
            })
        );

        emit Staked(
            _userAddress,
            msg.value,
            plansData[planIndex].duration,
            minTimeWithdrawReward,
            block.timestamp
        );

        uint256 referralDeposit = depositAddAmount(_referralAddress);
        if (
            referralDeposit >= referralMinAmount &&
            referralAddress[_msgSender()] == address(0) &&
            _referralAddress != _userAddress
        ) {
            uint256 referralAmount = (msg.value * referralPercentage) / 100;

            if (referralAmount > 0) {
                _referralRewards[_referralAddress] += referralAmount;
                _sendValue(payable(_referralAddress), referralAmount);

                emit ReferralRewardIssued(
                    _referralAddress,
                    _userAddress,
                    referralAmount,
                    block.timestamp
                );
            }
        }

        referralAddress[_userAddress] = _referralAddress;
    }

    function calculateRewards(
        address user,
        uint256 investIndex
    ) public view returns (uint256) {
        Invest memory investment = investments[user][investIndex];
        StakePlans memory plan = plansData[investment.planIndex];

        uint256 timeStaked = block.timestamp - investment.lastWithdrawTime;
        uint256 apy = plan.apy;
        uint256 duration = plan.duration;
        uint256 remainingTime = timeStaked >= investment.remainingTime
            ? investment.remainingTime
            : timeStaked;
        uint256 rewards = (investment.amount * apy * remainingTime) /
            duration /
            10000;
        return rewards;
    }

    function processRewardClaim(
        uint256 investIndex,
        address userAddress
    ) external whenNotPaused nonReentrant {
        require(
            investments[userAddress].length > investIndex,
            "Invalid investment index"
        );

        require(rewardsManagers[_msgSender()], "Unauthorized access");

        Invest storage investment = investments[userAddress][investIndex];
        uint256 nextWithdrawTime = investment.lastWithdrawTime +
            investment.rewardWithdrawalTime;
        require(nextWithdrawTime < block.timestamp, "Time not reached");

        uint256 rewards = calculateRewards(userAddress, investIndex);
        require(rewards > 0, "No rewards available");

        totalRewardsWithdrawn[userAddress] += rewards;

        _sendValue(payable(userAddress), rewards);

        uint256 totalTime = block.timestamp - investment.lastWithdrawTime;
        uint256 remainingTime = totalTime > investment.remainingTime
            ? 0
            : investment.remainingTime - totalTime;
        investment.remainingTime = remainingTime;
        investment.withdrawRewards += rewards;

        investment.lastWithdrawTime = block.timestamp;

        emit RewardsClaimed(
            userAddress,
            rewards,
            block.timestamp,
            remainingTime,
            investment.depositTime
        );
    }

    function unstake(uint256 investIndex) external whenNotPaused nonReentrant {
        require(
            investments[_msgSender()].length > investIndex,
            "Invalid investment index"
        );

        Invest storage investment = investments[_msgSender()][investIndex];
        uint256 amount = investment.amount;
        require(amount > 0, "No staked amount");
        require(!investment.isUnstake, "Already unstaked");
        require(
            investment.depositTime + plansData[investment.planIndex].duration <=
                block.timestamp,
            "Unstake time not reached"
        );

        uint256 rewards = calculateRewards(_msgSender(), investIndex);

        uint256 totalRewards = rewards + investment.withdrawRewards;

        _sendValue(_msgSender(), amount + rewards);
        investment.withdrawRewards += rewards;
        investment.remainingTime = 0;
        investment.isUnstake = true;
        emit Unstaked(
            _msgSender(),
            amount,
            rewards,
            totalRewards,
            block.timestamp,
            investment.depositTime
        );
    }

    function depositAddAmount(
        address _user
    ) public view returns (uint256 amount) {
        uint256 index = investments[_user].length;
        for (uint256 i = 0; i < index; i++) {
            Invest memory users = investments[_user][i];
            if (!users.isUnstake) {
                amount += users.amount;
            }
        }
        return amount;
    }

    function getStakePlan(
        uint256 index
    ) public view returns (uint256 apy, uint256 duration) {
        require(index < plansData.length, "Index out of bounds");
        StakePlans storage plan = plansData[index];
        return (plan.apy, plan.duration);
    }

    function getRewardsManagers() external view returns (address[] memory) {
        return rewardsManagerList;
    }

    function getMinTimeWithdrawRewards(
        uint256 planIndex
    ) public view returns (uint[] memory) {
        require(planIndex < plansData.length, "Invalid plan index");
        return minTimeWithdrawRewards[planIndex];
    }

    function referralOf(address account) external view returns (uint256) {
        return _referralRewards[account];
    }

    function getReferralAddress(address user) external view returns (address) {
        return referralAddress[user];
    }

    function userIndex(address _user) public view returns (uint256) {
        return investments[_user].length;
    }

    function numberOfPlans() public view returns (uint256) {
        return plansData.length;
    }

    receive() external payable {}
    fallback() external payable {}
}
