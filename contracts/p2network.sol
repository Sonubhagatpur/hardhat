// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

    /**
     * @dev Throws if called by any account other than the owner.
     */
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

contract Investment {
    uint public minimumDeposit = 10 ether; //10

    uint public minimumWithdraw = 0.05 ether; //5

    uint public maximumWithdraw = 100 ether;

    uint public totalInvestment;

    uint public apy = 4000; //40 for 0.4%

    uint public timeLimit = 20 minutes; // 750 days;

    struct activity {
        address user;
        string _event;
        uint256 amount;
        uint256 time;
    }

    struct Invest {
        uint amount;
        uint depositTime;
        uint timestamp;
        uint256 remaingTime;
    }

    struct Referral {
        address referrer;
        uint256 refferReward;
        address[] referrals;
        uint256[] timestamp;
    }

    mapping(address => bool) public isExits;
    mapping(address => Referral) public userReferrals;
    mapping(address => Invest[]) public investment;
    mapping(address => uint) public totalRewardsWithdraw;
    mapping(uint8 => uint256) public LEVEL_INCOME;
    mapping(address => uint) public remaingRewards;
    mapping(address => uint) public lastClaimRewardsTime;
    activity[] public activities;

    event Staked(
        address indexed user,
        uint256 indexed amount,
        uint256 timestamp
    );
    event RewardsClaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 timestamp
    );
    event RewardsDistributed(
        address indexed recipient,
        uint256 indexed amount,
        uint256 level,
        uint256 timestamp
    );
    event Unstaked(
        address indexed user,
        uint256 indexed amount,
        uint indexed rewards,
        uint256 timestamp
    );
}

contract Polytech is Investment, Ownable, Pausable {
    uint8 public LAST_LEVEL;

    constructor() {
        isExits[_msgSender()] = true;
        LAST_LEVEL = 7;
        LEVEL_INCOME[1] = 5;
        LEVEL_INCOME[2] = 4;
        LEVEL_INCOME[3] = 3;
        LEVEL_INCOME[4] = 2;
        LEVEL_INCOME[5] = 2;
        LEVEL_INCOME[6] = 1;
        LEVEL_INCOME[7] = 1;
    }

    function pause() external onlyOwner returns (bool success) {
        _pause();
        return true;
    }

    function unpause() external onlyOwner returns (bool success) {
        _unpause();
        return true;
    }

    function withdraw(uint _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient Amount");
        sendValue(_msgSender(), _amount);
    }

    function sendValue(
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transaction failed");
        return success;
    }

    function saveActivity(string memory _event, uint256 _amount) private {
        activities.push(
            activity(_msgSender(), _event, _amount, block.timestamp)
        );
    }

    modifier withdrawCheck(uint256 id) {
        Invest memory users = investment[_msgSender()][id];

        require(id < investment[_msgSender()].length, "Invalid enter Id");

        require(
            block.timestamp - users.depositTime > timeLimit,
            "withdrawal time has not come"
        );
        _;
    }

    function distributeReferralsReward(
        address _user,
        uint _amount,
        uint8 level
    ) private {
        address referrer = userReferrals[_user].referrer;

        if (referrer != address(0) && level <= LAST_LEVEL) {
            uint referralReward = (_amount * LEVEL_INCOME[level]) / 100;

            userReferrals[referrer].refferReward += referralReward;

            remaingRewards[referrer] += referralReward;

            emit RewardsDistributed(
                referrer,
                referralReward,
                level,
                block.timestamp
            );

            distributeReferralsReward(referrer, _amount, level + 1);
        }
    }

    function removeId(uint256 indexnum) internal {
        for (
            uint256 i = indexnum;
            i < investment[_msgSender()].length - 1;
            i++
        ) {
            investment[_msgSender()][i] = investment[_msgSender()][i + 1];
        }
        investment[_msgSender()].pop();
    }

    function stake(address _referral) external payable {
        invest(_referral);
    }

    function invest(address _referral) internal whenNotPaused {
        uint _amount = msg.value;
        require(_amount >= minimumDeposit, "Min deposit");
        totalInvestment += _amount;
        investment[_msgSender()].push(
            Invest({
                amount: _amount,
                depositTime: block.timestamp,
                timestamp: block.timestamp,
                remaingTime: timeLimit
            })
        );

        if (
            !isExits[_msgSender()] &&
            _referral != address(0) &&
            _referral != _msgSender() &&
            isExits[_referral]
        ) {
            userReferrals[_msgSender()].referrer = _referral;
            userReferrals[_referral].referrals.push(_msgSender());
            userReferrals[_referral].timestamp.push(block.timestamp);
        }

        isExits[_msgSender()] = true;

        saveActivity("Stake", _amount);

        emit Staked(_msgSender(), _amount, block.timestamp);
    }

    function claimRewards() external whenNotPaused returns (bool) {
        uint256 rewards = calculateRewards(_msgSender()) +
            remaingRewards[_msgSender()];

        require(rewards >= minimumWithdraw, "MINIMUM_REWARDS_FOUND");
        require(
            block.timestamp - lastClaimRewardsTime[_msgSender()] >= 1 days,
            "Claim rewards can be 1 time per day"
        );

        uint256 maxWithdraw;
        if (rewards > maximumWithdraw) {
            uint256 remainingRewards = rewards - maximumWithdraw;
            maxWithdraw = maximumWithdraw - (maximumWithdraw / 20); // 5% fee
            remaingRewards[_msgSender()] = remainingRewards;
        } else {
            maxWithdraw = rewards - (rewards / 20); // 5% fee
            remaingRewards[_msgSender()] = 0;
        }

        bool success = sendValue(_msgSender(), maxWithdraw);
        if (success) {
            totalRewardsWithdraw[_msgSender()] += maxWithdraw;
            emit RewardsClaimed(_msgSender(), maxWithdraw, block.timestamp);
            saveActivity("ClaimRewards", maxWithdraw);
            distributeReferralsReward(_msgSender(), maxWithdraw, 1);

            for (uint256 i = 0; i < investment[_msgSender()].length; i++) {
                Invest storage users = investment[_msgSender()][i];
                uint256 totalTime = block.timestamp - users.timestamp;
                uint256 remainingTime = totalTime >= users.remaingTime
                    ? 0
                    : users.remaingTime - totalTime;
                users.remaingTime = remainingTime;
                users.timestamp = block.timestamp;
            }
        }

        return success;
    }

    function calculateRewards(address _user) public view returns (uint256) {
        uint256 rewards;
        uint256 DIVIDER = 10000;
        for (uint256 i = 0; i < investment[_user].length; i++) {
            Invest memory user = investment[_user][i];

            uint256 totalTime = block.timestamp - user.timestamp;

            uint256 remainingTime = totalTime >= user.remaingTime
                ? user.remaingTime
                : totalTime;

            rewards += (user.amount * apy * remainingTime) / DIVIDER / 1 days;
        }
        return rewards;
    }

    function calculateReward(
        address _user,
        uint256 id
    ) public view returns (uint256 usdtRewards) {
        require(id < investment[_user].length, "Invalid Id");

        Invest memory user = investment[_user][id];
        uint256 DIVIDER = 10000;

        uint256 totalTime = block.timestamp - user.timestamp;

        uint256 remainingTime = totalTime >= user.remaingTime
            ? user.remaingTime
            : totalTime;

        usdtRewards = (user.amount * apy * remainingTime) / DIVIDER / 1 days;

        return usdtRewards;
    }

    function userIndex(address _user) public view returns (uint256) {
        return investment[_user].length;
    }

    function depositAddAmount(
        address _user
    ) public view returns (uint256 amount) {
        uint256 index = investment[_user].length;
        for (uint256 i = 0; i < index; i++) {
            Invest memory users = investment[_user][i];
            amount += users.amount;
        }
        return amount;
    }

    function getmyDirectReferrals(
        address _user
    )
        public
        view
        returns (address[] memory addresses, uint256[] memory timestamp)
    {
        addresses = userReferrals[_user].referrals;
        timestamp = userReferrals[_user].timestamp;
        return (addresses, timestamp);
    }

    function getReferralsReward(address _user) public view returns (uint256) {
        return userReferrals[_user].refferReward;
    }

    function latestActivitiesLength() public view returns (uint256) {
        return activities.length;
    }

    function getActivities(
        uint256 fromId,
        uint256 batchSize
    ) public view returns (activity[] memory) {
        require(fromId < activities.length, "Invalid range");

        uint256 toId = fromId + batchSize;
        if (toId > activities.length) {
            toId = activities.length;
        }

        uint256 numActivities = toId - fromId;
        activity[] memory selectedActivities = new activity[](numActivities);

        for (uint256 i = fromId; i < toId; i++) {
            selectedActivities[i - fromId] = activities[i];
        }

        return selectedActivities;
    }

    receive() external payable {
        if (msg.sender != owner()) {
            invest(address(0));
        }
    }
}
