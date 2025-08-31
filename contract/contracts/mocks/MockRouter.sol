// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRouter {
    mapping(address => uint256) public mockSwapResults;
    
    function setMockSwapResult(address token, uint256 amount) external {
        mockSwapResults[token] = amount;
    }
    
    // Add this function to fund the router with tokens
    function fundRouter(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
    
    function swap(
        address, /* recipient */
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256, /* minOut */
        uint256, /* deadline */
        bytes calldata /* routeData */
    ) external returns (uint256 amountOut) {
        // Simulate successful swap
        amountOut = mockSwapResults[assetOut];
        require(amountOut > 0, "Mock: no swap result set");
        
        // Transfer input tokens from vault to router
        IERC20(assetIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Transfer output tokens from router to vault
        IERC20(assetOut).transfer(msg.sender, amountOut);
        
        return amountOut;
    }
}