// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ITGSignalOracleInternal {
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
        bytes sig;
        string payloadUri;
        bytes attestation;
        address poster;
    }
}

contract TGSignalOracle is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using Address for address;

    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;
    bytes32 public constant ORACLE_SIGNER_ROLE =
        keccak256("ORACLE_SIGNER_ROLE");

    // EIP-712 domain
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant SIGNAL_TYPEHASH =
        keccak256(
            "Signal(address base,address quote,uint8 side,uint32 sizeBps,uint256 priceRef,uint32 confidenceBps,uint64 strategyVersion,uint64 deadline,bytes32 nonce,string payloadUri)"
        );

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
        address poster; // who posted (relayer)
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
        uint32 confidence,
        address signer,
        address poster
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

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("TGSignalOracle")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE_) {}

    /// @notice Post a signed signal. The signer is recovered from the EIP-712 signature contained in `s.sig`.
    function postSignal(
        ITGSignalOracleInternal.Signal calldata s
    ) external returns (bytes32 signalId) {
        require(!nonceUsed[s.nonce], "NONCE_USED");
        require(s.strategyVersion == strategyVersion, "STRAT_VERSION");
        require(s.confidenceBps >= minConfidenceBps, "LOW_CONF");
        require(
            s.deadline >= block.timestamp &&
                s.deadline <= block.timestamp + expiryWindow,
            "BAD_DEADLINE"
        );

        // Recreate the digest for EIP-712
        bytes32 structHash = keccak256(
            abi.encode(
                SIGNAL_TYPEHASH,
                s.base,
                s.quote,
                s.side,
                s.sizeBps,
                s.priceRef,
                s.confidenceBps,
                s.strategyVersion,
                s.deadline,
                s.nonce,
                keccak256(bytes(s.payloadUri))
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        address signer = _recoverSigner(digest, s.sig);
        require(hasRole(ORACLE_SIGNER_ROLE, signer), "BAD_SIGNER");

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
            s.confidenceBps,
            signer,
            msg.sender
        );
    }

    function getSignal(
        bytes32 signalId
    ) external view returns (ITGSignalOracleInternal.Signal memory) {
        Signal memory s = _signals[signalId];
        ITGSignalOracleInternal.Signal memory out;
        out.base = s.base;
        out.quote = s.quote;
        out.side = s.side;
        out.sizeBps = s.sizeBps;
        out.priceRef = s.priceRef;
        out.confidenceBps = s.confidenceBps;
        out.strategyVersion = s.strategyVersion;
        out.deadline = s.deadline;
        out.nonce = s.nonce;
        out.sig = ""; // signature not stored here
        out.payloadUri = s.payloadUri;
        out.attestation = s.attestation;
        out.poster = s.poster;
        return out;
    }

    function isValid(bytes32 signalId) external view returns (bool) {
        Signal memory s = _signals[signalId];
        return s.poster != address(0) && s.deadline >= block.timestamp;
    }

    // Admin helpers
    function addSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE_) {
        grantRole(ORACLE_SIGNER_ROLE, signer);
    }

    function removeSigner(
        address signer
    ) external onlyRole(DEFAULT_ADMIN_ROLE_) {
        revokeRole(ORACLE_SIGNER_ROLE, signer);
    }

    // --- internal helpers ---
    function _recoverSigner(
        bytes32 digest,
        bytes memory signature
    ) internal pure returns (address) {
        // signature is r(32) + s(32) + v(1)
        require(signature.length == 65, "BAD_SIG_LEN");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "BAD_V");
        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "INVALID_SIGNER");
        return signer;
    }
}
