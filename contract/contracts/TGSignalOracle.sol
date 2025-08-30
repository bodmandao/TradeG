// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TGSignalOracle is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;

    struct Signal {
        address base;
        address quote;
        uint8 side;
        uint32 sizeBps;
        uint256 priceRef;
        uint32 confidenceBps;
        uint64 strategyVersion;
        uint64 deadline;
        bytes32 nonce;
        string payloadUri;
        bytes attestation;
        address poster; // who posted (for transparency)
    }

    mapping(bytes32 => Signal) private _signals;
    mapping(bytes32 => bool) public nonceUsed;

    uint64 public strategyVersion;
    uint32 public minConfidenceBps;
    uint64 public expiryWindow; // seconds

    event SignalPosted(
        bytes32 indexed id,
        address indexed base,
        address indexed quote,
        uint8 side,
        uint32 sizeBps,
        uint32 confidence
    );

    function initialize(
        uint64 _strategyVersion,
        uint32 _minConfidenceBps,
        uint64 _expiryWindow,
        address admin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE_, admin);
        strategyVersion = _strategyVersion;
        minConfidenceBps = _minConfidenceBps;
        expiryWindow = _expiryWindow;
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE_) {}

    function postSignal( 
        ITGSignalOracle.Signal calldata s
    ) external returns (bytes32 signalId) {
        require(!nonceUsed[s.nonce], "NONCE_USED");
        require(s.strategyVersion == strategyVersion, "STRAT_VERSION");
        require(s.confidenceBps >= minConfidenceBps, "LOW_CONF");
        require(
            s.deadline >= block.timestamp &&
                s.deadline <= block.timestamp + expiryWindow,
            "BAD_DEADLINE"
        );

        // For simplicity we assume EIP-712 verification is done off-chain or by relayer.
        // The oracle may optionally verify signatures here.

        signalId = keccak256(
            abi.encodePacked(
                s.base,
                s.quote,
                s.side,
                s.sizeBps,
                s.priceRef,
                s.confidenceBps,
                s.strategyVersion,
                s.deadline,
                s.nonce,
                s.payloadUri
            )
        );
        require(_signals[signalId].poster == address(0), "SIGNAL_EXISTS");

        _signals[signalId] = Signal({
            base: s.base,
            quote: s.quote,
            side: s.side,
            sizeBps: s.sizeBps,
            priceRef: s.priceRef,
            confidenceBps: s.confidenceBps,
            strategyVersion: s.strategyVersion,
            deadline: s.deadline,
            nonce: s.nonce,
            payloadUri: s.payloadUri,
            attestation: s.attestation,
            poster: msg.sender
        });

        nonceUsed[s.nonce] = true;
        emit SignalPosted(
            signalId,
            s.base,
            s.quote,
            s.side,
            s.sizeBps,
            s.confidenceBps
        );
    }

    function getSignal(
        bytes32 signalId
    ) external view returns (ITGSignalOracle.Signal memory) {
        ITGSignalOracle.Signal memory out;
        Signal memory s = _signals[signalId];
        out.base = s.base;
        out.quote = s.quote;
        out.side = s.side;
        out.sizeBps = s.sizeBps;
        out.priceRef = s.priceRef;
        out.confidenceBps = s.confidenceBps;
        out.strategyVersion = s.strategyVersion;
        out.deadline = s.deadline;
        out.nonce = s.nonce;
        out.sig = ""; // signatures aren't stored in this simple implementation
        out.payloadUri = s.payloadUri;
        out.attestation = s.attestation;
        return out;
    }

    function isValid(bytes32 signalId) external view returns (bool) {
        Signal memory s = _signals[signalId];
        return s.poster != address(0) && s.deadline >= block.timestamp;
    }
}
