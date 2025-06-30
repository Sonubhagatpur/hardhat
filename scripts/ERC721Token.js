const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const args = ["AAAAAA", "AAAA", "https://myreview.website/think/thinker-demo/uploads/Ether%20Collection/", "0x1Fb0C631dF78c4Bb723e293D04d687bc0cEfc869", "20000", "10", "10000000000000"];

    // const lock = await hre.ethers.deployContract("ERC721Token", args);
    // await lock.waitForDeployment();
    // console.log("Contract address=", lock.target);
    await hre.run("verify:verify", {
        address: "0xE4384C4130dD480b079b4251e92D23D8522603BD",
        constructorArguments: args,
        contract: "contracts/erc721.sol:ERC721Token",
    });


    // const contractAddress = "0xE4384C4130dD480b079b4251e92D23D8522603BD"; // Replace with actual address
    // const ERC721Token = await hre.ethers.getContractFactory("ERC721Token");
    // const contract = await ERC721Token.attach(contractAddress);

    // // Define mintAdmin parameters
    // const recipient = deployer.address; // Replace with the recipient's address
    // const tokenId = 1; // Set the token ID

    // // Call mintAdmin function
    // const tx = await contract.mintAdmin(recipient, tokenId);
    // await tx.wait();

    // console.log(`mintAdmin executed! Token ID ${tokenId} minted to ${recipient}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});