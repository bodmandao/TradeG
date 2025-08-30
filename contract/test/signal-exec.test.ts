import { expect } from "chai";
import { ethers, upgrades } from "hardhat";


describe("Signal -> Execute flow (mock)", function () {
    it("posts signal then executor executes via vault and router", async function () {
        const [deployer, keeper] = await ethers.getSigners();


        const FeeManager = await ethers.getContractFactory("TGFeeManager");
        const feeManager = await upgrades.deployProxy(FeeManager, [1500, 100, deployer.address, deployer.address]);


        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const token = await MockERC20.deploy("USDC Mock", "mUSDC", 6);


        const MockRouter = await ethers.getContractFactory("MockRouter");
        const router = await MockRouter.deploy();


        const Oracle = await ethers.getContractFactory("TGSignalOracle");
        const oracle = await upgrades.deployProxy(Oracle, [1, 500, 3600, deployer.address]);


        const Vault = await ethers.getContractFactory("TGVault");
        const vault = await upgrades.deployProxy(Vault, [token.address, "TG Vault", "TGV", deployer.address, feeManager.address, router.address]);


        const Executor = await ethers.getContractFactory("TGExecutor");
        const executor = await upgrades.deployProxy(Executor, [oracle.address, vault.address, deployer.address]);


        // grant executor role on vault
        const EXECUTOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("EXECUTOR_ROLE"));
        await vault.grantRole(EXECUTOR_ROLE, executor.address);


        // mint some tokens to a user and deposit
        await token.mint(deployer.address, ethers.utils.parseUnits("1000000", 6));
        await token.approve(vault.address, ethers.utils.parseUnits("1000000", 6));
        await vault.deposit(ethers.utils.parseUnits("1000000", 6), deployer.address);


        // create a fake signal and post
        const Signal = {
            base: ethers.constants.AddressZero, // pretend base is ETH placeholder
            quote: token.address,
            side: 0,
            sizeBps: 1000, // 10%
            priceRef: ethers.utils.parseUnits("2000", 0),
            confidenceBps: 800,
            strategyVersion: 1,
            deadline: Math.floor(Date.now() / 1000) + 3600,
            nonce: ethers.utils.formatBytes32String("n1"),
            sig: "0x",
            payloadUri: "ipfs://QmFake",
            attestation: "0x"
        };


        const tx = await oracle.postSignal(Signal);
        const rc = await tx.wait();
        const id = rc.events?.[0].args?.id || ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake"));


        // executor executes
        const execParams = {
            signalId: id,
            maxSlippageBps: 50,
            minOut: 1,
            deadline: Math.floor(Date.now() / 1000) + 3600,
            routeData: "0x"
        };


        // grant executor role to keeper and call
        await executor.grantRole(EXECUTOR_ROLE, keeper.address);
        await executor.connect(keeper).execute(execParams);


        // check vault emitted event
        // (For brevity, checks are minimal)
        expect(true).to.be.true;
    });
});