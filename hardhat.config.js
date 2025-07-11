require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades')
require('dotenv').config();

const ALCHEMY_API_KEY = "EjDmR5n4GOP1VwRBn5dcDl7zOAe1g_hd";
const ALCHEMY_API_KEY_MAINNET = "pDY5hd3sJDp0zX2PdgKR21WNXzIe7cZk";
const GOERLI_PRIVATE_KEY = "";
// https://eth-mainnet.g.alchemy.com/v2/pDY5hd3sJDp0zX2PdgKR21WNXzIe7cZk

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },

  networks: {

    TijaraX: {
      url: `http://172.17.0.1:8545/`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },
    polygonTestnet: {
      url: `https://rpc-amoy.polygon.technology`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },
    sepolia: {
      url: `https://ethereum-sepolia-rpc.publicnode.com`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },
    // mainnet: {
    //   url: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY_MAINNET}`,
    //   accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    // },

    polygon: {
      url: `https://polygon.llamarpc.com`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },

    bscTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },

    wmtxTestnet: {
      url: `https://worldmobile-testnet.g.alchemy.com/v2/Nu51dDIbWs-4mj00WxhLEJ7xRW2pyPLr`,
      accounts: [`0x${process.env.PRIVATE_KEY_TESTNET}`],
    },
    // palmMainnet: {
    //   url: `https://rpc.palmsmartchain.io/`,
    //   accounts: [`0xd6eb5842cc4373bd809cae25c89e8a5bfe457bf09116613e01e541d6e9d3c52d`],
    // }
  },
  etherscan: {
    // apiKey: process.env.VERIFY_CODE_API_BNB_TESTNET,
    // apiKey: process.env.API_KEY_ETHERSCAN,

    apiKey: {
      bscTestnet: process.env.VERIFY_CODE_API_BNB_TESTNET,
      sepolia: process.env.API_KEY_ETHERSCAN,
      polygonTestnet: process.env.API_KEY_API_KEY_POLYSCAN,
      polygon: process.env.API_KEY_API_KEY_POLYSCAN,
      palmMainnet: "fdbfa288-1695-454e-a369-4501253a120",
      wmtxTestnet: "fdbfa288-1695-454e-a369-4501253a120",
    },
    customChains: [
      {
        network: "palmMainnet",
        chainId: 973,
        urls: {
          apiURL: "https://explorer.palmsmartchain.io/api",
          browserURL: "https://explorer.palmsmartchain.io"
        }
      },
      {
        network: "polygonTestnet",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        }
      },
      {
        network: "wmtxTestnet",
        chainId: 323432,
        urls: {
          apiURL: "https://testnet-explorer.worldmobile.net/api",
          browserURL: "https://testnet-explorer.worldmobile.net"
        }
      }
    ]
  }
};
