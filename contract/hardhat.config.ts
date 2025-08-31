import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv'
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy"
dotenv.config()

const config: HardhatUserConfig = {
  solidity: {
    compilers : [
      {
        version :"0.8.20"
      },
      {
        version : "0.8.22"
      },
      {
        version : "0.8.24"
      },
      {
        version :"0.8.21"
      }
    ],
    settings: {
      evmVersion: "cancun",
      optimizer: {
        enabled: true,
        runs: 200
      }
    } 
  },
  networks : {
    og_testnet : {
      url: "https://evmrpc-testnet.0g.ai",
    chainId: 16601,
    accounts: [process.env.PRIVATE_KEY!]
    },
     hardhat: {
        chainId: 31337,
    },
  },
    namedAccounts: {
      deployer: {
          default: 0,
          1: 0,
      },
  },
};

export default config;
