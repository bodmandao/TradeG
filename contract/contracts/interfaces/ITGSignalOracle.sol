// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITGSignalOracle {
    struct Signal {
        address base;
        address quote;
        uint8 side; // 0=buy,1=sell
        uint32 sizeBps; // portion of vault NAV
        uint256 priceRef;
        uint32 confidenceBps;
        uint64 strategyVersion;
        uint64 deadline;
        bytes32 nonce;
        bytes sig; // EIP-712 signature over Signal metadata
        string payloadUri; // 0G storage pointer (off-chain payload)
        bytes attestation; // optional TEE attestation / proof blob
    }

    function postSignal(Signal calldata s) external returns (bytes32 signalId);
    function getSignal(bytes32 signalId) external view returns (Signal memory);
    function isValid(bytes32 signalId) external view returns (bool);
}
