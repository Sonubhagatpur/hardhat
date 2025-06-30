// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: contracts/newAsadVesting.sol



pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract Vesting is Ownable, ReentrancyGuard {
    uint256 private constant DAY_IN_SECONDS = 86400;
    uint256 private constant FEE_DIVISOR = 10000;

    struct VestingInfo {
        uint256 allocatedAmount;
        uint256 claimedAmount;
        uint256 nextClaimTimestamp;
        uint256 claimEndTimestamp;
    }

    struct UserInfo {
        address wallet;
        uint256 totalAllocatedAmount;
        uint256 totalClaimedAmount;
        address userClaimAddress;

        // uint256 vestingCount;
    }

    // IERC20 public token;
    uint256 public adminComm;
    uint256 public claimEndDay;
    uint256 public vestingEndDay;
    uint256 public EndDay;

    mapping(address => UserInfo) public userInfo;
    mapping(address => VestingInfo[]) private userVestingInfo;
    mapping(address => bool) public allocatedUser;
    event AdminCommissionUpdated(uint256 newCommission);
    event VestingDaysUpdated(uint256 newVestingEndDay, uint256 newClaimEndDay);
    event UserVestingAllocated(address indexed user, uint256 amount, address userClaimAddress);
    event TokensClaimed(address indexed user, uint256 id, uint256 amount, uint256 timestamp);
    event UserClaimAddressChanged(address indexed user, address newUserClaimAddress);
    event TokensDrained(uint256 amount);
    event VestingStartTimestampUpdated(address indexed user, uint256 index, uint256 newTimestamp);
    event Withdraw(uint256 amount, uint256 timestamp);

    constructor(
        uint256 _adminComm,
        uint256 _vestingEndDay,
        uint256 _claimEndDay
    ) {
        // token = IERC20(_token);
        require(
            _vestingEndDay > 0 && _claimEndDay > 0,
            " Day should not be Zero"
        );
        adminComm = _adminComm;
        vestingEndDay = _vestingEndDay * DAY_IN_SECONDS;
        claimEndDay = _claimEndDay * DAY_IN_SECONDS;
        EndDay = _claimEndDay;
        emit VestingDaysUpdated(vestingEndDay, claimEndDay);
    }

    function updateAdminCommission(uint256 _adminComm) external onlyOwner {
        adminComm = _adminComm;
        emit AdminCommissionUpdated(_adminComm);

    }

    function updateVestingDays(uint256 _vestingEndDay, uint256 _claimEndDay)
        external
        onlyOwner
    {
        require(
            _vestingEndDay > 0 && _claimEndDay > 0,
            " Day should not be Zero"
        );
        vestingEndDay = _vestingEndDay * DAY_IN_SECONDS;
        claimEndDay = _claimEndDay * DAY_IN_SECONDS;
        EndDay = _claimEndDay;
        emit VestingDaysUpdated(_vestingEndDay, _claimEndDay);

    }

    function allocateForVesting(address _user, address _userClaimAddress) external payable onlyOwner {
        // require(
        //     !allocatedUser[_user],
        //     "vesting already allocated to this address"
        // );
        // token.transferFrom(msg.sender, address(this), _amount);
        _allocateAmount(_user, msg.value, _userClaimAddress);
        allocatedUser[_user] = true;
    }

    function _allocateAmount(address _user, uint256 _amount, address _userClaimAddress) internal {
        UserInfo storage user = userInfo[_user];
        VestingInfo[] storage vestingInfo = userVestingInfo[_user];

        // uint256 duration = 1 days;
        uint256 vestingStartTimestamp = block.timestamp + vestingEndDay; //Changes

        user.wallet = _user;
        user.userClaimAddress = _userClaimAddress;

        if (allocatedUser[_user]) {
            user.totalAllocatedAmount += _amount;
            // user.totalClaimedAmount = user.totalClaimedAmount; 
        } else {
            user.totalAllocatedAmount = _amount;
            user.totalClaimedAmount = 0;
        }

        // vestingInfo[vestingInfo.length].nextClaimTimestamp = vestingStartTimestamp;
        // vestingInfo[vestingInfo.length].tokensUnlockedAmount = 0;

        vestingInfo.push(
            VestingInfo({
                allocatedAmount: _amount,
                claimedAmount: 0,
                nextClaimTimestamp: vestingStartTimestamp,
                claimEndTimestamp: vestingStartTimestamp + claimEndDay //Changes
            })
        );
    }

    function claimTokens(address _user, uint256 _id) external nonReentrant  onlyUserClaimAddress(_user){
        require(allocatedUser[_user], "Funds not allocated to this user");

        UserInfo storage user = userInfo[_user];

        // require(block.timestamp >= userVestingInfo[_user][_id].nextClaimTimestamp, "Cannot claim before claim start time");

        (uint256 tokensToSend, uint256 numberOfDays) = getUnlockedTokenAmount(
            user.wallet,
            _id
        );

        // tokensToSend = tokensToSend - user.claimedAmount;

        require(tokensToSend != 0, "Claim amount is insufficient");

        if (tokensToSend > 0) {
            uint256 fee = (tokensToSend * adminComm) / FEE_DIVISOR;

            // token.transfer(_user, tokensToSend);
            // payable(_user).transfer(tokensToSend);

            payable(owner()).transfer(fee);
            payable(_user).transfer(tokensToSend - fee);

            user.totalClaimedAmount += tokensToSend;
            userVestingInfo[_user][_id].claimedAmount += tokensToSend;
            emit Withdraw(tokensToSend, block.timestamp);
            emit TokensClaimed(_user, _id, tokensToSend, block.timestamp);

        }
        if (
            userVestingInfo[_user][_id].claimedAmount ==
            userVestingInfo[_user][_id].allocatedAmount
        ) {
            userVestingInfo[_user][_id].nextClaimTimestamp = 0;
        } else {
            uint256 nextClaimTime = userVestingInfo[_user][_id].nextClaimTimestamp +
            (numberOfDays * DAY_IN_SECONDS);
            userVestingInfo[_user][_id].nextClaimTimestamp = nextClaimTime;
        }
    }

    function changeUserClaimAddress(address _user, address _newUserClaimAddress) external onlyOwner {
        userInfo[_user].userClaimAddress = _newUserClaimAddress;
        emit UserClaimAddressChanged(_user, _newUserClaimAddress);
    }

    function claimTotalTokens(address _user, uint256 _id) external nonReentrant onlyOwner {
        UserInfo storage user = userInfo[_user];

        uint256 leftBalance = userVestingInfo[_user][_id].allocatedAmount -
            userVestingInfo[_user][_id].claimedAmount;

        uint256 fee = (leftBalance * adminComm) / FEE_DIVISOR;

        userVestingInfo[_user][_id].nextClaimTimestamp = 0;
        user.totalClaimedAmount += leftBalance;
        userVestingInfo[_user][_id].claimedAmount += leftBalance;

        // token.transfer(owner(), fee);
        // token.transfer(_user, leftBalance - fee);

        payable(owner()).transfer(fee);
        payable(_user).transfer(leftBalance - fee);
        emit Withdraw(leftBalance, block.timestamp);
    }

    function getUnlockedTokenAmount(address _wallet, uint256 _id)
        public
        view
        returns (uint256, uint256)
    {
        require(_id < userVestingInfo[_wallet].length, "Vesting Error: Entered ID is invalid");
        VestingInfo memory vestingInfo = userVestingInfo[_wallet][_id];

        uint256 allowedAmount = 0;
        uint256 numberOfDays = 0;

        if (!allocatedUser[_wallet]) {
            return (0, 0);
        }

        if (block.timestamp >= vestingInfo.nextClaimTimestamp) {
            if (vestingInfo.nextClaimTimestamp != 0) {
                uint256 fromTime = block.timestamp >
                    vestingInfo.claimEndTimestamp
                    ? vestingInfo.claimEndTimestamp - DAY_IN_SECONDS
                    : block.timestamp;
                if(fromTime !=vestingInfo.nextClaimTimestamp){

                uint256 duration = (fromTime -
                    vestingInfo.nextClaimTimestamp) + DAY_IN_SECONDS;
                numberOfDays = duration / DAY_IN_SECONDS;
                }else{
                           uint256 duration = (fromTime -
                    vestingInfo.nextClaimTimestamp);
                numberOfDays = duration / DAY_IN_SECONDS;
                }

                allowedAmount =
                    (userVestingInfo[_wallet][_id].allocatedAmount / EndDay) *
                    numberOfDays;
            }
        }

        // allowedAmount = allowedAmount - user.claimedAmount;

        if (
            allowedAmount >
            (userVestingInfo[_wallet][_id].allocatedAmount -
                userVestingInfo[_wallet][_id].claimedAmount)
        ) {
            allowedAmount = (userVestingInfo[_wallet][_id].allocatedAmount -
                userVestingInfo[_wallet][_id].claimedAmount);
        }

        return (allowedAmount, numberOfDays);
    }

    function getVestingInfo(address _user, uint256 _id)
        public
        view
        returns (VestingInfo memory)
    {
        return userVestingInfo[_user][_id];
    }

    function getUserTotalVesting(address _user) public view returns (uint256) {
        return userVestingInfo[_user].length;
    }

    function drainTokens(uint256 _amount) external nonReentrant onlyOwner {
        // token.transfer(msg.sender, _amount);
        payable(msg.sender).transfer(_amount);
        emit TokensDrained(_amount);

    }

    function updateVestingStartTimestamp(
        address _user,
        uint256 index,
        uint256 _newVestingStartTimestamp
    ) external onlyOwner {
        require(
            _newVestingStartTimestamp > 0,
            "New vesting start time should not be zero"
        );
        //require(userVestingInfo[_user].length > index, "Invalid index");
        require(_user != address(0), "Invalid user address");

        userVestingInfo[_user][index]
            .nextClaimTimestamp = _newVestingStartTimestamp;
        userVestingInfo[_user][index].claimEndTimestamp =
            _newVestingStartTimestamp +
            claimEndDay;
        emit VestingStartTimestampUpdated(_user, index, _newVestingStartTimestamp);

    }
    modifier onlyUserClaimAddress(address _user) {
        address userAddress = userInfo[_user].userClaimAddress;
        // require( userAddress!= address(0), "Claim address is set as address(0)");
        require(msg.sender == userAddress, "Caller is not the claim address");
        _;
    }
}