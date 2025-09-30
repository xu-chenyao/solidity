// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/SqrtPriceMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SwapMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IFactory.sol";

/**
 * @title Pool - MetaNodeSwap 流动性池合约
 * @notice 实现 Uniswap V3 风格的集中流动性 AMM 池子
 * @dev 每个池子对应一个特定的代币对和价格区间，支持流动性提供和代币交换
 * 
 * 核心功能：
 * 1. 流动性管理：mint（添加）、burn（移除）、collect（收取手续费）
 * 2. 代币交换：swap 函数实现代币兑换
 * 3. 价格管理：基于 tick 和 sqrtPriceX96 的价格体系
 * 4. 手续费分配：自动计算和分配交易手续费给流动性提供者
 * 
 * 关键概念：
 * - tick: 价格的对数表示，每个 tick 对应特定的价格
 * - sqrtPriceX96: 价格的平方根，使用 Q64.96 定点数表示
 * - liquidity: 流动性数量，表示在当前价格区间内的虚拟流动性
 */
contract Pool is IPool {
    using SafeCast for uint256;
    using LowGasSafeMath for int256;
    using LowGasSafeMath for uint256;

    // ==================== 不可变状态变量 ====================
    // 这些变量在合约创建时设置，之后不可更改
    
    /// @inheritdoc IPool
    /// @notice 创建此池子的工厂合约地址
    address public immutable override factory;
    
    /// @inheritdoc IPool
    /// @notice 池子中的第一个代币地址（地址较小的代币）
    address public immutable override token0;
    
    /// @inheritdoc IPool
    /// @notice 池子中的第二个代币地址（地址较大的代币）
    address public immutable override token1;
    
    /// @inheritdoc IPool
    /// @notice 交易手续费率（以万分之一为单位，如3000表示0.3%）
    uint24 public immutable override fee;
    
    /// @inheritdoc IPool
    /// @notice 价格区间下限（tick值）
    int24 public immutable override tickLower;
    
    /// @inheritdoc IPool
    /// @notice 价格区间上限（tick值）
    int24 public immutable override tickUpper;

    // ==================== 可变状态变量 ====================
    // 这些变量会随着池子的使用而动态变化
    
    /// @inheritdoc IPool
    /// @notice 当前价格的平方根，使用Q64.96定点数表示
    uint160 public override sqrtPriceX96;
    
    /// @inheritdoc IPool
    /// @notice 当前价格对应的tick值
    int24 public override tick;
    
    /// @inheritdoc IPool
    /// @notice 当前活跃的流动性总量
    uint128 public override liquidity;

    /// @inheritdoc IPool
    /// @notice 全局累积的token0手续费增长率（Q128.128格式）
    /// @dev 记录从池子创建到现在，每单位流动性累积获得的token0手续费
    uint256 public override feeGrowthGlobal0X128;
    
    /// @inheritdoc IPool
    /// @notice 全局累积的token1手续费增长率（Q128.128格式）  
    /// @dev 记录从池子创建到现在，每单位流动性累积获得的token1手续费
    uint256 public override feeGrowthGlobal1X128;

    /**
     * @notice 流动性提供者的头寸信息结构体
     * @dev 记录每个流动性提供者在此池子中的详细信息
     */
    struct Position {
        /// @notice 该头寸拥有的流动性数量
        uint128 liquidity;
        
        /// @notice 可提取的token0数量（包括移除流动性和手续费收益）
        uint128 tokensOwed0;
        
        /// @notice 可提取的token1数量（包括移除流动性和手续费收益）
        uint128 tokensOwed1;
        
        /// @notice 上次更新时的token0手续费增长率快照
        /// @dev 用于计算从上次更新到现在累积的手续费
        uint256 feeGrowthInside0LastX128;
        
        /// @notice 上次更新时的token1手续费增长率快照
        /// @dev 用于计算从上次更新到现在累积的手续费
        uint256 feeGrowthInside1LastX128;
    }

    /// @notice 存储所有流动性提供者的头寸信息
    /// @dev 映射：提供者地址 => 头寸信息
    mapping(address => Position) public positions;

    /**
     * @notice 获取指定地址的流动性头寸信息
     * @dev 返回流动性提供者在此池子中的完整头寸数据
     * @param owner 流动性提供者的地址
     * @return _liquidity 该地址拥有的流动性数量
     * @return feeGrowthInside0LastX128 上次更新时的token0手续费增长率
     * @return feeGrowthInside1LastX128 上次更新时的token1手续费增长率  
     * @return tokensOwed0 可提取的token0数量
     * @return tokensOwed1 可提取的token1数量
     */
    function getPosition(
        address owner
    )
        external
        view
        override
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        return (
            positions[owner].liquidity,
            positions[owner].feeGrowthInside0LastX128,
            positions[owner].feeGrowthInside1LastX128,
            positions[owner].tokensOwed0,
            positions[owner].tokensOwed1
        );
    }

    /**
     * @notice Pool合约构造函数
     * @dev 通过Factory合约的parameters获取池子参数，使用CREATE2确保地址确定性
     * 
     * 设计说明：
     * - Factory使用CREATE2创建Pool，需要确定的bytecode
     * - 参数不能通过构造函数传入，否则会改变bytecode影响地址计算
     * - 通过读取Factory的临时parameters获取创建参数
     * - CREATE2地址计算：new_address = hash(0xFF, sender, salt, bytecode)
     */
    constructor() {
        // 从Factory合约读取临时存储的池子创建参数
        // msg.sender是Factory合约地址
        (factory, token0, token1, tickLower, tickUpper, fee) = IFactory(
            msg.sender
        ).parameters();
    }

    /**
     * @notice 初始化池子的起始价格
     * @dev 只能调用一次，设置池子的初始价格和对应的tick
     * @param sqrtPriceX96_ 初始价格的平方根（Q64.96格式）
     * 
     * 要求：
     * - 池子必须未初始化（sqrtPriceX96 == 0）
     * - 初始价格必须在池子的价格区间内
     * - 对应的tick必须在[tickLower, tickUpper)范围内
     */
    function initialize(uint160 sqrtPriceX96_) external override {
        // 检查池子是否已经初始化
        require(sqrtPriceX96 == 0, "INITIALIZED");
        
        // 通过价格计算对应的tick值
        tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96_);
        
        // 验证tick是否在池子的价格区间内
        require(
            tick >= tickLower && tick < tickUpper,
            "sqrtPriceX96 should be within the range of [tickLower, tickUpper)"
        );
        
        // 设置池子的初始价格
        sqrtPriceX96 = sqrtPriceX96_;
    }

    /**
     * @notice 修改头寸参数结构体
     * @dev 用于_modifyPosition函数的参数传递
     */
    struct ModifyPositionParams {
        /// @notice 头寸拥有者地址
        address owner;
        /// @notice 流动性变化量（正数表示增加，负数表示减少）
        int128 liquidityDelta;
    }

    /**
     * @notice 修改流动性头寸的内部函数
     * @dev 处理流动性的增加或减少，同时计算手续费和代币数量变化
     * @param params 修改参数，包含拥有者地址和流动性变化量
     * @return amount0 需要的token0数量变化（正数表示需要转入，负数表示可以转出）
     * @return amount1 需要的token1数量变化（正数表示需要转入，负数表示可以转出）
     * 
     * 核心逻辑：
     * 1. 根据流动性变化计算所需的代币数量
     * 2. 计算并更新累积的手续费
     * 3. 更新全局和个人的流动性数据
     */
    function _modifyPosition(
        ModifyPositionParams memory params
    ) private returns (int256 amount0, int256 amount1) {
        // 根据流动性变化计算token0数量变化
        // 使用当前价格到上限价格的区间计算
        amount0 = SqrtPriceMath.getAmount0Delta(
            sqrtPriceX96,                                    // 当前价格
            TickMath.getSqrtPriceAtTick(tickUpper),         // 上限价格
            params.liquidityDelta                           // 流动性变化量
        );

        // 根据流动性变化计算token1数量变化  
        // 使用下限价格到当前价格的区间计算
        amount1 = SqrtPriceMath.getAmount1Delta(
            TickMath.getSqrtPriceAtTick(tickLower),         // 下限价格
            sqrtPriceX96,                                   // 当前价格
            params.liquidityDelta                           // 流动性变化量
        );
        
        // 获取用户的头寸信息
        Position storage position = positions[params.owner];

        // 计算从上次更新到现在累积的token0手续费
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal0X128 - position.feeGrowthInside0LastX128,  // 手续费增长差值
                position.liquidity,                                        // 用户流动性
                FixedPoint128.Q128                                         // 精度调整
            )
        );
        
        // 计算从上次更新到现在累积的token1手续费
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal1X128 - position.feeGrowthInside1LastX128,  // 手续费增长差值
                position.liquidity,                                        // 用户流动性
                FixedPoint128.Q128                                         // 精度调整
            )
        );

        // 更新用户的手续费快照到最新状态
        // 表示已经计算了到当前时刻的所有手续费
        position.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
        position.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;
        
        // 将计算出的手续费添加到用户的可提取余额中
        // 用户可以通过collect函数提取这些手续费
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            position.tokensOwed0 += tokensOwed0;
            position.tokensOwed1 += tokensOwed1;
        }

        // 更新全局流动性总量
        liquidity = LiquidityMath.addDelta(liquidity, params.liquidityDelta);
        
        // 更新用户的流动性数量
        position.liquidity = LiquidityMath.addDelta(
            position.liquidity,
            params.liquidityDelta
        );
    }

    /**
     * @notice 获取池子当前的token0余额
     * @dev 使用staticcall进行gas优化，避免额外的extcodesize检查
     * @return 池子合约持有的token0数量
     */
    function balance0() private view returns (uint256) {
        // 使用staticcall调用token0的balanceOf函数
        (bool success, bytes memory data) = token0.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        // 检查调用是否成功且返回数据长度正确
        require(success && data.length >= 32);
        // 解码返回的余额数据
        return abi.decode(data, (uint256));
    }

    /**
     * @notice 获取池子当前的token1余额  
     * @dev 使用staticcall进行gas优化，避免额外的extcodesize检查
     * @return 池子合约持有的token1数量
     */
    function balance1() private view returns (uint256) {
        // 使用staticcall调用token1的balanceOf函数
        (bool success, bytes memory data) = token1.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        // 检查调用是否成功且返回数据长度正确
        require(success && data.length >= 32);
        // 解码返回的余额数据
        return abi.decode(data, (uint256));
    }

    /**
     * @notice 向池子添加流动性（铸造流动性代币）
     * @dev 通过回调机制要求调用者转入相应的代币数量
     * @param recipient 流动性接收者地址
     * @param amount 要添加的流动性数量
     * @param data 传递给回调函数的额外数据
     * @return amount0 需要转入的token0数量
     * @return amount1 需要转入的token1数量
     * 
     * 流程说明：
     * 1. 计算添加指定流动性所需的代币数量
     * 2. 记录转账前的余额
     * 3. 调用mintCallback要求调用者转入代币
     * 4. 验证转账是否成功
     * 5. 触发Mint事件
     */
    function mint(
        address recipient,
        uint128 amount,
        bytes calldata data
    ) external override returns (uint256 amount0, uint256 amount1) {
        // 检查流动性数量必须大于0
        require(amount > 0, "Mint amount must be greater than 0");
        
        // 调用内部函数计算添加流动性所需的代币数量
        (int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,                    // 流动性接收者
                liquidityDelta: int128(amount)       // 正数表示增加流动性
            })
        );
        
        // 转换为无符号整数（mint时amount0和amount1应该都是正数）
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        // 记录转账前的代币余额，用于后续验证
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        
        // 调用回调函数，要求调用者转入相应的代币
        // 调用者必须实现IMintCallback接口
        IMintCallback(msg.sender).mintCallback(amount0, amount1, data);

        // 验证token0转账是否成功
        if (amount0 > 0)
            require(balance0Before.add(amount0) <= balance0(), "M0");
        // 验证token1转账是否成功    
        if (amount1 > 0)
            require(balance1Before.add(amount1) <= balance1(), "M1");

        // 触发铸造事件
        emit Mint(msg.sender, recipient, amount, amount0, amount1);
    }

    /**
     * @notice 收取累积的代币（手续费收益和移除的流动性）
     * @dev 从用户的头寸中提取可提取的代币到指定地址
     * @param recipient 代币接收者地址
     * @param amount0Requested 请求提取的token0数量
     * @param amount1Requested 请求提取的token1数量
     * @return amount0 实际提取的token0数量
     * @return amount1 实际提取的token1数量
     * 
     * 功能说明：
     * 1. 检查用户的可提取余额
     * 2. 计算实际可提取数量（不超过余额）
     * 3. 更新用户余额
     * 4. 转账代币给接收者
     * 5. 触发Collect事件
     */
    function collect(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override returns (uint128 amount0, uint128 amount1) {
        // 获取调用者的头寸信息
        Position storage position = positions[msg.sender];

        // 计算实际可提取的token0数量（取请求数量和可用余额的较小值）
        amount0 = amount0Requested > position.tokensOwed0
            ? position.tokensOwed0
            : amount0Requested;
            
        // 计算实际可提取的token1数量（取请求数量和可用余额的较小值）
        amount1 = amount1Requested > position.tokensOwed1
            ? position.tokensOwed1
            : amount1Requested;

        // 如果有token0需要提取
        if (amount0 > 0) {
            // 减少用户的可提取余额
            position.tokensOwed0 -= amount0;
            // 安全转账token0给接收者
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        
        // 如果有token1需要提取
        if (amount1 > 0) {
            // 减少用户的可提取余额
            position.tokensOwed1 -= amount1;
            // 安全转账token1给接收者
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        // 触发收取事件
        emit Collect(msg.sender, recipient, amount0, amount1);
    }

    /**
     * @notice 销毁流动性（移除流动性）
     * @dev 减少用户的流动性头寸，计算可提取的代币数量
     * @param amount 要销毁的流动性数量
     * @return amount0 可提取的token0数量
     * @return amount1 可提取的token1数量
     * 
     * 功能说明：
     * 1. 验证销毁数量的有效性
     * 2. 调用_modifyPosition减少流动性
     * 3. 计算对应的代币数量
     * 4. 更新用户的可提取余额
     * 5. 触发Burn事件
     * 
     * 注意：销毁后的代币不会立即转出，需要调用collect函数提取
     */
    function burn(
        uint128 amount
    ) external override returns (uint256 amount0, uint256 amount1) {
        // 验证销毁数量必须大于0
        require(amount > 0, "Burn amount must be greater than 0");
        
        // 验证销毁数量不能超过用户拥有的流动性
        require(
            amount <= positions[msg.sender].liquidity,
            "Burn amount exceeds liquidity"
        );
        
        // 调用内部函数修改头寸，减少流动性
        (int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,                    // 头寸拥有者
                liquidityDelta: -int128(amount)       // 负数表示减少流动性
            })
        );
        
        // 转换为正数（burn时amount0Int和amount1Int应该都是负数）
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        // 如果有代币可以提取，更新用户的可提取余额
        if (amount0 > 0 || amount1 > 0) {
            (
                positions[msg.sender].tokensOwed0,
                positions[msg.sender].tokensOwed1
            ) = (
                positions[msg.sender].tokensOwed0 + uint128(amount0),  // 增加可提取的token0
                positions[msg.sender].tokensOwed1 + uint128(amount1)   // 增加可提取的token1
            );
        }

        // 触发销毁事件
        emit Burn(msg.sender, amount, amount0, amount1);
    }

    /**
     * @notice 交换过程中的状态变量结构体
     * @dev 用于在swap函数执行过程中临时存储计算状态
     */
    struct SwapState {
        /// @notice 剩余需要交换的指定代币数量
        /// @dev 在交换过程中逐步减少，直到为0或无法继续交换
        int256 amountSpecifiedRemaining;
        
        /// @notice 已计算出的输出代币数量
        /// @dev 累积计算的输出结果
        int256 amountCalculated;
        
        /// @notice 当前价格的平方根
        /// @dev 在交换过程中会动态更新
        uint160 sqrtPriceX96;
        
        /// @notice 输入代币的全局手续费增长率
        /// @dev 用于跟踪手续费的累积
        uint256 feeGrowthGlobalX128;
        
        /// @notice 该交换中实际转入的代币数量
        /// @dev 根据交换方向，可能是token0或token1
        uint256 amountIn;
        
        /// @notice 该交换中实际转出的代币数量
        /// @dev 根据交换方向，可能是token1或token0
        uint256 amountOut;
        
        /// @notice 该交换中产生的手续费数量
        /// @dev 手续费以输入代币计价
        uint256 feeAmount;
    }

    /**
     * @notice 执行代币交换
     * @dev 在池子中交换代币，支持精确输入和精确输出两种模式
     * @param recipient 代币接收者地址
     * @param zeroForOne 交换方向（true: token0->token1, false: token1->token0）
     * @param amountSpecified 指定的代币数量（正数=精确输入，负数=精确输出）
     * @param sqrtPriceLimitX96 价格限制，防止过度滑点
     * @param data 传递给回调函数的数据
     * @return amount0 token0的数量变化（正数=转入池子，负数=从池子转出）
     * @return amount1 token1的数量变化（正数=转入池子，负数=从池子转出）
     * 
     * 交换流程：
     * 1. 验证参数有效性
     * 2. 计算交换的具体数值
     * 3. 更新池子价格和手续费
     * 4. 通过回调要求转入代币
     * 5. 转出代币给接收者
     * 6. 触发Swap事件
     */
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        // 验证指定数量不能为0
        require(amountSpecified != 0, "AS");

        // 验证价格限制的合理性
        // zeroForOne=true: 价格应该下降，限制价格应小于当前价格且大于最小价格
        // zeroForOne=false: 价格应该上升，限制价格应大于当前价格且小于最大价格
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < sqrtPriceX96 &&
                    sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE
                : sqrtPriceLimitX96 > sqrtPriceX96 &&
                    sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE,
            "SPL"
        );

        // 确定交换模式：正数表示精确输入，负数表示精确输出
        bool exactInput = amountSpecified > 0;

        // 初始化交换状态
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,    // 剩余需要交换的数量
            amountCalculated: 0,                          // 已计算的输出数量
            sqrtPriceX96: sqrtPriceX96,                  // 当前价格
            feeGrowthGlobalX128: zeroForOne              // 对应方向的手续费增长率
                ? feeGrowthGlobal0X128
                : feeGrowthGlobal1X128,
            amountIn: 0,                                 // 实际输入数量
            amountOut: 0,                                // 实际输出数量
            feeAmount: 0                                 // 手续费数量
        });

        // 计算池子的价格边界
        uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(tickLower);  // 下限价格
        uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(tickUpper);  // 上限价格
        
        // 确定池子的价格限制
        // zeroForOne=true: 交换会压低价格，限制为下限价格
        // zeroForOne=false: 交换会抬高价格，限制为上限价格
        uint160 sqrtPriceX96PoolLimit = zeroForOne
            ? sqrtPriceX96Lower
            : sqrtPriceX96Upper;

        // 调用SwapMath库计算交换的具体数值
        (
            state.sqrtPriceX96,     // 交换后的新价格
            state.amountIn,         // 实际输入数量
            state.amountOut,        // 实际输出数量
            state.feeAmount         // 手续费数量
        ) = SwapMath.computeSwapStep(
            sqrtPriceX96,           // 当前价格
            (                       // 确定实际的价格限制
                zeroForOne
                    ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96
                    : sqrtPriceX96PoolLimit > sqrtPriceLimitX96
            )
                ? sqrtPriceLimitX96      // 使用用户指定的限制
                : sqrtPriceX96PoolLimit, // 使用池子的边界限制
            liquidity,              // 当前流动性
            amountSpecified,        // 指定的交换数量
            fee                     // 手续费率
        );

        // 更新池子的价格状态
        sqrtPriceX96 = state.sqrtPriceX96;                              // 更新价格
        tick = TickMath.getTickAtSqrtPrice(state.sqrtPriceX96);         // 更新对应的tick

        // 计算并累积手续费增长率
        // 手续费增长率 = 手续费数量 * Q128 / 流动性
        state.feeGrowthGlobalX128 += FullMath.mulDiv(
            state.feeAmount,        // 手续费数量
            FixedPoint128.Q128,     // 精度调整
            liquidity               // 当前流动性
        );

        // 更新全局手续费增长率
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;  // 更新token0手续费增长率
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;  // 更新token1手续费增长率
        }

        // 根据交换模式更新状态变量
        if (exactInput) {
            // 精确输入模式：减少剩余输入数量，累积输出数量
            state.amountSpecifiedRemaining -= (state.amountIn + state.feeAmount)
                .toInt256();
            state.amountCalculated = state.amountCalculated.sub(
                state.amountOut.toInt256()
            );
        } else {
            // 精确输出模式：增加已获得的输出数量，累积输入数量
            state.amountSpecifiedRemaining += state.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add(
                (state.amountIn + state.feeAmount).toInt256()
            );
        }

        // 根据交换方向和模式计算最终的amount0和amount1
        (amount0, amount1) = zeroForOne == exactInput
            ? (
                amountSpecified - state.amountSpecifiedRemaining,  // 输入的token0数量
                state.amountCalculated                             // 输出的token1数量（负数）
            )
            : (
                state.amountCalculated,                            // 输入的token0数量  
                amountSpecified - state.amountSpecifiedRemaining   // 输出的token1数量（负数）
            );

        // 根据交换方向处理代币转账
        if (zeroForOne) {
            // token0 -> token1 交换
            
            // 记录转账前的token0余额
            uint256 balance0Before = balance0();
            
            // 调用回调函数，要求调用者转入token0
            ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
            
            // 验证token0转账是否成功
            require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");

            // 如果有token1需要转出给用户
            if (amount1 < 0)
                TransferHelper.safeTransfer(
                    token1,                    // 转出token1
                    recipient,                 // 给接收者
                    uint256(-amount1)          // 转出数量（转为正数）
                );
        } else {
            // token1 -> token0 交换
            
            // 记录转账前的token1余额
            uint256 balance1Before = balance1();
            
            // 调用回调函数，要求调用者转入token1
            ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
            
            // 验证token1转账是否成功
            require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");

            // 如果有token0需要转出给用户
            if (amount0 < 0)
                TransferHelper.safeTransfer(
                    token0,                    // 转出token0
                    recipient,                 // 给接收者
                    uint256(-amount0)          // 转出数量（转为正数）
                );
        }

        // 触发交换事件，记录交换的详细信息
        emit Swap(
            msg.sender,         // 交换发起者
            recipient,          // 代币接收者
            amount0,            // token0数量变化
            amount1,            // token1数量变化
            sqrtPriceX96,       // 交换后的价格
            liquidity,          // 当前流动性
            tick                // 交换后的tick
        );
    }
}
