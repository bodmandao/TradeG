import { ethers, upgrades } from "hardhat";
// import 


async function main() {
const [deployer] = await ethers.getSigners();
console.log("Deploying with", deployer.address);


// Deploy fee manager
const FeeManager = await ethers.getContractFactory("TGFeeManager");
const feeManager = await upgrades.deployProxy(FeeManager, [1500, 100, deployer.address, deployer.address]);
await feeManager.deployed();
console.log("FeeManager:", feeManager.address);


// Mock router - for production replace with a router adapter
const Router = await ethers.getContractFactory("MockRouter");
const router = await Router.deploy();
await router.deployed();
console.log("Router:", router.address);


// Deploy SignalOracle
const Oracle = await ethers.getContractFactory("TGSignalOracle");
const oracle = await upgrades.deployProxy(Oracle, [1, 500, 3600, deployer.address]);
await oracle.deployed();
console.log("Oracle:", oracle.address);


// Deploy Vault - need an ERC20 to wrap
const Token = await ethers.getContractFactory("MockERC20");
const token = await Token.deploy("USDC Mock", "mUSDC", 6);
await token.deployed();
console.log("Mock token:", token.address);


const Vault = await ethers.getContractFactory("TGVault");
const vault = await upgrades.deployProxy(Vault, [token.address, "TG Vault", "TGV", deployer.address, feeManager.address, router.address]);
await vault.deployed();
console.log("Vault:", vault.address);


// Executor
const Executor = await ethers.getContractFactory("TGExecutor");
const executor = await upgrades.deployProxy(Executor, [oracle.address, vault.address, deployer.address]);
await executor.deployed();
console.log("Executor:", executor.address);


// Grant roles
const EXECUTOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("EXECUTOR_ROLE"));
await vault.grantRole(EXECUTOR_ROLE, executor.address);
console.log("Granted executor role to executor")
}


main().catch((e) => { console.error(e); process.exit(1); });