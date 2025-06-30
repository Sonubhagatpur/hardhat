const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const lock = await hre.ethers.deployContract("NFT_Marketplace");
    await new Promise(resolve => setTimeout(resolve, 5000));
    await lock.waitForDeployment();
    console.log("Contract address =", lock.target);

    // await hre.run("verify:verify", {
    //     address: lock.target,
    // });

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
