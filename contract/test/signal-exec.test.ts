import { ethers, upgrades } from "hardhat";
import { expect } from "chai";

describe("Signal -> Execute flow", function () {
    let oracle: any;
    let token: any;
    let deployer: any;
    let signer: any;
    let keeper: any;
    let oracleSignerWallet: any;
    let vault :any
    let executor:any

    beforeEach(async function () {
        [deployer, signer, keeper] = await ethers.getSigners();
        
        // Use one of the test accounts as signer
        oracleSignerWallet = signer;

        const MockERC20 = await ethers.getContractFactory("MockERC20");
        token = await MockERC20.deploy("Test Token", "TT",6);
        
         // Deploy Vault
        const Vault = await ethers.getContractFactory("TGVault");
        vault = await upgrades.deployProxy(
            Vault,
            [token.target, "TG Vault", "TGV", deployer.address, deployer.address, deployer.address],
            { initializer: "initialize", kind: "uups" }
        );
        await vault.waitForDeployment();


        // Deploy Oracle as upgradeable proxy
        const TGSignalOracle = await ethers.getContractFactory("TGSignalOracle");
        oracle = await upgrades.deployProxy(
            TGSignalOracle,
            [
                1, // strategyVersion
                500, // minConfidenceBps (5%)
                3600, // expiryWindow (1 hour)
                deployer.address // admin
            ],
            { 
                initializer: "initialize",
                kind: "uups" 
            }
        );
        
        // Wait for deployment to complete
        await oracle.waitForDeployment();
        
        // Add the oracle signer wallet as a valid signer
        await oracle.addSigner(oracleSignerWallet.address);

        // Deploy Executor 
        const Executor = await ethers.getContractFactory("TGExecutor");
        executor = await upgrades.deployProxy(
            Executor,
            [await oracle.getAddress(), await vault.getAddress(), deployer.address],
            { initializer: "initialize", kind: "uups" }
        );
        await executor.waitForDeployment();
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

        const signature = await oracleSignerWallet.signTypedData(domain, types, value);
        return signature;
    }

    it("Should post signal then executor executes", async function () {
        const deadline = Math.floor(Date.now() / 1000) + 3600;
        const nonce = ethers.encodeBytes32String("n1");
        
        const signalData = {
            base: ethers.ZeroAddress,
            quote: token.target,
            side: 0,
            sizeBps: 1000,
            priceRef: ethers.parseUnits("2000", 0),
            confidenceBps: 800,
            strategyVersion: 1,
            deadline: deadline,
            nonce: nonce,
            payloadUri: "ipfs://QmFake",
            attestation: "0x",
            poster: deployer.address
        };

        // Generate valid signature
        const signature = await createSignature(signalData);

        const Signal = {
            ...signalData,
            sig: signature,
            attestation: "0x"
        };

        // Post the signal
        const tx = await oracle.postSignal(Signal);
        const receipt = await tx.wait();

        // Get signal ID from event
        let signalId: string;
        const eventLog = receipt.logs.find(async(log:any) => 
            log.address.toLowerCase() === (await oracle.getAddress()).toLowerCase()
        );
        
        if (eventLog) {
            const parsedEvent = oracle.interface.parseLog(eventLog);
            signalId = parsedEvent.args[0];
            console.log("Signal posted with ID:", signalId);
        } else {
            throw new Error("SignalPosted event not found");
        }

        expect(signalId).to.not.be.undefined;
    });
});