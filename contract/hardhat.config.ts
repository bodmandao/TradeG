import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatKeystore from "@nomicfoundation/hardhat-keystore";

import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [
    hardhatToolboxMochaEthersPlugin,
    hardhatKeystore
  ],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    og_testnet: {
    type:"http",
    url: configVariable("OG_TESTNET_RPC_URL"),
    chainId: 16601,
    accounts: [configVariable("OG_PRIVATE_KEY")]
  }
  },
};

export default config;
