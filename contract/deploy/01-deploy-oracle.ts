import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, upgrades } = hre;
  const { deploy, get } = deployments;
  const { deployer, oracleSigner } = await getNamedAccounts();

  // Deploy TGSignalOracle as upgradeable proxy
  const oracle = await upgrades.deployProxy(
    await ethers.getContractFactory("TGSignalOracle"),
    [
      1, // strategyVersion
      500, // minConfidenceBps (5%)
      3600, // expiryWindow (1 hour)
      deployer, // admin
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );

  await oracle.waitForDeployment();

  // Save proxy address to deployments
  const oracleAddress = await oracle.getAddress();
  await deployments.save("TGSignalOracle", {
    address: oracleAddress,
    abi: (await ethers.getContractFactory("TGSignalOracle")).interface.formatJson() as any,
  });

  // Add oracle signer role
  await oracle.addSigner(oracleSigner);

  console.log("TGSignalOracle deployed to:", oracleAddress);
};

export default func;
func.tags = ["oracle"];
func.dependencies = ["mocks"];