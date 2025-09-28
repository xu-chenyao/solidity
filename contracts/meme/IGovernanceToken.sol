// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title 治理代币接口
 * @dev 定义了治理代币必须实现的基本功能，包括投票权委托和历史投票记录查询
 * @notice 此接口用于实现去中心化治理功能，允许代币持有者参与项目决策
 */
interface IGovernanceToken {
    
    /**
     * @notice 投票检查点结构体，用于记录特定区块的投票权数量
     * @dev 使用紧凑存储优化gas消耗，将区块号和投票数打包在一个存储槽中
     * SSTORE 的成本（大约数值，实际还受 refund 等影响）：
        把 0 → 非 0 写入：20,000 gas / 槽。
        把非 0 → 非 0 更新：5,000 gas / 槽。
        所以：
        方案 A（uint32+uint224）
        新写入：20,000 gas
        更新：5,000 gas
        方案 B（uint32+uint256）
        新写入：40,000 gas
        更新：10,000 gas
     */
    struct Checkpoint {
        // 区块号，使用32位整数可支持到以下预估日期：
        //  - BSC链: 2428年12月23日 18:23:11 UTC
        //  - ETH链: 3826年4月18日 09:27:12 UTC
        // 假设区块生成速度不会显著加快
        uint32 blockNumber;  // 记录投票权变更时的区块号
        
        // 投票权数量，使用224位整数进行存储优化
        // 与blockNumber一起正好填满一个32字节的存储槽
        // 假设治理代币的投票权总数不会超过224位整数的最大值
        uint224 votes;       // 该检查点时刻的投票权数量
    }

    /**
     * @notice 查询指定账户在特定区块的投票权数量
     * @dev 区块号必须是已确认的历史区块，否则函数会回滚以防止错误信息
     * @param account 要查询的账户地址
     * @param blockNumber 要查询的目标区块号（必须小于当前区块号）
     * @return 该账户在指定区块时拥有的投票权数量
     * 
     * 功能说明：
     * - 用于治理投票时确定用户在提案创建时刻的投票权
     * - 防止用户在投票期间转移代币来重复投票
     * - 支持历史投票权查询，确保治理过程的公平性
     */
    function getVotesAtBlock(address account, uint32 blockNumber) external view returns (uint224);

    /**
     * @notice 当账户设置新的投票权委托人时触发
     * @param delegator 委托人地址（投票权的原始拥有者）
     * @param currentDelegate 当前委托人地址（可能为零地址）
     * @param newDelegate 新委托人地址（接收投票权的地址）
     * 
     * 事件说明：
     * - 记录投票权委托关系的变更
     * - 用于追踪治理参与度和委托网络
     */
    event DelegateChanged(address delegator, address currentDelegate, address newDelegate);

    /**
     * @notice 当委托人的投票权数量发生变化时触发
     * @param delegatee 委托人地址（实际行使投票权的地址）
     * @param oldVotes 变更前的投票权数量
     * @param newVotes 变更后的投票权数量
     * 
     * 事件说明：
     * - 记录投票权数量的变化，用于更新投票权检查点
     * - 帮助前端应用实时显示投票权分布情况
     */
    event DelegateVotesChanged(address delegatee, uint224 oldVotes, uint224 newVotes);
}