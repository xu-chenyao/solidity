// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestSwap - 交换测试合约
 * @notice 用于测试池子交换功能的简单合约
 * @dev 实现ISwapCallback接口，提供基本的代币交换测试功能
 * 
 * 主要功能：
 * 1. 直接调用池子的swap函数进行测试
 * 2. 实现swapCallback处理代币转账
 * 3. 简化的交换逻辑，便于单元测试
 */
contract TestSwap is ISwapCallback {
    /**
     * @notice 测试交换函数
     * @dev 直接调用指定池子进行代币交换测试
     * @param recipient 代币接收者地址
     * @param amount 交换数量（正数表示精确输入）
     * @param sqrtPriceLimitX96 价格限制
     * @param pool 目标池子地址
     * @param token0 池子的token0地址
     * @param token1 池子的token1地址
     * @return amount0 token0数量变化
     * @return amount1 token1数量变化
     */
    function testSwap(
        address recipient,
        int256 amount,
        uint160 sqrtPriceLimitX96,
        address pool,
        address token0,
        address token1
    ) external returns (int256 amount0, int256 amount1) {
        // 调用池子的swap函数，固定使用zeroForOne=true
        (amount0, amount1) = IPool(pool).swap(
            recipient,                              // 代币接收者
            true,                                   // zeroForOne: token0 -> token1
            amount,                                 // 交换数量
            sqrtPriceLimitX96,                     // 价格限制
            abi.encode(token0, token1)             // 回调数据
        );
    }

    /**
     * @notice 交换回调函数
     * @dev 池子调用此函数要求转入相应的代币
     * @param amount0Delta token0数量变化（正数表示需要转入）
     * @param amount1Delta token1数量变化（正数表示需要转入）
     * @param data 回调数据，包含代币地址信息
     */
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // 解码回调数据获取代币地址
        (address token0, address token1) = abi.decode(data, (address, address));
        
        // 如果需要转入token0，执行转账
        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint(amount0Delta));
        }
        
        // 如果需要转入token1，执行转账
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint(amount1Delta));
        }
    }
}
