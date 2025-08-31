import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { get } = deployments;
  const { deployer, oracleSigner } = await getNamedAccounts();

  console.log("=== Protocol Deployment Complete ===");
  console.log("Deployer:", deployer);
  console.log("Oracle Signer:", oracleSigner);

  // Log all deployed addresses
  const contracts = [
    "MockERC20",
    "MockWETH",
    "MockRouter",
    "TGFeeManager",
    "TGSignalOracle",
    "TGVault",
    "TGExecutor"
  ];

  for (const contractName of contracts) {
    try {
      const deployment = await get(contractName);
      console.log(`${contractName}:`, deployment.address);
    } catch (error) {
      console.log(`${contractName}: Not deployed`);
    }
  }

  console.log("\n=== Ready for testing ===");
};

export default func;
func.tags = ["setup"];
func.dependencies = ["executor", "configuration"];