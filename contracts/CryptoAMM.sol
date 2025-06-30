// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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

abstract contract OperatorAccessControl is Ownable {
    mapping(address => bool) private isOperatorMap;
    address[] private operatorList;

    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    modifier onlyOperator() {
        require(isOperatorMap[msg.sender], "Caller is not an operator");
        _;
    }

    modifier onlyAdminOrOperator() {
        require(msg.sender == owner() || isOperatorMap[msg.sender], "Not admin or operator");
        _;
    }

    function addOperator(address operator) external onlyOwner {
        _addOperator(operator);
    }

    function _addOperator(address operator) internal {
        require(operator != address(0), "Invalid address");
        require(!isOperatorMap[operator], "Already an operator");

        isOperatorMap[operator] = true;
        operatorList.push(operator);

        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        require(isOperatorMap[operator], "Not an operator");

        isOperatorMap[operator] = false;

        // Remove from array
        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operatorList[i] == operator) {
                operatorList[i] = operatorList[operatorList.length - 1];
                operatorList.pop();
                break;
            }
        }

        emit OperatorRemoved(operator);
    }

    function isOperator(address account) public view returns (bool) {
        return isOperatorMap[account];
    }

    function getOperators() external view returns (address[] memory) {
        return operatorList;
    }
}

/**
 * @title UserAccessControl
 * @dev Manages a whitelist of users allowed to access restricted features.
 */
contract UserAccessControl is OperatorAccessControl {
    mapping(address => bool) private whitelistedUsers;

    // Events
    event UserWhitelisted(address indexed user);
    event UserRemovedFromWhitelist(address indexed user);

    // Errors
    error NotWhitelistedUser();
    error AlreadyWhitelistedUser();
    error ZeroAddressNotAllowed();

    // Modifier to restrict access
    modifier onlyWhitelistedUser() {
        if (!whitelistedUsers[msg.sender]) revert NotWhitelistedUser();
        _;
    }

    // =======================
    // === PUBLIC FUNCTIONS ==
    // =======================

    function whitelistUser(address user) external onlyAdminOrOperator {
        _whitelistUser(user);
    }

    function removeWhitelistedUser(address user) external onlyAdminOrOperator {
        _removeWhitelistedUser(user);
    }

    function whitelistMultipleUsers(address[] calldata users) external onlyAdminOrOperator {
        for (uint256 i = 0; i < users.length; i++) {
            _whitelistUser(users[i]);
        }
    }

    function removeMultipleWhitelistedUsers(address[] calldata users) external onlyAdminOrOperator {
        for (uint256 i = 0; i < users.length; i++) {
            _removeWhitelistedUser(users[i]);
        }
    }

    function isUserWhitelisted(address user) public view returns (bool) {
        return _isWhitelisted(user);
    }

    // ========================
    // === INTERNAL FUNCTIONS =
    // ========================

    function _whitelistUser(address user) internal {
        if (user == address(0)) revert ZeroAddressNotAllowed();
        if (whitelistedUsers[user]) revert AlreadyWhitelistedUser();
        whitelistedUsers[user] = true;
        emit UserWhitelisted(user);
    }

    function _removeWhitelistedUser(address user) internal {
        if (!whitelistedUsers[user]) revert NotWhitelistedUser();
        whitelistedUsers[user] = false;
        emit UserRemovedFromWhitelist(user);
    }

    function _isWhitelisted(address user) internal view returns (bool) {
        return whitelistedUsers[user];
    }
}

contract CryptoAMM is UserAccessControl, Pausable, ReentrancyGuard {
    // Global Totals
    AggregatorV3Interface public bnbUsdPriceFeed;
    address public cryptoAMMToken;
    bool public isClaimEnabled;
    uint256 public minContributionUsd = 1 ether;
    uint256 public maxContributionUsd = 5000 ether;
    uint256 public vestingInterval = 5 minutes;
    uint256 public welcomeRewardUsd;
    uint256 public welcomeRewardForReferral;
    uint256 public currentStage;
    uint256 internal totalTokensSold;
    uint256 internal totalBonusDistributed;
    uint256 internal totalWelcomeBonus;
    uint256 internal totalReferralBonus;
    uint256 internal totalReferralUsdPaid;
    uint256 internal totalReferralBNBPaid;
    uint256 internal totalVestedClaimed;
    uint256 internal totalUsdContributed;

    struct DesignatedLevel {
        uint256 rewardPercent;
        uint256 minSales;      // USD value required (in 18 decimals)
    }

    struct Stage {
        uint256 pricePerToken; // USD cents
        uint256 tokenCap;
        uint256 sold;
        uint256 bonusPercent;   
    }

    struct VestingTier {
        uint256 minAmountUsd;
        uint256 maxAmountUsd;
        uint256 tgeUnlockPercent; // in %
        uint256 vestingDuration;
    }

struct User {
    bool isRegistered;                   
    bool kycVerified;                   
    uint256 kycTimestamp;              
    address referrer;                   

    uint256 totalUsdContributed;       
    uint256 totalTokensPurchased;       
    uint256 bonusBalance;              
    
    uint256 locked;                     
    uint256 totalClaimedVested;        

    uint256 tier;                       
    bool tgeClaimed;                   

    uint256 lastClaimedTimestamp;      
}

    // mapping(uint256 => Stage) public stages;
    mapping(address => User) public users;
    mapping(address => bool) public isAcceptedToken;

    address[] public acceptedTokenList;
    Stage[] public stages;
    VestingTier[] public vestingTiers;
    DesignatedLevel[] public designatedLevels;

    event StageAdvanced(uint256 newStage);
    event WelcomeBonusSet(uint256 usdAmount);
    event WelcomeReferralBonusSet(uint256 usdAmount);
    event WelcomeBonusGranted(address indexed user, uint256 tokenAmount);
    event AssetTransferred(address indexed to, uint256 amount, address indexed tokenAddress);
    event ReferralBonusGranted(address indexed referrer, address indexed referredUser, uint256 tokenAmount);
    event ReferralRewardDistributed(address indexed referrer, uint256 level, uint256 rewardAmount, address rewardToken);
    event ReferralRewardCompleted(address indexed distributor, uint256 totalDistributed, address rewardToken);
    event DesignatedLevelUpdated(uint256 level, uint256 newPercent, uint256 newMinSales);
    event Registered(address user, address referrer);
    event KYCVerified(address user);
    event Purchased(address user, uint256 tokens);
    event ClaimedVested(address indexed user, uint256 amount);
    event BonusGiven(address indexed user, uint256 bonusAmount);

    constructor(address _operatorAddress, address _cryptoAMMToken, address[] memory tokens, DesignatedLevel[] memory levels, Stage[] memory initialStages) {
        bnbUsdPriceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        ); 
        _addOperator(_operatorAddress);
        cryptoAMMToken = _cryptoAMMToken;
        for (uint256 i = 0; i < tokens.length; i++) {
            isAcceptedToken[tokens[i]] = true;
            acceptedTokenList.push(tokens[i]);
        }

        for (uint256 i = 0; i < initialStages.length; i++) {
            stages.push(initialStages[i]);
        }

        initializeVestingTiers();
        welcomeRewardForReferral = 1 ether;
        welcomeRewardUsd = 1 ether;
        
        for (uint256 i = 0; i < levels.length; i++) {
            require(levels[i].rewardPercent > 0 && levels[i].minSales > 0, "Invalid input");
            designatedLevels.push(levels[i]);
        }

        users[_operatorAddress].kycVerified = true;
        users[_operatorAddress].isRegistered = true;
        _whitelistUser(_operatorAddress);

    }

    modifier onlyKYCVerified() {
        require(users[msg.sender].kycVerified, "KYC not verified");
        _;
    }

    modifier validContributionAmount(uint256 usdtAmount) {
        require(usdtAmount >= minContributionUsd, "Below minimum contribution");
        _;
    }

    modifier tgeClaimEligible(address userAddr) {
        User memory user = users[userAddr];
        require(!user.tgeClaimed, "TGE already claimed");
        require(user.locked > 0, "Nothing locked");
        _;
    }

    function register(address userAddress, address _referrer) external onlyAdminOrOperator {
        require(!users[userAddress].isRegistered, "Already registered");
        require(_referrer != address(0), "Referrer is required");
        require(_referrer != userAddress, "Cannot refer yourself");
        require(users[_referrer].isRegistered, "Referrer not registered");

        users[userAddress].referrer = _referrer;
        users[userAddress].isRegistered = true;

        emit Registered(userAddress, _referrer);
    }

    function buyTokens(address tokenAddress, uint256 usdtAmount) external onlyKYCVerified  onlyWhitelistedUser {
        require(usdtAmount > 0, "Amount must be greater then > 0");
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(_msgSender()) >= usdtAmount, "Insufficient balance of tokens");
        require(token.allowance(msg.sender, address(this)) >= usdtAmount, "Insufficient allowance of tokens to buy with");
        token.transferFrom(msg.sender, address(this), usdtAmount);
        _buy(tokenAddress, msg.sender, usdtAmount);
    }

    function buyWithBNB() external payable  onlyKYCVerified  onlyWhitelistedUser {
        require(msg.value > 0, "Amount must be greater then > 0");
        uint256 bnbUsd = (msg.value * getBNBPriceUSD()) / 1e8;
        _buy(address(0), msg.sender, bnbUsd);
    }

    function claimTokens() external nonReentrant {
        require(isClaimEnabled, "Claim is not enabled");
        User storage user = users[msg.sender];
        require(user.locked > 0, "No tokens locked");


        // Ensure at least 30 days passed since last claim
        require(block.timestamp >= user.lastClaimedTimestamp + vestingInterval, "Next vesting claim not available yet");


        // Subtract already claimed
        uint256 claimable = getClaimableAmount(msg.sender);
        require(claimable > 0, "Nothing to claim");
        if(!user.tgeClaimed) user.tgeClaimed = true;

        user.totalClaimedVested += claimable;
        user.lastClaimedTimestamp = block.timestamp;
        totalVestedClaimed += claimable;

        // Transfer tokens
        _transferAsset(msg.sender, claimable, cryptoAMMToken);

        emit ClaimedVested(msg.sender, claimable);
    }



    function _buy(address tokenAddress, address userAddress, uint256 usdtAmount) 
        internal 
        virtual 
        whenNotPaused 
        nonReentrant 
        validContributionAmount(usdtAmount)
        returns (uint256)
    {
        require(tokenAddress == address(0) || isAcceptedToken[tokenAddress], "Token must be accepted");

        (uint256 tokenAmount, uint256 lastUsedStage,uint256 bonusAmount, uint256[] memory tokensUsed )= _usdToTokenAmount(usdtAmount);
        require(tokenAmount > 0, "No tokens available for purchase");

        User storage user = users[userAddress];

        uint256 newUsdTotal = user.totalUsdContributed + usdtAmount;
        require(newUsdTotal <= maxContributionUsd, "Above maximum total purchase");

        user.totalUsdContributed = newUsdTotal;
        user.totalTokensPurchased += tokenAmount;
        user.lastClaimedTimestamp = block.timestamp;
        totalUsdContributed += usdtAmount;
        totalTokensSold += tokenAmount;

        uint256 nextStage = stages.length; // default sentinel
        for (uint256 i = currentStage; i <= lastUsedStage; i++) {
            // Update sold tokens per stage
            if (tokensUsed[i] > 0) {
                stages[i].sold += tokensUsed[i];
            }

            if (nextStage == stages.length && stages[i].sold < stages[i].tokenCap) {
                nextStage = i;
            }
        }
        // Update currentStage if a valid next stage was found
        if (nextStage < stages.length && nextStage != currentStage) {
            currentStage = nextStage;
            emit StageAdvanced(currentStage); // Optional event
        }

        // Determine tier
        (, uint256 tierIndex) = getTierByAmount(newUsdTotal);
        user.tier = tierIndex;

        // locked tokens based on TGE
        user.locked += tokenAmount;

        emit Purchased(userAddress, tokenAmount);

        // Bonus trasnfer
        if (bonusAmount > 0) {
            user.bonusBalance += bonusAmount;
            totalBonusDistributed += bonusAmount;
            _transferAsset(msg.sender, bonusAmount, cryptoAMMToken);
            emit BonusGiven(userAddress, bonusAmount);
        }

        return tokenAmount;
    }


    function _transferAsset(address to, uint256 amount, address tokenAddress) internal {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        if (tokenAddress == address(0)) {
            // BNB transfer
            require(address(this).balance >= amount, "Insufficient BNB balance");
            (bool sent, ) = to.call{value: amount}("");
            require(sent, "Failed to send BNB");
        } else {
            // ERC20 transfer
            IERC20 token = IERC20(tokenAddress);
            require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");
            require(token.transfer(to, amount), "Token transfer failed");
        }

        emit AssetTransferred(to, amount, tokenAddress);
    }

    function _grantWelcomeAndReferralBonus(address user) internal {

        // Welcome bonus in tokens
        if (welcomeRewardUsd > 0) {
        uint256 welcomeTokenAmount = calculateTokenAmount(welcomeRewardUsd);
        users[user].bonusBalance += welcomeTokenAmount;
        totalWelcomeBonus += welcomeTokenAmount;
        // Transfer tokens
        _transferAsset(user, welcomeTokenAmount, cryptoAMMToken);

        emit WelcomeBonusGranted(user, welcomeTokenAmount);
        }

        // Referral bonus to parent (if registered & KYC verified)
        address referrer = users[user].referrer;
        if (
            referrer != address(0) &&
            users[referrer].isRegistered &&
            users[referrer].kycVerified
        ) {
            uint256 referralTokenAmount = calculateTokenAmount(welcomeRewardForReferral);
            users[referrer].bonusBalance += referralTokenAmount;
            totalReferralBonus += referralTokenAmount;
            // Transfer tokens
            _transferAsset(referrer, referralTokenAmount, cryptoAMMToken);

            emit ReferralBonusGranted(referrer, user, referralTokenAmount);
        }
    }

    function distributeReferralRewards(
        address[] calldata referralTree,      // Level 1 to 10
        uint256[] calldata amounts,         // USD amounts per level (18 decimals)
        address tokenAddress                  // ERC20 token or address(0) for BNB
    ) external payable onlyOwner whenNotPaused {
        require(referralTree.length == amounts.length, "Mismatched input lengths");
        require(referralTree.length <= designatedLevels.length, "Max 10 levels");

        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < referralTree.length; i++) {
            address referrer = referralTree[i];
            uint256 reward = amounts[i];
            if (referrer == address(0) || reward == 0) continue;

            User memory user = users[referrer];
            if (!user.kycVerified) continue;

            // if (i >= designatedLevels.length) break; // Level overflow protection

            if (reward > 0) {
                if (tokenAddress == address(0)) {
                    // Native BNB transfer
                    totalReferralBNBPaid += reward;
                    _transferAsset(referrer, reward, tokenAddress);
                 } else {
                    // ERC20 transfer
                    require(isAcceptedToken[tokenAddress], "Token not accepted");
                    totalReferralUsdPaid += reward;
                     _transferAsset(referrer, reward, tokenAddress);
                }

                totalDistributed += reward;
                emit ReferralRewardDistributed(referrer, i + 1, reward, tokenAddress);
            }
        }

        emit ReferralRewardCompleted(msg.sender, totalDistributed, tokenAddress);
    }

    function setVestingInterval(uint256 newInterval) external onlyOwner {
        // require(newInterval >= 1 days, "Interval must be at least 1 day");
        vestingInterval = newInterval;
    }

    function batchVerifyKYC(address[] calldata usersToVerify) external onlyAdminOrOperator {
        for (uint256 i = 0; i < usersToVerify.length; i++) {
            verifyKYC(usersToVerify[i]);
        }
    }

    function verifyKYC(address user) public  onlyAdminOrOperator {
        require(users[user].isRegistered, "User is not registered");
        require(!users[user].kycVerified, "Already verified");
        users[user].kycVerified = true;
        _whitelistUser(user);
        users[user].kycTimestamp = block.timestamp;

        emit KYCVerified(user);

        _grantWelcomeAndReferralBonus(user);
    }

    function withdrawToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        _transferAsset(msg.sender, amount, tokenAddress);
    }

    function withdrawBNB(uint256 amount) external onlyOwner {
        _transferAsset(msg.sender, amount, address(0));
    }


    function setClaimEnabled(bool _status) external onlyOwner {
        isClaimEnabled = _status;
    }

    // Called by admin (owner)
    function initializeVestingTiers() private {
        vestingTiers.push(VestingTier(0, 500 * 1e18, 10, 24 * 30 days));
        vestingTiers.push(VestingTier(501 * 1e18, 1100 * 1e18, 20, 24 * 30 days));
        vestingTiers.push(VestingTier(1101 * 1e18, 1800 * 1e18, 30, 24 * 30 days));
        vestingTiers.push(VestingTier(1801 * 1e18, 2600 * 1e18, 40, 24 * 30 days));
        vestingTiers.push(VestingTier(2601 * 1e18, type(uint256).max, 50, 24 * 30 days));
    }

    function updateStage(
        uint256 index,
        uint256 pricePerToken,
        uint256 tokenCap,
        uint256 bonusPercent
    ) external onlyOwner {
        require(index < stages.length, "Invalid stage index");

        Stage storage stage = stages[index];

        if (pricePerToken > 0) stage.pricePerToken = pricePerToken;
        if (tokenCap > 0) stage.tokenCap = tokenCap;
        if (bonusPercent > 0)stage.bonusPercent = bonusPercent;
    }

    function setContributionLimits(uint256 _min, uint256 _max) external onlyOwner {
        require(_min < _max, "Invalid contribution limits");
        minContributionUsd = _min;
        maxContributionUsd = _max;
    }

    function setWelcomeReward(uint256 usdAmount) external onlyOwner {
        welcomeRewardUsd = usdAmount;
        emit WelcomeBonusSet(usdAmount);
    }

    function setWelcomeRewardForReferral(uint256 usdAmount) external onlyOwner {
        welcomeRewardForReferral = usdAmount;
        emit WelcomeReferralBonusSet(usdAmount);
    }

    function deactivateSale() external onlyOwner {
        _pause();
    }

    function activateSale() external onlyOwner {
        _unpause();
    }

    function updateDesignatedLevel(uint256 level, uint256 percent, uint256 minSales) external onlyOwner {
        require(level >= 1 && level <= designatedLevels.length, "Out of bounds");

        DesignatedLevel storage lvl = designatedLevels[level - 1];

        if (percent > 0) {
            lvl.rewardPercent = percent;
        }
        if (minSales > 0) {
            lvl.minSales = minSales;
        }

        emit DesignatedLevelUpdated(level, lvl.rewardPercent, lvl.minSales);
    }

    function calculateTokenAmount(uint256 usdtAmount) public view returns (uint256) {
        (uint256 tokenAmount, , , )= _usdToTokenAmount(usdtAmount);
        return tokenAmount;
    }

    function _usdToTokenAmount(uint256 usdAmount) internal view returns (uint256 totalTokens, uint256 lastUsedStage, uint256 totalBonus, uint256[] memory usedPerStage ) {
        uint256 remainingUsd = usdAmount;
        totalTokens = 0;
        totalBonus = 0;
        lastUsedStage = currentStage;
        uint256[] memory tokensUsed = new uint256[](stages.length);

        for (uint256 i = currentStage; i < stages.length && remainingUsd > 0; i++) {
            Stage memory stage = stages[i];

            uint256 pricePerToken = (stage.pricePerToken * 1e18) / 100; // convert to wei
            uint256 availableTokens = stage.tokenCap - stage.sold;

            if (availableTokens == 0) continue;

            uint256 maxUsdThisStage = (availableTokens * pricePerToken) / 1e18;
            uint256 usdToUse = remainingUsd > maxUsdThisStage ? maxUsdThisStage : remainingUsd;
            uint256 tokensToBuy = (usdToUse * 1e18) / pricePerToken;

            totalTokens += tokensToBuy;
            tokensUsed[i] = tokensToBuy;

            remainingUsd -= usdToUse;
            lastUsedStage = i;

            // Calculate bonus directly here
            uint256 bonus = (tokensToBuy * stage.bonusPercent) / 100;
            totalBonus += bonus;
        }

        require(remainingUsd == 0, "Not enough liquidity in stages");
        
        return (totalTokens, lastUsedStage, totalBonus, tokensUsed);
    }

    function tokenToUsdAmount(uint256 tokenAmount) public view returns (uint256 totalUsd) {
        uint256 remainingTokens = tokenAmount;
        totalUsd = 0;

        for (uint256 i = currentStage; i < stages.length && remainingTokens > 0; i++) {
            Stage memory stage = stages[i];

            uint256 availableTokens = stage.tokenCap - stage.sold;
            if (availableTokens == 0) continue;

            uint256 tokensFromStage = remainingTokens > availableTokens ? availableTokens : remainingTokens;
            uint256 pricePerToken = (stage.pricePerToken * 1e18) / 100; // cents to wei

            totalUsd += (tokensFromStage * pricePerToken) / 1e18;
            remainingTokens -= tokensFromStage;
        }

        require(remainingTokens == 0, "Not enough tokens available in stages");
    }


    function getClaimableAmount(address userAddr) public view returns (uint256 claimable) {
        User memory user = users[userAddr];
        if (user.totalTokensPurchased == 0) return 0;

        VestingTier memory tier = vestingTiers[user.tier - 1];
        uint256 total = user.totalTokensPurchased;

        uint256 tgeUnlocked = (total * tier.tgeUnlockPercent) / 100;
        uint256 vestedTotal = total - tgeUnlocked;

        // TGE claimable if not claimed yet
        if (!user.tgeClaimed && isClaimEnabled) {
            claimable += tgeUnlocked;
        }

        // Vested tokens claimable if TGE was claimed
        if (user.tgeClaimed && user.locked > 0) {
            uint256 lastClaim = user.lastClaimedTimestamp;

            if (block.timestamp > lastClaim) {
                uint256 elapsed = block.timestamp - lastClaim;
                uint256 totalUnlockedFromVesting = (vestedTotal * elapsed) / tier.vestingDuration;

                // Cap unlock to remaining locked
                uint256 remaining = user.locked - user.totalClaimedVested;
                uint256 claimableVested = totalUnlockedFromVesting > remaining
                    ? remaining
                    : totalUnlockedFromVesting;

                claimable += claimableVested;
            }
        }

        return claimable;
    }

    function getAllVestingTiers() external view returns (VestingTier[] memory) {
        return vestingTiers;
    }

    function getAllDesignatedLevels() external view returns (DesignatedLevel[] memory) {
        return designatedLevels;
    }

    function getGlobalStats() external view returns (
        uint256 tokensSold,
        uint256 bonusDistributed,
        uint256 welcomeBonus,
        uint256 referralBonus,
        uint256 referralUsdBase,
        uint256 referralBNBBase,
        uint256 vestedClaimed,
        uint256 UsdContributed
    ) {
        return (
            totalTokensSold,
            totalBonusDistributed,
            totalWelcomeBonus,
            totalReferralBonus,
            totalReferralUsdPaid,
            totalReferralBNBPaid,
            totalVestedClaimed,
            totalUsdContributed
        );
    }

    function getTierByAmount(uint256 amountUsd) public view returns (VestingTier memory tier, uint256 index) {
        for (uint256 i = 0; i < vestingTiers.length; i++) {
            if (amountUsd >= vestingTiers[i].minAmountUsd && amountUsd <= vestingTiers[i].maxAmountUsd) {
                return (vestingTiers[i], i + 1); // Tier index starts from 1
            }
        }
        revert("No tier matched");
    }

    function getBNBPriceUSD() public view returns (uint256) {
        (, int256 price,,,) = bnbUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price); // Usually 8 decimals
    }

    receive() external payable {}

}