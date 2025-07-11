const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);


  // 10 Designated Levels
  const levels = [
    { rewardPercent: 10, minSales: ethers.parseUnits("1000") },                         // Level 1: KYC only
    { rewardPercent: 9, minSales: ethers.parseUnits("2500") },
    { rewardPercent: 8, minSales: ethers.parseUnits("5000") },
    { rewardPercent: 7, minSales: ethers.parseUnits("12500") },
    { rewardPercent: 6, minSales: ethers.parseUnits("25000") },
    { rewardPercent: 5, minSales: ethers.parseUnits("50000") },
    { rewardPercent: 4, minSales: ethers.parseUnits("125000") },
    { rewardPercent: 3, minSales: ethers.parseUnits("250000") },
    { rewardPercent: 2, minSales: ethers.parseUnits("500000") },
    { rewardPercent: 1, minSales: ethers.parseUnits("1250000") },
  ];

  // 18 Stages (example: price increases gradually, bonus decreases)
  const stages = [];
  for (let i = 0; i < 18; i++) {
    stages.push({
      pricePerToken: 100 + i * 10, // e.g., start at 1.00 USDT and increase
      tokenCap: ethers.parseUnits("100000"), // each stage has 100,000 tokens
      sold: 0,
      bonusPercent: i < 7 ? 14 - i * 2 : 1, // bonus starts high then fades
    });
  }

  // const tiers = [
  //   [0, ethers.parseUnits("500"), 10, 24 * 30 * 24 * 60 * 60],
  //   [ethers.parseUnits("501"), ethers.parseUnits("1100"), 20, 24 * 30 * 24 * 60 * 60],
  //   [ethers.parseUnits("1101"), ethers.parseUnits("1800"), 30, 24 * 30 * 24 * 60 * 60],
  //   [ethers.parseUnits("1801"), ethers.parseUnits("2600"), 40, 24 * 30 * 24 * 60 * 60],
  //   [ethers.parseUnits("2601"), ethers.constants.MaxUint256, 50, 24 * 30 * 24 * 60 * 60]
  // ];
  const FIVE_DAYS = 2 * 60 * 60;   // 432 000


  const tiers = [
    [0, ethers.parseUnits("500"), 10, FIVE_DAYS],
    [ethers.parseUnits("501"), ethers.parseUnits("1100"), 20, FIVE_DAYS],
    [ethers.parseUnits("1101"), ethers.parseUnits("1800"), 30, FIVE_DAYS],
    [ethers.parseUnits("1801"), ethers.parseUnits("2600"), 40, FIVE_DAYS],
    [ethers.parseUnits("2601"), ethers.MaxUint256, 50, FIVE_DAYS]
  ];

  const tokens = [
    "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd",
    "0x64544969ed7EBf5f083679233325356EbE738930",
    "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee"
  ];

  const args = [
    "0x3067506445c2B4eC8f0A907Cb19B137EF1705D15",
    "0x96c888f612505DE4F9F5F35f54B218da68187E4D", // CryptoAMMToken address
    tokens, // tokens address
    levels, // Designated Levels
    stages, // Stages of the AMM
    tiers
  ];
  const CryptoAMM = await ethers.getContractFactory("contracts/CryptoAMM.sol:CryptoAMM");
  console.log("Deploying CryptoAMM...");
  const cryptoAMM = await upgrades.deployProxy(
    CryptoAMM,
    args,
    { initializer: "initialize" }
  );

  // const lock = await hre.ethers.deployContract("contracts/CryptoAMM.sol:CryptoAMM", args);
  await cryptoAMM.waitForDeployment();
  // console.log("Contract address Brain=", lock.target);
  const contractAddress = cryptoAMM.target;
  await hre.run("verify:verify", {
    address: contractAddress,
    // constructorArguments: args,
    contract: "contracts/CryptoAMM.sol:CryptoAMM",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
