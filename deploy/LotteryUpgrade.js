const CONTRACT_NAME = 'LotteryV2';

module.exports = async ({getNamedAccounts, deployments}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const random = await deploy('RandomNumberConsumer', {
        from: deployer,
        log: true,
    });

    console.log('success');

    const fee = 5;
    const feeRecipient = deployer;
    const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
    const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
    const USDT = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
    const cDAI = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643';
    const stableSwap = '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7';

    const _args = [feeRecipient, fee, DAI, USDC, USDT, cDAI, random.address, stableSwap];

    await deploy('TinyLottery', {
        from: deployer,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: "initialize",
                    args: _args,
                },
            },
        },
        log: true
    });

    console.log('successfully deployed');

};

module.exports.tags = [CONTRACT_NAME];