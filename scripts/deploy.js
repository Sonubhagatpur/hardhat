const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(balance, " balance")


  const arg = [1296000, 2592000, 15780096];
  const arg1 = [1296000, 2592000, 21040128];
  const arg2 = [1296000, 2592000, 28930176];

  const lock = await hre.ethers.deployContract("PalmStaking", [arg, arg1, arg2]);
  await new Promise(resolve => setTimeout(resolve, 5000));
  await lock.waitForDeployment();
  console.log("Contract address =", lock.target);
  // await hre.run("verify:verify", {
  //   address: lock.target,
  //   contract: "contracts/PalmWallet.sol:PalmStaking",
  //   constructorArguments: [arg, arg1, arg2]
  // });

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
