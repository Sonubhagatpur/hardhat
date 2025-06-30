const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const args = ["0xAB594600376Ec9fD91F8e885dADF0CE036862dE0", "0xaf3A55D29e3C7a072F9c448B94e5154A71b23f6d"]

    const lock = await hre.ethers.deployContract("MultiGIFNFTWithInstallments", args);
    await lock.waitForDeployment();
    console.log("Contract address=", lock.target);
    await hre.run("verify:verify", {
        address: lock.target,
        contract: "contracts/MultiGIFNFTWithInstallments.sol:MultiGIFNFTWithInstallments",
        constructorArguments: [args]
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
