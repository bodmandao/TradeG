// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./interfaces/ITGRouter.sol";
import "./TGFeeManager.sol";

contract TGVault is
    ERC4626,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuard,
    Pausable
{
    using Math for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE_ = 0x00;

    uint256 private _highWaterMark; // 1e18 scaled assetPerShare
    address public feeManager;
    ITGRouter public router;
    bool public withdrawalOnly;

    event TradeExecuted(
        address indexed assetIn,
        address indexed assetOut,
        uint256 amountIn,
        uint256 amountOut
    );

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

        _grantRole(DEFAULT_ADMIN_ROLE_, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        feeManager = feeManager_;
        router = ITGRouter(router_);
        _highWaterMark = 1e18; // initial NAV = 1
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE_) {}

    // expose assetPerShare for fee manager
    function assetPerShare() public view returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        return (totalAssets() * 1e18) / totalSupply();
    }

    // deposit / redeem overrides to add fee hooks
    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant whenNotPaused returns (uint256) {
        require(!withdrawalOnly, "WITHDRAWALS_ONLY");
        uint256 shares = previewDeposit(assets);
        // entry fee hook if needed
        ERC4626.deposit(assets, receiver);
        _maybeUpdateHWM();
        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256) {
        uint256 assets = previewRedeem(shares);
        // exit fee hook if needed
        uint256 out = ERC4626.redeem(shares, receiver, owner);
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
        IERC20(assetIn).approve(address(router), amountIn);
        uint256 out = router.swap(
            address(this),
            assetIn,
            assetOut,
            amountIn,
            minOut,
            deadline,
            routeData
        );
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
            try
                TGFeeManager(feeManager).accruePerformanceFee(
                    address(this),
                    nav,
                    _highWaterMark
                )
            {
                // ignore revert; fee manager may opt to revert on edge-cases
            } catch {
                // continue without reverting execution
            }
            _highWaterMark = nav;
        }
    }

    // admin helpers
    function setWithdrawalOnly(bool v) external onlyRole(DEFAULT_ADMIN_ROLE_) {
        withdrawalOnly = v;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
