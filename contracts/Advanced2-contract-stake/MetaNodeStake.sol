// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入OpenZeppelin标准库合约
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";           // ERC20代币接口
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";  // 安全的ERC20操作库
import "@openzeppelin/contracts/utils/Address.sol";                // 地址工具库
import "@openzeppelin/contracts/utils/math/Math.sol";              // 数学运算工具库

// 导入OpenZeppelin可升级合约库
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";        // 初始化器
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";      // UUPS升级模式
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";  // 访问控制
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";        // 暂停功能

/**
 * @title MetaNodeStake - MetaNode代币质押挖矿合约
 * @dev 这是一个支持多币种质押挖矿的合约，用户可以质押ETH或ERC20代币来获得MetaNode代币奖励
 * 
 * 核心功能：
 * 1. 多资金池支持：支持ETH和多种ERC20代币质押
 * 2. 灵活奖励机制：基于区块高度和权重分配奖励
 * 3. 延迟提取：支持设置提取锁定期，防止短期投机
 * 4. 管理员控制：支持暂停、参数调整等管理功能
 * 5. 可升级架构：使用UUPS模式支持合约升级
 * 
 * 奖励计算公式：
 * pending MetaNode = (user.stAmount * pool.accMetaNodePerST) - user.finishedMetaNode
 * 
 * 工作流程：
 * 1. 用户质押代币到指定资金池
 * 2. 合约根据区块奖励和池权重计算累积奖励
 * 3. 用户可以随时领取已累积的奖励
 * 4. 用户申请提取质押代币（需要等待锁定期）
 * 5. 锁定期结束后可以提取代币
 */
contract MetaNodeStake is
    Initializable,              // 初始化器：支持代理合约初始化
    UUPSUpgradeable,           // UUPS升级：支持合约逻辑升级
    PausableUpgradeable,       // 暂停功能：紧急情况下可暂停合约
    AccessControlUpgradeable   // 访问控制：基于角色的权限管理
{
    // 使用SafeERC20库进行安全的代币操作，防止转账失败等问题
    using SafeERC20 for IERC20;
    // 使用Address库进行地址相关操作
    using Address for address;
    // 使用Math库进行安全的数学运算，防止溢出
    using Math for uint256;

    // ===================================== 常量定义 =====================================

    // 管理员角色：拥有合约管理权限
    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    // 升级角色：拥有合约升级权限  
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    // ETH资金池ID：ETH质押池固定为0号池
    uint256 public constant ETH_PID = 0;
    
    // ===================================== 数据结构定义 =====================================
    /**
     * @dev 奖励计算机制说明：
     * 
     * 在任何时间点，用户应得但尚未分发的MetaNode数量为：
     * pending MetaNode = (user.stAmount * pool.accMetaNodePerST) - user.finishedMetaNode
     * 
     * 当用户存入或提取质押代币时，会发生以下操作：
     * 1. 更新资金池的 accMetaNodePerST（累积每质押代币奖励）和 lastRewardBlock（上次奖励区块）
     * 2. 将用户的待领取MetaNode发送到其地址
     * 3. 更新用户的 stAmount（质押数量）
     * 4. 更新用户的 finishedMetaNode（已结算奖励）
     * 
     * 这种机制确保：
     * - 奖励计算的准确性和公平性
     * - 用户可以随时准确查询待领取奖励
     * - 避免重复计算和奖励丢失
     */
    /**
     * @dev 资金池结构体
     * 每个资金池代表一种可质押的代币类型
     */
    struct Pool {
        address stTokenAddress;      // 质押代币地址（address(0)表示ETH）
        uint256 poolWeight;          // 资金池权重（决定奖励分配比例）
        uint256 lastRewardBlock;     // 上次更新奖励的区块号
        uint256 accMetaNodePerST;    // 每个质押代币累积的MetaNode奖励（乘以1e18精度）
        uint256 stTokenAmount;       // 资金池中质押代币总量
        uint256 minDepositAmount;    // 最小质押数量限制
        uint256 unstakeLockedBlocks; // 提取锁定区块数（防止短期投机）
    }

    /**
     * @dev 提取请求结构体
     * 用户申请提取时创建，需要等待锁定期
     */
    struct UnstakeRequest {
        uint256 amount;       // 申请提取的数量
        uint256 unlockBlocks; // 可以提取的区块号（当前区块+锁定期）
    }

    /**
     * @dev 用户信息结构体
     * 记录用户在每个资金池中的质押和奖励信息
     */
    struct User {
        uint256 stAmount;         // 用户质押的代币数量
        uint256 finishedMetaNode; // 已结算的MetaNode奖励数量
        uint256 pendingMetaNode;  // 待领取的MetaNode奖励数量
        UnstakeRequest[] requests; // 用户的提取请求列表
    }

    // ===================================== 状态变量 =====================================
    
    // 挖矿开始区块号
    uint256 public startBlock;
    // 挖矿结束区块号  
    uint256 public endBlock;
    // 每个区块产出的MetaNode代币数量
    uint256 public MetaNodePerBlock;

    // 提取功能暂停标志
    bool public withdrawPaused;
    // 领取功能暂停标志
    bool public claimPaused;

    // MetaNode奖励代币合约接口
    IERC20 public MetaNode;

    // 所有资金池总权重（用于计算奖励分配比例）
    uint256 public totalPoolWeight;
    // 资金池数组
    Pool[] public pool;

    // 嵌套映射：资金池ID => 用户地址 => 用户信息
    mapping (uint256 => mapping (address => User)) public user;

    // ===================================== 事件定义 =====================================

    // 设置MetaNode代币地址事件
    event SetMetaNode(IERC20 indexed MetaNode);
    // 暂停提取事件
    event PauseWithdraw();
    // 恢复提取事件
    event UnpauseWithdraw();
    // 暂停领取事件
    event PauseClaim();
    // 恢复领取事件
    event UnpauseClaim();
    // 设置开始区块事件
    event SetStartBlock(uint256 indexed startBlock);
    // 设置结束区块事件
    event SetEndBlock(uint256 indexed endBlock);
    // 设置每区块奖励事件
    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);
    // 添加资金池事件
    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);
    // 更新资金池信息事件
    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks);
    // 设置资金池权重事件
    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);
    // 更新资金池事件
    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);
    // 质押事件
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    // 申请提取事件
    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);
    // 提取事件
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);
    // 领取奖励事件
    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);

    // ===================================== 修饰符定义 =====================================

    /**
     * @dev 检查资金池ID是否有效
     * @param _pid 资金池ID
     */
    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");  // 资金池ID必须小于池数组长度
        _;
    }

    /**
     * @dev 检查领取功能是否被暂停
     */
    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");  // 领取功能未被暂停
        _;
    }

    /**
     * @dev 检查提取功能是否被暂停
     */
    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");  // 提取功能未被暂停
        _;
    }

    // ===================================== 初始化函数 =====================================

    /**
     * @notice 初始化合约
     * @dev 代替构造函数，用于代理合约的初始化
     * @param _MetaNode MetaNode代币合约地址
     * @param _startBlock 挖矿开始区块号
     * @param _endBlock 挖矿结束区块号
     * @param _MetaNodePerBlock 每区块MetaNode奖励数量
     */
    function initialize(
        IERC20 _MetaNode,           // MetaNode代币合约接口
        uint256 _startBlock,        // 挖矿开始区块
        uint256 _endBlock,          // 挖矿结束区块
        uint256 _MetaNodePerBlock   // 每区块奖励数量
    ) public initializer {
        // 参数有效性检查：开始区块不能大于结束区块，每区块奖励必须大于0
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters");

        // 初始化各个升级模块
        __AccessControl_init();      // 初始化访问控制
        __UUPSUpgradeable_init();   // 初始化UUPS升级功能
        
        // 为部署者分配所有角色权限
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);  // 默认管理员角色
        _grantRole(UPGRADE_ROLE, msg.sender);        // 升级角色
        _grantRole(ADMIN_ROLE, msg.sender);          // 管理员角色

        // 设置MetaNode代币地址
        setMetaNode(_MetaNode);

        // 设置挖矿参数
        startBlock = _startBlock;           // 开始区块
        endBlock = _endBlock;               // 结束区块
        MetaNodePerBlock = _MetaNodePerBlock; // 每区块奖励
    }

    /**
     * @dev 授权升级函数，只有具有UPGRADE_ROLE的账户才能升级合约
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)  // 只有升级角色可以调用
        override
    {
        // 空实现，权限检查在修饰符中完成
    }

    // ************************************** ADMIN FUNCTION **************************************

    /**
     * @notice 设置MetaNode代币地址，只有管理员可以调用
     * @dev 用于更新奖励代币的合约地址
     * @param _MetaNode MetaNode代币合约接口
     */
    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;                    // 更新MetaNode代币合约地址

        emit SetMetaNode(MetaNode);              // 触发设置MetaNode代币事件
    }

    /**
     * @notice 暂停提取功能，只有管理员可以调用
     * @dev 紧急情况下可以暂停用户提取质押代币的功能
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");  // 检查提取功能是否已经被暂停

        withdrawPaused = true;                   // 设置提取暂停标志为true

        emit PauseWithdraw();                    // 触发暂停提取事件
    }

    /**
     * @notice 恢复提取功能，只有管理员可以调用
     * @dev 解除提取功能的暂停状态，允许用户正常提取质押代币
     */
    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");  // 检查提取功能是否处于暂停状态

        withdrawPaused = false;                  // 设置提取暂停标志为false

        emit UnpauseWithdraw();                  // 触发恢复提取事件
    }

    /**
     * @notice 暂停领取功能，只有管理员可以调用
     * @dev 紧急情况下可以暂停用户领取奖励的功能
     */
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");  // 检查领取功能是否已经被暂停

        claimPaused = true;                      // 设置领取暂停标志为true

        emit PauseClaim();                       // 触发暂停领取事件
    }

    /**
     * @notice 恢复领取功能，只有管理员可以调用
     * @dev 解除领取功能的暂停状态，允许用户正常领取奖励
     */
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");  // 检查领取功能是否处于暂停状态

        claimPaused = false;                     // 设置领取暂停标志为false

        emit UnpauseClaim();                     // 触发恢复领取事件
    }

    /**
     * @notice 更新质押挖矿开始区块，只有管理员可以调用
     * @dev 设置质押挖矿开始的区块高度
     * @param _startBlock 新的开始区块号
     */
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block");  // 开始区块必须小于等于结束区块

        startBlock = _startBlock;                // 更新开始区块号

        emit SetStartBlock(_startBlock);         // 触发设置开始区块事件
    }

    /**
     * @notice 更新质押挖矿结束区块，只有管理员可以调用
     * @dev 设置质押挖矿结束的区块高度
     * @param _endBlock 新的结束区块号
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block");  // 开始区块必须小于等于结束区块

        endBlock = _endBlock;                    // 更新结束区块号

        emit SetEndBlock(_endBlock);             // 触发设置结束区块事件
    }

    /**
     * @notice 更新每区块MetaNode奖励数量，只有管理员可以调用
     * @dev 调整每个区块产出的MetaNode代币数量
     * @param _MetaNodePerBlock 新的每区块奖励数量
     */
    function setMetaNodePerBlock(uint256 _MetaNodePerBlock) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid parameter");  // 每区块奖励必须大于0

        MetaNodePerBlock = _MetaNodePerBlock;    // 更新每区块奖励数量

        emit SetMetaNodePerBlock(_MetaNodePerBlock);  // 触发设置每区块奖励事件
    }

    /**
     * @notice 添加新的质押资金池，只有管理员可以调用
     * @dev 创建一个新的资金池供用户质押代币获得奖励
     * 警告：不要重复添加相同的质押代币，否则会导致奖励计算错误
     * @param _stTokenAddress 质押代币地址（address(0)表示ETH）
     * @param _poolWeight 资金池权重（决定奖励分配比例）
     * @param _minDepositAmount 最小质押数量
     * @param _unstakeLockedBlocks 提取锁定区块数
     * @param _withUpdate 是否同时更新所有资金池
     */
    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks,  bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        // 第一个池默认为ETH池，所以第一个池必须使用stTokenAddress = address(0x0)
        if (pool.length > 0) {
            require(_stTokenAddress != address(0x0), "invalid staking token address");  // 非第一个池不能是ETH池
        } else {
            require(_stTokenAddress == address(0x0), "invalid staking token address");   // 第一个池必须是ETH池
        }
        // 允许最小质押数量为0
        //require(_minDepositAmount > 0, "invalid min deposit amount");
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");  // 锁定区块数必须大于0
        require(block.number < endBlock, "Already ended");                    // 挖矿必须未结束

        if (_withUpdate) {
            massUpdatePools();                   // 如果需要，更新所有资金池的奖励状态
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;  // 确定上次奖励区块
        totalPoolWeight = totalPoolWeight + _poolWeight;  // 更新总权重

        pool.push(Pool({                         // 添加新的资金池到数组
            stTokenAddress: _stTokenAddress,     // 质押代币地址
            poolWeight: _poolWeight,             // 池权重
            lastRewardBlock: lastRewardBlock,    // 上次奖励区块
            accMetaNodePerST: 0,                 // 累积每质押代币奖励（初始为0）
            stTokenAmount: 0,                    // 质押代币总量（初始为0）
            minDepositAmount: _minDepositAmount, // 最小质押数量
            unstakeLockedBlocks: _unstakeLockedBlocks  // 提取锁定区块数
        }));

        emit AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, _unstakeLockedBlocks);  // 触发添加资金池事件
    }

    /**
     * @notice 更新指定资金池的信息（最小质押数量和锁定区块数），只有管理员可以调用
     * @dev 允许管理员调整资金池的参数设置
     * @param _pid 资金池ID
     * @param _minDepositAmount 新的最小质押数量
     * @param _unstakeLockedBlocks 新的提取锁定区块数
     */
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pool[_pid].minDepositAmount = _minDepositAmount;        // 更新最小质押数量
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;  // 更新提取锁定区块数

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);  // 触发更新资金池信息事件
    }

    /**
     * @notice 更新指定资金池的权重，只有管理员可以调用
     * @dev 调整资金池在奖励分配中的权重比例
     * @param _pid 资金池ID
     * @param _poolWeight 新的资金池权重
     * @param _withUpdate 是否同时更新所有资金池
     */
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");  // 权重必须大于0
        
        if (_withUpdate) {
            massUpdatePools();                   // 如果需要，先更新所有资金池
        }

        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;  // 更新总权重
        pool[_pid].poolWeight = _poolWeight;     // 更新指定池的权重

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);  // 触发设置资金池权重事件
    }

    // ************************************** QUERY FUNCTION **************************************

    /**
     * @notice 获取资金池数量
     * @dev 返回当前已创建的资金池总数
     * @return 资金池数量
     */
    function poolLength() external view returns(uint256) {
        return pool.length;                      // 返回资金池数组长度
    }

    /**
     * @notice 计算指定区块范围内的奖励倍数 [_from, _to)
     * @dev 用于计算在指定区块范围内应该产生的总奖励
     * @param _from 起始区块号（包含）
     * @param _to 结束区块号（不包含）
     * @return multiplier 奖励倍数（区块数 × 每区块奖励）
     */
    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256 multiplier) {
        require(_from <= _to, "invalid block");  // 起始区块必须小于等于结束区块
        if (_from < startBlock) {_from = startBlock;}  // 如果起始区块小于挖矿开始区块，则使用挖矿开始区块
        if (_to > endBlock) {_to = endBlock;}          // 如果结束区块大于挖矿结束区块，则使用挖矿结束区块
        require(_from <= _to, "end block must be greater than start block");  // 再次检查区块范围有效性
        bool success;                            // 溢出检查标志
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);  // 安全计算：区块数 × 每区块奖励
        require(success, "multiplier overflow"); // 确保计算没有溢出
    }

    /**
     * @notice 获取用户在指定资金池中的待领取MetaNode数量
     * @dev 查询用户当前可以领取的奖励数量
     * @param _pid 资金池ID
     * @param _user 用户地址
     * @return 待领取的MetaNode数量
     */
    function pendingMetaNode(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);  // 调用按区块号查询函数，使用当前区块号
    }

    /**
     * @notice 根据指定区块号获取用户在资金池中的待领取MetaNode数量
     * @dev 允许查询用户在特定区块高度时的奖励数量
     * @param _pid 资金池ID
     * @param _user 用户地址
     * @param _blockNumber 指定的区块号
     * @return 在指定区块号时用户的待领取MetaNode数量
     */
    function pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns(uint256) {
        Pool storage pool_ = pool[_pid];         // 获取资金池信息
        User storage user_ = user[_pid][_user];  // 获取用户信息
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;  // 获取当前累积每质押代币奖励
        uint256 stSupply = pool_.stTokenAmount;  // 获取资金池中质押代币总量

        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {  // 如果指定区块大于上次奖励区块且有质押
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);  // 计算奖励倍数
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;  // 计算该池应得奖励
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;  // 更新累积每质押代币奖励
        }

        return user_.stAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;  // 计算用户待领取奖励
    }

    /**
     * @notice 获取用户的质押数量
     * @dev 查询用户在指定资金池中质押的代币数量
     * @param _pid 资金池ID
     * @param _user 用户地址
     * @return 用户质押的代币数量
     */
    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].stAmount;       // 返回用户质押数量
    }

    /**
     * @notice 获取用户的提取数量信息，包括锁定的和可提取的数量
     * @dev 查询用户申请提取的代币状态信息
     * @param _pid 资金池ID
     * @param _user 用户地址
     * @return requestAmount 总申请提取数量
     * @return pendingWithdrawAmount 可立即提取数量（已解锁）
     */
    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];  // 获取用户信息

        for (uint256 i = 0; i < user_.requests.length; i++) {  // 遍历用户的所有提取请求
            if (user_.requests[i].unlockBlocks <= block.number) {  // 如果解锁区块已到达
                pendingWithdrawAmount = pendingWithdrawAmount + user_.requests[i].amount;  // 累加可提取数量
            }
            requestAmount = requestAmount + user_.requests[i].amount;  // 累加总申请数量
        }
    }

    // ************************************** PUBLIC FUNCTION **************************************

    /**
     * @notice 更新指定资金池的奖励变量至最新状态
     * @dev 计算并更新资金池的累积奖励，确保奖励分配的准确性
     * @param _pid 资金池ID
     */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];         // 获取资金池存储引用

        if (block.number <= pool_.lastRewardBlock) {  // 如果当前区块小于等于上次奖励区块
            return;                              // 无需更新，直接返回
        }

        // 计算该池从上次更新到现在应得的总奖励
        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");           // 确保计算没有溢出

        // 根据池权重占比计算该池实际应得奖励
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");           // 确保除法计算没有溢出

        uint256 stSupply = pool_.stTokenAmount;  // 获取资金池中质押代币总量
        if (stSupply > 0) {                      // 如果池中有质押代币
            // 计算每个质押代币应得的奖励（乘以1e18保持精度）
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");       // 确保乘法计算没有溢出

            // 计算每质押代币的奖励增量
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");       // 确保除法计算没有溢出

            // 更新累积每质押代币奖励
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");       // 确保加法计算没有溢出
            pool_.accMetaNodePerST = accMetaNodePerST;  // 保存更新后的累积奖励
        }

        pool_.lastRewardBlock = block.number;    // 更新上次奖励区块为当前区块

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);  // 触发更新资金池事件
    }

    /**
     * @notice 更新所有资金池的奖励变量，注意gas消耗！
     * @dev 批量更新所有资金池的奖励状态，gas消耗较高，谨慎使用
     */
    function massUpdatePools() public {
        uint256 length = pool.length;            // 获取资金池数量
        for (uint256 pid = 0; pid < length; pid++) {  // 遍历所有资金池
            updatePool(pid);                     // 更新每个资金池
        }
    }

    /**
     * @notice 质押ETH获得MetaNode奖励
     * @dev 用户向ETH资金池质押ETH代币
     */
    function depositETH() public whenNotPaused() payable {
        Pool storage pool_ = pool[ETH_PID];      // 获取ETH资金池（ID为0）
        require(pool_.stTokenAddress == address(0x0), "invalid staking token address");  // 确认是ETH池

        uint256 _amount = msg.value;             // 获取发送的ETH数量
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");  // 检查是否满足最小质押数量

        _deposit(ETH_PID, _amount);              // 调用内部质押函数
    }

    /**
     * @notice 质押ERC20代币获得MetaNode奖励
     * @dev 用户向指定资金池质押ERC20代币
     * 注意：质押前用户需要先授权本合约可以转移其代币
     * @param _pid 要质押到的资金池ID
     * @param _amount 要质押的代币数量
     */
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");  // 此函数不支持ETH质押（ETH使用depositETH函数）
        Pool storage pool_ = pool[_pid];         // 获取指定资金池
        require(_amount > pool_.minDepositAmount, "deposit amount is too small");  // 检查质押数量是否满足最小要求

        if(_amount > 0) {                        // 如果质押数量大于0
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);  // 安全转移代币到合约
        }

        _deposit(_pid, _amount);                 // 调用内部质押函数
    }

    /**
     * @notice 申请提取质押代币
     * @dev 用户申请提取质押的代币，需要等待锁定期后才能实际提取
     * @param _pid 要提取的资金池ID
     * @param _amount 要提取的代币数量
     */
    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];         // 获取资金池信息
        User storage user_ = user[_pid][msg.sender];  // 获取用户信息

        require(user_.stAmount >= _amount, "Not enough staking token balance");  // 检查用户质押余额是否足够

        updatePool(_pid);                        // 更新资金池奖励状态

        // 计算用户当前待领取的奖励
        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode;

        if(pendingMetaNode_ > 0) {               // 如果有待领取奖励
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;  // 累加到待领取奖励中
        }

        if(_amount > 0) {                        // 如果提取数量大于0
            user_.stAmount = user_.stAmount - _amount;  // 减少用户质押数量
            user_.requests.push(UnstakeRequest({  // 添加提取请求
                amount: _amount,                 // 提取数量
                unlockBlocks: block.number + pool_.unstakeLockedBlocks  // 解锁区块号
            }));
        }

        pool_.stTokenAmount = pool_.stTokenAmount - _amount;  // 减少资金池质押总量
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);  // 更新用户已结算奖励

        emit RequestUnstake(msg.sender, _pid, _amount);  // 触发申请提取事件
    }

    /**
     * @notice 提取已解锁的质押代币
     * @dev 用户提取已过锁定期的质押代币
     * @param _pid 要提取的资金池ID
     */
    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];         // 获取资金池信息
        User storage user_ = user[_pid][msg.sender];  // 获取用户信息

        uint256 pendingWithdraw_;                // 可提取数量
        uint256 popNum_;                         // 需要移除的请求数量
        
        // 遍历用户的提取请求，找出已解锁的
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks > block.number) {  // 如果还未解锁
                break;                           // 跳出循环（因为请求是按时间顺序的）
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;  // 累加可提取数量
            popNum_++;                           // 增加需要移除的请求计数
        }

        // 移除已处理的请求：将后面的请求前移
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }

        // 删除数组末尾的空元素
        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }

        if (pendingWithdraw_ > 0) {              // 如果有可提取的代币
            if (pool_.stTokenAddress == address(0x0)) {  // 如果是ETH池
                _safeETHTransfer(msg.sender, pendingWithdraw_);  // 安全转移ETH
            } else {                             // 如果是ERC20代币池
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);  // 安全转移ERC20代币
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);  // 触发提取事件
    }

    /**
     * @notice 领取MetaNode代币奖励
     * @dev 用户领取在指定资金池中累积的奖励
     * @param _pid 要领取奖励的资金池ID
     */
    function claim(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotClaimPaused() {
        Pool storage pool_ = pool[_pid];         // 获取资金池信息
        User storage user_ = user[_pid][msg.sender];  // 获取用户信息

        updatePool(_pid);                        // 更新资金池奖励状态

        // 计算用户总的待领取奖励（当前奖励 + 之前累积的待领取奖励）
        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;

        if(pendingMetaNode_ > 0) {               // 如果有待领取奖励
            user_.pendingMetaNode = 0;           // 清零待领取奖励
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);  // 安全转移奖励代币给用户
        }

        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);  // 更新用户已结算奖励

        emit Claim(msg.sender, _pid, pendingMetaNode_);  // 触发领取奖励事件
    }

    // ************************************** INTERNAL FUNCTION **************************************

    /**
     * @notice 内部质押函数，处理质押逻辑
     * @dev 执行实际的质押操作，包括奖励计算和状态更新
     * @param _pid 资金池ID
     * @param _amount 质押数量
     */
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];         // 获取资金池存储引用
        User storage user_ = user[_pid][msg.sender];  // 获取用户存储引用

        updatePool(_pid);                        // 更新资金池奖励状态

        if (user_.stAmount > 0) {                // 如果用户已有质押
            // 计算用户当前应得奖励：质押数量 × 累积每质押代币奖励
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
            require(success1, "user stAmount mul accMetaNodePerST overflow");  // 防止乘法溢出
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");  // 防止除法溢出
            
            // 计算新增的待领取奖励
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");  // 防止减法溢出

            if(pendingMetaNode_ > 0) {           // 如果有新增奖励
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");  // 防止加法溢出
                user_.pendingMetaNode = _pendingMetaNode;  // 累加到用户待领取奖励
            }
        }

        if(_amount > 0) {                        // 如果质押数量大于0
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");  // 防止加法溢出
            user_.stAmount = stAmount;           // 更新用户质押数量
        }

        // 更新资金池总质押数量
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");  // 防止加法溢出
        pool_.stTokenAmount = stTokenAmount;

        // 更新用户已结算奖励：新质押数量 × 累积每质押代币奖励
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
        require(success6, "user stAmount mul accMetaNodePerST overflow");  // 防止乘法溢出

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");  // 防止除法溢出

        user_.finishedMetaNode = finishedMetaNode;  // 保存已结算奖励

        emit Deposit(msg.sender, _pid, _amount); // 触发质押事件
    }

    /**
     * @notice 安全的MetaNode代币转账函数
     * @dev 防止因舍入误差导致合约MetaNode余额不足的情况
     * @param _to 接收MetaNode代币的地址
     * @param _amount 要转账的MetaNode数量
     */
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));  // 获取合约当前MetaNode余额

        if (_amount > MetaNodeBal) {             // 如果要转账的数量大于合约余额
            MetaNode.transfer(_to, MetaNodeBal); // 转账全部余额
        } else {                                 // 如果余额足够
            MetaNode.transfer(_to, _amount);     // 转账指定数量
        }
    }

    /**
     * @notice 安全的ETH转账函数
     * @dev 使用call方法安全转账ETH，避免gas限制问题
     * @param _to 接收ETH的地址
     * @param _amount 要转账的ETH数量
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{  // 使用call方法转账ETH
            value: _amount                       // 转账金额
        }("");

        require(success, "ETH transfer call failed");  // 确保call调用成功
        if (data.length > 0) {                   // 如果有返回数据
            require(
                abi.decode(data, (bool)),        // 解码返回数据为bool
                "ETH transfer operation did not succeed"  // 确保操作成功
            );
        }
    }
}