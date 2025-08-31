// deploy/02-deploy-vault.ts - Fixed version
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, upgrades, ethers } = hre;
  const { deploy, get } = deployments;
  const { deployer, feeCollector } = await getNamedAccounts();

  // Get deployed contracts
  const mockToken = await get("MockERC20");
  const mockRouter = await get("MockRouter");
  const feeManager = await get("TGFeeManager");

  // Deploy TGVault as upgradeable proxy
  const vault = await upgrades.deployProxy(
    await ethers.getContractFactory("TGVault"),
    [
      mockToken.address, // underlying asset
      "TG Vault", // name
      "TGV", // symbol
      deployer, // admin
      feeManager.address, // fee manager
      mockRouter.address, // router
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );

  await vault.waitForDeployment();

  const vaultAddress = await vault.getAddress();
  await deployments.save("TGVault", {
    address: vaultAddress,
    abi: (await ethers.getContractFactory("TGVault")).interface.formatJson() as any,
  });

  console.log("TGVault deployed to:", vaultAddress);

  // Get the token contract with proper typing
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const token = await ethers.getContractAt("MockERC20", mockToken.address);
  
  const initialAmount = ethers.parseEther("1000000");
  
  // Mint and approve tokens
  await token.mint(deployer, initialAmount);
  await token.approve(vaultAddress, initialAmount);
  
  // Deposit into vault
  await vault.deposit(initialAmount, deployer);

  console.log("Vault funded with", initialAmount.toString(), "tokens");
};

export default func;
func.tags = ["vault"];
func.dependencies = ["mocks"];