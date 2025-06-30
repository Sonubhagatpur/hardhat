// Import Hardhat utilities
const { ethers, deployments } = require("hardhat");

async function main() {
    // Get signers (owners)
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy the Factory contract (you can specify deployment arguments if needed)
    const factory = await ethers.deployContract("TokenFactory", []);
    console.log("Factory contract deployed at:", factory?.address);


    // Deploying the ERC20 contract using Factory
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    const bytecode = ERC20Token.bytecode;

    const name = "MyToken";
    const symbol = "MTK";
    const decimals = 18;
    const totalSupply = "1000000";
    const owner = deployer.address;

    // Deploy the token using Factory contract
    const deployTx = await factory.deployUsingBytecode(
        bytecode,
        name,
        symbol,
        decimals,
        totalSupply,
        owner,
        { value: "1000000" }
    );

    // Wait for the contract deployment transaction to be confirmed
    const receipt = await deployTx.wait();
    console.log("Token contract deployed at address:", receipt.contractAddress);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
