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

    describe('Tests for functions', () => {
        describe('Tests for setRecipient', () => {
            it('Should set the feeRecipient', async () => {
                await app.connect(deployerSigner).setRecipient(feeRecipientSigner._address);
                expect(await app.feeRecipient()).to.equal(feeRecipientSigner._address);
            });
        });

        describe('Tests for setFee', () => {
            it('Should set the fee', async () => {
                await app.connect(deployerSigner).setFee(100) // fee = 100 is 1%
                expect(await app.fee()).to.equal(100);
            });
        });

        describe('Tests for createLottery', () => {
            it('Should create a new lottery', async () => {
                var lotteryInProgress = await app.lotteryInCourse();
                var lotteryIndex = await app.currentLottery();
                expect(lotteryInProgress).to.be.equal(false);
                expect(lotteryIndex).to.be.equal(0);
                await app.connect(deployerSigner).createLottery();
                lotteryInProgress = await app.lotteryInCourse();
                lotteryIndex = await app.currentLottery();
                expect(lotteryInProgress).to.be.equal(true);
                expect(lotteryIndex).to.be.equal(0);
            });

            it('Should fail if a lottery is already in progress', async () => {
                await app.connect(deployerSigner).createLottery();
                await expect(app.connect(deployerSigner).createLottery()).to.be.revertedWith('There is a lottery in progress');
            });
        });

        describe('Tests for buyTickets', () => {
            it('Should fail if no lottery in progress', async () => {
                await expect(app.connect(deployerSigner).buyTickets('ETH')).to.be.revertedWith('There is no lottery in progress');
            });

            it('Should buy tickets with DAI', async () => {
                const toInpersonate = '0x5D38B4e4783E34e2301A2a36c39a03c45798C4dD';

                await hre.network.provider.request({
                    method: "hardhat_impersonateAccount",
                    params: [toInpersonate],
                });

                const signerImpersonate = await ethers.getSigner(toInpersonate);

                await app.connect(deployerSigner).createLottery();

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);

                var balance = parseInt(await dai.balanceOf(app.address));
                expect(balance).to.be.equal(0);

                const amount = 10*10**18;

                await dai.connect(signerImpersonate).approve(app.address, amount.toString());
                expect(await app.connect(signerImpersonate).buyTickets('DAI')).to.emit(app, 'TicketsBought')
                .withArgs(amount.toString(), 0, 0, signerImpersonate.address);

                balance = parseInt(await dai.balanceOf(app.address));
                expect(balance.toString()).to.be.equal(amount.toString());

                const Lottery = await app.getLottery(0);
                expect(Lottery[0]).to.be.equal(amount.toString());
                expect(Lottery[1].toNumber()).to.be.greaterThan(0);

                const User = await app.getUser(0, 0);
                expect(User[0]).to.be.equal(signerImpersonate.address);
                expect(User[1]).to.be.equal(amount.toString());
            });

            it('Should refund DAI if pass decimals', async () => {
                const toInpersonate = '0x5D38B4e4783E34e2301A2a36c39a03c45798C4dD';

                await hre.network.provider.request({
                    method: "hardhat_impersonateAccount",
                    params: [toInpersonate],
                });

                const signerImpersonate = await ethers.getSigner(toInpersonate);

                await app.connect(deployerSigner).createLottery();

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);

                var balance = parseInt(await dai.balanceOf(app.address));
                expect(balance).to.be.equal(0);
                var signerBalanceBefore = parseInt(await dai.balanceOf(signerImpersonate.address));

                // should refund 0.1 DAI
                const amount = 10.1*10**18;
                const correctAmount = 10*10**18;

                await dai.connect(signerImpersonate).approve(app.address, amount.toString());
                expect(await app.connect(signerImpersonate).buyTickets('DAI')).to.emit(app, 'TicketsBought')
                .withArgs(amount.toString(), 0, 0, signerImpersonate.address);

                balance = parseInt(await dai.balanceOf(app.address));
                expect(balance.toString()).to.be.equal(correctAmount.toString());
                var signerBalance = parseInt(await dai.balanceOf(signerImpersonate.address));
                // This is tested in this way for precision problems
                expect(signerBalanceBefore - signerBalance).to.be.lessThanOrEqual(10.00001*10**18);
                expect(signerBalanceBefore - signerBalance).to.be.greaterThanOrEqual(10.00000*10**18);
            });
        });
    });
});