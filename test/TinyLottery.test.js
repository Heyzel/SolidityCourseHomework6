const { expect } = require('chai');
const { ethers } = require('hardhat');
const { fixture } = deployments;

const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

describe('TinyLotteryV1 contract', () => {
    beforeEach(async function(){
        ({deployer, feeRecipient, user, user2, user3} = await getNamedAccounts());

        deployerSigner = await ethers.provider.getSigner(deployer);
        feeRecipientSigner = await ethers.provider.getSigner(feeRecipient);
        userSigner = await ethers.provider.getSigner(user);
        user2Signer = await ethers.provider.getSigner(user2);
        user3Signer = await ethers.provider.getSigner(user3);

        // Deploy
        await fixture(["LotteryV1"]);
        app = await ethers.getContract("TinyLottery");
    });

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await app.owner()).to.equal(deployerSigner._address);
        });
    });

})