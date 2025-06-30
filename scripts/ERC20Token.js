const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const args = ["Doge Token", "DOGE", 18, 400000, "0x1Fb0C631dF78c4Bb723e293D04d687bc0cEfc869"];

    // const lock = await hre.ethers.deployContract("ERC20Token", args);
    // await lock.waitForDeployment();
    // console.log("Contract address=", lock.target);
    await hre.run("verify:verify", {
        address: "0x3Aa75FEbf6C8fE0Bc977327Eb3bC41D017De6E06",
        constructorArguments: args,
        contract: "contracts/ERC20TokenMintBurnable.sol:ERC20Token",
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});