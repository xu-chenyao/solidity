// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./ITaxHandler.sol";

/**
 * @title 简单税收处理器实现
 * @dev 实现ITaxHandler接口的基础税收计算逻辑
 * @notice 这是一个示例实现，可以根据项目需要进行定制
 */
contract SimpleTaxHandler is ITaxHandler {
    
    // ========== 状态变量 ==========
    
    /// @notice 合约所有者地址
    address public owner;
    
    /// @notice 默认税率（基点，10000 = 100%）
    /// @dev 例如：500 = 5%, 1000 = 10%
    uint256 public defaultTaxRate = 500; // 5%
    
    /// @notice 买入税率（从DEX购买代币时）
    uint256 public buyTaxRate = 300; // 3%
    
    /// @notice 卖出税率（向DEX出售代币时）
    uint256 public sellTaxRate = 700; // 7%
    
    /// @notice UniswapV2交易对地址
    address public uniswapV2Pair;
    
    /// @notice 免税地址映射
    mapping(address => bool) public taxExempt;
    
    // ========== 高级税收策略 ==========
    
    /// @notice 大额交易税率（单笔交易超过阈值时）
    uint256 public largeTxTaxRate = 1000; // 10%
    
    /// @notice 大额交易阈值
    uint256 public largeTxThreshold = 1e12 * 1e9; // 1万亿代币
    
    /// @notice 频繁交易税率（短时间内多次交易）
    uint256 public frequentTradingTaxRate = 800; // 8%
    
    /// @notice 频繁交易时间窗口（秒）
    uint256 public frequentTradingWindow = 300; // 5分钟
    
    /// @notice 频繁交易次数阈值
    uint256 public frequentTradingThreshold = 3; // 5分钟内3次交易
    
    /// @notice 用户交易历史记录
    mapping(address => uint256[]) public userTransactionTimes;
    
    /// @notice 反MEV税率（防止套利机器人）
    uint256 public antiMEVTaxRate = 1500; // 15%
    
    /// @notice 是否启用反MEV机制
    bool public antiMEVEnabled = true;
    
    // ========== 事件 ==========
    
    event TaxRateUpdated(string taxType, uint256 oldRate, uint256 newRate);
    event TaxExemptionUpdated(address indexed account, bool exempt);
    event UniswapPairUpdated(address indexed oldPair, address indexed newPair);
    
    // ========== 修饰符 ==========
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    // ========== 构造函数 ==========
    
    /**
     * @notice 构造函数
     * @param _owner 合约所有者地址
     * @param _uniswapV2Pair UniswapV2交易对地址（可选，传零地址表示暂未设置）
     */
    constructor(address _owner, address _uniswapV2Pair) {
        owner = _owner;
        uniswapV2Pair = _uniswapV2Pair;
        
        // 设置所有者为免税地址
        taxExempt[_owner] = true;
    }
    
    // ========== 税收计算核心函数 ==========
    
    /**
     * @notice 计算转账交易中需要缴纳的税收代币数量
     * @param benefactor 转账发送方地址
     * @param beneficiary 转账接收方地址
     * @param amount 转账的代币数量
     * @return 需要作为税收扣除的代币数量
     */
    function getTax(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external override returns (uint256) {
        
        // 如果发送方或接收方是免税地址，不收税
        if (taxExempt[benefactor] || taxExempt[beneficiary]) {
            return 0;
        }
        
        // 记录交易时间（用于频繁交易检测）
        userTransactionTimes[benefactor].push(block.timestamp);
        
        // 确定基础税率
        uint256 baseTaxRate = _getBaseTaxRate(benefactor, beneficiary);
        
        // 应用高级税收策略
        uint256 finalTaxRate = _applyAdvancedTaxStrategies(benefactor, beneficiary, amount, baseTaxRate);
        
        // 计算税收
        return (amount * finalTaxRate) / 10000;
    }
    
    /**
     * @notice 获取基础税率
     * @param benefactor 转出地址
     * @param beneficiary 转入地址
     * @return baseTaxRate 基础税率
     */
    function _getBaseTaxRate(address benefactor, address beneficiary) private view returns (uint256 baseTaxRate) {
        // 如果还未设置交易对地址，使用默认税率
        if (uniswapV2Pair == address(0)) {
            return defaultTaxRate;
        }
        
        // 买入交易（从交易对转出代币给用户）
        if (benefactor == uniswapV2Pair) {
            return buyTaxRate;
        }
        
        // 卖出交易（用户转代币给交易对）
        if (beneficiary == uniswapV2Pair) {
            return sellTaxRate;
        }
        
        // 普通转账，使用默认税率
        return defaultTaxRate;
    }
    
    /**
     * @notice 应用高级税收策略
     * @param benefactor 转出地址
     * @param beneficiary 转入地址
     * @param amount 转账金额
     * @param baseTaxRate 基础税率
     * @return finalTaxRate 最终税率
     */
    function _applyAdvancedTaxStrategies(
        address benefactor,
        address beneficiary,
        uint256 amount,
        uint256 baseTaxRate
    ) private view returns (uint256 finalTaxRate) {
        finalTaxRate = baseTaxRate;
        
        // 1. 大额交易税率
        if (amount >= largeTxThreshold && largeTxTaxRate > finalTaxRate) {
            finalTaxRate = largeTxTaxRate;
        }
        
        // 2. 频繁交易税率
        if (_isFrequentTrading(benefactor) && frequentTradingTaxRate > finalTaxRate) {
            finalTaxRate = frequentTradingTaxRate;
        }
        
        // 3. 反MEV机制
        if (antiMEVEnabled && _isMEVTransaction(benefactor, beneficiary) && antiMEVTaxRate > finalTaxRate) {
            finalTaxRate = antiMEVTaxRate;
        }
        
        // 确保税率不超过50%（安全限制）
        if (finalTaxRate > 5000) {
            finalTaxRate = 5000;
        }
        
        return finalTaxRate;
    }
    
    /**
     * @notice 检查是否为频繁交易
     * @param user 用户地址
     * @return isFrequent 是否为频繁交易
     */
    function _isFrequentTrading(address user) private view returns (bool isFrequent) {
        uint256[] storage timestamps = userTransactionTimes[user];
        if (timestamps.length < frequentTradingThreshold) {
            return false;
        }
        
        uint256 recentTransactions = 0;
        uint256 currentTime = block.timestamp;
        
        // 从最新交易向前检查
        for (uint256 i = timestamps.length; i > 0; i--) {
            if (currentTime - timestamps[i - 1] <= frequentTradingWindow) {
                recentTransactions++;
            } else {
                break; // 超出时间窗口，停止检查
            }
        }
        
        return recentTransactions >= frequentTradingThreshold;
    }
    
    /**
     * @notice 检查是否为MEV交易（简单版本）
     * @param benefactor 转出地址
     * @param beneficiary 转入地址
     * @return isMEV 是否为MEV交易
     */
    function _isMEVTransaction(address benefactor, address beneficiary) private view returns (bool isMEV) {
        // 简单的MEV检测：同一区块内的连续交易
        uint256[] storage senderTimes = userTransactionTimes[benefactor];
        uint256[] storage recipientTimes = userTransactionTimes[beneficiary];
        
        if (senderTimes.length > 0 && recipientTimes.length > 0) {
            // 检查最近的交易是否在同一区块
            uint256 lastSenderTx = senderTimes[senderTimes.length - 1];
            uint256 lastRecipientTx = recipientTimes[recipientTimes.length - 1];
            
            // 如果两个地址在很短时间内（同一区块或相邻区块）都有交易，可能是MEV
            return (block.timestamp - lastSenderTx < 15) && (block.timestamp - lastRecipientTx < 15);
        }
        
        return false;
    }
    
    // ========== 管理员功能 ==========
    
    /**
     * @notice 设置默认税率
     * @param _rate 新的税率（基点）
     */
    function setDefaultTaxRate(uint256 _rate) external onlyOwner {
        require(_rate <= 2000, "Tax rate too high"); // 最大20%
        uint256 oldRate = defaultTaxRate;
        defaultTaxRate = _rate;
        emit TaxRateUpdated("default", oldRate, _rate);
    }
    
    /**
     * @notice 设置买入税率
     * @param _rate 新的买入税率（基点）
     */
    function setBuyTaxRate(uint256 _rate) external onlyOwner {
        require(_rate <= 2000, "Tax rate too high"); // 最大20%
        uint256 oldRate = buyTaxRate;
        buyTaxRate = _rate;
        emit TaxRateUpdated("buy", oldRate, _rate);
    }
    
    /**
     * @notice 设置卖出税率
     * @param _rate 新的卖出税率（基点）
     */
    function setSellTaxRate(uint256 _rate) external onlyOwner {
        require(_rate <= 2000, "Tax rate too high"); // 最大20%
        uint256 oldRate = sellTaxRate;
        sellTaxRate = _rate;
        emit TaxRateUpdated("sell", oldRate, _rate);
    }
    
    /**
     * @notice 设置UniswapV2交易对地址
     * @param _pair 新的交易对地址
     */
    function setUniswapV2Pair(address _pair) external onlyOwner {
        address oldPair = uniswapV2Pair;
        uniswapV2Pair = _pair;
        emit UniswapPairUpdated(oldPair, _pair);
    }
    
    /**
     * @notice 设置地址的免税状态
     * @param account 要设置的地址
     * @param exempt 是否免税
     */
    function setTaxExemption(address account, bool exempt) external onlyOwner {
        taxExempt[account] = exempt;
        emit TaxExemptionUpdated(account, exempt);
    }
    
    /**
     * @notice 转移所有权
     * @param newOwner 新所有者地址
     */
    /**
     * @notice 设置高级税收策略参数
     * @param _largeTxTaxRate 大额交易税率
     * @param _largeTxThreshold 大额交易阈值
     * @param _frequentTradingTaxRate 频繁交易税率
     * @param _frequentTradingWindow 频繁交易时间窗口
     * @param _frequentTradingThreshold 频繁交易次数阈值
     */
    function setAdvancedTaxStrategies(
        uint256 _largeTxTaxRate,
        uint256 _largeTxThreshold,
        uint256 _frequentTradingTaxRate,
        uint256 _frequentTradingWindow,
        uint256 _frequentTradingThreshold
    ) external onlyOwner {
        require(_largeTxTaxRate <= 5000, "Large tx tax rate too high");
        require(_frequentTradingTaxRate <= 5000, "Frequent trading tax rate too high");
        require(_frequentTradingWindow <= 3600, "Window too long");
        require(_frequentTradingThreshold > 0, "Threshold must be positive");
        
        largeTxTaxRate = _largeTxTaxRate;
        largeTxThreshold = _largeTxThreshold;
        frequentTradingTaxRate = _frequentTradingTaxRate;
        frequentTradingWindow = _frequentTradingWindow;
        frequentTradingThreshold = _frequentTradingThreshold;
        
        emit TaxRateUpdated("AdvancedStrategies", 0, _largeTxTaxRate);
    }
    
    /**
     * @notice 设置反MEV参数
     * @param _enabled 是否启用反MEV
     * @param _antiMEVTaxRate 反MEV税率
     */
    function setAntiMEVSettings(bool _enabled, uint256 _antiMEVTaxRate) external onlyOwner {
        require(_antiMEVTaxRate <= 5000, "Anti-MEV tax rate too high");
        
        antiMEVEnabled = _enabled;
        antiMEVTaxRate = _antiMEVTaxRate;
        
        emit TaxRateUpdated("AntiMEV", antiMEVEnabled ? 0 : 1, _antiMEVTaxRate);
    }
    
    /**
     * @notice 获取用户交易历史记录数量
     * @param user 用户地址
     * @return count 交易记录数量
     */
    function getUserTransactionCount(address user) external view returns (uint256 count) {
        return userTransactionTimes[user].length;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        owner = newOwner;
    }
}
