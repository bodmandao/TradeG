// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ITGVaultFeeable {
    function totalSupply() external view returns (uint256);

    function assetPerShare() external view returns (uint256);

    function mintFeeShares(uint256 feeShares, address collector) external;
}

contract TGFeeManager is UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;

    uint16 public perfFeeBps; // e.g., 1500 = 15%
    uint16 public mgmtFeeBps; // annualized in bps (e.g., 100 = 1%)
    address public feeCollector;

    function initialize(
        uint16 _perfFeeBps,
        uint16 _mgmtFeeBps,
        address collector,
        address admin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE_, admin);
        perfFeeBps = _perfFeeBps;
        mgmtFeeBps = _mgmtFeeBps;
        feeCollector = collector;
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE_) {}

    /// @notice Accrue and mint performance fee shares to feeCollector.
    /// @param vault The vault address (must implement ITGVaultFeeable)
    /// @param newNAV assetPerShare scaled 1e18
    /// @param oldHWM assetPerShare scaled 1e18
    function accruePerformanceFee(
        address vault,
        uint256 newNAV,
        uint256 oldHWM
    ) external {
        require(newNAV > oldHWM, "NO_GAIN");
        ITGVaultFeeable v = ITGVaultFeeable(vault);
        uint256 totalSupply = v.totalSupply();
        if (totalSupply == 0) return;

        // gain per share (scaled 1e18)
        uint256 gainPerShare = newNAV - oldHWM; // scaled 1e18
        // total gain in assets = gainPerShare * totalSupply / 1e18
        uint256 totalGainAssets = (gainPerShare * totalSupply) / 1e18;
        // fee in assets = totalGainAssets * perfFeeBps / 10000
        uint256 feeAssets = (totalGainAssets * uint256(perfFeeBps)) / 10000;
        if (feeAssets == 0) return;

        // convert feeAssets -> feeShares using newNAV (assetPerShare)
        // feeShares = feeAssets * 1e18 / newNAV
        uint256 feeShares = (feeAssets * 1e18) / newNAV;
        if (feeShares == 0) return;

        // mint fee shares to collector via vault
        v.mintFeeShares(feeShares, feeCollector);
    }
}
