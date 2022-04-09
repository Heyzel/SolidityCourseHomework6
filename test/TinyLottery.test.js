const { expect, use } = require('chai');
const { ethers } = require('hardhat');
const { fixture } = deployments;

const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";
const cDAI_ADDRESS = "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";

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
        random = await ethers.getContract("RandomNumberConsumer");
        mock = await ethers.getContract("VRFCoordinatorMock");
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

            it('Should buy tickets with ETH', async () => {
                await app.connect(deployerSigner).createLottery();

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);
                
                const balanceDAIBefore = parseInt(await dai.balanceOf(app.address));
                const daiBefore = parseInt(await dai.balanceOf(userSigner._address));

                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});

                const daiAfter = parseInt(await dai.balanceOf(userSigner._address));
                const balanceDAIAfter = parseInt(await dai.balanceOf(app.address));
                
                expect(daiAfter).to.be.greaterThan(daiBefore);
                
                expect(balanceDAIAfter).to.be.greaterThan(balanceDAIBefore);
                
                const currentLottery = await app.currentLottery();

                const Lottery = await app.getLottery(currentLottery);
                expect(Lottery[0].toString()).to.be.equal(balanceDAIAfter.toString());
                expect(Lottery[1].toNumber()).to.be.greaterThan(0);

                const User = await app.getUser(currentLottery, 0);
                expect(User[0]).to.be.equal(userSigner._address);
                expect(User[1].toString()).to.be.equal(balanceDAIAfter.toString());
                
            });

            it('Should buy tickets with ETH but participate in the next week lottery', async () => {
                await app.connect(deployerSigner).createLottery();
                const currentLottery = await app.currentLottery();
                var Lottery = await app.getLottery(currentLottery);
                const startTime = parseInt(Lottery[1]);
                await ethers.provider.send("evm_mine", [startTime + 172901]);

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);
                
                const balanceDAIBefore = parseInt(await dai.balanceOf(app.address));
                const daiBefore = parseInt(await dai.balanceOf(userSigner._address));

                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});

                const daiAfter = parseInt(await dai.balanceOf(userSigner._address));
                const balanceDAIAfter = parseInt(await dai.balanceOf(app.address));
                
                expect(daiAfter).to.be.greaterThan(daiBefore);
                
                expect(balanceDAIAfter).to.be.greaterThan(balanceDAIBefore);
                
                Lottery = await app.getLottery(currentLottery+1);

                expect(Lottery[0].toString()).to.be.equal(balanceDAIAfter.toString());
                expect(Lottery[1].toNumber()).to.be.greaterThan(0);

                const User = await app.getUser(currentLottery+1, 0);
                expect(User[0]).to.be.equal(userSigner._address);
                expect(User[1].toString()).to.be.equal(balanceDAIAfter.toString());
                
            });


            it('Should buy tickets with USDC', async () => {
                const toInpersonate = '0xCFFAd3200574698b78f32232aa9D63eABD290703';

                await hre.network.provider.request({
                    method: "hardhat_impersonateAccount",
                    params: [toInpersonate],
                });

                const signerImpersonate = await ethers.getSigner(toInpersonate);

                await app.connect(deployerSigner).createLottery();

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);
                const usdc = await hre.ethers.getContractAt(IERC20, USDC_ADDRESS);

                var balance = parseInt(await dai.balanceOf(app.address));
                expect(balance).to.be.equal(0);

                const amount = 10*10**6;

                await usdc.connect(signerImpersonate).approve(app.address, amount.toString());
                
                await app.connect(signerImpersonate).buyTickets('USDC');

                const Lottery = await app.getLottery(0);
                expect(parseInt(Lottery[0])).to.be.greaterThanOrEqual((amount-(1*10**18)))
                expect(Lottery[1].toNumber()).to.be.greaterThanOrEqual(0);

                const User = await app.getUser(0, 0);
                expect(User[0]).to.be.equal(signerImpersonate.address);
                expect(parseInt(User[1])).to.be.greaterThanOrEqual((amount-(1*10**18)));
            });

            it('Should buy tickets with USDT', async () => {
                const toInpersonate = '0x61F2f664FEc20a2FC1D55409cFc85e1BaeB943e2';

                await hre.network.provider.request({
                    method: "hardhat_impersonateAccount",
                    params: [toInpersonate],
                });

                const signerImpersonate = await ethers.getSigner(toInpersonate);

                await app.connect(deployerSigner).createLottery();

                const IERC20 = require("../abi/ERC20.json");
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);
                const usdt = await hre.ethers.getContractAt(IERC20, USDT_ADDRESS);

                var balance = parseInt(await dai.balanceOf(app.address));
                expect(balance).to.be.equal(0);

                const amount = 10*10**6;

                await usdt.connect(signerImpersonate).approve(app.address, amount.toString());
                
                await app.connect(signerImpersonate).buyTickets('USDT');

                const Lottery = await app.getLottery(0);
                expect(parseInt(Lottery[0])).to.be.greaterThanOrEqual((amount-(1*10**18)))
                expect(Lottery[1].toNumber()).to.be.greaterThanOrEqual(0);

                const User = await app.getUser(0, 0);
                expect(User[0]).to.be.equal(signerImpersonate.address);
                expect(parseInt(User[1])).to.be.greaterThanOrEqual((amount-(1*10**18)));
            });

            it('Should fail if the crypto is not accepted', async () => {
                await app.connect(deployerSigner).createLottery();

                await expect(app.connect(userSigner).buyTickets('LINK')).to.be.revertedWith('That Token is not accepted in this lottery');
            });

        });

        describe('Tests for invest', () => {
            it('Should fail if no lottery in progress', async () => {
                await expect(app.connect(deployerSigner).invest()).to.be.revertedWith("There is no lottery in progress");
            });

            it('Should fail if two days have not passed since the lottery started', async () => {
                await app.connect(deployerSigner).createLottery();
                await expect(app.connect(deployerSigner).invest()).to.be.revertedWith("Cannot invest yet");
            });

            it('Should invest the tokens in the lottery and mint cDAI tokens', async () => {
                await app.connect(deployerSigner).createLottery();
                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                const Lottery = await app.getLottery(0);
                const startTime = parseInt(Lottery[1]);
                await ethers.provider.send("evm_mine", [startTime + 172901]);
                await app.connect(deployerSigner).invest();

                const IERC20 = require("../abi/ERC20.json");
                const cdai = await hre.ethers.getContractAt(IERC20, cDAI_ADDRESS);

                const balance = parseInt(await cdai.balanceOf(app.address));
                expect(balance).to.be.greaterThan(0);
            });
        });

        describe('Tests for chooseWinner', () => {
            it('Should fail if no lottery in progress', async () => {
                await expect(app.connect(deployerSigner).chooseWinner()).to.be.revertedWith("There is no lottery in progress");
            });

            it('Should fail if seven days have not passed since the lottery started', async () => {
                await app.connect(deployerSigner).createLottery();
                await expect(app.connect(deployerSigner).chooseWinner()).to.be.revertedWith("Cannot choose a winner yet");
            });

            it('Should choose a winner for the lottery using a random number from chainlink. Should transfer tokens to the winner and release the user tokens', async () => {
                await app.connect(deployerSigner).createLottery();

                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user2Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user3Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});

                const Lottery = await app.getLottery(0);
                const startTime = parseInt(Lottery[1]);
                await ethers.provider.send("evm_mine", [startTime + 172901]);
                await app.connect(deployerSigner).invest();

                await ethers.provider.send("evm_mine", [startTime + 604801]);

                const IERC20 = require("../abi/ERC20.json");
                const link = await hre.ethers.getContractAt(IERC20, LINK_ADDRESS);
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);

                const amount = 100*10**18;
                await link.connect(deployerSigner).transfer(random.address, amount.toString());

                await random.connect(deployerSigner).getRandomNumber();

                const winnerBalanceBefore = parseInt(await dai.balanceOf(user2Signer._address));
                const recipientBalanceBefore = parseInt(await dai.balanceOf(feeRecipientSigner._address));

                await app.connect(deployerSigner).chooseWinner();

                const winnerBalanceAfter = parseInt(await dai.balanceOf(user2Signer._address));
                const recipientBalanceAfter = parseInt(await dai.balanceOf(feeRecipientSigner._address));

                expect(winnerBalanceAfter).to.be.greaterThan(winnerBalanceBefore);
                expect(recipientBalanceAfter).to.be.greaterThan(recipientBalanceBefore);

            });
        });
        
        describe('Tests for claimTokens', () => {
            it('Should fail if use an invalid ID for lottery or try to claim tokens of a lottery in progress', async () => {
                await app.connect(deployerSigner).createLottery();
                await expect(app.connect(deployerSigner).claimTokens(1, 0)).to.be.revertedWith("Invalid lottery");
                await expect(app.connect(deployerSigner).claimTokens(0, 0)).to.be.revertedWith("Invalid lottery");
            });

            it('Should fail if a user try to claim tokens of other user', async () => {
                await app.connect(deployerSigner).createLottery();

                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user2Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user3Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});

                const Lottery = await app.getLottery(0);
                const startTime = parseInt(Lottery[1]);
                await ethers.provider.send("evm_mine", [startTime + 172901]);
                await app.connect(deployerSigner).invest();

                await ethers.provider.send("evm_mine", [startTime + 604801]);

                const IERC20 = require("../abi/ERC20.json");
                const link = await hre.ethers.getContractAt(IERC20, LINK_ADDRESS);

                const amount = 100*10**18;
                await link.connect(deployerSigner).transfer(random.address, amount.toString());

                await random.connect(deployerSigner).getRandomNumber();

                await app.connect(deployerSigner).chooseWinner();

                await expect(app.connect(userSigner).claimTokens(0, 1)).to.be.revertedWith("Only the user can claim theirs tokens");

            });

            it('The user claim theirs token', async () => {
                await app.connect(deployerSigner).createLottery();

                await app.connect(userSigner).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user2Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});
                await app.connect(user3Signer).buyTickets('ETH', {value: ethers.utils.parseEther("0.01")});

                const Lottery = await app.getLottery(0);
                const startTime = parseInt(Lottery[1]);
                await ethers.provider.send("evm_mine", [startTime + 172901]);
                await app.connect(deployerSigner).invest();

                await ethers.provider.send("evm_mine", [startTime + 604801]);

                const IERC20 = require("../abi/ERC20.json");
                const link = await hre.ethers.getContractAt(IERC20, LINK_ADDRESS);
                const dai = await hre.ethers.getContractAt(IERC20, DAI_ADDRESS);

                const amount = 100*10**18;
                await link.connect(deployerSigner).transfer(random.address, amount.toString());

                await random.connect(deployerSigner).getRandomNumber();

                await app.connect(deployerSigner).chooseWinner();

                const balanceBefore = parseInt(await dai.balanceOf(userSigner._address));

                await app.connect(userSigner).claimTokens(0, 0);

                const balanceAfter = parseInt(await dai.balanceOf(userSigner._address));

                expect(balanceAfter).to.be.greaterThan(balanceBefore);

                await app.connect(deployerSigner).createLottery();
            });
        });
    });
});