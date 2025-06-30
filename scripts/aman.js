const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    const tokenContracts = ["0x0000000000000000000000000000000000000000"];
    const userTypes = [0]; // Assuming UserType is an enum, use appropriate values
    const durations = [[1, 10, 100]];
    const rewardRates = [[5000, 10000, 15000]];
    const tax = [[1000, 2000, 3000]];

    console.log("Deploying contracts with the account:", deployer.address);

    // const Aman = await hre.ethers.getContractFactory("Aman");
    // const aman = await Aman.deploy(tokenContracts, userTypes, durations, rewardRates, tax);
    // await aman.waitForDeployment();

    // await new Promise(resolve => setTimeout(resolve, 5000));

    const contractAddress = "0x3170131b2Ad70D1Ba27b254fE7bD5Ad8F2E1136C" //aman.address;


    console.log("Aman contract deployed to:", contractAddress);

    // Verify the contract after a short delay to ensure propagation
    await hre.run("verify:verify", {
        address: contractAddress,
        contract: "contracts/aman.sol:Aman",
        constructorArguments: [tokenContracts, userTypes, durations, rewardRates, tax]
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
