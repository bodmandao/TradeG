import { ethers, upgrades } from "hardhat";
import { expect } from "chai";

describe("Full Integration: Signal -> Execute -> Trade -> Vault", function () {
    let oracle: any;
    let executor: any;
    let vault: any;
    let router: any;
    let feeManager: any;
    let token: any;
    let weth: any;
    let deployer: any;
    let signer: any;
    let keeper: any;

    beforeEach(async function () {
        [deployer, signer, keeper] = await ethers.getSigners();

        // Deploy Mock Token (underlying asset)
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        token = await MockERC20.deploy("Test Token", "TT",6);
        
        // Deploy Mock WETH (for trading)
        weth = await MockERC20.deploy("Wrapped Ether", "WETH",6);

        // Deploy Mock Router
        const MockRouter = await ethers.getContractFactory("MockRouter");
        router = await MockRouter.deploy();

        // Deploy Fee Manager
        const TGFeeManager = await ethers.getContractFactory("TGFeeManager");
        feeManager = await TGFeeManager.deploy();

        // Deploy Vault (upgradeable)
        const TGVault = await ethers.getContractFactory("TGVault");
        vault = await upgrades.deployProxy(
            TGVault,
            [
                token.target,    // underlying asset
                "TG Vault",      // name
                "TGV",           // symbol
                deployer.address, // admin
                feeManager.target, // fee manager
                router.target     // router
            ],
            { initializer: "initialize", kind: "uups" }
        );
        await vault.waitForDeployment();

        // Deploy Oracle (upgradeable)
        const TGSignalOracle = await ethers.getContractFactory("TGSignalOracle");
        oracle = await upgrades.deployProxy(
            TGSignalOracle,
            [
                1, // strategyVersion
                500, // minConfidenceBps
                3600, // expiryWindow
                deployer.address // admin
            ],
            { initializer: "initialize", kind: "uups" }
        );
        await oracle.waitForDeployment();

        // Deploy Executor (upgradeable)
        const TGExecutor = await ethers.getContractFactory("TGExecutor");
        executor = await upgrades.deployProxy(
            TGExecutor,
            [
                oracle.target,
                vault.target,
                deployer.address
            ],
            { initializer: "initialize", kind: "uups" }
        );
        await executor.waitForDeployment();

        // Setup roles
        await oracle.addSigner(signer.address);
        const EXECUTOR_ROLE = await executor.EXECUTOR_ROLE();
        await executor.grantRole(EXECUTOR_ROLE, keeper.address);
        
        // Grant executor role to executor contract in vault
        const VAULT_EXECUTOR_ROLE = await vault.EXECUTOR_ROLE();
        await vault.grantRole(VAULT_EXECUTOR_ROLE, executor.target);

        // Fund the vault with initial tokens
        const initialAmount = ethers.parseEther("1000000");
        await token.mint(deployer.address, initialAmount);
        await token.connect(deployer).approve(vault.target, initialAmount);
        await vault.connect(deployer).deposit(initialAmount, deployer.address);
    });

    // Helper function to create EIP-712 signature
    async function createSignature(signalData: any) {
        const domain = {
            name: "TGSignalOracle",
            version: "1",
            chainId: (await ethers.provider.getNetwork()).chainId,
            verifyingContract: await oracle.getAddress()
        };

        const types = {
            Signal: [
                { name: "base", type: "address" },
                { name: "quote", type: "address" },
                { name: "side", type: "uint8" },
                { name: "sizeBps", type: "uint32" },
                { name: "priceRef", type: "uint256" },
                { name: "confidenceBps", type: "uint32" },
                { name: "strategyVersion", type: "uint64" },
                { name: "deadline", type: "uint64" },
                { name: "nonce", type: "bytes32" },
                { name: "payloadUri", type: "string" }
            ]
        };

        const value = {
            base: signalData.base,
            quote: signalData.quote,
            side: signalData.side,
            sizeBps: signalData.sizeBps,
            priceRef: signalData.priceRef,
            confidenceBps: signalData.confidenceBps,
            strategyVersion: signalData.strategyVersion,
            deadline: signalData.deadline,
            nonce: signalData.nonce,
            payloadUri: signalData.payloadUri
        };

        const signature = await signer.signTypedData(domain, types, value);
        return signature;
    }

    it("Full flow: Signal -> Execute -> Trade -> Vault", async function () {
        // 1. Create and post signal
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        const nonce = ethers.encodeBytes32String("n1");
        
        const signalData = {
            base: weth.target,    // Buy WETH with vault's token
            quote: token.target,
            side: 0,              // 0 = buy base (WETH)
            sizeBps: 1000,        // 10% of AUM
            priceRef: ethers.parseUnits("2000", 0), // $2000 per ETH
            confidenceBps: 800,
            strategyVersion: 1,
            deadline: deadline,
            nonce: nonce,
            payloadUri: "ipfs://QmFake",
            attestation: "0x",
            poster: deployer.address
        };

        const signature = await createSignature(signalData);
        const Signal = { ...signalData, sig: signature, attestation: "0x" };

        // Post the signal
        const postTx = await oracle.postSignal(Signal);
        const postReceipt = await postTx.wait();

        // Get signal ID from event
        const eventLog = postReceipt.logs.find(async(log:any) => 
            log.address.toLowerCase() === (await oracle.getAddress()).toLowerCase()
        );
        const parsedEvent = oracle.interface.parseLog(eventLog!);
        const signalId = parsedEvent.args[0];

        // 2. Prepare execution parameters
        const totalAssets = await vault.totalAssets();
        const expectedAmountIn = (totalAssets * 1000n) / 10000n; // 10% of AUM
        
        const execParams = {
            signalId: signalId,
            maxSlippageBps: 500, // 5% slippage
            minOut: 1,           // Minimum 1 wei out (for testing)
            deadline: deadline,
            routeData: "0x"      // Mock route data
        };

        // 3. Mock router to return expected output
        const expectedAmountOut = ethers.parseEther("50"); // Mock 50 WETH out
        await router.setMockSwapResult(weth.target, expectedAmountOut);

        // 4. Execute the trade
        const executeTx = await executor.connect(keeper).execute(execParams);
        const executeReceipt = await executeTx.wait();

        // 5. Verify execution events
        const executionEvents = executeReceipt.logs
            .filter((log:any)   => log.address === executor.target)
            .map((log:any) => executor.interface.parseLog(log))
            .filter((event:any) => event?.name === "Executed");

        expect(executionEvents.length).to.equal(1);
        expect(executionEvents[0].args.signalId).to.equal(signalId);
        expect(executionEvents[0].args.assetIn).to.equal(token.target);
        expect(executionEvents[0].args.assetOut).to.equal(weth.target);
        expect(executionEvents[0].args.amountIn).to.equal(expectedAmountIn);

        // 6. Verify vault emitted TradeExecuted event
        const tradeEvents = executeReceipt.logs
            .filter((log:any) => log.address === vault.target)
            .map((log:any) => vault.interface.parseLog(log))
            .filter((event:any) => event?.name === "TradeExecuted");

        expect(tradeEvents.length).to.equal(1);
        expect(tradeEvents[0].args.assetIn).to.equal(token.target);
        expect(tradeEvents[0].args.assetOut).to.equal(weth.target);
        expect(tradeEvents[0].args.amountIn).to.equal(expectedAmountIn);

        // 7. Verify vault state changed (WETH balance increased)
        const wethBalance = await weth.balanceOf(vault.target);
        expect(wethBalance).to.equal(expectedAmountOut);

        // 8. Verify token balance decreased
        const tokenBalance = await token.balanceOf(vault.target);
        expect(tokenBalance).to.be.lt(totalAssets); // Should be less after trade
    });

    it("Vault releases funds on redeem", async function () {
        // Deposit funds
        const depositAmount = ethers.parseEther("1000");
        await token.mint(deployer.address, depositAmount);
        await token.connect(deployer).approve(vault.target, depositAmount);
        
        const shares = await vault.connect(deployer).deposit(depositAmount, deployer.address);
        
        // Verify deposit worked
        expect(await vault.balanceOf(deployer.address)).to.equal(shares);
        
        // Redeem funds
        const redeemTx = await vault.connect(deployer).redeem(shares, deployer.address, deployer.address);
        const redeemReceipt = await redeemTx.wait();
        
        // Verify redemption was successful
        expect(redeemReceipt.status).to.equal(1);
        
        // Check final token balance
        const finalBalance = await token.balanceOf(deployer.address);
        expect(finalBalance).to.be.gt(0);
    });

    it("Should handle sell signals (side = 1)", async function () {
        // First acquire some WETH in the vault
        const wethAmount = ethers.parseEther("10");
        await weth.mint(vault.target, wethAmount);
        
        // Create sell signal (sell WETH for token)
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        const nonce = ethers.encodeBytes32String("n2");
        
        const signalData = {
            base: weth.target,    // Sell WETH
            quote: token.target,  // For token
            side: 1,              // 1 = sell base (WETH)
            sizeBps: 5000,        // 50% of WETH position
            priceRef: ethers.parseUnits("2000", 0),
            confidenceBps: 800,
            strategyVersion: 1,
            deadline: deadline,
            nonce: nonce,
            payloadUri: "ipfs://QmFake",
            attestation: "0x",
            poster: deployer.address
        };

        const signature = await createSignature(signalData);
        const Signal = { ...signalData, sig: signature, attestation: "0x" };

        // Post and execute signal
        await oracle.postSignal(Signal);
        
        const execParams = {
            signalId: ethers.keccak256(ethers.toUtf8Bytes("test-sell")),
            maxSlippageBps: 500,
            minOut: 1,
            deadline: deadline,
            routeData: "0x"
        };

        // Mock router for sell trade
        const expectedTokenOut = ethers.parseEther("20000"); // 10 ETH * $2000 = 20000 tokens
        await router.setMockSwapResult(token.target, expectedTokenOut);

        await expect(executor.connect(keeper).execute(execParams)).to.emit(vault, "TradeExecuted");
    });
});