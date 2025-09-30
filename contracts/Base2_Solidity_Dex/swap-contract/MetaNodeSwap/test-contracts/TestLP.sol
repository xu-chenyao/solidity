// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestLP - 流动性提供测试合约
 * @notice 用于测试池子流动性管理功能的简单合约
 * @dev 实现IMintCallback接口，提供基本的流动性操作测试功能
 * 
 * 主要功能：
 * 1. 添加流动性（mint）
 * 2. 移除流动性（burn）
 * 3. 收取手续费（collect）
 * 4. 实现mintCallback处理代币转账
 * 5. 简化的流动性管理逻辑，便于单元测试
 */
contract TestLP is IMintCallback {
    /**
     * @notice 对代币地址进行排序
     * @dev 确保token0 < token1，与Factory保持一致
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return token0 较小的代币地址
     * @return token1 较大的代币地址
     */
    function sortToken(
        address tokenA,
        address tokenB
    ) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @notice 向池子添加流动性
     * @dev 调用池子的mint函数添加指定数量的流动性
     * @param recipient 流动性接收者地址
     * @param amount 要添加的流动性数量
     * @param pool 目标池子地址
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return amount0 需要转入的token0数量
     * @return amount1 需要转入的token1数量
     */
    function mint(
        address recipient,
        uint128 amount,
        address pool,
        address tokenA,
        address tokenB
    ) external returns (uint256 amount0, uint256 amount1) {
        // 对代币地址进行排序
        (address token0, address token1) = sortToken(tokenA, tokenB);

        // 调用池子的mint函数
        (amount0, amount1) = IPool(pool).mint(
            recipient,                          // 流动性接收者
            amount,                            // 流动性数量
            abi.encode(token0, token1)         // 回调数据
        );
    }

    /**
     * @notice 从池子移除流动性
     * @dev 调用池子的burn函数移除指定数量的流动性
     * @param amount 要移除的流动性数量
     * @param pool 目标池子地址
     * @return amount0 可以提取的token0数量
     * @return amount1 可以提取的token1数量
     */
    function burn(
        uint128 amount,
        address pool
    ) external returns (uint256 amount0, uint256 amount1) {
        // 调用池子的burn函数移除流动性
        (amount0, amount1) = IPool(pool).burn(amount);
    }

    /**
     * @notice 收取累积的手续费和代币
     * @dev 提取所有可提取的代币（包括移除的流动性和手续费收益）
     * @param recipient 代币接收者地址
     * @param pool 目标池子地址
     * @return amount0 实际提取的token0数量
     * @return amount1 实际提取的token1数量
     */
    function collect(
        address recipient,
        address pool
    ) external returns (uint256 amount0, uint256 amount1) {
        // 获取当前头寸的可提取代币数量
        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = IPool(pool)
            .getPosition(address(this));
            
        // 调用池子的collect函数提取所有可提取的代币
        (amount0, amount1) = IPool(pool).collect(
            recipient,      // 代币接收者
            tokensOwed0,    // 要提取的token0数量
            tokensOwed1     // 要提取的token1数量
        );
    }

    /**
     * @notice 铸造流动性回调函数
     * @dev 池子调用此函数要求转入相应的代币
     * @param amount0Owed 需要转入的token0数量
     * @param amount1Owed 需要转入的token1数量
     * @param data 回调数据，包含代币地址信息
     */
    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        // 解码回调数据获取代币地址
        (address token0, address token1) = abi.decode(data, (address, address));
        
        // 如果需要转入token0，执行转账
        if (amount0Owed > 0) {
            IERC20(token0).transfer(msg.sender, amount0Owed);
        }
        
        // 如果需要转入token1，执行转账
        if (amount1Owed > 0) {
            IERC20(token1).transfer(msg.sender, amount1Owed);
        }
    }
}
