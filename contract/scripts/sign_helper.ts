import { ethers } from "ethers";


// EIP-712 helper for signing TGSignalOracle.Signal struct
export async function signSignal(signer: ethers.Wallet, domain: any, types: any, value: any) {
    // domain: { name, version, chainId, verifyingContract }
    // types: { Signal: [...] }
    const signature = await signer.signTypedData(domain, types, value);
    return signature;
}


export const SIGNAL_TYPES = {
    Signal: [
        { name: 'base', type: 'address' },
        { name: 'quote', type: 'address' },
        { name: 'side', type: 'uint8' },
        { name: 'sizeBps', type: 'uint32' },
        { name: 'priceRef', type: 'uint256' },
        { name: 'confidenceBps', type: 'uint32' },
        { name: 'strategyVersion', type: 'uint64' },
        { name: 'deadline', type: 'uint64' },
        { name: 'nonce', type: 'bytes32' },
        { name: 'payloadUri', type: 'string' }
    ]
};


export function buildDomain(chainId: number, verifyingContract: string) {
    return {
        name: 'TGSignalOracle',
        version: '1',
        chainId,
        verifyingContract
    };
}