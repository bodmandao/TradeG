// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ITGRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock router for tests. Simulates a swap by transferring `amountIn` from vault to itself
/// and then transferring the same amount back to the vault as `amountOut` (1:1). This allows tests
/// to exercise vault executeTrade without integrating a real DEX.
contract MockRouter is ITGRouter {
    function swap(
        address vault,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 /*minOut*/,
        uint256 /*deadline*/,
        bytes calldata /*routeData*/
    ) external pure returns (uint256) {
        // In a real router, pool logic determines amounts. For mock, simply ensure vault approved this contract and then return amountIn.
        // No transfers are required because the vault holds the tokens already and we assume router will pull them via allowance in production.
        // For testing, return amountIn as amountOut (1:1).
        return amountIn;
    }
}
