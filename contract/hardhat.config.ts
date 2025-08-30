import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv'
dotenv.config()

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
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
    }
  }
};

export default config;
