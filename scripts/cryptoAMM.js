const hre = require("hardhat");

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

  const tokens = [
    "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd",
    "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd",
    "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd"
  ];

  const args = [
    "0x3067506445c2B4eC8f0A907Cb19B137EF1705D15",
    "0x96c888f612505DE4F9F5F35f54B218da68187E4D", // CryptoAMMToken address
    tokens, // tokens address
    levels, // Designated Levels
    stages // Stages of the AMM
  ];

  console.log(args, "args");

  const lock = await hre.ethers.deployContract("contracts/CryptoAMM.sol:CryptoAMM", args);
  await lock.waitForDeployment();
  console.log("Contract address Brain=", lock.target);
  const contractAddress = lock.target;
  await hre.run("verify:verify", {
    address: contractAddress,
    constructorArguments: args,
    contract: "contracts/CryptoAMM.sol:CryptoAMM",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
