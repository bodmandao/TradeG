// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ITGRouter.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Simple adapter for UniswapV2-style routers.
contract UniswapV2Adapter is ITGRouter {
    IUniswapV2Router02 public immutable router;

    constructor(address router_) {
        router = IUniswapV2Router02(router_);
    }

    function swap(
        address vault,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bytes calldata routeData
    ) external returns (uint256) {
        // routeData is abi-encoded address[] path
        address[] memory path = abi.decode(routeData, (address[]));
        require(path.length >= 2, "BAD_PATH");
        require(
            path[0] == assetIn && path[path.length - 1] == assetOut,
            "PATH_MISMATCH"
        );

        // Pull tokens from vault (vault must have approved this adapter)
        // We assume vault has already approved router in production; adapter will call router.swapExactTokensForTokens
        IERC20(assetIn).approve(address(router), amountIn);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            vault,
            deadline
        );
        return amounts[amounts.length - 1];
    }
}
