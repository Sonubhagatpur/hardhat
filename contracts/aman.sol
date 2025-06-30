// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {

    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
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

abstract contract Blacklist is Ownable {
    mapping(address => bool) private blacklisted;

    event AddedToBlacklist(address account);
    event RemovedFromBlacklist(address account);

    modifier notBlacklisted() {
        require(!isBlacklisted(_msgSender()), "User is blacklisted");
        _;
    }

    error ZeroAddressCannotBlacklisted();
    error AccountAlreadyBlacklisted();
    error AccountNotBlacklisted();

    function addToBlacklist(address account) public onlyOwner {
        if (account == address(0)) revert ZeroAddressCannotBlacklisted();
        if (blacklisted[account]) revert AccountAlreadyBlacklisted();
        _addToBlacklist(account);
    }

    function removeFromBlacklist(address account) public onlyOwner {
        if (!blacklisted[account]) revert AccountNotBlacklisted();
        _removeFromBlacklist(account);
    }

    function batchBlacklist(
        address[] memory accounts,
        bool toBeBlacklisted
    ) public onlyOwner {
        for (uint256 i; i < accounts.length; ++i) {
            toBeBlacklisted
                ? _addToBlacklist(accounts[i])
                : _removeFromBlacklist(accounts[i]);
        }
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _isBlacklisted(account);
    }

    function _addToBlacklist(address account) internal {
        blacklisted[account] = true;
        emit AddedToBlacklist(account);
    }

    function _removeFromBlacklist(address account) internal {
        blacklisted[account] = false;
        emit RemovedFromBlacklist(account);
    }

    function _isBlacklisted(address account) internal view returns (bool) {
        return blacklisted[account];
    }
}

contract BasicStaking {
    address internal constant ZERO_ADDRESS = address(0);

    enum UserType {
        Individual,
        Business
    }

    struct Plan {
        address tokenContract;
        UserType userType;
        uint256[] durations; // Array of durations in days
        uint256[] rewardRates; // Array of reward rates per day in thousandths
        uint256[] tax;
    }

    struct Stake {
        UserType userType;
        address tokenContract;
        uint256 amount;
        uint256 depositTime;
        uint256 duration;
        uint256 rewardRate;
        uint256 taxPercentage;
        uint256 withdrawRewards;
        bool isStaked;
        bool isSale;
        uint256 salePrice;  // Price for selling the stake
    }

    Plan[] public plans;
    mapping(address => Stake[]) public userStakes;

    event Staked(address indexed user, uint256 planIndex, uint256 amount);
    event Unstaked(
        address indexed user,
        uint256 planIndex,
        uint256 amount,
        uint256 reward
    );
    event NewPlanAdded(
        address indexed tokenAddress,
        uint256 duration,
        uint256 rewardRate
    );
    event PlanUpdated(uint256 indexed planIndex);
    event StakeForSale(address indexed user, uint256 indexed stakeIndex, uint256 price);
    event StakePurchased(
        address indexed buyer,
        address indexed seller,
        uint256 indexed stakeIndex,
        uint256 price
    );
    event StakeSaleCancelled(address indexed user, uint256 indexed stakeIndex);

    function sendValue(
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Payment failed");
        return success;
    }

    function getNumberOfPlans() external view returns (uint256) {
        return plans.length;
    }

    function getPlan(uint256 planIndex) external view  returns (
            address tokenContract,
            UserType userType,
            uint256[] memory durations,
            uint256[] memory rewardRates
        )
    {
        require(planIndex < plans.length, "Plan index out of bounds");

        Plan memory plan = plans[planIndex];
        return (
            plan.tokenContract,
            plan.userType,
            plan.durations,
            plan.rewardRates
        );
    }
}

contract Aman is BasicStaking, Blacklist, Pausable {
    constructor(
        address[] memory _tokenContracts,
        UserType[] memory _userTypes,
        uint256[][] memory _durations,
        uint256[][] memory _rewardRates,
        uint256[][] memory _tax
    ) {
        require(
            _tokenContracts.length == _userTypes.length &&
                _tokenContracts.length == _durations.length &&
                _tokenContracts.length == _rewardRates.length &&
                _tokenContracts.length == _tax.length,
            "Array lengths must be equal"
        );

        for (uint256 i = 0; i < _tokenContracts.length; i++) {
            addPlan(
                _tokenContracts[i],
                _userTypes[i],
                _durations[i],
                _rewardRates[i],
                _tax[i]
            );
        }
    }

    function withdrawLostTokens(
        address recipient,
        address tokenAddress,
        uint256 _amount
    ) public onlyOwner {
        IERC20 newToken = IERC20(tokenAddress);
        uint256 tokenBalance = newToken.balanceOf(address(this));
        require(
            tokenBalance >= _amount && tokenBalance > 0,
            "Insufficient balance."
        );
        newToken.transfer(recipient, _amount);
    }

    function withdrawBNB(address recipient, uint256 amount) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance >= amount && balance > 0, "Insufficient balance.");
        bool success = sendValue(recipient, amount);
        require(success, "Transaction Failed");
    }

    modifier checkUnstake(uint256 stakeIndex) {
        require(
            stakeIndex < userStakes[msg.sender].length,
            "Invalid stake index"
        );
        Stake memory userStake = userStakes[msg.sender][stakeIndex];
        require(userStake.isStaked, "Stake already withdrawn");
        _;
    }

    function addPlan(
        address _tokenContract,
        UserType _userType,
        uint256[] memory _durations,
        uint256[] memory _rewardRates,
        uint256[] memory _tax
    ) public onlyOwner {
        require(
            _durations.length == _rewardRates.length,
            "Array lengths must be equal"
        );

        Plan memory newPlan = Plan({
            tokenContract: _tokenContract,
            userType: _userType,
            durations: _durations,
            rewardRates: _rewardRates,
            tax: _tax
        });

        plans.push(newPlan);
        emit NewPlanAdded(_tokenContract, _durations[0], _rewardRates[0]);
    }

    function stake(
        uint256 planIndex,
        uint256 durationIndex,
        uint256 amount
    ) external payable whenNotPaused notBlacklisted {
        require(planIndex < plans.length, "Plan index out of bounds");
        Plan memory selectedPlan = plans[planIndex];
        uint256 duration = selectedPlan.durations[durationIndex];
        uint256 rewardRate = selectedPlan.rewardRates[durationIndex];
        uint256 tax = selectedPlan.tax[durationIndex];

        Stake memory newStake = Stake({
            userType: selectedPlan.userType,
            tokenContract: selectedPlan.tokenContract,
            amount: amount,
            depositTime: block.timestamp,
            duration: duration,
            rewardRate: rewardRate,
            taxPercentage: tax,
            withdrawRewards: 0,
            isStaked: true,
            isSale: false,
            salePrice: 0
        });

        if (selectedPlan.tokenContract == ZERO_ADDRESS) {
            require(msg.value == amount, "Incorrect BNB value sent");
        } else {
            IERC20 token = IERC20(selectedPlan.tokenContract);
            require(
                token.transferFrom(msg.sender, address(this), amount),
                "Token transfer failed"
            );
        }

        userStakes[msg.sender].push(newStake);
        emit Staked(msg.sender, planIndex, amount);
    }

    function unstake(uint256 stakeIndex) external checkUnstake(stakeIndex) notBlacklisted {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        uint256 reward = _calculateReward(msg.sender,stakeIndex);
        uint256 totalAmount = userStake.amount + reward;
        userStake.isStaked = false;

        if (userStake.tokenContract == ZERO_ADDRESS) {
            bool success = sendValue(msg.sender, totalAmount);
            require(success, "transfer failed");
        } else {
            IERC20 token = IERC20(userStake.tokenContract);
            require(
                token.transfer(msg.sender, totalAmount),
                "Token transfer failed"
            );
        }

        emit Unstaked(msg.sender, stakeIndex, userStake.amount, reward);
    }

    function _calculateReward(address user, uint256 stakeIndex) internal view returns (uint256) {
        Stake memory userStake = userStakes[user][stakeIndex];

        uint256 duration = userStake.duration * 1 days;
        uint256 rewardRate = userStake.rewardRate;

        uint256 endTime = userStake.depositTime + duration;
        uint256 currentTime = block.timestamp;

        if (currentTime < endTime) {
            uint256 elapsedTime = currentTime - userStake.depositTime;
            return
                (userStake.amount * elapsedTime * rewardRate) /
                (100000 * 1 days);
        } else {
            uint256 fullReward = (userStake.amount * duration * rewardRate) /
                100000;
            return fullReward;
        }
    }

    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
         require(stakeIndex < userStakes[user].length, "Invalid Stake Id");

         Stake memory userStake = userStakes[user][stakeIndex];

         if (userStake.isStaked) {
            return _calculateReward(user, stakeIndex);   
        }

        return 0;
    }


    function sellStake(uint256 stakeIndex, uint256 price) external checkUnstake(stakeIndex) {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        require(price > 0, "Price must be greater than zero");

        userStake.isSale = true;
        userStake.salePrice = price;

        emit StakeForSale(msg.sender, stakeIndex, price);
    }

    function buyStake(address seller, uint256 stakeIndex) external {
        require(seller != msg.sender, "Cannot buy your own stake");
        require(stakeIndex < userStakes[seller].length,"Invalid stake index");
        Stake storage sellerStake = userStakes[seller][stakeIndex];
        require(sellerStake.isSale, "Stake not for sale");

        uint256 salePrice = sellerStake.salePrice;
        require(salePrice > 0, "Sale price must be set");

        // Transfer the sale price to the seller
        if (sellerStake.tokenContract == ZERO_ADDRESS) {
            bool success = sendValue(seller, salePrice);
            require(success, "BNB transfer failed");
        } else {
            IERC20 token = IERC20(sellerStake.tokenContract);
            require(
                token.transferFrom(msg.sender, seller, salePrice),
                "Token transfer failed"
            );
        }

        // Create a new stake for the buyer
        Stake memory stakeToTransfer = sellerStake;
        stakeToTransfer.isSale = false;
        stakeToTransfer.isStaked = true;
        userStakes[msg.sender].push(stakeToTransfer);

        // Mark the seller's stake as unstaked
        sellerStake.isStaked = false;

        emit StakePurchased(msg.sender, seller, stakeIndex, salePrice);
    }


    function cancelSale(uint256 stakeIndex) external {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        require(userStake.isSale, "Stake not for sale");

        userStake.isSale = false;
        userStake.salePrice = 0;

        emit StakeSaleCancelled(msg.sender, stakeIndex);
    }

    function userIndex(address _user) public view returns (uint256) {
        return userStakes[_user].length;
    }

    function getUserStakeHistory(
        address userAddress
    ) public view returns (Stake[] memory) {
        return userStakes[userAddress];
    }
}
