// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/ITGSignalOracle.sol";
import "./TGVault.sol";

contract TGExecutor is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;

    ITGSignalOracle public oracle;
    TGVault public vault;

    event Executed(
        bytes32 indexed signalId,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function initialize(
        address oracle_,
        address vault_,
        address admin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE_, admin);
        oracle = ITGSignalOracle(oracle_);
        vault = TGVault(vault_);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE_) {}

    struct ExecParams {
        bytes32 signalId;
        uint256 maxSlippageBps;
        uint256 minOut;
        uint256 deadline;
        bytes routeData;
    }

    function execute(
        ExecParams calldata p
    ) external nonReentrant onlyRole(EXECUTOR_ROLE) {
        require(oracle.isValid(p.signalId), "BAD_SIGNAL");
        ITGSignalOracle.Signal memory s = oracle.getSignal(p.signalId);
        // Risk checks (sizeBps, cooldowns, price sanity) should happen here.
        // For simplicity, amountIn is computed as vault.totalAssets() * sizeBps / 10000
        uint256 amountIn = (vault.totalAssets() * uint256(s.sizeBps)) / 10000;

        address assetIn = s.side == 0 ? address(vault.asset()) : s.base; // simplistic mapping
        address assetOut = s.side == 0 ? s.base : address(vault.asset());

        vault.executeTrade(
            assetIn,
            assetOut,
            amountIn,
            p.minOut,
            p.deadline,
            p.routeData
        );

        emit Executed(p.signalId, assetIn, assetOut, amountIn, p.minOut);
    }
}
