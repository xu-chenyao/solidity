// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title 税收处理器接口
 * @dev 定义了税收计算的标准接口，任何实现此接口的合约都可以用于协议特定的税收计算
 * @notice 此接口用于实现灵活的税收策略，支持不同的交易场景和税率规则
 */
interface ITaxHandler {
    
    /**
     * @notice 计算转账交易中需要缴纳的税收代币数量
     * @dev 此函数为纯查询函数，不会修改合约状态，可以被外部合约安全调用
     * 
     * @param benefactor 转账发送方地址（代币的转出者）
     * @param beneficiary 转账接收方地址（代币的接收者）
     * @param amount 转账的代币数量（转账总金额）
     * 
     * @return 需要作为税收扣除的代币数量
     * 
     * 功能说明：
     * - 根据发送方和接收方地址计算税率（可能有白名单机制）
     * - 支持基于交易金额的累进税率
     * - 可以实现买入税、卖出税、转账税等不同税收类型
     * - 返回值应该小于等于转账金额，否则交易会失败
     * 
     * 使用场景：
     * - DEX交易时的买入/卖出税
     * - 普通转账时的转账税
     * - 特殊地址（如流动性池）的差异化税率
     * - 基于持有时间的税收优惠
     */
    function getTax(
        address benefactor,    // 转账发送方
        address beneficiary,   // 转账接收方  
        uint256 amount        // 转账金额
    ) external returns (uint256);  // 返回税收金额
}