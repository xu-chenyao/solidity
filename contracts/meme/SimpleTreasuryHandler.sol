// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./ITreasuryHandler.sol";
import "./ILiquidityPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title 简单国库处理器实现
 * @dev 实现ITreasuryHandler接口的基础国库管理逻辑
 * @notice 这是一个示例实现，包含自动回购、流动性管理等功能
 */
contract SimpleTreasuryHandler is ITreasuryHandler {
    
    // ========== 状态变量 ==========
    
    /// @notice 合约所有者地址
    address public owner;
    
    /// @notice FLOKI代币合约地址
    address public tokenContract;
    
    /// @notice 营销钱包地址
    address public marketingWallet;
    
    /// @notice 开发团队钱包地址
    address public devWallet;
    
    /// @notice 流动性钱包地址
    address public liquidityWallet;
    
    /// @notice 流动性池合约地址
    ILiquidityPool public liquidityPool;
    
    /// @notice 税收分配比例（基点，总和应为10000）
    uint256 public marketingShare = 3000;  // 30%
    uint256 public devShare = 2000;        // 20%
    uint256 public liquidityShare = 3000;  // 30% (增加流动性分配)
    uint256 public buybackShare = 2000;    // 20%
    
    /// @notice 自动处理阈值（当累积税收达到此数量时触发处理）
    uint256 public autoProcessThreshold = 1000 * 1e9; // 1000个代币
    
    /// @notice 是否启用自动处理
    bool public autoProcessEnabled = true;
    
    /// @notice 累积的税收代币数量
    uint256 public accumulatedTax;
    
    /// @notice 是否启用自动流动性管理
    bool public autoLiquidityEnabled = true;
    
    /// @notice 流动性管理的最小ETH阈值
    uint256 public minEthForLiquidity = 0.1 ether;
    
    /// @notice 流动性锁定时间（默认30天）
    uint256 public liquidityLockDuration = 30 days;
    
    // ========== 事件 ==========
    
    event TaxProcessed(uint256 amount, uint256 marketing, uint256 dev, uint256 liquidity, uint256 buyback);
    event WalletUpdated(string walletType, address oldWallet, address newWallet);
    event SharesUpdated(uint256 marketing, uint256 dev, uint256 liquidity, uint256 buyback);
    event AutoProcessConfigUpdated(bool enabled, uint256 threshold);
    event LiquidityPoolUpdated(address oldPool, address newPool);
    event AutoLiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event LiquidityConfigUpdated(bool autoEnabled, uint256 minEth, uint256 lockDuration);
    
    // ========== 修饰符 ==========
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier onlyToken() {
        require(msg.sender == tokenContract, "Not the token contract");
        _;
    }
    
    // ========== 构造函数 ==========
    
    /**
     * @notice 构造函数
     * @param _owner 合约所有者地址
     * @param _marketingWallet 营销钱包地址
     * @param _devWallet 开发团队钱包地址
     * @param _liquidityWallet 流动性钱包地址
     */
    constructor(
        address _owner,
        address _marketingWallet,
        address _devWallet,
        address _liquidityWallet
    ) {
        owner = _owner;
        marketingWallet = _marketingWallet;
        devWallet = _devWallet;
        liquidityWallet = _liquidityWallet;
    }
    
    /**
     * @notice 设置流动性池合约地址
     * @param _liquidityPool 流动性池合约地址
     */
    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        address oldPool = address(liquidityPool);
        liquidityPool = ILiquidityPool(_liquidityPool);
        emit LiquidityPoolUpdated(oldPool, _liquidityPool);
    }
    
    // ========== 国库处理核心函数 ==========
    
    /**
     * @notice 在代币转账执行前执行的操作
     * @param benefactor 转账发送方地址
     * @param beneficiary 转账接收方地址
     * @param amount 转账的代币数量
     */
    function beforeTransferHandler(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external override onlyToken {
        // 转账前处理逻辑（如果需要的话）
        // 例如：记录交易统计、风险检测等
        
        // 当前实现为空，可以根据需要添加逻辑
    }
    
    /**
     * @notice 在代币转账执行后执行的操作
     * @param benefactor 转账发送方地址
     * @param beneficiary 转账接收方地址
     * @param amount 转账的代币数量
     */
    function afterTransferHandler(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external override onlyToken {
        // 更新累积税收（如果这次转账产生了税收）
        uint256 currentBalance = IERC20(tokenContract).balanceOf(address(this));
        
        // 如果余额增加了，说明收到了税收
        if (currentBalance > accumulatedTax) {
            accumulatedTax = currentBalance;
            
            // 检查是否达到自动处理阈值
            if (autoProcessEnabled && accumulatedTax >= autoProcessThreshold) {
                _processTax();
            }
        }
    }
    
    // ========== 税收处理功能 ==========
    
    /**
     * @notice 手动处理累积的税收
     */
    function processTax() external onlyOwner {
        _processTax();
    }
    
    /**
     * @notice 内部税收处理逻辑
     */
    function _processTax() private {
        uint256 taxAmount = accumulatedTax;
        if (taxAmount == 0) return;
        
        // 计算各部分分配
        uint256 marketingAmount = (taxAmount * marketingShare) / 10000;
        uint256 devAmount = (taxAmount * devShare) / 10000;
        uint256 liquidityAmount = (taxAmount * liquidityShare) / 10000;
        uint256 buybackAmount = taxAmount - marketingAmount - devAmount - liquidityAmount;
        
        // 重置累积税收
        accumulatedTax = 0;
        
        IERC20 token = IERC20(tokenContract);
        
        // 分配给营销钱包
        if (marketingAmount > 0 && marketingWallet != address(0)) {
            token.transfer(marketingWallet, marketingAmount);
        }
        
        // 分配给开发团队钱包
        if (devAmount > 0 && devWallet != address(0)) {
            token.transfer(devWallet, devAmount);
        }
        
        // 🎯 新增：智能流动性管理
        if (liquidityAmount > 0) {
            _handleLiquidityDistribution(liquidityAmount);
        }
        
        // 回购部分保留在合约中，可以用于后续的回购和销毁
        // buybackAmount 保留在合约中
        
        emit TaxProcessed(taxAmount, marketingAmount, devAmount, liquidityAmount, buybackAmount);
    }
    
    /**
     * @notice 处理流动性分配的内部逻辑
     * @param liquidityAmount 分配给流动性的代币数量
     */
    function _handleLiquidityDistribution(uint256 liquidityAmount) private {
        // 如果启用了自动流动性管理且设置了流动性池
        if (autoLiquidityEnabled && address(liquidityPool) != address(0) && address(this).balance >= minEthForLiquidity) {
            // 将部分代币自动添加到流动性池
            uint256 autoLiquidityTokens = liquidityAmount / 2; // 使用50%的流动性代币
            uint256 ethForLiquidity = address(this).balance; // 使用合约中的ETH
            
            if (autoLiquidityTokens > 0 && ethForLiquidity > 0) {
                _addLiquidityToPool(autoLiquidityTokens, ethForLiquidity);
            }
            
            // 剩余部分发送给流动性钱包
            uint256 remainingTokens = liquidityAmount - autoLiquidityTokens;
            if (remainingTokens > 0 && liquidityWallet != address(0)) {
                IERC20(tokenContract).transfer(liquidityWallet, remainingTokens);
            }
        } else {
            // 传统方式：全部发送给流动性钱包
            if (liquidityWallet != address(0)) {
                IERC20(tokenContract).transfer(liquidityWallet, liquidityAmount);
            }
        }
    }
    
    /**
     * @notice 自动添加流动性到池子
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     */
    function _addLiquidityToPool(uint256 tokenAmount, uint256 ethAmount) private {
        IERC20 token = IERC20(tokenContract);
        
        // 授权流动性池使用代币
        token.approve(address(liquidityPool), tokenAmount);
        
        try liquidityPool.addLiquidity{value: ethAmount}(
            tokenAmount,
            tokenAmount * 95 / 100, // 5% 滑点容忍度
            ethAmount * 95 / 100,   // 5% 滑点容忍度  
            liquidityLockDuration   // 锁定期
        ) returns (uint256 liquidity) {
            emit AutoLiquidityAdded(tokenAmount, ethAmount, liquidity);
        } catch {
            // 如果添加流动性失败，将代币发送给流动性钱包
            if (liquidityWallet != address(0)) {
                token.transfer(liquidityWallet, tokenAmount);
            }
        }
    }
    
    // ========== 管理员功能 ==========
    
    /**
     * @notice 设置代币合约地址
     * @param _tokenContract FLOKI代币合约地址
     */
    function setTokenContract(address _tokenContract) external onlyOwner {
        tokenContract = _tokenContract;
    }
    
    /**
     * @notice 更新营销钱包地址
     * @param _wallet 新的营销钱包地址
     */
    function setMarketingWallet(address _wallet) external onlyOwner {
        address oldWallet = marketingWallet;
        marketingWallet = _wallet;
        emit WalletUpdated("marketing", oldWallet, _wallet);
    }
    
    /**
     * @notice 更新开发团队钱包地址
     * @param _wallet 新的开发团队钱包地址
     */
    function setDevWallet(address _wallet) external onlyOwner {
        address oldWallet = devWallet;
        devWallet = _wallet;
        emit WalletUpdated("dev", oldWallet, _wallet);
    }
    
    /**
     * @notice 更新流动性钱包地址
     * @param _wallet 新的流动性钱包地址
     */
    function setLiquidityWallet(address _wallet) external onlyOwner {
        address oldWallet = liquidityWallet;
        liquidityWallet = _wallet;
        emit WalletUpdated("liquidity", oldWallet, _wallet);
    }
    
    /**
     * @notice 更新税收分配比例
     * @param _marketingShare 营销钱包分配比例（基点）
     * @param _devShare 开发团队分配比例（基点）
     * @param _liquidityShare 流动性分配比例（基点）
     * @param _buybackShare 回购分配比例（基点）
     */
    function updateShares(
        uint256 _marketingShare,
        uint256 _devShare,
        uint256 _liquidityShare,
        uint256 _buybackShare
    ) external onlyOwner {
        require(_marketingShare + _devShare + _liquidityShare + _buybackShare == 10000, "Shares must sum to 10000");
        
        marketingShare = _marketingShare;
        devShare = _devShare;
        liquidityShare = _liquidityShare;
        buybackShare = _buybackShare;
        
        emit SharesUpdated(_marketingShare, _devShare, _liquidityShare, _buybackShare);
    }
    
    /**
     * @notice 配置自动处理设置
     * @param _enabled 是否启用自动处理
     * @param _threshold 自动处理阈值
     */
    function setAutoProcessConfig(bool _enabled, uint256 _threshold) external onlyOwner {
        autoProcessEnabled = _enabled;
        autoProcessThreshold = _threshold;
        emit AutoProcessConfigUpdated(_enabled, _threshold);
    }
    
    /**
     * @notice 紧急提取代币（仅限所有者）
     * @param token 代币合约地址
     * @param amount 提取数量
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
    
    /**
     * @notice 配置流动性管理参数
     * @param _autoEnabled 是否启用自动流动性管理
     * @param _minEth 最小ETH阈值
     * @param _lockDuration 流动性锁定时间
     */
    function setLiquidityConfig(
        bool _autoEnabled,
        uint256 _minEth,
        uint256 _lockDuration
    ) external onlyOwner {
        require(_lockDuration <= 365 days, "Lock duration too long");
        
        autoLiquidityEnabled = _autoEnabled;
        minEthForLiquidity = _minEth;
        liquidityLockDuration = _lockDuration;
        
        emit LiquidityConfigUpdated(_autoEnabled, _minEth, _lockDuration);
    }
    
    // ========== 流动性池交互函数 ==========
    
    /**
     * @notice 手动添加流动性到池子
     * @param tokenAmount 代币数量
     * @param lockDuration 锁定时间（秒）
     */
    function addLiquidityManual(uint256 tokenAmount, uint256 lockDuration) external payable onlyOwner {
        require(address(liquidityPool) != address(0), "Liquidity pool not set");
        require(tokenAmount > 0, "Token amount must be positive");
        require(msg.value > 0, "Must send ETH");
        require(lockDuration <= 365 days, "Lock duration too long");
        
        IERC20 token = IERC20(tokenContract);
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        
        // 授权并添加流动性
        token.approve(address(liquidityPool), tokenAmount);
        
        uint256 liquidity = liquidityPool.addLiquidity{value: msg.value}(
            tokenAmount,
            tokenAmount * 95 / 100, // 5% 滑点容忍度
            msg.value * 95 / 100,   // 5% 滑点容忍度
            lockDuration
        );
        
        emit AutoLiquidityAdded(tokenAmount, msg.value, liquidity);
    }
    
    /**
     * @notice 移除流动性（仅限所有者）
     * @param liquidityAmount LP代币数量
     * @param minTokenAmount 最小代币数量
     * @param minEthAmount 最小ETH数量
     */
    function removeLiquidityManual(
        uint256 liquidityAmount,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external onlyOwner {
        require(address(liquidityPool) != address(0), "Liquidity pool not set");
        
        (uint256 tokenAmount, uint256 ethAmount) = liquidityPool.removeLiquidity(
            liquidityAmount,
            minTokenAmount,
            minEthAmount
        );
        
        // 资产已经转到合约中，可以进一步处理
        // 例如：重新分配或保留用于其他用途
    }
    
    /**
     * @notice 查询合约在流动性池中的LP余额
     * @return balance LP代币余额
     */
    function getLiquidityBalance() external view returns (uint256 balance) {
        if (address(liquidityPool) == address(0)) return 0;
        return liquidityPool.getLPBalance(address(this));
    }
    
    /**
     * @notice 查询流动性池信息
     * @return tokenReserve 代币储备量
     * @return ethReserve ETH储备量
     * @return totalLiquidity 总流动性
     */
    function getPoolInfo() external view returns (
        uint256 tokenReserve,
        uint256 ethReserve,
        uint256 totalLiquidity
    ) {
        if (address(liquidityPool) == address(0)) return (0, 0, 0);
        
        (tokenReserve, ethReserve) = liquidityPool.getReserves();
        totalLiquidity = liquidityPool.getTotalLiquidity();
    }
    
    /**
     * @notice 预估添加流动性所需的代币数量
     * @param ethAmount ETH数量
     * @return tokenAmount 需要的代币数量
     */
    function getTokenAmountForLiquidity(uint256 ethAmount) external view returns (uint256 tokenAmount) {
        if (address(liquidityPool) == address(0)) return 0;
        return liquidityPool.getTokenAmountForLiquidity(ethAmount);
    }
    
    /**
     * @notice 转移所有权
     * @param newOwner 新所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        owner = newOwner;
    }
    
    // ========== 接收ETH ==========
    
    /**
     * @notice 接收ETH（用于流动性管理）
     */
    receive() external payable {
        // 允许接收ETH用于流动性管理
    }
}
