// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ILiquidityPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title 流动性池实现
 * @dev 实现自定义的流动性池，支持代币与ETH的交易对
 * @notice 提供添加/移除流动性、流动性锁定、滑点保护等功能
 */
contract LiquidityPool is ILiquidityPool, Ownable, ReentrancyGuard {
    
    // ========== 状态变量 ==========
    
    /// @notice 关联的代币合约
    IERC20 public immutable token;
    
    /// @notice 代币储备量
    uint256 public tokenReserve;
    
    /// @notice ETH储备量  
    uint256 public ethReserve;
    
    /// @notice 总流动性供应量
    uint256 public totalLiquidity;
    
    /// @notice 流动性提供者信息映射
    mapping(address => LiquidityProvider) public liquidityProviders;
    
    /// @notice 用户LP代币余额
    mapping(address => uint256) public lpBalances;
    
    /// @notice 交易手续费率（基点，10000 = 100%）
    uint256 public feeRate = 30; // 0.3%
    
    /// @notice 最小流动性（防止除零错误）
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    /// @notice 是否暂停交易
    bool public tradingPaused = false;
    
    // ========== 修饰符 ==========
    
    modifier whenNotPaused() {
        require(!tradingPaused, "Trading is paused");
        _;
    }
    
    modifier validLockDuration(uint256 lockDuration) {
        require(lockDuration <= 365 days, "Lock duration too long");
        _;
    }
    
    // ========== 构造函数 ==========
    
    /**
     * @notice 构造函数
     * @param _token 代币合约地址
     * @param _owner 合约所有者地址
     */
    constructor(address _token, address _owner) Ownable(_owner) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }
    
    // ========== 流动性管理核心函数 ==========
    
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
    ) 
        external 
        payable 
        override 
        nonReentrant 
        whenNotPaused 
        validLockDuration(lockDuration)
        returns (uint256 liquidity) 
    {
        require(msg.value > 0, "Must send ETH");
        require(tokenAmount > 0, "Token amount must be positive");
        
        uint256 ethAmount = msg.value;
        
        // 如果池子为空，这是第一次添加流动性
        if (totalLiquidity == 0) {
            // 初始流动性 = sqrt(tokenAmount * ethAmount) - MINIMUM_LIQUIDITY
            liquidity = _sqrt(tokenAmount * ethAmount) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Insufficient liquidity minted");
            
            // 锁定最小流动性防止攻击
            lpBalances[address(0)] = MINIMUM_LIQUIDITY;
            totalLiquidity = liquidity + MINIMUM_LIQUIDITY;
            
            // 更新储备
            tokenReserve = tokenAmount;
            ethReserve = ethAmount;
        } else {
            // 根据现有比例计算最优添加数量
            uint256 optimalTokenAmount = (ethAmount * tokenReserve) / ethReserve;
            uint256 optimalEthAmount = (tokenAmount * ethReserve) / tokenReserve;
            
            uint256 actualTokenAmount;
            uint256 actualEthAmount;
            
            if (optimalTokenAmount <= tokenAmount) {
                // 使用提供的ETH数量，调整代币数量
                actualTokenAmount = optimalTokenAmount;
                actualEthAmount = ethAmount;
            } else {
                // 使用提供的代币数量，调整ETH数量
                actualTokenAmount = tokenAmount;
                actualEthAmount = optimalEthAmount;
            }
            
            // 滑点保护
            require(actualTokenAmount >= minTokenAmount, "Token amount below minimum");
            require(actualEthAmount >= minEthAmount, "ETH amount below minimum");
            
            // 计算获得的流动性
            liquidity = (actualTokenAmount * totalLiquidity) / tokenReserve;
            
            // 更新储备
            tokenReserve += actualTokenAmount;
            ethReserve += actualEthAmount;
            
            // 退还多余的ETH
            if (actualEthAmount < ethAmount) {
                payable(msg.sender).transfer(ethAmount - actualEthAmount);
            }
            
            tokenAmount = actualTokenAmount;
            ethAmount = actualEthAmount;
        }
        
        // 转移代币到池子
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        
        // 更新用户LP余额和总供应量
        lpBalances[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        
        // 更新流动性提供者信息
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        provider.liquidityAmount += liquidity;
        provider.tokenAmount += tokenAmount;
        provider.ethAmount += ethAmount;
        provider.timestamp = block.timestamp;
        
        // 设置锁定期
        if (lockDuration > 0) {
            uint256 lockUntil = block.timestamp + lockDuration;
            if (lockUntil > provider.lockUntil) {
                provider.lockUntil = lockUntil;
                emit LiquidityLocked(msg.sender, lockUntil);
            }
        }
        
        emit LiquidityAdded(msg.sender, tokenAmount, ethAmount, liquidity, provider.lockUntil);
    }
    
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
    ) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 tokenAmount, uint256 ethAmount) 
    {
        require(liquidityAmount > 0, "Liquidity amount must be positive");
        require(lpBalances[msg.sender] >= liquidityAmount, "Insufficient LP balance");
        
        // 检查锁定期
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        require(block.timestamp >= provider.lockUntil, "Liquidity is locked");
        
        // 计算可以获得的代币和ETH数量
        tokenAmount = (liquidityAmount * tokenReserve) / totalLiquidity;
        ethAmount = (liquidityAmount * ethReserve) / totalLiquidity;
        
        // 滑点保护
        require(tokenAmount >= minTokenAmount, "Token amount below minimum");
        require(ethAmount >= minEthAmount, "ETH amount below minimum");
        
        // 更新状态
        lpBalances[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        tokenReserve -= tokenAmount;
        ethReserve -= ethAmount;
        
        // 更新流动性提供者信息
        provider.liquidityAmount -= liquidityAmount;
        if (provider.liquidityAmount == 0) {
            // 如果全部移除，清零记录
            provider.tokenAmount = 0;
            provider.ethAmount = 0;
            provider.lockUntil = 0;
        } else {
            // 按比例减少
            uint256 ratio = (liquidityAmount * 1e18) / (provider.liquidityAmount + liquidityAmount);
            provider.tokenAmount -= (provider.tokenAmount * ratio) / 1e18;
            provider.ethAmount -= (provider.ethAmount * ratio) / 1e18;
        }
        
        // 转移资产给用户
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        payable(msg.sender).transfer(ethAmount);
        
        emit LiquidityRemoved(msg.sender, tokenAmount, ethAmount, liquidityAmount);
    }
    
    // ========== 查询函数 ==========
    
    /**
     * @notice 获取添加流动性所需的代币数量
     * @param ethAmount 要添加的ETH数量
     * @return tokenAmount 需要的代币数量
     */
    function getTokenAmountForLiquidity(uint256 ethAmount) external view override returns (uint256 tokenAmount) {
        if (totalLiquidity == 0) {
            // 初始流动性可以是任意比例
            return 0;
        }
        tokenAmount = (ethAmount * tokenReserve) / ethReserve;
    }
    
    /**
     * @notice 获取流动性提供者信息
     * @param provider 流动性提供者地址
     * @return 流动性提供者详细信息
     */
    function getLiquidityProvider(address provider) external view override returns (LiquidityProvider memory) {
        return liquidityProviders[provider];
    }
    
    /**
     * @notice 获取池子总流动性
     * @return totalLiquidity 总流动性数量
     */
    function getTotalLiquidity() external view override returns (uint256) {
        return totalLiquidity;
    }
    
    /**
     * @notice 获取池子储备量
     * @return tokenReserve 代币储备量
     * @return ethReserve ETH储备量
     */
    function getReserves() external view override returns (uint256, uint256) {
        return (tokenReserve, ethReserve);
    }
    
    /**
     * @notice 获取用户LP代币余额
     * @param user 用户地址
     * @return balance LP代币余额
     */
    function getLPBalance(address user) external view returns (uint256 balance) {
        return lpBalances[user];
    }
    
    /**
     * @notice 预估移除流动性可获得的资产
     * @param liquidityAmount 要移除的LP代币数量
     * @return tokenAmount 可获得的代币数量
     * @return ethAmount 可获得的ETH数量
     */
    function previewRemoveLiquidity(uint256 liquidityAmount) 
        external 
        view 
        returns (uint256 tokenAmount, uint256 ethAmount) 
    {
        if (totalLiquidity == 0) return (0, 0);
        
        tokenAmount = (liquidityAmount * tokenReserve) / totalLiquidity;
        ethAmount = (liquidityAmount * ethReserve) / totalLiquidity;
    }
    
    // ========== 管理员函数 ==========
    
    /**
     * @notice 设置交易手续费率
     * @param _feeRate 新的手续费率（基点）
     */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee rate too high"); // 最大10%
        feeRate = _feeRate;
    }
    
    /**
     * @notice 暂停/恢复交易
     * @param _paused 是否暂停
     */
    function setPaused(bool _paused) external onlyOwner {
        tradingPaused = _paused;
    }
    
    /**
     * @notice 紧急提取（仅限所有者，紧急情况使用）
     * @param tokenAmount 提取的代币数量
     * @param ethAmount 提取的ETH数量
     */
    function emergencyWithdraw(uint256 tokenAmount, uint256 ethAmount) external onlyOwner {
        if (tokenAmount > 0) {
            token.transfer(owner(), tokenAmount);
        }
        if (ethAmount > 0) {
            payable(owner()).transfer(ethAmount);
        }
    }
    
    // ========== 内部辅助函数 ==========
    
    /**
     * @notice 计算平方根（使用巴比伦方法）
     * @param x 输入数值
     * @return y 平方根结果
     */
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // ========== 接收ETH ==========
    
    /**
     * @notice 接收ETH（用于接收退款等）
     */
    receive() external payable {
        // 只允许合约内部调用发送ETH
        require(msg.sender == address(this), "Direct ETH not allowed");
    }
}
