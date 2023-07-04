/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { HardhatUserConfig } from "hardhat/config";
const dotenv = require("dotenv");
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@float-capital/solidity-coverage";
import "@typechain/hardhat";
import "hardhat-abi-exporter";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10_000,
      },
    },
  },
  networks: {
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [process.env.WALLET_PRIVATE_KEY!].filter(Boolean),
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/7e92a4d7e4f84c949538574187ddf3bf`,
      accounts: process.env.MNEMONIC
        ? { mnemonic: process.env.MNEMONIC }
        : [process.env.WALLET_PRIVATE_KEY!].filter(Boolean),
    },
    fantom: {
      url: `https://rpc.ankr.com/fantom`,
      accounts: [process.env.WALLET_PRIVATE_KEY!].filter(Boolean),
    },
    fantom_test: {
      url: `https://rpc.ankr.com/fantom_testnet`,
      accounts: process.env.MNEMONIC
        ? { mnemonic: process.env.MNEMONIC }
        : [process.env.WALLET_PRIVATE_KEY!].filter(Boolean),
    },
    hardhat: {
      initialBaseFeePerGas: 0,
      forking: {
        url: `https://rpc.ankr.com/fantom_testnet`,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  abiExporter: {
    path: "./abi",
    clear: true,
  },
  typechain: {
    outDir: "./typechain",
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
    gasPrice: 50,
    src: "contracts",
    coinmarketcap: "7643dfc7-a58f-46af-8314-2db32bdd18ba",
  },
  mocha: {
    timeout: 60_000,
  },
};
export default config;
