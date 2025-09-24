// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入OpenZeppelin标准合约
import "@openzeppelin/contracts/access/Ownable.sol";  // 所有权管理合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20代币标准实现

/**
 * @title PEPE代币合约
 * @dev 基于ERC20标准的meme币实现，具有以下特性：
 *      - 标准ERC20功能（转账、授权等）
 *      - 所有权管理（只有owner可以执行管理操作）
 *      - 黑名单机制（阻止恶意地址交易）
 *      - 交易限制（限制单个地址最大/最小持币量）
 *      - 交易开关（可以暂停/开启交易）
 *      - 代币销毁功能
 * @notice 这是一个简化版的meme币实现，适合快速部署和管理
 */
contract PepeToken is Ownable, ERC20 {
    
    // ========== 交易控制状态变量 ==========
    
    /// @notice 是否启用交易限制（持币量限制）
    /// @dev 当为true时，会检查接收方的持币量是否在允许范围内
    bool public limited;
    
    /// @notice 单个地址允许持有的最大代币数量
    /// @dev 只有在limited为true且从UniswapV2交易对买入时生效
    uint256 public maxHoldingAmount;
    
    /// @notice 单个地址必须持有的最小代币数量  
    /// @dev 只有在limited为true且从UniswapV2交易对买入时生效
    uint256 public minHoldingAmount;
    
    /// @notice UniswapV2交易对地址
    /// @dev 用于识别DEX交易，应用特殊的交易规则
    /// @notice 当此地址为零地址时，只有owner可以进行转账
    address public uniswapV2Pair;
    
    // ========== 新增交易限制功能 ==========
    
    /// @notice 单笔交易最大金额限制
    uint256 public maxTransactionAmount;
    
    /// @notice 每日交易次数限制
    uint256 public dailyTransactionLimit = 100;
    
    /// @notice 交易冷却时间（秒）
    uint256 public transactionCooldown = 30; // 30秒
    
    /// @notice 用户每日交易次数记录
    mapping(address => mapping(uint256 => uint256)) public dailyTransactionCount;
    
    /// @notice 用户最后交易时间
    mapping(address => uint256) public lastTransactionTime;
    
    /// @notice 交易限制白名单
    mapping(address => bool) public tradingLimitExempt;
    
    // ========== 黑名单管理 ==========
    
    /// @notice 黑名单映射表
    /// @dev 被列入黑名单的地址无法进行任何代币转账操作
    mapping(address => bool) public blacklists;

    /**
     * @notice PEPE代币合约构造函数
     * @dev 初始化ERC20代币并设置基本参数
     * @param _totalSupply 代币总供应量（将全部铸造给部署者）
     * 
     * 构造函数执行流程：
     * 1. 调用ERC20构造函数设置代币名称为"Pepe"，符号为"PEPE"
     * 2. 调用Ownable构造函数设置部署者为合约owner
     * 3. 将全部代币供应量铸造给部署者
     */
    constructor(uint256 _totalSupply) ERC20("Pepe", "PEPE") Ownable(msg.sender) {
        _mint(msg.sender, _totalSupply);  // 将全部代币铸造给合约部署者
        
        // 初始化交易限制参数
        maxTransactionAmount = _totalSupply / 100; // 1% 的总供应量
        
        // 设置交易限制白名单
        tradingLimitExempt[msg.sender] = true;     // 部署者豁免
        tradingLimitExempt[address(0)] = true;     // 零地址豁免
    }

    // ========== 管理员功能 ==========

    /**
     * @notice 管理黑名单（添加或移除地址）
     * @dev 只有合约owner可以调用此函数
     * @param _address 要操作的地址
     * @param _isBlacklisting true表示加入黑名单，false表示移出黑名单
     * 
     * 功能说明：
     * - 被加入黑名单的地址无法进行任何转账操作
     * - 可以用于阻止恶意地址或机器人交易
     * - 管理员可以随时添加或移除黑名单地址
     */
    function blacklist(address _address, bool _isBlacklisting) external onlyOwner {
        blacklists[_address] = _isBlacklisting;  // 更新地址的黑名单状态
    }

    /**
     * @notice 设置交易规则和限制
     * @dev 只有合约owner可以调用此函数
     * @param _limited 是否启用持币量限制
     * @param _uniswapV2Pair UniswapV2交易对地址
     * @param _maxHoldingAmount 最大持币量限制
     * @param _minHoldingAmount 最小持币量限制
     * 
     * 功能说明：
     * - 可以控制是否开启交易
     * - 设置DEX交易对地址以识别买卖操作
     * - 限制单个地址的持币量范围（防止巨鲸操控）
     * - 可以在项目早期限制交易，后期开放
     */
    function setRule(bool _limited, address _uniswapV2Pair, uint256 _maxHoldingAmount, uint256 _minHoldingAmount) external onlyOwner {
        limited = _limited;                    // 设置是否启用限制
        uniswapV2Pair = _uniswapV2Pair;      // 设置UniswapV2交易对地址
        maxHoldingAmount = _maxHoldingAmount; // 设置最大持币量
        minHoldingAmount = _minHoldingAmount; // 设置最小持币量
    }
    
    /**
     * @notice 设置高级交易限制参数
     * @param _maxTransactionAmount 单笔交易最大金额
     * @param _dailyLimit 每日交易次数限制
     * @param _cooldown 交易冷却时间（秒）
     */
    function setAdvancedTradingLimits(
        uint256 _maxTransactionAmount,
        uint256 _dailyLimit,
        uint256 _cooldown
    ) external onlyOwner {
        require(_maxTransactionAmount > 0, "Max transaction must be positive");
        require(_dailyLimit > 0, "Daily limit must be positive");
        require(_cooldown <= 3600, "Cooldown cannot exceed 1 hour");
        
        maxTransactionAmount = _maxTransactionAmount;
        dailyTransactionLimit = _dailyLimit;
        transactionCooldown = _cooldown;
    }
    
    /**
     * @notice 设置交易限制白名单
     * @param account 要设置的地址
     * @param exempt 是否豁免交易限制
     */
    function setTradingLimitExempt(address account, bool exempt) external onlyOwner {
        require(account != address(0), "Cannot exempt zero address");
        tradingLimitExempt[account] = exempt;
    }

    // ========== 交易限制检查函数 ==========
    
    /**
     * @notice 检查高级交易限制
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 交易金额
     */
    function _checkAdvancedTradingLimits(address from, address to, uint256 amount) private {
        // 检查白名单，白名单地址不受限制
        if (tradingLimitExempt[from] || tradingLimitExempt[to]) return;
        
        // 1. 检查单笔交易金额限制
        if (maxTransactionAmount > 0) {
            require(amount <= maxTransactionAmount, "Transfer amount exceeds maximum transaction amount");
        }
        
        // 2. 检查交易冷却时间
        if (transactionCooldown > 0) {
            require(block.timestamp >= lastTransactionTime[from] + transactionCooldown, "Transaction cooldown not met");
        }
        
        // 3. 检查每日交易次数限制
        if (dailyTransactionLimit > 0) {
            uint256 today = block.timestamp / 86400; // 获取当天日期
            require(dailyTransactionCount[from][today] < dailyTransactionLimit, "Daily transaction limit exceeded");
            
            // 更新交易记录
            dailyTransactionCount[from][today]++;
        }
        
        // 更新最后交易时间
        lastTransactionTime[from] = block.timestamp;
    }

    // ========== 核心转账逻辑 ==========

    /**
     * @notice 代币转账的核心逻辑（重写ERC20的_update函数）
     * @dev 在每次代币转移时被调用，实现各种交易限制和检查
     * @param from 转出地址（代币发送方）
     * @param to 转入地址（代币接收方）
     * @param amount 转账数量
     * 
     * 检查流程：
     * 1. 黑名单检查：确保发送方和接收方都不在黑名单中
     * 2. 交易开启检查：如果未设置Uniswap交易对，只允许owner转账
     * 3. 持币量限制：如果启用了限制且从交易对买入，检查持币量范围
     * 4. 高级交易限制检查：单笔限额、冷却时间、每日次数
     * 5. 执行实际转账
     */
    function _update(
        address from,    // 转出地址
        address to,      // 转入地址
        uint256 amount   // 转账数量
    ) internal virtual override {
        // 检查黑名单：发送方和接收方都不能在黑名单中
        require(!blacklists[to] && !blacklists[from], "Blacklisted");
        
        // 检查高级交易限制
        _checkAdvancedTradingLimits(from, to, amount);

        // 如果还未设置UniswapV2交易对地址，说明交易尚未开启
        if (uniswapV2Pair == address(0)) {
            // 只允许合约owner进行转账（用于初始分发等）
            require(from == owner() || to == owner(), "trading is not started");
            super._update(from, to, amount);  // 执行转账
            return;
        }

        // 如果启用了限制且是从交易对买入（DEX买入）
        if (limited && from == uniswapV2Pair) {
            // 检查接收方转账后的持币量是否在允许范围内
            require(
                super.balanceOf(to) + amount <= maxHoldingAmount && 
                super.balanceOf(to) + amount >= minHoldingAmount, 
                "Forbid"
            );
        }
        
        // 执行实际的代币转移
        super._update(from, to, amount);
    }

    // ========== 代币销毁功能 ==========

    /**
     * @notice 销毁调用者持有的代币
     * @dev 任何用户都可以销毁自己的代币，减少总供应量
     * @param value 要销毁的代币数量
     * 
     * 功能说明：
     * - 永久性减少代币总供应量
     * - 可能推高剩余代币的价值（通缩机制）
     * - 用户可以主动销毁代币来支持项目
     */
    function burn(uint256 value) external {
        _burn(msg.sender, value);  // 销毁调用者的代币
    }
}