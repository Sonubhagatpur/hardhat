const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const Polytech = await hre.ethers.getContractAt("Aman", "0x351048CefC47945ef7e09f1543E62b579D8CE66f"); // Replace CONTRACT_ADDRESS with the address of your deployed contract
    const hash = await Polytech.withdrawBNB("0x1Fb0C631dF78c4Bb723e293D04d687bc0cEfc869", "42000000000000000"); // Call the withdraw function with the desired argument

    console.log(hash, " sonu singh")

    // const lock = await hre.ethers.deployContract("Polytech");
    // await lock.waitForDeployment();
    // console.log("Contract address =", lock.target);
    // await new Promise(resolve => setTimeout(resolve, 10000));
    // await hre.run("verify:verify", {
    //     address: lock.target,
    //     contract: "contracts/ecoai.sol:ECOAI",
    // });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
