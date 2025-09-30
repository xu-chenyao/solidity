// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./Factory.sol";
import "./interfaces/IPool.sol";

/**
 * @title PoolManager - MetaNodeSwap 池子管理合约
 * @notice 继承Factory功能，提供池子管理和查询的高级接口
 * @dev 作为Factory的扩展，增加了池子信息聚合和批量查询功能
 * 
 * 核心功能：
 * 1. 继承Factory的所有池子创建功能
 * 2. 管理代币对列表（pairs）
 * 3. 提供所有池子信息的聚合查询
 * 4. 支持创建并初始化池子的一站式操作
 * 5. 自动维护代币对的索引
 */
contract PoolManager is Factory, IPoolManager {
    /// @notice 存储所有已创建的代币对信息
    /// @dev 用于快速查询和遍历所有代币对
    Pair[] public pairs;

    /**
     * @notice 获取所有代币对信息
     * @dev 返回系统中所有已创建池子的代币对列表
     * @return 代币对数组，包含token0和token1地址
     */
    function getPairs() external view override returns (Pair[] memory) {
        return pairs;
    }

    /**
     * @notice 获取所有池子的详细信息
     * @dev 遍历所有代币对，收集每个池子的完整状态信息
     * @return poolsInfo 包含所有池子详细信息的数组
     * 
     * 返回信息包括：
     * - 池子合约地址
     * - 代币对地址（token0, token1）
     * - 池子索引
     * - 手续费率
     * - 价格区间（tickLower, tickUpper）
     * - 当前价格和tick
     * - 当前流动性
     */
    function getAllPools()
        external
        view
        override
        returns (PoolInfo[] memory poolsInfo)
    {
        uint32 length = 0;
        
        // 第一遍遍历：计算总池子数量
        for (uint32 i = 0; i < pairs.length; i++) {
            length += uint32(pools[pairs[i].token0][pairs[i].token1].length);
        }

        // 创建结果数组
        poolsInfo = new PoolInfo[](length);
        uint256 index;
        
        // 第二遍遍历：填充池子信息
        for (uint32 i = 0; i < pairs.length; i++) {
            // 获取当前代币对的所有池子地址
            address[] memory addresses = pools[pairs[i].token0][
                pairs[i].token1
            ];
            
            // 遍历当前代币对的每个池子
            for (uint32 j = 0; j < addresses.length; j++) {
                IPool pool = IPool(addresses[j]);
                
                // 构造池子信息结构体
                poolsInfo[index] = PoolInfo({
                    pool: addresses[j],                    // 池子合约地址
                    token0: pool.token0(),                 // token0地址
                    token1: pool.token1(),                 // token1地址
                    index: j,                              // 池子在代币对中的索引
                    fee: pool.fee(),                       // 手续费率
                    feeProtocol: 0,                        // 协议费率（暂未实现）
                    tickLower: pool.tickLower(),           // 价格区间下限
                    tickUpper: pool.tickUpper(),           // 价格区间上限
                    tick: pool.tick(),                     // 当前tick
                    sqrtPriceX96: pool.sqrtPriceX96(),     // 当前价格平方根
                    liquidity: pool.liquidity()            // 当前流动性
                });
                index++;
            }
        }
        return poolsInfo;
    }

    /**
     * @notice 创建并初始化池子（如果需要的话）
     * @dev 一站式操作：创建池子、初始化价格、维护代币对索引
     * @param params 创建和初始化参数
     * @return poolAddress 创建或已存在的池子地址
     * 
     * 功能说明：
     * 1. 验证代币地址顺序（token0 < token1）
     * 2. 创建池子（如果不存在）
     * 3. 初始化池子价格（如果未初始化）
     * 4. 维护代币对索引（如果是新代币对）
     */
    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address poolAddress) {
        // 验证代币地址顺序，确保token0 < token1
        require(
            params.token0 < params.token1,
            "token0 must be less than token1"
        );

        // 调用Factory的createPool函数创建池子
        // 如果池子已存在，会返回现有池子地址
        poolAddress = this.createPool(
            params.token0,
            params.token1,
            params.tickLower,
            params.tickUpper,
            params.fee
        );

        // 获取池子合约实例
        IPool pool = IPool(poolAddress);

        // 获取当前代币对的池子数量
        uint256 index = pools[pool.token0()][pool.token1()].length;

        // 检查池子是否需要初始化价格
        if (pool.sqrtPriceX96() == 0) {
            // 初始化池子的起始价格
            pool.initialize(params.sqrtPriceX96);

            // 如果这是该代币对的第一个池子，需要添加到pairs数组
            if (index == 1) {
                pairs.push(
                    Pair({token0: pool.token0(), token1: pool.token1()})
                );
            }
        }
    }
}
