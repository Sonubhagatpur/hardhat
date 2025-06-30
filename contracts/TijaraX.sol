// SPDX-License-Identifier: MIT
  pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

  contract TijaraxBasic {
 
      struct User {
          uint id;
          uint totalInvestment;
          address referrer;
          uint partnersCount;
          address[] referrerAddresses;
          
          mapping(uint8 => bool) activeX3Levels;

          mapping(uint8 => uint) slotEarning;

      }

      uint8 public LAST_LEVEL;
      
      mapping(address => User) public users;
      mapping(uint => address) public idToAddress;
      mapping(uint => address) public userIds;

      uint public lastUserId;
      address public id1;
      address public paymentWallet;
      
      mapping(uint8 => uint) public levelPrice;
      mapping(uint8 => uint) public LEVEL_INCOME;

      IERC20Upgradeable public depositToken;
      
      uint public BASIC_PRICE;
      
      event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId);
      event Upgrade(address indexed user, address indexed referrer, uint8 level);
      event ReferralRewardDistributed(address indexed user, uint256 amount, uint8 level);
      event RewardNotDistributed(address indexed user, uint256 amount, uint8 level, string reason);
      event RewardNotFullyReceived(address indexed user, uint256 amount, uint8 level, string reason);

  }


  contract TijaraX is TijaraxBasic, Initializable, OwnableUpgradeable, PausableUpgradeable {

        function initialize() external initializer {
          __Pausable_init_unchained();
          __Ownable_init_unchained();
          BASIC_PRICE = 5 ether;
          LAST_LEVEL = 10;

          levelPrice[1] = BASIC_PRICE;
          levelPrice[2] = 7 ether;
          levelPrice[3] = 15 ether;
          levelPrice[4] = 30 ether;
          levelPrice[5] = 60 ether;
          levelPrice[6] = 100 ether;
          levelPrice[7] = 150 ether;
          levelPrice[8] = 250 ether;
          levelPrice[9] = 400 ether;
          levelPrice[10] = 600 ether;

          
          id1 = _msgSender();
          
          users[id1].id = 1;
          users[id1].referrer = address(0);
          users[id1].partnersCount = 0;
          idToAddress[1] = _msgSender();

          for (uint8 i = 1; i <= LAST_LEVEL; i++) {
              users[id1].activeX3Levels[i] = true;
          }

          LEVEL_INCOME[1] = 40;
          LEVEL_INCOME[2] = 25;
          LEVEL_INCOME[3] = 15;
          LEVEL_INCOME[4] = 10;
          LEVEL_INCOME[5] = 10;

          
          userIds[1] = _msgSender();
          lastUserId = 2;
          paymentWallet = _msgSender();
          depositToken = IERC20Upgradeable(0xe41E2BD1F843B78663e71D1852623d735072a190);
      }

      function pause() external onlyAdmin returns (bool success) {
          _pause();
          return true;
      }

      function unpause() external onlyAdmin returns (bool success) {
          _unpause();
          return true;
      }
      
      function changePaymentWallet(address _newPaymentWallet) external onlyAdmin {
          require(_newPaymentWallet != address(0), "address cannot be zero");
          require(_newPaymentWallet != paymentWallet, "This address is already fixed");
          paymentWallet = _newPaymentWallet;
      }

      modifier onlyUnlocked() { 
      require(!paused() || msg.sender == owner()); 
      _; 
      }

      modifier onlyAdmin() {
        require(owner() == _msgSender() || _msgSender() == paymentWallet, "Admin: caller is not the admin");
        _;
      }

      function registrationExt(address referrerAddress) external onlyUnlocked() {
          registration(msg.sender, referrerAddress);
      }

      function registrationFor(address userAddress, address referrerAddress) external onlyAdmin() {
          registration(userAddress, referrerAddress);
      }

      function buyNewLevel(uint8 level) external onlyUnlocked() {
      _buyNewLevel(msg.sender, level);
      }

      function buyNewLevelFor(address userAddress, uint8 level) external onlyAdmin() {
          _buyNewLevel(userAddress, level);
      }

      function registration(address userAddress, address referrerAddress) private {

          require(!isUserExists(userAddress), "user exists");
          require(isUserExists(referrerAddress), "referrer not exists");

          //depositToken.transferFrom(msg.sender, address(this), BASIC_PRICE);
          
          users[userAddress].id = lastUserId;
          users[userAddress].referrer = referrerAddress;
          users[userAddress].partnersCount = 0;

          idToAddress[lastUserId] = userAddress;
                  
          users[userAddress].activeX3Levels[1] = true; 
          
          userIds[lastUserId] = userAddress;
          lastUserId++;
          
          users[referrerAddress].partnersCount++;

          users[referrerAddress].referrerAddresses.push(userAddress);

          users[userAddress].totalInvestment += levelPrice[1];

          distributeReferralsReward(userAddress, levelPrice[1], 1, 1);

          emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id);
      }

      function distributeReferralsReward(
          address _user,
          uint256 amount,
          uint8 level,
          uint8 _incomeLevel
      ) private {

          address directAddress = users[_user].referrer;
          if (_incomeLevel <= 5 && directAddress != address(0)) {
              uint256 income = LEVEL_INCOME[_incomeLevel];
              uint256 payAmount = (amount * income) / 100;

              if(users[directAddress].activeX3Levels[level]){
              (address receiver, uint256 receivingAmount) = findPaymentReceiver(directAddress, level, payAmount);
              //if(receivingAmount > 0) depositToken.transfer(receiver, receivingAmount);
              users[receiver].slotEarning[level] += receivingAmount;
              emit ReferralRewardDistributed(receiver, receivingAmount, level);
              }else{
              //depositToken.transfer(paymentWallet, payAmount);
              emit ReferralRewardDistributed(paymentWallet, payAmount, level);
              // Emit an event to explain why the user did not receive the amount
              emit RewardNotDistributed(directAddress, payAmount, level, "User's X3 level is not active");
              }
              
              distributeReferralsReward(directAddress, amount, level, _incomeLevel + 1);
          }
      }

    function findPaymentReceiver(address userAddress, uint8 level, uint256 amount) private returns(address, uint256) {
          uint256 maxEarning = levelPrice[level] * 3;
          if(users[userAddress].slotEarning[level] + amount >= maxEarning){
            uint256 receivingAmount = maxEarning - users[userAddress].slotEarning[level];
              uint leftAmount = amount - receivingAmount;
              //if(leftAmount > 0) depositToken.transfer(paymentWallet, leftAmount);
              emit ReferralRewardDistributed(paymentWallet,  leftAmount, level);
              emit RewardNotFullyReceived(userAddress, leftAmount, level, "User's earning limit reached");
              return (userAddress,receivingAmount);
              }else{
                return (userAddress, amount);
              }
      }

      function _buyNewLevel(address _userAddress, uint8 level) internal {
          require(isUserExists(_userAddress), "user is not exists. Register first.");
          require(level > 1 && level <= LAST_LEVEL, "invalid level");

          require(users[_userAddress].activeX3Levels[level-1], "buy previous level first");
          require(!users[_userAddress].activeX3Levels[level], "level already activated");

         // depositToken.transferFrom(msg.sender, address(this), levelPrice[level]);
          
          users[_userAddress].activeX3Levels[level] = true;

          users[_userAddress].totalInvestment += levelPrice[level];

          distributeReferralsReward(_userAddress, levelPrice[level], level,1);

          emit Upgrade(_userAddress, users[_userAddress].referrer, level);

      }

      function usersActiveX3Levels(address userAddress, uint8 level) public view returns(bool) {
        return users[userAddress].activeX3Levels[level];
      }

      function usersX3LevelsEarnings(address userAddress, uint8 level) public view returns(uint) {
        return users[userAddress].slotEarning[level];
      }

      function isUserExists(address user) public view returns (bool) {
          return (users[user].id != 0);
      }
      
      function withdrawLostTokens(address tokenAddress, uint amount) public onlyAdmin() {
        
        IERC20Upgradeable newToken = IERC20Upgradeable(tokenAddress);
        uint256 tokenBalance = newToken.balanceOf(address(this));
        require(tokenBalance >= amount, "Insufficient balance");
        bool success = newToken.transfer(paymentWallet, amount);
        require(success, "Transfer failed");
      } 

      receive() external payable {
        revert("BNB deposits are not accepted");
      }

  }