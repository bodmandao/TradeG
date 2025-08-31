import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { get } = deployments;
  const { deployer } = await getNamedAccounts();

  // Get deployed contracts
  const mockRouter = await get("MockRouter");
  const mockToken = await get("MockERC20");
  const mockWETH = await get("MockWETH");

  const router = await ethers.getContractAt("MockRouter", mockRouter.address);
  const token = await ethers.getContractAt("MockERC20", mockToken.address);
  const weth = await ethers.getContractAt("MockWETH", mockWETH.address);

  // Fund router with tokens for testing
  const routerFundAmount = ethers.parseEther("1000000");
  
  // Fund with WETH
  await weth.mint(deployer, routerFundAmount);
  await weth.approve(mockRouter.address, routerFundAmount);
  await router.fundRouter(mockWETH.address, routerFundAmount);

  // Fund with token
  await token.mint(deployer, routerFundAmount);
  await token.approve(mockRouter.address, routerFundAmount);
  await router.fundRouter(mockToken.address, routerFundAmount);

  console.log("Router funded with tokens for testing");

  // Set mock swap results
  await router.setMockSwapResult(mockWETH.address, ethers.parseEther("50"));
  await router.setMockSwapResult(mockToken.address, ethers.parseEther("20000"));

  console.log("Mock swap results configured");
};

export default func;
func.tags = ["configuration"];
func.dependencies = ["mocks", "vault"];