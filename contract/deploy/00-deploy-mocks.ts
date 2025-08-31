import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Deploy Mock Tokens
  await deploy("MockERC20", {
    from: deployer,
    args: ["Test Token", "TT"],
    log: true,
  });

  await deploy("MockWETH", {
    from: deployer,
    args: ["Wrapped Ether", "WETH"],
    log: true,
  });

  // Deploy Mock Router
  await deploy("MockRouter", {
    from: deployer,
    log: true,
  });

  // Deploy Fee Manager
  await deploy("TGFeeManager", {
    from: deployer,
    log: true,
  });
};

export default func;
func.tags = ["mocks"];