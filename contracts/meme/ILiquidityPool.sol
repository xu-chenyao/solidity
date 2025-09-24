// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * @title 流动性池接口
 * @dev 定义流动性池交互的标准接口
 * @notice 支持添加/移除流动性、获取池信息等功能
 */
interface ILiquidityPool {
    
    /**
     * @notice 流动性提供者信息结构体
     * @param liquidityAmount 提供的流动性数量
     * @param tokenAmount 提供的代币数量
     * @param ethAmount 提供的ETH数量
     * @param timestamp 添加流动性的时间戳
     * @param lockUntil 锁定到期时间（0表示无锁定）
     */
    struct LiquidityProvider {
        uint256 liquidityAmount;   // LP代币数量
        uint256 tokenAmount;       // 代币数量
        uint256 ethAmount;         // ETH数量
        uint256 timestamp;         // 添加时间
        uint256 lockUntil;         // 锁定期限
    }
    
    /**
     * @notice 添加流动性
     * @param tokenAmount 要添加的代币数量
     * @param minTokenAmount 最小代币数量（滑点保护）
     * @param minEthAmount 最小ETH数量（滑点保护）
     * @param lockDuration 锁定持续时间（秒）
     * @return liquidity 获得的LP代币数量
     */
    function addLiquidity(
        uint256 tokenAmount,
        uint256 minTokenAmount,
        uint256 minEthAmount,
        uint256 lockDuration
    ) external payable returns (uint256 liquidity);
    
    /**
     * @notice 移除流动性
     * @param liquidityAmount 要移除的LP代币数量
     * @param minTokenAmount 最小获得代币数量（滑点保护）
     * @param minEthAmount 最小获得ETH数量（滑点保护）
     * @return tokenAmount 获得的代币数量
     * @return ethAmount 获得的ETH数量
     */
    function removeLiquidity(
        uint256 liquidityAmount,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external returns (uint256 tokenAmount, uint256 ethAmount);
    
    /**
     * @notice 获取添加流动性所需的代币数量
     * @param ethAmount 要添加的ETH数量
     * @return tokenAmount 需要的代币数量
     */
    function getTokenAmountForLiquidity(uint256 ethAmount) external view returns (uint256 tokenAmount);
    
    /**
     * @notice 获取流动性提供者信息
     * @param provider 流动性提供者地址
     * @return 流动性提供者详细信息
     */
    function getLiquidityProvider(address provider) external view returns (LiquidityProvider memory);
    
    /**
     * @notice 获取池子总流动性
     * @return totalLiquidity 总流动性数量
     */
    function getTotalLiquidity() external view returns (uint256 totalLiquidity);
    
    /**
     * @notice 获取池子储备量
     * @return tokenReserve 代币储备量
     * @return ethReserve ETH储备量
     */
    function getReserves() external view returns (uint256 tokenReserve, uint256 ethReserve);
    
    // ========== 事件定义 ==========
    
    /// @notice 添加流动性时触发
    event LiquidityAdded(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity,
        uint256 lockUntil
    );
    
    /// @notice 移除流动性时触发
    event LiquidityRemoved(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );
    
    /// @notice 流动性锁定状态更新时触发
    event LiquidityLocked(address indexed provider, uint256 lockUntil);
}
