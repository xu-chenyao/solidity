// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入OpenZeppelin标准合约
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";    // ERC20代币标准接口
import "@openzeppelin/contracts/access/Ownable.sol";       // 所有权管理合约

// 导入自定义接口
import "./IGovernanceToken.sol";    // 治理代币接口
import "./ITaxHandler.sol";         // 税收处理器接口  
import "./ITreasuryHandler.sol";    // 国库处理器接口

/**
 * @title FLOKI代币合约
 * @dev FLOKI代币具有模块化的税收和国库处理系统，以及治理功能
 * @notice 这是一个功能完整的meme币实现，包含：
 *         - 标准ERC20功能
 *         - 去中心化治理（投票权委托）
 *         - 灵活的税收系统
 *         - 自动化国库管理
 *         - 所有权管理
 */
contract FLOKI is IERC20, IGovernanceToken, Ownable {
    // ========== 代币基础存储 ==========
    
    /// @dev 用户代币余额注册表 - 记录每个地址持有的代币数量
    mapping(address => uint256) private _balances;

    /// @dev 代币授权注册表 - 记录用户授权给其他地址的代币数量
    /// @notice 格式：_allowances[owner][spender] = amount
    mapping(address => mapping(address => uint256)) private _allowances;

    // ========== 治理相关存储 ==========
    
    /// @notice 投票权委托注册表 - 记录每个用户将投票权委托给谁
    /// @dev 如果用户想要自己投票，也需要将投票权委托给自己
    mapping(address => address) public delegates;

    /// @notice 投票委托随机数注册表 - 防止重放攻击
    /// @dev 用于delegateBySig函数中验证签名的唯一性
    mapping(address => uint256) public nonces;

    /// @notice 账户检查点数量注册表 - 记录每个账户有多少个投票权检查点
    /// @dev 用于优化历史投票权查询的性能
    mapping(address => uint32) public numCheckpoints;

    /// @notice 账户投票权检查点注册表 - 记录每个账户的历史投票权变化
    /// @dev 格式：checkpoints[account][checkpointIndex] = Checkpoint
    /// @notice 支持查询任意历史区块的投票权分布
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    // ========== EIP-712 签名相关常量 ==========
    
    /// @notice EIP-712域分隔符的类型哈希
    /// @dev 用于构建域分隔符，确保签名只在特定合约和链上有效
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice 投票权委托结构体的EIP-712类型哈希
    /// @dev 用于delegateBySig函数中验证委托签名的结构
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // ========== 外部合约引用 ==========
    
    /// @notice 税收处理器合约实例
    /// @dev 负责计算每笔交易的税收金额，支持动态税率策略
    ITaxHandler public taxHandler;

    /// @notice 国库处理器合约实例  
    /// @dev 负责处理税收收入和执行国库管理策略
    ITreasuryHandler public treasuryHandler;
    
    // ========== 交易限制相关 ==========
    
    /// @notice 是否启用交易限制
    bool public tradingLimitsEnabled = true;
    
    /// @notice 单笔交易最大金额限制
    uint256 public maxTransactionAmount = 1e12 * 1e9; // 1万亿代币 (总供应量的10%)
    
    /// @notice 单个地址最大持币量限制
    uint256 public maxWalletAmount = 2e12 * 1e9; // 2万亿代币 (总供应量的20%)
    
    /// @notice 每日交易次数限制
    uint256 public dailyTransactionLimit = 50;
    
    /// @notice 交易冷却时间（秒）
    uint256 public transactionCooldown = 60; // 1分钟
    
    /// @notice 用户每日交易次数记录
    mapping(address => mapping(uint256 => uint256)) public dailyTransactionCount;
    
    /// @notice 用户最后交易时间
    mapping(address => uint256) public lastTransactionTime;
    
    /// @notice 交易限制白名单（不受限制的地址）
    mapping(address => bool) public tradingLimitExempt;

    // ========== 事件定义 ==========
    
    /// @notice 当税收处理器合约地址更改时触发
    /// @param oldAddress 旧的税收处理器地址
    /// @param newAddress 新的税收处理器地址
    event TaxHandlerChanged(address oldAddress, address newAddress);

    /// @notice 当国库处理器合约地址更改时触发
    /// @param oldAddress 旧的国库处理器地址
    /// @param newAddress 新的国库处理器地址
    event TreasuryHandlerChanged(address oldAddress, address newAddress);
    
    /// @notice 当交易限制配置更新时触发
    event TradingLimitsUpdated(bool enabled, uint256 maxTransaction, uint256 maxWallet, uint256 dailyLimit, uint256 cooldown);
    
    /// @notice 当交易限制白名单更新时触发
    event TradingLimitExemptUpdated(address indexed account, bool exempt);

    // ========== 代币基本信息 ==========
    
    /// @dev 代币名称（如："Floki Inu"）
    string private _name;

    /// @dev 代币符号（如："FLOKI"）
    string private _symbol;

    /**
     * @notice FLOKI代币合约构造函数
     * @dev 初始化代币基本信息，设置税收和国库处理器，并将全部代币铸造给部署者
     * 
     * @param name_ 代币名称（如："Floki Inu"）
     * @param symbol_ 代币符号（如："FLOKI"）  
     * @param taxHandlerAddress 初始税收处理器合约地址
     * @param treasuryHandlerAddress 初始国库处理器合约地址
     * 
     * 构造函数执行流程：
     * 1. 设置代币基本信息（名称和符号）
     * 2. 初始化税收和国库处理器合约引用
     * 3. 将全部代币供应量铸造给合约部署者
     * 4. 触发Transfer事件记录初始铸造
     */
    constructor(
        string memory name_,              // 代币名称
        string memory symbol_,            // 代币符号
        address taxHandlerAddress,        // 税收处理器地址
        address treasuryHandlerAddress   // 国库处理器地址
    ) Ownable(msg.sender) {
        // 设置代币基本信息
        _name = name_;                    // 存储代币名称
        _symbol = symbol_;                // 存储代币符号

        // 初始化外部合约引用
        taxHandler = ITaxHandler(taxHandlerAddress);           // 设置税收处理器
        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress); // 设置国库处理器

        // 将全部代币供应量分配给部署者
        _balances[_msgSender()] = totalSupply();  // 设置部署者余额为总供应量

        // 设置交易限制豁免地址
        tradingLimitExempt[_msgSender()] = true;           // 部署者豁免
        tradingLimitExempt[address(0)] = true;             // 零地址豁免（销毁）
        tradingLimitExempt[taxHandlerAddress] = true;      // 税收处理器豁免
        tradingLimitExempt[treasuryHandlerAddress] = true; // 国库处理器豁免

        // 🔧 修复：设置国库处理器的投票权委托给自己
        // 确保税收产生的投票权有明确的归属
        delegates[treasuryHandlerAddress] = treasuryHandlerAddress;

        // 触发转账事件，记录从零地址到部署者的初始铸造
        emit Transfer(address(0), _msgSender(), totalSupply());
    }

    // ========== ERC20 基础查询函数 ==========
    
    /**
     * @notice 获取代币名称
     * @return 代币的完整名称（如："Floki Inu"）
     * @dev 实现ERC20标准的name()函数
     */
    function name() public view returns (string memory) {
        return _name;  // 返回构造函数中设置的代币名称
    }

    /**
     * @notice 获取代币符号
     * @return 代币的交易符号（如："FLOKI"）
     * @dev 实现ERC20标准的symbol()函数
     */
    function symbol() external view returns (string memory) {
        return _symbol;  // 返回构造函数中设置的代币符号
    }

    /**
     * @notice 获取代币精度（小数位数）
     * @return 代币的小数位数（固定为9位）
     * @dev 实现ERC20标准的decimals()函数
     * @notice 9位精度意味着1个代币 = 1,000,000,000个最小单位
     */
    function decimals() external pure returns (uint8) {
        return 9;  // FLOKI代币使用9位小数精度
    }

    /**
     * @notice 获取代币总供应量
     * @return 代币的最大供应量（永远不会超过此数量）
     * @dev 实现ERC20标准的totalSupply()函数
     * @notice 总供应量为10万亿个代币（10,000,000,000,000）
     */
    function totalSupply() public pure override returns (uint256) {
        // 十万亿代币，即 10,000,000,000,000 个代币
        // 计算：1e13 * 1e9 = 10^13 * 10^9 = 10^22 最小单位
        return 1e13 * 1e9;
    }

    /**
     * @notice 查询指定账户的代币余额
     * @param account 要查询余额的账户地址
     * @return 该账户所持有的代币数量
     * @dev 实现ERC20标准的balanceOf()函数
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];  // 从余额映射中返回账户余额
    }

    // ========== ERC20 转账函数 ==========

    /**
     * @notice 从调用者地址向另一个地址转账代币
     * @param recipient 接收代币的目标地址
     * @param amount 要转账的代币数量
     * @return 转账成功返回true，失败则抛出异常
     * @dev 实现ERC20标准的transfer()函数
     * @notice 此函数会触发税收计算和国库管理逻辑
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);  // 调用内部转账函数
        return true;  // 转账成功返回true
    }

    /**
     * @notice 获取授权额度（owner给spender的授权量）
     * @param owner 代币所有者地址（被授权方）
     * @param spender 被授权地址（可以代为owner花费代币的地址）
     * @return owner给spender的授权代币数量
     * @dev 实现ERC20标准的allowance()函数
     * @notice 返回0表示没有授权，大于0表示有授权余额
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];  // 从授权映射中返回授权量
    }

    // ========== ERC20 授权函数 ==========

    /**
     * @notice 授权地址花费调用者的代币
     * @dev 如果被授权地址已经有非零授权，此方法可能被恶意利用。
     *      详情参见：https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *      如果之前已经授权过，请确保被授权地址可信任。
     *      否则请使用increaseAllowance/decreaseAllowance函数，
     *      或者先将授权设为零，再设置新的授权。
     * @param spender 被授权地址（可以花费代币的地址）
     * @param amount 允许spender花费的代币数量
     * @return 授权成功返回true，失败则抛出异常
     * 
     * 安全注意事项：
     * - 避免给不可信的地址授权
     * - 授权前检查当前授权状态
     * - 优先使用增减授权函数而非直接覆盖
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);  // 调用内部授权函数
        return true;  // 授权成功返回true
    }

    /**
     * @notice 从一个地址向另一个地址转账代币（代理转账）
     * @param sender 代币转出地址（代币所有者）
     * @param recipient 代币接收地址（目标地址）
     * @param amount 要转账的代币数量
     * @return 转账成功返回true，失败则抛出异常
     * @dev 实现ERC20标准的transferFrom()函数
     * 
     * 执行流程：
     * 1. 执行代币转移（包括税收计算和国库管理）
     * 2. 检查调用者的授权额度是否足够
     * 3. 减少调用者的授权额度
     * 
     * 安全检查：
     * - 验证授权额度是否足够
     * - 使用unchecked优化gas消耗（已经检查过溢出）
     */
    function transferFrom(
        address sender,      // 代币转出地址
        address recipient,   // 代币接收地址
        uint256 amount      // 转账数量
    ) external override returns (bool) {
        // 执行代币转移（会触发税收计算和国库管理）
        _transfer(sender, recipient, amount);

        // 获取当前授权额度
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        
        // 检查授权额度是否足够
        require(
            currentAllowance >= amount,
            "FLOKI:transferFrom:ALLOWANCE_EXCEEDED: Transfer amount exceeds allowance."
        );
        
        // 减少授权额度（使用unchecked优化gas，因为已经检查过溢出）
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;  // 转账成功返回true
    }

    /**
     * @notice 增加被授权地址的授权额度
     * @param spender 被授权地址（可以花费调用者代币的地址）
     * @param addedValue 要增加的代币数量
     * @return 增加成功返回true，失败则抛出异常
     * 
     * 优势：
     * - 避免了approve函数的竞态条件攻击风险
     * - 更安全的授权管理方式
     * - 支持逐步增加授权额度
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        // 在当前授权基础上增加指定数量
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);

        return true;  // 增加成功返回true
    }

    /**
     * @notice 减少被授权地址的授权额度
     * @param spender 被授权地址（可以花费调用者代币的地址）
     * @param subtractedValue 要减少的代币数量
     * @return 减少成功返回true，失败则抛出异常
     * 
     * 安全检查：
     * - 防止授权额度下溢（变成负数）
     * - 确保减少后的授权额度不会小于零
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        // 获取当前授权额度
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        
        // 检查是否会下溢（减少量不能大于当前授权量）
        require(
            currentAllowance >= subtractedValue,
            "FLOKI:decreaseAllowance:ALLOWANCE_UNDERFLOW: Subtraction results in sub-zero allowance."
        );
        
        // 减少授权额度（使用unchecked优化gas，因为已经检查过下溢）
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;  // 减少成功返回true
    }

    // ========== 治理功能 ==========

    /**
     * @notice 将投票权委托给指定地址
     * @dev 需要注意的是，想要自己投票的用户也需要调用此方法，
     *      只不过是将投票权委托给自己的地址。
     * @param delegatee 接收投票权委托的地址
     * 
     * 功能说明：
     * - 投票权委托是治理系统的核心机制
     * - 用户可以将投票权委托给信任的代表
     * - 委托后的投票权会立即生效
     * - 可以随时更改委托对象
     */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);  // 调用内部委托函数
    }

    /**
     * @notice 通过签名将投票权从签名者委托给delegatee
     * @param delegatee 接收投票权委托的地址
     * @param nonce 签名者的当前随机数（用于防止重放攻击）
     * @param expiry 签名过期时间戳（秒）
     * @param v ECDSA签名的恢复字节
     * @param r ECDSA签名对的一半
     * @param s ECDSA签名对的另一半
     * 
     * 功能说明：
     * - 允许用户通过签名进行投票权委托，无需直接发送交易
     * - 遵循EIP-712标准，提供结构化签名支持
     * - 支持签名过期机制，增强安全性
     * - 使用nonce防止签名重放攻击
     * 
     * 安全检查：
     * 1. 验证签名的有效性
     * 2. 检查签名是否过期
     * 3. 验证并更新nonce防止重放
     */
    function delegateBySig(
        address delegatee,  // 委托目标地址
        uint256 nonce,      // 签名随机数
        uint256 expiry,     // 过期时间
        uint8 v,            // 签名参数v
        bytes32 r,          // 签名参数r
        bytes32 s           // 签名参数s
    ) external {
        // 构建EIP-712域分隔符（确保签名只在特定合约和链上有效）
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
        );
        
        // 构建委托结构体哈希
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        
        // 构建最终的签名消息哈希
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // 从签名中恢复签名者地址
        address signatory = ecrecover(digest, v, r, s);

        // 验证签名有效性（签名者不能是零地址）
        require(signatory != address(0), "FLOKI:delegateBySig:INVALID_SIGNATURE: Received signature was invalid.");
        
        // 检查签名是否过期
        require(block.timestamp <= expiry, "FLOKI:delegateBySig:EXPIRED_SIGNATURE: Received signature has expired.");
        
        // 验证并更新nonce（防止重放攻击）
        require(nonce == nonces[signatory]++, "FLOKI:delegateBySig:INVALID_NONCE: Received nonce was invalid.");

        // 执行投票权委托
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice 查询指定账户当前的投票权数量
     * @param account 要查询的账户地址
     * @return 该账户当前拥有的投票权数量
     * 
     * 功能说明：
     * - 如果账户没有设置委托，自动查询自己的投票权
     * - 如果账户设置了委托，查询被委托人的投票权
     */
    function getVotes(address account) public view returns (uint224) {
        // 确定实际的委托人（如果没有设置委托，默认是自己）
        address accountDelegate = delegates[account] == address(0) ? account : delegates[account];
        
        uint32 nCheckpoints = numCheckpoints[accountDelegate];
        return nCheckpoints > 0 ? checkpoints[accountDelegate][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice 查询指定账户在特定区块的投票权数量
     * @dev 区块号必须是已确认的历史区块，否则函数会回滚以防止错误信息
     * @param account 要查询的账户地址
     * @param blockNumber 要查询的区块号
     * @return 该账户在指定区块时拥有的投票权数量
     * 
     * 功能说明：
     * - 用于治理投票时确定用户在提案创建时刻的投票权
     * - 防止用户在投票期间转移代币来重复投票
     * - 使用二分查找算法优化查询性能
     * 
     * 查询算法：
     * 1. 首先检查最近的检查点
     * 2. 然后检查隐式的零余额
     * 3. 最后使用二分查找精确定位
     */
    function getVotesAtBlock(address account, uint32 blockNumber) public view returns (uint224) {
        // 检查区块号是否在未来（只能查询历史数据）
        require(
            blockNumber < block.number,
            "FLOKI:getVotesAtBlock:FUTURE_BLOCK: Cannot get votes at a block in the future."
        );

        // 确定实际的委托人（如果没有设置委托，默认是自己）
        address accountDelegate = delegates[account] == address(0) ? account : delegates[account];

        // 获取委托人的检查点数量
        uint32 nCheckpoints = numCheckpoints[accountDelegate];
        
        // 如果没有检查点，说明从未有过投票权
        if (nCheckpoints == 0) {
            return 0;
        }

        // 首先检查最近的余额（如果最近的检查点在目标区块之前或同时）
        if (checkpoints[accountDelegate][nCheckpoints - 1].blockNumber <= blockNumber) {
            return checkpoints[accountDelegate][nCheckpoints - 1].votes;
        }

        // 检查隐式的零余额（如果第一个检查点在目标区块之后）
        if (checkpoints[accountDelegate][0].blockNumber > blockNumber) {
            return 0;
        }

        // 执行二分查找算法定位精确的检查点
        uint32 lowerBound = 0;                    // 下界索引
        uint32 upperBound = nCheckpoints - 1;     // 上界索引
        
        // 二分查找循环
        while (upperBound > lowerBound) {
            // 计算中间位置（避免溢出的安全计算方式）
            uint32 center = upperBound - (upperBound - lowerBound) / 2;
            
            // 获取中间检查点
            Checkpoint memory checkpoint = checkpoints[accountDelegate][center];

            if (checkpoint.blockNumber == blockNumber) {
                // 找到精确匹配的区块号
                return checkpoint.votes;
            } else if (checkpoint.blockNumber < blockNumber) {
                // 中间检查点在目标区块之前，搜索右半部分
                lowerBound = center;
            } else {
                // 中间检查点在目标区块之后，搜索左半部分
                upperBound = center - 1;
            }
        }

        // 没有找到精确匹配的区块号，使用该区块号之前的最后一个已知余额
        return checkpoints[accountDelegate][lowerBound].votes;
    }

    // ========== 交易限制检查函数 ==========
    
    /**
     * @notice 检查交易是否符合限制条件
     * @param from 发送者地址
     * @param to 接收者地址  
     * @param amount 交易金额
     */
    function _checkTradingLimits(address from, address to, uint256 amount) private {
        // 如果交易限制未启用，直接返回
        if (!tradingLimitsEnabled) return;
        
        // 检查白名单，白名单地址不受限制
        if (tradingLimitExempt[from] || tradingLimitExempt[to]) return;
        
        // 1. 检查单笔交易金额限制
        require(amount <= maxTransactionAmount, "Transfer amount exceeds maximum transaction amount");
        
        // 2. 检查接收者持币量限制（排除销毁地址）
        if (to != address(0)) {
            require(this.balanceOf(to) + amount <= maxWalletAmount, "Recipient wallet exceeds maximum wallet amount");
        }
        
        // 3. 检查交易冷却时间
        require(block.timestamp >= lastTransactionTime[from] + transactionCooldown, "Transaction cooldown not met");
        
        // 4. 检查每日交易次数限制
        uint256 today = block.timestamp / 86400; // 获取当天日期
        require(dailyTransactionCount[from][today] < dailyTransactionLimit, "Daily transaction limit exceeded");
        
        // 更新交易记录
        lastTransactionTime[from] = block.timestamp;
        dailyTransactionCount[from][today]++;
    }

    // ========== 管理员功能 ==========

    /**
     * @notice 设置新的税收处理器合约
     * @param taxHandlerAddress 新的税收处理器合约地址
     * @dev 只有合约owner可以调用此函数
     * 
     * 功能说明：
     * - 允许管理员更新税收计算逻辑
     * - 支持热更新税收策略而无需重新部署代币
     * - 可以实现动态税率调整
     * - 触发事件通知用户和前端应用
     */
    function setTaxHandler(address taxHandlerAddress) external onlyOwner {
        address oldTaxHandlerAddress = address(taxHandler);  // 保存旧地址用于事件
        taxHandler = ITaxHandler(taxHandlerAddress);         // 更新税收处理器

        // 触发更新事件
        emit TaxHandlerChanged(oldTaxHandlerAddress, taxHandlerAddress);
    }

    /**
     * @notice 设置新的国库处理器合约
     * @param treasuryHandlerAddress 新的国库处理器合约地址
     * @dev 只有合约owner可以调用此函数
     * 
     * 功能说明：
     * - 允许管理员更新国库管理逻辑
     * - 支持热更新资金管理策略
     * - 可以实现不同的国库运作模式
     * - 触发事件通知用户和前端应用
     */
    function setTreasuryHandler(address treasuryHandlerAddress) external onlyOwner {
        address oldTreasuryHandlerAddress = address(treasuryHandler);  // 保存旧地址用于事件
        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);     // 更新国库处理器

        // 触发更新事件
        emit TreasuryHandlerChanged(oldTreasuryHandlerAddress, treasuryHandlerAddress);
    }
    
    /**
     * @notice 配置交易限制参数
     * @param _enabled 是否启用交易限制
     * @param _maxTransaction 单笔交易最大金额
     * @param _maxWallet 单个地址最大持币量
     * @param _dailyLimit 每日交易次数限制
     * @param _cooldown 交易冷却时间（秒）
     */
    function setTradingLimits(
        bool _enabled,
        uint256 _maxTransaction,
        uint256 _maxWallet,
        uint256 _dailyLimit,
        uint256 _cooldown
    ) external onlyOwner {
        require(_maxTransaction > 0, "Max transaction must be positive");
        require(_maxWallet > 0, "Max wallet must be positive");
        require(_dailyLimit > 0, "Daily limit must be positive");
        require(_cooldown <= 3600, "Cooldown cannot exceed 1 hour");
        
        tradingLimitsEnabled = _enabled;
        maxTransactionAmount = _maxTransaction;
        maxWalletAmount = _maxWallet;
        dailyTransactionLimit = _dailyLimit;
        transactionCooldown = _cooldown;
        
        emit TradingLimitsUpdated(_enabled, _maxTransaction, _maxWallet, _dailyLimit, _cooldown);
    }
    
    /**
     * @notice 设置交易限制白名单
     * @param account 要设置的地址
     * @param exempt 是否豁免交易限制
     */
    function setTradingLimitExempt(address account, bool exempt) external onlyOwner {
        require(account != address(0), "Cannot exempt zero address");
        tradingLimitExempt[account] = exempt;
        emit TradingLimitExemptUpdated(account, exempt);
    }

    // ========== 内部治理函数 ==========

    /**
     * @notice 将投票权从一个地址委托给另一个地址（内部函数）
     * @param delegator 委托人地址（投票权的原始拥有者）
     * @param delegatee 被委托人地址（接收投票权的地址）
     * 
     * 执行流程：
     * 1. 获取当前委托关系和委托人余额
     * 2. 更新委托关系映射
     * 3. 触发委托变更事件
     * 4. 移动投票权并更新检查点
     */
    function _delegate(address delegator, address delegatee) private {
        address currentDelegate = delegates[delegator];  // 获取当前委托人
        uint256 delegatorBalance = _balances[delegator]; // 获取委托人的代币余额
        delegates[delegator] = delegatee;                // 更新委托关系

        // 触发委托变更事件
        emit DelegateChanged(delegator, currentDelegate, delegatee);

        // 移动投票权（从旧委托人到新委托人）
        _moveDelegates(currentDelegate, delegatee, uint224(delegatorBalance));
    }

    /**
     * @notice 在两个地址之间移动投票权（内部函数）
     * @param from 投票权转出地址（原委托人）
     * @param to 投票权转入地址（新委托人）
     * @param amount 要移动的投票权数量
     * 
     * 优化逻辑：
     * - 如果投票权在相同委托人之间移动，无需更新检查点
     * - 如果移动数量为0，无需执行任何操作
     * - 分别处理转出和转入操作
     */
    function _moveDelegates(
        address from,   // 投票权转出地址
        address to,     // 投票权转入地址
        uint224 amount  // 移动数量
    ) private {
        // 如果投票权在相同的委托人之间移动，无需更新检查点
        // 这可能发生在两个用户都将投票权委托给同一个地址的情况下
        if (from == to) {
            return;  // 直接返回，不做任何操作
        }

        // 一些用户可能在拥有代币之前就提前委托了投票权
        // 在这种情况下无需更新检查点
        if (amount == 0) {
            return;  // 没有投票权需要移动
        }

        // 处理转出方（减少原委托人的投票权）
        if (from != address(0)) {
            uint32 fromRepNum = numCheckpoints[from];  // 获取转出方的检查点数量
            // 获取转出方的当前投票权（如果没有检查点则为0）
            uint224 fromRepOld = fromRepNum > 0 ? checkpoints[from][fromRepNum - 1].votes : 0;
            uint224 fromRepNew = fromRepOld - amount;  // 计算新的投票权数量

            // 为转出方写入新的检查点
            _writeCheckpoint(from, fromRepNum, fromRepOld, fromRepNew);
        }

        // 处理转入方（增加新委托人的投票权）
        if (to != address(0)) {
            uint32 toRepNum = numCheckpoints[to];      // 获取转入方的检查点数量
            // 获取转入方的当前投票权（如果没有检查点则为0）
            uint224 toRepOld = toRepNum > 0 ? checkpoints[to][toRepNum - 1].votes : 0;
            uint224 toRepNew = toRepOld + amount;      // 计算新的投票权数量

            // 为转入方写入新的检查点
            _writeCheckpoint(to, toRepNum, toRepOld, toRepNew);
        }
    }

    /**
     * @notice 将投票权检查点写入区块链（内部函数）
     * @param delegatee 要写入检查点的委托人地址
     * @param nCheckpoints 委托人当前已有的检查点数量
     * @param oldVotes 更新前的投票权数量
     * @param newVotes 更新后的投票权数量
     * 
     * 检查点写入逻辑：
     * - 如果在同一区块内多次更新，只更新最后一个检查点
     * - 否则创建新的检查点并增加计数器
     * - 始终触发投票权变更事件
     */
    function _writeCheckpoint(
        address delegatee,    // 委托人地址
        uint32 nCheckpoints,  // 当前检查点数量
        uint224 oldVotes,     // 旧投票权数量
        uint224 newVotes      // 新投票权数量
    ) private {
        uint32 blockNumber = uint32(block.number);  // 获取当前区块号

        // 检查是否在同一区块内更新（优化存储）
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].blockNumber == blockNumber) {
            // 在同一区块内，只更新最后一个检查点的投票数
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            // 不同区块，创建新的检查点
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;  // 增加检查点计数
        }

        // 触发投票权变更事件
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    // ========== 内部ERC20函数 ==========

    /**
     * @notice 代表owner授权spender花费代币（内部函数）
     * @param owner 代币所有者地址（被授权方）
     * @param spender 被授权地址（可以花费代币的地址）
     * @param amount 允许spender花费的代币数量
     * 
     * 安全检查：
     * - owner不能是零地址
     * - spender不能是零地址
     * - 更新授权映射并触发事件
     */
    function _approve(
        address owner,    // 代币所有者
        address spender,  // 被授权者
        uint256 amount    // 授权数量
    ) private {
        // 检查owner不能是零地址
        require(owner != address(0), "FLOKI:_approve:OWNER_ZERO: Cannot approve for the zero address.");
        
        // 检查spender不能是零地址
        require(spender != address(0), "FLOKI:_approve:SPENDER_ZERO: Cannot approve to the zero address.");

        // 更新授权映射
        _allowances[owner][spender] = amount;

        // 触发授权事件
        emit Approval(owner, spender, amount);
    }

    /**
     * @notice 从账户from向账户to转账amount数量的代币（核心转账函数）
     * @param from 代币转出地址
     * @param to 代币转入地址
     * @param amount 转账的代币数量
     * 
     * 转账流程：
     * 1. 安全检查（地址、数量、余额验证）
     * 2. 执行转账前处理逻辑（国库管理）
     * 3. 计算税收金额
     * 4. 执行代币转移和投票权移动
     * 5. 处理税收收入（如果有）
     * 6. 执行转账后处理逻辑
     * 7. 触发转账事件
     */
    function _transfer(
        address from,   // 转出地址
        address to,     // 转入地址
        uint256 amount  // 转账数量
    ) private {
        // ========== 安全检查 ==========
        
        // 检查转出地址不能是零地址
        require(from != address(0), "FLOKI:_transfer:FROM_ZERO: Cannot transfer from the zero address.");
        
        // 检查转入地址不能是零地址
        require(to != address(0), "FLOKI:_transfer:TO_ZERO: Cannot transfer to the zero address.");
        
        // 检查转账数量必须大于0
        require(amount > 0, "FLOKI:_transfer:ZERO_AMOUNT: Transfer amount must be greater than zero.");
        
        // 检查转出方余额是否足够
        require(amount <= _balances[from], "FLOKI:_transfer:INSUFFICIENT_BALANCE: Transfer amount exceeds balance.");
        
        // 检查交易限制
        _checkTradingLimits(from, to, amount);

        // ========== 转账前处理 ==========
        
        // 执行国库管理器的转账前处理逻辑
        treasuryHandler.beforeTransferHandler(from, to, amount);

        // ========== 税收计算和代币转移 ==========
        
        // 计算税收金额
        uint256 tax = taxHandler.getTax(from, to, amount);
        uint256 taxedAmount = amount - tax;  // 实际到账金额

        // 更新余额：从转出方扣除全部金额
        _balances[from] -= amount;
        
        // 更新余额：给转入方增加税后金额
        _balances[to] += taxedAmount;
        
        // 移动投票权：从转出方的委托人到转入方的委托人
        // 如果用户没有设置委托，默认委托给自己
        address fromDelegate = delegates[from] == address(0) ? from : delegates[from];
        address toDelegate = delegates[to] == address(0) ? to : delegates[to];
        _moveDelegates(fromDelegate, toDelegate, uint224(taxedAmount));

        // ========== 税收处理 ==========
        
        // 如果有税收，处理税收收入
        if (tax > 0) {
            // 将税收转给国库处理器
            _balances[address(treasuryHandler)] += tax;

            // 移动税收部分的投票权到国库处理器
            // 使用之前已经计算的fromDelegate
            _moveDelegates(fromDelegate, address(treasuryHandler), uint224(tax));

            // 触发税收转账事件
            emit Transfer(from, address(treasuryHandler), tax);
        }

        // ========== 转账后处理 ==========
        
        // 执行国库管理器的转账后处理逻辑
        treasuryHandler.afterTransferHandler(from, to, amount);

        // 触发主转账事件（税后金额）
        emit Transfer(from, to, taxedAmount);
    }
}