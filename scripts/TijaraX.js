const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const TijaraX = await hre.ethers.getContractFactory("TijaraX");

    const contract = await TijaraX.attach("0x2fA47D768875b374Dd7ce2420b471Adbd3a25aD9");
    // Prepare test user and referrer addresses
    const referrerAddress = "0x1Fb0C631dF78c4Bb723e293D04d687bc0cEfc869" // replace with actual referrer address

    // Call the function
    const tx = await contract.registrationExt(referrerAddress);
    await tx.wait();

    console.log("registrationFor executed successfully.");


    return;
    const lock = await hre.ethers.deployContract("TijaraX");
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
