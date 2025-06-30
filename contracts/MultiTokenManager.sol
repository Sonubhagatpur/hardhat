// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19; 
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; 
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; 
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; 
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol"; 


contract MultiTokenManager is 
ERC20Upgradeable, 
OwnableUpgradeable, 
UUPSUpgradeable, 
ReentrancyGuardUpgradeable 
{ 
// Struct to hold token information 
struct TokenInfo { 
string name; 
string symbol; 
uint256 mintingFee; 
uint256 referralRewardRate; 
uint256 airdropAmount; 
bool isActive; 
uint256 collateralizationRatio; 
} 
struct Proposal { 
string description; 
uint256 votesFor; 
uint256 votesAgainst; 
uint256 snapshotBlock; 
uint256 deadline; 
bool executed; 
} 
mapping(string => TokenInfo) public supportedTokens; 
mapping(uint256 => Proposal) public proposals; 
mapping(uint256 => mapping(address => bool)) public hasVoted; 
uint256 public proposalCount; 
IUniswapV2Router02 public uniswapRouter; 
IUniswapV2Factory public uniswapFactory; 
AggregatorV3Interface internal priceFeed; 
mapping(address => uint256) public collateral; 
mapping(address => address) public referrals; 
// Events 
event TokenAdded(string indexed name, string indexed symbol); 
event ProposalCreated(uint256 indexed proposalId, string description, uint256 deadline); 
event VoteCast(uint256 indexed proposalId, address indexed voter, bool support); 
event ProposalExecuted(uint256 indexed proposalId); 
event AirdropClaimed(address indexed user, uint256 amount); 
event ReferralRewardClaimed(address indexed referrer, uint256 reward); 
/// @custom:oz-upgrades-unsafe-allow constructor 
constructor() { 
_disableInitializers(); 
} 
function initialize( 
string memory name, 
string memory symbol, 
address _router, 
address _factory, 
address _priceFeed 
) public initializer { 
__ERC20_init(name, symbol); 
//__Ownable_init(0xaf3A55D29e3C7a072F9c448B94e5154A71b23f6d); 
__UUPSUpgradeable_init(); 
__ReentrancyGuard_init(); 
uniswapRouter = IUniswapV2Router02(_router); 
uniswapFactory = IUniswapV2Factory(_factory); 
priceFeed = AggregatorV3Interface(_priceFeed); 
} 
function _authorizeUpgrade(address newImplementation) internal override onlyOwner {} 
function addToken( 
string memory name, 
string memory symbol, 
uint256 mintingFee, 
uint256 referralRewardRate, 
uint256 airdropAmount, 
uint256 collateralizationRatio 
) external onlyOwner { 
require(!supportedTokens[name].isActive, "Token already added"); 
supportedTokens[name] = TokenInfo({ 
name: name, 
symbol: symbol, 
mintingFee: mintingFee, 
referralRewardRate: referralRewardRate, 
airdropAmount: airdropAmount, 
isActive: true, 
collateralizationRatio: collateralizationRatio 
}); 
emit TokenAdded(name, symbol); 
} 
function mintTokens(address to, uint256 amount) external onlyOwner { 
uint256 dynamicAmount = amount * getDynamicMintingFactor(msg.sender); 
_mint(to, dynamicAmount); 
} 
function getDynamicMintingFactor(address user) public view returns (uint256) { 
uint256 userBalance = balanceOf(user); 
uint256 dynamicFactor = 100; 
if (userBalance >= 100 * (10**18)) { 
dynamicFactor = 110; 
} 
return dynamicFactor; 
} 
function depositCollateral() external payable nonReentrant { 
collateral[msg.sender] += msg.value; 
} 
function mintAgainstCollateral(string memory tokenName, uint256 amount) external { 
require( 
collateral[msg.sender] >= (amount * supportedTokens[tokenName].collateralizationRatio) / 100, 
"Insufficient collateral" 
); 
_mint(msg.sender, amount); 
} 
function provideLiquidity( 
address tokenA, 
address tokenB, 
uint256 amountADesired, 
uint256 amountBDesired, 
uint256 amountAMin, 
uint256 amountBMin 
) external nonReentrant { 
IERC20Upgradeable(tokenA).transferFrom(msg.sender, address(this), amountADesired); 
IERC20Upgradeable(tokenB).transferFrom(msg.sender, address(this), amountBDesired); 
IERC20Upgradeable(tokenA).approve(address(uniswapRouter), amountADesired); 
IERC20Upgradeable(tokenB).approve(address(uniswapRouter), amountBDesired); 
uniswapRouter.addLiquidity( 
tokenA, 
tokenB, 
amountADesired, 
amountBDesired, 
amountAMin, 
amountBMin, 
msg.sender, 
block.timestamp 
); 
} 
function getLatestPrice() public view returns (int) { 
(, int price, , , ) = priceFeed.latestRoundData(); 
return price; 
} 
function registerReferral(address referrer) external { 
require(referrer != msg.sender, "Cannot refer yourself"); 
require(referrals[msg.sender] == address(0), "Referral already registered"); 
referrals[msg.sender] = referrer; 
} 
function claimAirdrop(string memory tokenName) external { 
TokenInfo memory token = supportedTokens[tokenName]; 
require(token.isActive, "Token not active"); 
require(referrals[msg.sender] != address(0), "No referrer registered"); 
// Mint airdrop tokens to the user 
_mint(msg.sender, token.airdropAmount); 
// Mint referral reward to the referrer 
_mint(referrals[msg.sender], (token.airdropAmount * token.referralRewardRate) / 100); 
// Emit event for airdrop 
emit AirdropClaimed(msg.sender, token.airdropAmount); 
emit ReferralRewardClaimed(referrals[msg.sender], (token.airdropAmount * token.referralRewardRate) / 100); 
} 
function createProposal(string memory description) external onlyOwner { 
proposals[proposalCount] = Proposal({ 
description: description, 
votesFor: 0, 
votesAgainst: 0, 
snapshotBlock: block.number, 
deadline: block.timestamp + 7 days, 
executed: false 
}); 
emit ProposalCreated(proposalCount, description, block.timestamp + 7 days); 
proposalCount++; 
} 
function vote(uint256 proposalId, bool support) external { 
Proposal storage proposal = proposals[proposalId]; 
require(block.timestamp < proposal.deadline, "Voting period ended"); 
require(proposal.snapshotBlock <= block.number, "Snapshot not yet taken"); 
require(!hasVoted[proposalId][msg.sender], "Already voted"); 
uint256 votingPower = balanceOfAt(msg.sender, proposal.snapshotBlock); 
require(votingPower > 0, "No voting power"); 
hasVoted[proposalId][msg.sender] = true; 
if (support) { 
proposal.votesFor += votingPower; 
} else { 
proposal.votesAgainst += votingPower; 
} 
emit VoteCast(proposalId, msg.sender, support); 
} 
function executeProposal(uint256 proposalId) external { 
Proposal storage proposal = proposals[proposalId]; 
require(block.timestamp >= proposal.deadline, "Voting period not ended"); 
require(!proposal.executed, "Proposal already executed"); 
require(proposal.votesFor > proposal.votesAgainst, "Proposal not approved"); 
proposal.executed = true; 
emit ProposalExecuted(proposalId); 
} 
function balanceOfAt(address account, uint256 blockNumber) public view returns (uint256) { 
ERC20Upgradeable token = ERC20Upgradeable(address(this)); 
uint256 balanceAtSnapshot = token.balanceOf(account); 
return balanceAtSnapshot; 
} 
receive() external payable {} 
} 
