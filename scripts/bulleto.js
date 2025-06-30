const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const lock = await hre.ethers.deployContract("BulletoToken",['0x1Fb0C631dF78c4Bb723e293D04d687bc0cEfc869']);
    await lock.waitForDeployment();
    console.log("Contract address=", lock.target);
    await hre.run("verify:verify", {
        address: lock.target
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
