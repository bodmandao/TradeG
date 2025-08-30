// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TGFeeManager is UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;

    uint16 public perfFeeBps; // e.g., 1500 = 15%
    uint16 public mgmtFeeBps; // annualized
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

    // Placeholder: real implementations compute delta over high-water mark and mint fee shares or skim assets.
    function accruePerformanceFee(
        address /*vault*/,
        uint256 /*newNAV*/,
        uint256 /*oldHWM*/
    ) external {
        // Implement fee minting / collection logic off-chain planned design
    }
}
