// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 导入OpenZeppelin的标准ERC20合约实现
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MetaNodeToken - MetaNode奖励代币合约
 * @dev 这是一个标准的ERC20代币合约，用作质押挖矿的奖励代币
 * 
 * 功能特点：
 * 1. 标准ERC20功能：转账、授权、查询余额等
 * 2. 预铸造供应量：在部署时一次性铸造全部代币
 * 3. 简单设计：无额外的铸造、销毁或管理功能
 * 
 * 代币信息：
 * - 名称：MetaNodeToken
 * - 符号：MetaNode  
 * - 精度：18位小数（ERC20标准）
 * - 总供应量：10,000,000 个代币
 * 
 * 使用场景：
 * - 作为MetaNodeStake合约的奖励代币
 * - 用户通过质押ETH或其他代币获得MetaNode奖励
 * - 可以在去中心化交易所进行交易
 */
contract MetaNodeToken is ERC20 {
    
    /**
     * @dev 构造函数 - 初始化代币并铸造初始供应量
     * @notice 在合约部署时执行，设置代币基本信息并铸造全部代币给部署者
     */
    constructor() ERC20("MetaNodeToken", "MetaNode") {
        // 调用父合约ERC20的构造函数
        // 参数1: "MetaNodeToken" - 代币的全称
        // 参数2: "MetaNode" - 代币的符号/简称
        
        // 铸造初始供应量给合约部署者
        // 10,000,000 * 10^18 = 10,000,000 个代币（18位小数精度）
        // msg.sender: 合约部署者地址
        // 1_000_000_000_000_000_000: 1 * 10^18，即1个代币的最小单位
        _mint(
            msg.sender,                           // 接收者：合约部署者
            10000000 * 1_000_000_000_000_000_000 // 数量：1000万个代币
        );
        
        // 铸造完成后，部署者将拥有全部的MetaNode代币
        // 部署者可以：
        // 1. 将代币转移到质押合约作为奖励池
        // 2. 分发给团队或社区
        // 3. 在DEX上提供流动性
    }
    
    // 注意：此合约没有额外的铸造函数
    // 这意味着代币供应量是固定的，无法增发
    // 只有部署时铸造的1000万个代币会存在
}