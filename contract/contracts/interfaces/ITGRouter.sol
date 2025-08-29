// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITGRouter {
    /// Swaps assetIn -> assetOut held by vault, sends back to vault.
    function swap(
        address vault,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bytes calldata routeData
    ) external returns (uint256 amountOut);
}
