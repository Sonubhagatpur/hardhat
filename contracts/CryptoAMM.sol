// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./access/UserAccessControlUpgradeable.sol";
import "./utils/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CryptoAMM is 
    Initializable, 
    UserAccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
    {
    // Global Totals
    AggregatorV3Interface public bnbUsdPriceFeed;
    address public cryptoAMMToken;
    bool public isClaimEnabled;
    uint256 public claimEnabledTime;
    uint256 public claimDisabledTime;
    uint256 public minContributionUsd;
    uint256 public maxContributionUsd;
    uint256 public vestingInterval;
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
    uint256 public totalLockedTokens;

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
    uint256 designationLevel;    
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
    event ReferralRewardDistributed(address indexed referrer, uint256 level, uint256 rewardAmount, address rewardToken, uint256 designation);
    event ReferralRewardCompleted(address indexed distributor, uint256 totalDistributed, address rewardToken);
    event DesignatedLevelUpdated(uint256 level, uint256 newPercent, uint256 newMinSales);
    event VestingIntervalUpdated(uint256 indexed newInterval, uint256 indexed timestamp);
    event VestingTiersInitialized(uint256 count, uint256 timestamp);
    event ClaimToggle(bool indexed enabled, uint256 indexed timestamp);
    event Registered(address user, address referrer);
    event KYCVerified(address user);
    event Purchased(address user, uint256 tokens);
    event ClaimedVested(address indexed user, uint256 amount);
    event BonusGiven(address indexed user, uint256 bonusAmount);

    //constructor(address _operatorAddress, address _cryptoAMMToken, address[] memory tokens, DesignatedLevel[] memory levels, Stage[] memory initialStages, VestingTier[] memory tiers) {
    function initialize(
        address _operatorAddress,
        address _cryptoAMMToken,
        address[] memory tokens,
        DesignatedLevel[] memory levels,
        Stage[] memory initialStages,
        VestingTier[] memory tiers
    ) public initializer {
        __UserAccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
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

        _initializeVestingTiers(tiers);
        welcomeRewardForReferral = 1 ether;
        welcomeRewardUsd = 1 ether;
        
        for (uint256 i = 0; i < levels.length; i++) {
            require(levels[i].rewardPercent > 0 && levels[i].minSales > 0, "Invalid input");
            designatedLevels.push(levels[i]);
        }

        users[_operatorAddress].kycVerified = true;
        users[_operatorAddress].isRegistered = true;
        _whitelistUser(_operatorAddress);

        minContributionUsd = 1 ether;
        maxContributionUsd = 3000 ether;
        vestingInterval = 5 minutes;

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
        user.locked        -= claimable;
        totalLockedTokens  -= claimable;
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

        (uint256 tokenAmount, uint256 lastUsedStage, uint256 bonusAmount, uint256[] memory tokensUsed )= _usdToTokenAmount(usdtAmount);
        require(tokenAmount > 0, "No tokens available for purchase");

        User storage user = users[userAddress];

        uint256 newUsdTotal = user.totalUsdContributed + usdtAmount;
        require(newUsdTotal <= maxContributionUsd, "Above maximum total purchase");

        user.totalUsdContributed = newUsdTotal;
        user.totalTokensPurchased += tokenAmount;
        user.lastClaimedTimestamp = block.timestamp;
        totalUsdContributed += usdtAmount;
        totalTokensSold += tokenAmount;

        uint256 newStage = lastUsedStage;
        for (uint256 i = currentStage; i <= lastUsedStage; i++) {
            // Update sold tokens per stage
            if (tokensUsed[i] > 0) {
                stages[i].sold += tokensUsed[i];
            }

        }

        // Advance stage if the last used stage is fully sold
        if (
            stages[lastUsedStage].tokenCap - stages[lastUsedStage].sold <= 1 &&
            lastUsedStage + 1 < stages.length
        ) {
            newStage = lastUsedStage + 1;
        }

        if (newStage != currentStage) {
            currentStage = newStage;
            emit StageAdvanced(currentStage);
        }

        // Determine tier
        (, uint256 tierIndex) = getTierByAmount(newUsdTotal);
        user.tier = tierIndex;

        // locked tokens based on TGE
        user.locked += tokenAmount;
        totalLockedTokens += tokenAmount;

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
        address tokenAddress,                  // ERC20 token or address(0) for BNB
        uint256[] calldata designations         // designation levels passed from backend
    ) external payable onlyAdminOrOperator whenNotPaused {
        require(referralTree.length == amounts.length, "Mismatched input lengths");
        require(referralTree.length <= designatedLevels.length, "Max 10 levels");
        require(designations.length == referralTree.length, "Mismatched designations length");

        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < referralTree.length; i++) {
            address referrer = referralTree[i];
            uint256 reward = amounts[i];
            uint256 designation = designations[i];
            if (referrer == address(0) || reward == 0) continue;

            User memory user = users[referrer];
            if (!user.kycVerified) continue;

            user.designationLevel = designation;
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
                emit ReferralRewardDistributed(referrer, i + 1, reward, tokenAddress, designation);
            }
        }

        emit ReferralRewardCompleted(msg.sender, totalDistributed, tokenAddress);
    }

    function setVestingInterval(uint256 newInterval) external onlyOwner {
        // require(newInterval >= 1 days, "Interval must be at least 1 day");
        vestingInterval = newInterval;
        emit VestingIntervalUpdated(newInterval, block.timestamp);
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

    function withdrawToken(address tokenAddress, uint256 amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount = 0");
        if (tokenAddress == cryptoAMMToken) {
            uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
            require(balance - amount >= totalLockedTokens, "Amount exceeds unlocked tokens");
        }
        _transferAsset(msg.sender, amount, tokenAddress);
    }

    function withdrawBNB(uint256 amount) external onlyOwner nonReentrant {
        _transferAsset(msg.sender, amount, address(0));
    }


    function setClaimEnabled(bool _status) external onlyOwner {
        require(_status != isClaimEnabled, "Already in this claim state");

        isClaimEnabled = _status;

        if (_status) {
            claimEnabledTime = block.timestamp;
        } else {
            claimDisabledTime = block.timestamp;
        }

        emit ClaimToggle(_status, block.timestamp);
    }

    function _initializeVestingTiers(VestingTier[] memory tiers) internal {
        require(vestingTiers.length == 0, "Already initialised");
        require(tiers.length > 0, "No tiers supplied");

        for (uint256 i = 0; i < tiers.length; ++i) {
            vestingTiers.push(tiers[i]);
        }
        emit VestingTiersInitialized(tiers.length, block.timestamp);
    }

    function updateVestingTier(
        uint256 index,
        uint256 minAmountUsd,
        uint256 maxAmountUsd,
        uint256 tgeUnlockPercent,
        uint256 vestingDuration
    ) external onlyOwner {
        require(index < vestingTiers.length, "Index out of range");

        // Load the tier we’re editing
        VestingTier storage tier = vestingTiers[index];

        /* ── Apply “only‑if‑non‑zero” rule ───────────────────────── */
        uint256 newMin     = (minAmountUsd      == 0) ? tier.minAmountUsd      : minAmountUsd;
        uint256 newMax     = (maxAmountUsd      == 0) ? tier.maxAmountUsd      : maxAmountUsd;
        uint256 newPercent = (tgeUnlockPercent  == 0) ? tier.tgeUnlockPercent  : tgeUnlockPercent;
        uint256 newDur     = (vestingDuration   == 0) ? tier.vestingDuration   : vestingDuration;
        /* ────────────────────────────────────────────────────────── */

        /* ── Sanity checks after substitution ───────────────────── */
        require(newPercent <= 100,         "Unlock % > 100");
        require(newMax >= newMin,          "max < min");
        require(newDur >= 1 hours, "Duration < 1 hr");
        /* ────────────────────────────────────────────────────────── */

        /* ── Commit to storage ───────────────────────────────────── */
        tier.minAmountUsd     = newMin;
        tier.maxAmountUsd     = newMax;
        tier.tgeUnlockPercent = newPercent;
        tier.vestingDuration  = newDur;
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

            // Clamp to avoid exceeding available tokens due to rounding
            if (tokensToBuy > availableTokens) {
                tokensToBuy = availableTokens;
                usdToUse = (tokensToBuy * pricePerToken) / 1e18;
            }

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
                if (elapsed > tier.vestingDuration) {
                    elapsed = tier.vestingDuration;
                }

                uint256 totalUnlockedFromVesting = (vestedTotal * elapsed) / tier.vestingDuration;

                // Cap unlock to remaining locked
                uint256 claimableVested = totalUnlockedFromVesting > user.locked
                    ? user.locked
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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}