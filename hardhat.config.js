require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require('hardhat-deploy-ethers');
require("solidity-coverage");
require("hardhat-deploy");
require('chai');

require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 14545041,
      },
      chainId: 31337,
    },
  },
  etherscan: {
    apiKey: process.env.API_KEY,
  },
  namedAccounts: {
    deployer: '0x0D4f1ff895D12c34994D6B65FaBBeEFDc1a9fb39',
    feeRecipient: 1,
    user: 2,
    user2: 3,
    user3: 4,
  },
  paths:{
    deploy: 'deploy',
    deployments: 'deployments',
  }
};
