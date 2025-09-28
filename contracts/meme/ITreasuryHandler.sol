// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title 国库处理器接口
 * @dev 定义了国库相关操作的标准接口，任何实现此接口的合约都可以用于协议特定的国库管理操作
 * @notice 此接口用于实现复杂的国库管理逻辑，如自动复投、流动性管理、奖励分发等
 */
interface ITreasuryHandler {
    
    /**
     * @notice 在代币转账执行前执行的操作
     * @dev 此函数在代币实际转移前被调用，可以用于预处理逻辑
     * 
     * @param benefactor 转账发送方地址（代币转出者）
     * @param beneficiary 转账接收方地址（代币接收者）
     * @param amount 转账的代币数量
     * 
     * 功能说明：
     * - 可以用于记录转账前的状态快照
     * - 执行转账前的风险检查和合规验证
     * - 更新用户的交易历史和统计数据
     * - 触发自动化的国库管理策略
     * 
     * 使用场景：
     * - 反欺诈检测和交易监控
     * - 动态调整税率或手续费
     * - 更新用户等级或VIP状态
     * - 触发自动套利或再平衡机制
     */
    function beforeTransferHandler(
        address benefactor,    // 转账发送方
        address beneficiary,   // 转账接收方
        uint256 amount        // 转账金额
    ) external;

    /**
     * @notice 在代币转账执行后执行的操作  
     * @dev 此函数在代币实际转移后被调用，可以用于后处理逻辑
     * 
     * @param benefactor 转账发送方地址（代币转出者）
     * @param beneficiary 转账接收方地址（代币接收者）
     * @param amount 转账的代币数量
     * 
     * 功能说明：
     * - 处理税收收入的分配和使用
     * - 执行自动化的流动性管理
     * - 更新奖励池和分红机制
     * - 触发代币回购和销毁操作
     * 
     * 使用场景：
     * - 将税收收入添加到流动性池
     * - 自动执行代币回购和销毁
     * - 分发持币奖励给代币持有者
     * - 更新项目发展基金余额
     * - 触发营销钱包的资金分配
     */
    function afterTransferHandler(
        address benefactor,    // 转账发送方
        address beneficiary,   // 转账接收方
        uint256 amount        // 转账金额
    ) external;
}