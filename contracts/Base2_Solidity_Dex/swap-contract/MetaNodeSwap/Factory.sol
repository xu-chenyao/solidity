// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./Pool.sol";

/**
 * @title Factory - MetaNodeSwap 工厂合约
 * @notice 负责创建和管理流动性池的工厂合约
 * @dev 基于 Uniswap V3 架构，支持多个相同代币对的不同参数池子
 * 
 * 主要功能：
 * 1. 创建新的流动性池
 * 2. 管理已创建的池子映射
 * 3. 通过 CREATE2 确保池子地址的确定性
 * 4. 支持同一代币对创建多个不同参数的池子
 */
contract Factory is IFactory {
    // 存储所有创建的池子：token0 => token1 => 池子数组
    // 同一代币对可以有多个不同参数的池子
    mapping(address => mapping(address => address[])) public pools;

    // 临时存储池子创建参数，用于 CREATE2 部署时传递参数
    Parameters public override parameters;

    /**
     * @notice 对代币地址进行排序，确保 token0 < token1
     * @dev 统一代币顺序，避免因顺序不同导致的重复池子
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
     * @notice 获取指定代币对和索引的池子地址
     * @dev 通过代币对和索引查找对应的池子地址
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址  
     * @param index 池子索引（同一代币对可能有多个池子）
     * @return pool 池子合约地址，如果不存在返回零地址
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view override returns (address) {
        // 检查代币地址不能相同
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        // 检查代币地址不能为零地址
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

        // 声明排序后的代币地址
        address token0;
        address token1;

        // 对代币地址进行排序
        (token0, token1) = sortToken(tokenA, tokenB);

        // 返回对应索引的池子地址
        return pools[token0][token1][index];
    }

    /**
     * @notice 创建新的流动性池
     * @dev 使用 CREATE2 创建确定性地址的池子，如果相同参数的池子已存在则返回现有池子
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param tickLower 价格区间下限（tick值）
     * @param tickUpper 价格区间上限（tick值）
     * @param fee 交易手续费率（以万分之一为单位，如3000表示0.3%）
     * @return pool 创建或已存在的池子地址
     */
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override returns (address pool) {
        // 验证代币地址的唯一性，不能是相同代币
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

        // 声明排序后的代币地址
        address token0;
        address token1;

        // 对代币进行排序，避免顺序错误导致的问题
        (token0, token1) = sortToken(tokenA, tokenB);

        // 获取当前代币对的所有池子
        address[] memory existingPools = pools[token0][token1];

        // 检查是否已存在相同参数的池子
        for (uint256 i = 0; i < existingPools.length; i++) {
            IPool currentPool = IPool(existingPools[i]);

            // 如果找到相同参数的池子，直接返回现有池子地址
            if (
                currentPool.tickLower() == tickLower &&
                currentPool.tickUpper() == tickUpper &&
                currentPool.fee() == fee
            ) {
                return existingPools[i];
            }
        }

        // 临时保存池子创建参数，供Pool构造函数读取
        // 使用这种方式是因为CREATE2需要确定的bytecode，不能包含构造函数参数
        parameters = Parameters(
            address(this),
            token0,
            token1,
            tickLower,
            tickUpper,
            fee
        );

        // 生成CREATE2的salt，确保相同参数产生相同地址
        bytes32 salt = keccak256(
            abi.encode(token0, token1, tickLower, tickUpper, fee)
        );

        // 使用CREATE2创建池子合约，确保地址的确定性
        pool = address(new Pool{salt: salt}());

        // 将新创建的池子保存到映射中
        pools[token0][token1].push(pool);

        // 清除临时参数，防止被其他调用读取
        delete parameters;

        // 触发池子创建事件
        emit PoolCreated(
            token0,
            token1,
            uint32(existingPools.length),
            tickLower,
            tickUpper,
            fee,
            pool
        );
    }
}
