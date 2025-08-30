// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ITGRouter.sol";
import "./TGFeeManager.sol";

contract TGVault is
    Initializable,
    IERC20,
    ERC4626Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    // State
    uint256 private _highWaterMark; // assetPerShare scaled 1e18
    address public feeManager;
    ITGRouter public router;
    bool public withdrawalOnly;

    event TradeExecuted(address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);

    /// @notice Initialize the upgradeable vault.
    /// @param asset_ underlying asset 
    /// @param name_ ERC20 name
    /// @param symbol_ ERC20 symbol
    /// @param admin_ admin (governance)
    /// @param feeManager_ fee manager address
    /// @param router_ router/adapter address
    function initialize(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address admin_,
        address feeManager_,
        address router_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC4626_init(asset_);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        feeManager = feeManager_;
        router = ITGRouter(router_);
        _highWaterMark = 1e18; // initial NAV = 1
    }

    // UUPS authorization
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // expose assetPerShare for fee manager (scaled 1e18)
    function assetPerShare() public view returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        // totalAssets() is from ERC4626Upgradeable; scaled arithmetic:
        return (totalAssets() * 1e18) / totalSupply();
    }

    // --- deposit / redeem overrides (call super to use ERC4626Upgradeable implementations) ---
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626Upgradeable)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(!withdrawalOnly, "WITHDRAWALS_ONLY");
        uint256 shares = previewDeposit(assets);
        // entry fee hook could be added here
        super.deposit(assets, receiver);
        _maybeUpdateHWM();
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626Upgradeable)
        nonReentrant
        returns (uint256)
    {
        uint256 assets = previewRedeem(shares);
        // exit fee hook could be added here
        uint256 out = super.redeem(shares, receiver, owner);
        _maybeUpdateHWM();
        return out;
    }

    // Executor calls this to execute a trade
    function executeTrade(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minOut,
        uint256 deadline,
        bytes calldata routeData
    ) external nonReentrant onlyRole(EXECUTOR_ROLE) whenNotPaused {
        require(!withdrawalOnly, "TRADING_HALTED");
        // vault approves router adapter to pull tokens (adapter should call router)
        IERC20(assetIn).approve(address(router), amountIn);
        uint256 out = router.swap(address(this), assetIn, assetOut, amountIn, minOut, deadline, routeData);
        _maybeUpdateHWM();
        emit TradeExecuted(assetIn, assetOut, amountIn, out);
    }

    // Called by fee manager to mint fee shares to collector
    function mintFeeShares(uint256 feeShares, address collector) external {
        require(msg.sender == feeManager, "ONLY_FEE_MANAGER");
        _mint(collector, feeShares);
    }

    function _maybeUpdateHWM() internal {
        if (totalSupply() == 0) return;
        uint256 nav = assetPerShare();
        if (nav > _highWaterMark) {
            // call fee manager to accrue performance fee
            try TGFeeManager(feeManager).accruePerformanceFee(address(this), nav, _highWaterMark) {
                // ignore revert; fee manager may opt to revert on edge-cases
            } catch {
                // continue without reverting execution
            }
            _highWaterMark = nav;
        }
    }

    // admin helpers
    function setWithdrawalOnly(bool v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawalOnly = v;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
