// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/LiquidityAmounts.sol";
import "./libraries/TickMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPositionManager.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

/**
 * @title PositionManager - MetaNodeSwap 头寸管理合约
 * @notice 使用ERC721 NFT来表示和管理流动性头寸
 * @dev 每个NFT代表一个独特的流动性头寸，包含特定池子中的流动性信息
 * 
 * 核心功能：
 * 1. NFT化流动性头寸：每个头寸对应一个唯一的NFT
 * 2. 流动性管理：mint（添加）、burn（移除）、collect（收取）
 * 3. 权限控制：基于NFT所有权的操作权限验证
 * 4. 头寸查询：提供头寸信息的批量查询功能
 * 5. 回调处理：实现mintCallback接口处理代币转账
 * 
 * NFT特性：
 * - 名称：MetaNodeSwapPosition
 * - 符号：MNSP
 * - 每个tokenId对应一个独特的流动性头寸
 */
contract PositionManager is IPositionManager, ERC721 {
    /// @notice PoolManager合约实例，用于池子操作
    IPoolManager public poolManager;

    /// @notice 下一个要铸造的NFT ID，从1开始（跳过0）
    uint176 private _nextId = 1;

    /**
     * @notice PositionManager构造函数
     * @param _poolManger PoolManager合约地址
     */
    constructor(address _poolManger) ERC721("MetaNodeSwapPosition", "MNSP") {
        poolManager = IPoolManager(_poolManger);
    }

    /// @notice 存储所有头寸信息的映射
    /// @dev 映射：NFT tokenId => 头寸详细信息
    mapping(uint256 => PositionInfo) public positions;

    /**
     * @notice 获取所有头寸信息
     * @dev 返回系统中所有已创建的流动性头寸详细信息
     * @return positionInfo 头寸信息数组，包含每个NFT对应的头寸详情
     */
    function getAllPositions()
        external
        view
        override
        returns (PositionInfo[] memory positionInfo)
    {
        // 创建结果数组，大小为已铸造的NFT数量
        positionInfo = new PositionInfo[](_nextId - 1);
        
        // 遍历所有已铸造的NFT，收集头寸信息
        for (uint32 i = 0; i < _nextId - 1; i++) {
            positionInfo[i] = positions[i + 1];  // NFT ID从1开始
        }
        return positionInfo;
    }

    /**
     * @notice 获取当前调用者地址
     * @dev 辅助函数，用于调试和测试
     * @return 当前消息发送者地址
     */
    function getSender() public view returns (address) {
        return msg.sender;
    }

    /**
     * @notice 获取当前区块时间戳
     * @dev 虚拟函数，可在测试中重写
     * @return 当前区块时间戳
     */
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * @notice 检查交易截止时间的修饰符
     * @dev 防止交易在过期后被执行
     * @param deadline 交易截止时间戳
     */
    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
        _;
    }

    /**
     * @notice 铸造NFT流动性头寸
     * @dev 创建一个新的流动性头寸并铸造对应的NFT
     * @param params 铸造参数结构体
     * @return positionId 新铸造的NFT ID
     * @return liquidity 实际添加的流动性数量
     * @return amount0 实际使用的token0数量
     * @return amount1 实际使用的token1数量
     * 
     * 铸造流程：
     * 1. 获取目标池子合约
     * 2. 根据期望的代币数量计算流动性
     * 3. 向池子添加流动性
     * 4. 铸造NFT给接收者
     * 5. 记录头寸信息
     */
    function mint(
        MintParams calldata params
    )
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (
            uint256 positionId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // 通过PoolManager获取目标池子地址
        address _pool = poolManager.getPool(
            params.token0,
            params.token1,
            params.index
        );
        IPool pool = IPool(_pool);

        // 获取池子的价格信息用于计算流动性
        uint160 sqrtPriceX96 = pool.sqrtPriceX96();           // 当前价格
        uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(pool.tickLower()); // 下限价格
        uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(pool.tickUpper()); // 上限价格

        // 根据期望的代币数量和价格区间计算实际需要的流动性
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,               // 当前价格
            sqrtRatioAX96,              // 价格区间下限
            sqrtRatioBX96,              // 价格区间上限
            params.amount0Desired,      // 期望的token0数量
            params.amount1Desired       // 期望的token1数量
        );

        // 构造传递给mintCallback的数据
        // 包含代币地址、池子索引和付款人信息
        bytes memory data = abi.encode(
            params.token0,
            params.token1,
            params.index,
            msg.sender                  // 实际付款人
        );

        // 向池子添加流动性，流动性归属于PositionManager合约
        (amount0, amount1) = pool.mint(address(this), liquidity, data);

        _mint(params.recipient, (positionId = _nextId++));

        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) = pool.getPosition(address(this));

        positions[positionId] = PositionInfo({
            id: positionId,
            owner: params.recipient,
            token0: params.token0,
            token1: params.token1,
            index: params.index,
            fee: pool.fee(),
            liquidity: liquidity,
            tickLower: pool.tickLower(),
            tickUpper: pool.tickUpper(),
            tokensOwed0: 0,
            tokensOwed1: 0,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128
        });
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        address owner = ERC721.ownerOf(tokenId);
        require(_isAuthorized(owner, msg.sender, tokenId), "Not approved");
        _;
    }

    function burn(
        uint256 positionId
    )
        external
        override
        isAuthorizedForToken(positionId)
        returns (uint256 amount0, uint256 amount1)
    {
        PositionInfo storage position = positions[positionId];
        // 通过 isAuthorizedForToken 检查 positionId 是否有权限
        // 移除流动性，但是 token 还是保留在 pool 中，需要再调用 collect 方法才能取回 token
        // 通过 positionId 获取对应 LP 的流动性
        uint128 _liquidity = position.liquidity;
        // 调用 Pool 的方法给 LP 退流动性
        address _pool = poolManager.getPool(
            position.token0,
            position.token1,
            position.index
        );
        IPool pool = IPool(_pool);
        (amount0, amount1) = pool.burn(_liquidity);

        // 计算这部分流动性产生的手续费
        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) = pool.getPosition(address(this));

        position.tokensOwed0 +=
            uint128(amount0) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 -
                        position.feeGrowthInside0LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );

        position.tokensOwed1 +=
            uint128(amount1) +
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 -
                        position.feeGrowthInside1LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );

        // 更新 position 的信息
        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        position.liquidity = 0;
    }

    function collect(
        uint256 positionId,
        address recipient
    )
        external
        override
        isAuthorizedForToken(positionId)
        returns (uint256 amount0, uint256 amount1)
    {
        // 通过 isAuthorizedForToken 检查 positionId 是否有权限
        // 调用 Pool 的方法给 LP 退流动性
        PositionInfo storage position = positions[positionId];
        address _pool = poolManager.getPool(
            position.token0,
            position.token1,
            position.index
        );
        IPool pool = IPool(_pool);
        (amount0, amount1) = pool.collect(
            recipient,
            position.tokensOwed0,
            position.tokensOwed1
        );

        // position 已经彻底没用了，销毁
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        if (position.liquidity == 0) {
            _burn(positionId);
        }
    }

    function mintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 检查 callback 的合约地址是否是 Pool
        (address token0, address token1, uint32 index, address payer) = abi
            .decode(data, (address, address, uint32, address));
        address _pool = poolManager.getPool(token0, token1, index);
        require(_pool == msg.sender, "Invalid callback caller");

        // 在这里给 Pool 打钱，需要用户先 approve 足够的金额，这里才会成功
        if (amount0 > 0) {
            IERC20(token0).transferFrom(payer, msg.sender, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(payer, msg.sender, amount1);
        }
    }
}
