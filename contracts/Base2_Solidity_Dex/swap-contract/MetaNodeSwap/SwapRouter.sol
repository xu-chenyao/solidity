// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ISwapRouter.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

/**
 * @title SwapRouter - MetaNodeSwap 交换路由合约
 * @notice 提供代币交换的高级接口，支持精确输入和精确输出两种交换模式
 * @dev 作为用户与流动性池交互的主要入口，处理多池路径交换和价格查询
 * 
 * 核心功能：
 * 1. exactInput: 指定输入代币数量，获得尽可能多的输出代币
 * 2. exactOutput: 指定输出代币数量，使用尽可能少的输入代币
 * 3. 价格查询: quoteExactInput 和 quoteExactOutput
 * 4. 多池路径支持: 通过indexPath支持跨多个池子的交换
 * 5. 滑点保护: 通过最小输出/最大输入限制保护用户
 */
contract SwapRouter is ISwapRouter {
    /// @notice PoolManager合约实例，用于获取池子信息
    IPoolManager public poolManager;

    /**
     * @notice SwapRouter构造函数
     * @param _poolManager PoolManager合约地址
     */
    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    /**
     * @notice 解析revert原因，用于价格查询时获取数值结果
     * @dev 在价格查询时，交易会故意revert并在revert数据中包含计算结果
     * @param reason revert的原因数据
     * @return amount0 token0的数量变化
     * @return amount1 token1的数量变化
     */
    function parseRevertReason(
        bytes memory reason
    ) private pure returns (int256, int256) {
        // 检查revert数据长度是否为64字节（两个int256）
        if (reason.length != 64) {
            // 如果不是预期的数值数据，则重新抛出原始错误
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        // 解码并返回两个int256数值
        return abi.decode(reason, (int256, int256));
    }

    /**
     * @notice 在指定池子中执行交换操作
     * @dev 包装池子的swap函数，处理可能的revert（用于价格查询）
     * @param pool 目标流动性池合约
     * @param recipient 代币接收者地址
     * @param zeroForOne 交换方向（true: token0->token1, false: token1->token0）
     * @param amountSpecified 指定的代币数量（正数表示精确输入，负数表示精确输出）
     * @param sqrtPriceLimitX96 价格限制（防止过度滑点）
     * @param data 传递给回调函数的数据
     * @return amount0 token0的数量变化
     * @return amount1 token1的数量变化
     */
    function swapInPool(
        IPool pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        try
            pool.swap(
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        returns (int256 _amount0, int256 _amount1) {
            // 正常交换成功，返回结果
            return (_amount0, _amount1);
        } catch (bytes memory reason) {
            // 交换失败（通常是价格查询），解析revert中的数值
            return parseRevertReason(reason);
        }
    }

    /**
     * @notice 精确输入交换：指定输入代币数量，获得尽可能多的输出代币
     * @dev 支持通过多个池子进行路径交换，提供滑点保护
     * @param params 交换参数结构体
     * @return amountOut 实际获得的输出代币数量
     * 
     * 交换流程：
     * 1. 确定交换方向（token0->token1 或 token1->token0）
     * 2. 遍历指定的池子路径进行交换
     * 3. 累计输出代币数量
     * 4. 验证滑点保护
     * 5. 触发交换事件
     */
    function exactInput(
        ExactInputParams calldata params
    ) external payable override returns (uint256 amountOut) {
        // 记录剩余需要交换的输入代币数量
        uint256 amountIn = params.amountIn;

        // 根据代币地址大小关系确定交换方向
        // tokenIn < tokenOut 表示从token0交换到token1
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 遍历所有指定的池子进行交换
        for (uint256 i = 0; i < params.indexPath.length; i++) {
            // 通过PoolManager获取指定索引的池子地址
            address poolAddress = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            // 验证池子是否存在
            require(poolAddress != address(0), "Pool not found");

            // 获取池子合约实例
            IPool pool = IPool(poolAddress);

            // 构造传递给swapCallback的数据
            // 包含代币地址、池子索引和付款人信息
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i],
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 在当前池子中执行交换
            (int256 amount0, int256 amount1) = this.swapInPool(
                pool,
                params.recipient,           // 代币接收者
                zeroForOne,                 // 交换方向
                int256(amountIn),          // 剩余输入数量（正数表示精确输入）
                params.sqrtPriceLimitX96,  // 价格限制
                data                       // 回调数据
            );

            // 更新剩余输入数量和累计输出数量
            // amount0和amount1中一个为正（输入），一个为负（输出）
            amountIn -= uint256(zeroForOne ? amount0 : amount1);      // 减少已使用的输入
            amountOut += uint256(zeroForOne ? -amount1 : -amount0);   // 增加获得的输出

            // 如果输入代币已全部交换完成，提前结束
            if (amountIn == 0) {
                break;
            }
        }

        // 滑点保护：验证实际输出是否达到最小要求
        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        // 触发交换事件
        emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);

        // 返回实际获得的输出代币数量
        return amountOut;
    }

    /**
     * @notice 精确输出交换：指定输出代币数量，使用尽可能少的输入代币
     * @dev 支持通过多个池子进行路径交换，提供滑点保护
     * @param params 交换参数结构体
     * @return amountIn 实际消耗的输入代币数量
     * 
     * 交换流程：
     * 1. 确定交换方向（token0->token1 或 token1->token0）
     * 2. 遍历指定的池子路径进行交换
     * 3. 累计输入代币数量
     * 4. 验证滑点保护
     * 5. 触发交换事件
     */
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override returns (uint256 amountIn) {
        // 记录剩余需要获得的输出代币数量
        uint256 amountOut = params.amountOut;

        // 根据代币地址大小关系确定交换方向
        // tokenIn < tokenOut 表示从token0交换到token1
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 遍历所有指定的池子进行交换
        for (uint256 i = 0; i < params.indexPath.length; i++) {
            // 通过PoolManager获取指定索引的池子地址
            address poolAddress = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            // 验证池子是否存在
            require(poolAddress != address(0), "Pool not found");

            // 获取池子合约实例
            IPool pool = IPool(poolAddress);

            // 构造传递给swapCallback的数据
            // 包含代币地址、池子索引和付款人信息
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i],
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 在当前池子中执行交换
            (int256 amount0, int256 amount1) = this.swapInPool(
                pool,
                params.recipient,           // 代币接收者
                zeroForOne,                 // 交换方向
                -int256(amountOut),         // 剩余输出数量（负数表示精确输出）
                params.sqrtPriceLimitX96,   // 价格限制
                data                        // 回调数据
            );

            // 更新剩余输出数量和累计输入数量
            // amount0和amount1中一个为正（输入），一个为负（输出）
            amountOut -= uint256(zeroForOne ? -amount1 : -amount0);   // 减少已获得的输出
            amountIn += uint256(zeroForOne ? amount0 : amount1);      // 增加消耗的输入

            // 如果输出代币已全部获得，提前结束
            if (amountOut == 0) {
                break;
            }
        }

        // 滑点保护：验证实际输入是否不超过最大限制
        require(amountIn <= params.amountInMaximum, "Slippage exceeded");

        // 触发交换事件
        emit Swap(
            msg.sender,
            zeroForOne,
            params.amountOut,
            amountOut,
            amountIn
        );

        // 返回实际消耗的输入代币数量
        return amountIn;
    }

    /**
     * @notice 精确输入价格查询：预估指定输入数量能获得多少输出代币
     * @dev 通过模拟交换获取价格信息，不会实际执行交换
     * @param params 查询参数结构体
     * @return amountOut 预估的输出代币数量
     * 
     * 工作原理：
     * 1. 调用exactInput函数但设置recipient为address(0)
     * 2. 在swapCallback中检测到payer为address(0)时会revert
     * 3. 在revert数据中包含计算结果
     * 4. parseRevertReason解析并返回结果
     */
    function quoteExactInput(
        QuoteExactInputParams calldata params
    ) external override returns (uint256 amountOut) {
        // 调用exactInput进行价格查询
        // recipient设为address(0)表示这是价格查询而非实际交换
        return
            this.exactInput(
                ExactInputParams({
                    tokenIn: params.tokenIn,
                    tokenOut: params.tokenOut,
                    indexPath: params.indexPath,
                    recipient: address(0),              // 标记为价格查询
                    deadline: block.timestamp + 1 hours, // 设置较长的截止时间
                    amountIn: params.amountIn,
                    amountOutMinimum: 0,                 // 价格查询无需滑点保护
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                })
            );
    }

    /**
     * @notice 精确输出价格查询：预估获得指定输出数量需要多少输入代币
     * @dev 通过模拟交换获取价格信息，不会实际执行交换
     * @param params 查询参数结构体
     * @return amountIn 预估的输入代币数量
     * 
     * 工作原理：
     * 1. 调用exactOutput函数但设置recipient为address(0)
     * 2. 在swapCallback中检测到payer为address(0)时会revert
     * 3. 在revert数据中包含计算结果
     * 4. parseRevertReason解析并返回结果
     */
    function quoteExactOutput(
        QuoteExactOutputParams calldata params
    ) external override returns (uint256 amountIn) {
        // 调用exactOutput进行价格查询
        // recipient设为address(0)表示这是价格查询而非实际交换
        return
            this.exactOutput(
                ExactOutputParams({
                    tokenIn: params.tokenIn,
                    tokenOut: params.tokenOut,
                    indexPath: params.indexPath,
                    recipient: address(0),               // 标记为价格查询
                    deadline: block.timestamp + 1 hours,  // 设置较长的截止时间
                    amountOut: params.amountOut,
                    amountInMaximum: type(uint256).max,   // 价格查询设为最大值
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                })
            );
    }

    /**
     * @notice 交换回调函数
     * @dev 池子调用此函数要求转入相应的代币，或在价格查询时返回计算结果
     * @param amount0Delta token0数量变化（正数表示需要转入池子）
     * @param amount1Delta token1数量变化（正数表示需要转入池子）
     * @param data 回调数据，包含代币地址、池子索引和付款人信息
     * 
     * 功能说明：
     * 1. 验证调用者是否为合法的池子合约
     * 2. 如果是价格查询（payer为address(0)），通过revert返回计算结果
     * 3. 如果是正常交换，执行代币转账
     */
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // 解码回调数据获取交换信息
        (address tokenIn, address tokenOut, uint32 index, address payer) = abi
            .decode(data, (address, address, uint32, address));
            
        // 获取对应的池子地址
        address _pool = poolManager.getPool(tokenIn, tokenOut, index);

        // 验证回调调用者是否为合法的池子合约
        require(_pool == msg.sender, "Invalid callback caller");

        // 计算需要支付的代币数量（amount0Delta和amount1Delta中只有一个为正数）
        uint256 amountToPay = amount0Delta > 0
            ? uint256(amount0Delta)
            : uint256(amount1Delta);
            
        // 价格查询模式：payer为address(0)表示这是价格查询请求
        // 通过assembly revert返回计算结果，供parseRevertReason解析
        if (payer == address(0)) {
            assembly {
                let ptr := mload(0x40)              // 获取空闲内存指针
                mstore(ptr, amount0Delta)           // 存储amount0Delta
                mstore(add(ptr, 0x20), amount1Delta) // 存储amount1Delta
                revert(ptr, 64)                     // revert并返回64字节数据
            }
        }

        // 正常交换模式：执行代币转账
        if (amountToPay > 0) {
            // 从付款人转账输入代币到池子
            IERC20(tokenIn).transferFrom(payer, _pool, amountToPay);
        }
    }
}
