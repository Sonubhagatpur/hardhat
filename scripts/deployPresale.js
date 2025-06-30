const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const lock = await hre.ethers.deployContract("EcoAiCoinPresale");
  await lock.waitForDeployment();
  console.log("Contract address=", lock.target);
  await new Promise(resolve => setTimeout(resolve, 10000));
  await hre.run("verify:verify", {
    address: lock.target,
    contract: "contracts/EcoAiCoinPresale.sol:EcoAiCoinPresale",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
