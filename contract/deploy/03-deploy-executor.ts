import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, upgrades, ethers } = hre;
  const { deploy, get } = deployments;
  const { deployer, keeper } = await getNamedAccounts();

  // Get deployed contracts
  const oracle = await get("TGSignalOracle");
  const vault = await get("TGVault");

  // Deploy TGExecutor as upgradeable proxy
  const executor = await upgrades.deployProxy(
    await ethers.getContractFactory("TGExecutor"),
    [
      oracle.address, // oracle
      vault.address, // vault
      deployer, // admin
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );

  await executor.waitForDeployment();

  const executorAddress = await executor.getAddress();
  await deployments.save("TGExecutor", {
    address: executorAddress,
    abi: (await ethers.getContractFactory("TGExecutor")).interface.formatJson() as any,
  });

  console.log("TGExecutor deployed to:", executorAddress);

  // Setup roles
  const EXECUTOR_ROLE = await executor.EXECUTOR_ROLE();
  await executor.grantRole(EXECUTOR_ROLE, keeper);

  // Grant executor role in vault to executor contract
  const vaultContract = await ethers.getContractAt("TGVault", vault.address);
  const VAULT_EXECUTOR_ROLE = await vaultContract.EXECUTOR_ROLE();
  await vaultContract.grantRole(VAULT_EXECUTOR_ROLE, executorAddress);

  console.log("Executor roles configured");
};

export default func;
func.tags = ["executor"];
func.dependencies = ["oracle", "vault"];