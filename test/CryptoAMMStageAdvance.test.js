const { expect } = require("chai");
const { ethers } = require("hardhat");

const toEther = (amount) => ethers.parseUnits(amount.toString(), 18);

describe("CryptoAMM Stage Advancement", function () {
    let CryptoAMM, cryptoAMM;
    let MockToken, token, cryptoToken;
    let owner, operator, user;

    beforeEach(async function () {
        [owner, operator, user] = await ethers.getSigners();

        // Deploy mock token (used as stablecoin for purchase)
        MockToken = await ethers.getContractFactory("BTCB");
        token = await MockToken.deploy();
        await token.waitForDeployment();

        cryptoToken = await MockToken.deploy();
        await cryptoToken.waitForDeployment();

        // Define Stages
        const stages = [
            { pricePerToken: 100, tokenCap: toEther(100), sold: 0, bonusPercent: 0 }, // pricePerToken in cents
            { pricePerToken: 100, tokenCap: toEther(100), sold: 0, bonusPercent: 0 }
        ];

        // Define Designated Levels (Only 1 level needed for basic test)
        const designatedLevels = [
            { rewardPercent: 5, minSales: toEther(100) }
        ];

        // Define Vesting Tiers
        const vestingTiers = [
            {
                minAmountUsd: toEther(1),
                maxAmountUsd: toEther(5000),
                tgeUnlockPercent: 10,
                vestingDuration: 86400
            }
        ];

        // Deploy CryptoAMM contract
        CryptoAMM = await ethers.getContractFactory("contracts/CryptoAMM.sol:CryptoAMM");
        cryptoAMM = await CryptoAMM.deploy(
            operator.address,
            cryptoToken.address,
            [token.address],
            designatedLevels,
            stages,
            vestingTiers
        );
        await cryptoAMM.waitForDeployment();

        // Mint and fund test accounts
        await token.mint(user.address, toEther(1000));
        await cryptoToken.mint(cryptoAMM.target, toEther(1000)); // fund contract with token for bonus claim

        // Approve CryptoAMM to spend tokens
        await token.connect(user).approve(cryptoAMM.target, toEther(1000));

        // Register and verify KYC for user
        await cryptoAMM.connect(operator).register(user.address, operator.address);
        await cryptoAMM.connect(operator).verifyKYC(user.address);
    });

    it("should stay on same stage if cap not reached", async () => {
        const stageBefore = await cryptoAMM.currentStage();
        await cryptoAMM.connect(user).buyTokens(token.target, toEther(5)); // $5 at $1/token

        const stageAfter = await cryptoAMM.currentStage();
        expect(stageAfter).to.equal(stageBefore);

        const currentStageData = await cryptoAMM.stages(stageAfter);
        expect(currentStageData.sold).to.be.greaterThan(0);
    });

    it("should advance stage when stage cap is reached", async () => {
        const stageBefore = await cryptoAMM.currentStage();
        const pricePerToken = (await cryptoAMM.stages(stageBefore)).pricePerToken;

        // Purchase all 100 tokens ($1.00 per token)
        await cryptoAMM.connect(user).buyTokens(token.target, toEther(100)); // 100 tokens at 1 USD/token

        const stageAfter = await cryptoAMM.currentStage();
        expect(stageAfter).to.equal(stageBefore + 1);

        const prevStageData = await cryptoAMM.stages(stageBefore);
        expect(prevStageData.sold).to.equal(toEther(100));
    });

    it("should not advance beyond last stage", async () => {
        // Buy 200 tokens, which fills both stages
        await cryptoAMM.connect(user).buyTokens(token.target, toEther(200));

        const currentStage = await cryptoAMM.currentStage();
        expect(currentStage).to.equal(1); // Stage index starts at 0, so max is 1
    });
});
