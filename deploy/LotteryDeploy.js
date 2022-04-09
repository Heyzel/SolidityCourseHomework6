const CONTRACT_NAME = 'LotteryV1';

module.exports = async ({getNamedAccounts, deployments}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

    const mock = await deploy('VRFCoordinatorMock', {
        from: deployer,
        log: true,
        args: [LINK],
    });

    const random = await deploy('RandomNumberConsumer', {
        from: deployer,
        log: true,
        args: [mock.address, LINK],
    });

    console.log('success');

    const fee = 5;
    const feeRecipient = deployer;
    const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
    const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
    const USDT = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
    const cDAI = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643';
    const stableSwapUSDC = '0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56';
    const stableSwapUSDT = '0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C';

    const _args = [feeRecipient, fee, DAI, USDC, USDT, cDAI, random.address, stableSwapUSDC, stableSwapUSDT];

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