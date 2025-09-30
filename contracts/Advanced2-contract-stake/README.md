# MetaNode质押挖矿系统

一个基于以太坊的去中心化质押挖矿平台，支持ETH和ERC20代币质押，通过智能合约自动分发MetaNode代币奖励。

## 📋 项目概述

MetaNode质押挖矿系统是一个完整的DeFi质押解决方案，具有以下核心特性：

### 🎯 核心功能

- **多币种质押支持**：支持ETH和多种ERC20代币质押
- **灵活奖励机制**：基于区块高度和池权重的公平奖励分配
- **延迟提取保护**：可配置的锁定期防止短期投机
- **管理员控制**：完善的权限管理和紧急暂停机制
- **可升级架构**：使用UUPS模式支持合约逻辑升级
- **安全保障**：基于OpenZeppelin标准库，经过充分测试

### 🏗️ 系统架构

```
MetaNode质押挖矿系统
├── MetaNodeToken.sol          # 奖励代币合约
├── MetaNodeStake.sol          # 主质押合约
├── scripts/                   # 部署和交互脚本
│   ├── deploy.js             # 完整系统部署
│   ├── addPool.js            # 添加资金池
│   ├── MetaNodeStake.js      # Sepolia网络部署
│   └── tokenInteract.js      # 合约交互测试
└── test/                     # 测试文件
    └── MetaNodeStake.test.js # 综合测试套件
```

## 🔧 技术栈

- **智能合约**：Solidity ^0.8.20
- **开发框架**：Hardhat
- **升级模式**：OpenZeppelin UUPS
- **标准库**：OpenZeppelin Contracts
- **测试工具**：Hardhat + Ethers.js
- **网络支持**：以太坊主网、Sepolia测试网、本地开发网络

## 📊 合约详解

### MetaNodeToken.sol - 奖励代币

```solidity
// 标准ERC20代币，用作质押奖励
contract MetaNodeToken is ERC20 {
    // 总供应量：10,000,000 MetaNode
    // 精度：18位小数
    // 特点：固定供应量，无增发机制
}
```

**关键特性：**
- ✅ 标准ERC20功能
- ✅ 预铸造1000万代币
- ✅ 无额外管理权限
- ✅ 去中心化设计

### MetaNodeStake.sol - 主质押合约

```solidity
// 可升级的多池质押挖矿合约
contract MetaNodeStake is 
    Initializable, 
    UUPSUpgradeable, 
    PausableUpgradeable, 
    AccessControlUpgradeable {
    
    // 支持多个资金池
    // 基于区块的奖励分发
    // 延迟提取机制
    // 完善的权限控制
}
```

**核心数据结构：**

```solidity
struct Pool {
    address stTokenAddress;      // 质押代币地址（0x0 = ETH）
    uint256 poolWeight;          // 池权重（决定奖励分配）
    uint256 lastRewardBlock;     // 上次更新区块
    uint256 accMetaNodePerST;    // 累积每代币奖励
    uint256 stTokenAmount;       // 池内总质押量
    uint256 minDepositAmount;    // 最小质押限制
    uint256 unstakeLockedBlocks; // 提取锁定期
}

struct User {
    uint256 stAmount;         // 用户质押量
    uint256 finishedMetaNode; // 已结算奖励
    uint256 pendingMetaNode;  // 待领取奖励
    UnstakeRequest[] requests; // 提取请求列表
}
```

## 🚀 快速开始

### 环境要求

- Node.js >= 16.0.0
- npm 或 yarn
- Git

### 安装依赖

```bash
# 克隆项目
git clone <repository-url>
cd solidity

# 安装依赖
npm install

# 编译合约
npx hardhat compile
```

### 网络配置

在 `hardhat.config.js` 中配置网络：

```javascript
module.exports = {
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/YOUR-PROJECT-ID",
      accounts: ["YOUR-PRIVATE-KEY"]
    }
  }
};
```

## 📦 部署指南

### 1. 本地开发网络部署

```bash
# 启动本地节点
npx hardhat node

# 新终端：部署合约
npx hardhat run scripts/Advanced2-contract-stake/deploy.js --network localhost

# 添加ETH资金池
npx hardhat run scripts/Advanced2-contract-stake/addPool.js --network localhost
```

### 2. Sepolia测试网部署

```bash
# 部署到Sepolia
npx hardhat run scripts/Advanced2-contract-stake/deploy.js --network sepolia

# 添加资金池
npx hardhat run scripts/Advanced2-contract-stake/addPool.js --network sepolia
```

### 3. 主网部署（谨慎操作）

```bash
# 主网部署前请充分测试
npx hardhat run scripts/Advanced2-contract-stake/deploy.js --network mainnet
```

## 🧪 测试指南

### 运行测试套件

```bash
# 运行所有测试
npx hardhat test

# 运行特定测试文件
npx hardhat test test/Advanced2-contract-stake/MetaNodeStake.test.js

# 生成测试覆盖率报告
npx hardhat coverage
```

### 测试覆盖范围

- ✅ 合约部署和初始化
- ✅ 资金池管理（添加、更新、权重调整）
- ✅ 用户质押和提取流程
- ✅ 奖励计算和分发
- ✅ 权限控制和安全检查
- ✅ 紧急暂停功能
- ✅ 合约升级机制
- ✅ 边界条件和错误处理

## 💡 使用示例

### 用户操作流程

#### 1. 质押ETH获得奖励

```javascript
// 连接到合约
const stakeContract = await ethers.getContractAt("MetaNodeStake", contractAddress);

// 质押1 ETH到池0（ETH池）
await stakeContract.depositETH({ value: ethers.parseEther("1.0") });

// 查询待领取奖励
const pending = await stakeContract.pendingMetaNode(0, userAddress);
console.log("待领取奖励:", ethers.formatUnits(pending, 18), "MetaNode");
```

#### 2. 领取奖励

```javascript
// 领取池0的所有奖励
await stakeContract.claim(0);
```

#### 3. 申请提取质押

```javascript
// 申请提取0.5 ETH
await stakeContract.unstake(0, ethers.parseEther("0.5"));

// 等待锁定期结束后提取
await stakeContract.withdraw(0);
```

### 管理员操作

#### 1. 添加新资金池

```javascript
// 添加USDT池（假设USDT地址为0x123...）
await stakeContract.addPool(
    "0x123...",              // USDT代币地址
    300,                     // 池权重
    ethers.parseUnits("10", 6), // 最小质押10 USDT
    5760,                    // 锁定1天（假设15秒/块）
    true                     // 更新所有池
);
```

#### 2. 调整池权重

```javascript
// 将池0的权重调整为800
await stakeContract.setPoolWeight(0, 800, true);
```

#### 3. 紧急暂停

```javascript
// 暂停提取功能
await stakeContract.pauseWithdraw();

// 暂停领取功能
await stakeContract.pauseClaim();

// 恢复功能
await stakeContract.unpauseWithdraw();
await stakeContract.unpauseClaim();
```

## 🔐 安全考虑

### 智能合约安全

- **重入攻击防护**：使用OpenZeppelin的ReentrancyGuard
- **整数溢出保护**：使用SafeMath库和Solidity 0.8+内置检查
- **权限控制**：基于角色的访问控制（RBAC）
- **暂停机制**：紧急情况下可暂停关键功能
- **升级安全**：UUPS模式确保升级权限控制

### 经济模型安全

- **奖励计算精度**：使用1e18精度避免舍入误差
- **锁定期机制**：防止短期投机和套利攻击
- **最小质押限制**：防止粉尘攻击和gas浪费
- **权重平衡**：合理分配各池奖励比例

### 运营安全建议

1. **多重签名管理**：使用多重签名钱包管理管理员权限
2. **逐步放权**：随着系统稳定运行，逐步减少中心化控制
3. **监控告警**：建立完善的链上监控和异常告警机制
4. **定期审计**：定期进行智能合约安全审计
5. **社区治理**：逐步向DAO治理模式转变

## 📈 经济模型

### 代币分配

```
MetaNode代币总供应量：10,000,000 MetaNode

建议分配方案：
├── 70% (7,000,000) → 质押挖矿奖励池
├── 15% (1,500,000) → 团队和开发者
├── 10% (1,000,000) → 社区激励和空投
└── 5% (500,000)    → 流动性提供和交易所上市
```

### 奖励机制

- **基础奖励**：每区块固定数量的MetaNode奖励
- **权重分配**：根据池权重分配总奖励
- **用户分成**：根据用户在池中的占比分配池奖励
- **复利效应**：奖励可以重新质押获得更多收益

### 参数示例

```javascript
// 示例配置
const rewardConfig = {
    metaNodePerBlock: "1000000000000000000",  // 1 MetaNode/块
    ethPoolWeight: 500,                       // ETH池权重50%
    usdtPoolWeight: 300,                      // USDT池权重30%
    btcPoolWeight: 200,                       // WBTC池权重20%
    unstakeLockBlocks: 5760                   // 1天锁定期
};
```

## 🔄 升级机制

### UUPS升级模式

本系统采用OpenZeppelin的UUPS（Universal Upgradeable Proxy Standard）升级模式：

**优势：**
- ✅ Gas效率高（升级逻辑在实现合约中）
- ✅ 代理合约简单稳定
- ✅ 支持权限控制的升级
- ✅ 数据存储持久化

**升级流程：**

```javascript
// 1. 部署新实现合约
const NewImplementation = await ethers.getContractFactory("MetaNodeStakeV2");
const newImpl = await NewImplementation.deploy();

// 2. 执行升级（需要UPGRADE_ROLE权限）
await upgrades.upgradeProxy(proxyAddress, NewImplementation);
```

### 升级治理

- **权限要求**：只有具有UPGRADE_ROLE的账户可以执行升级
- **多重签名**：建议使用多重签名钱包控制升级权限
- **时间锁**：考虑引入时间锁机制，给用户预留反应时间
- **社区投票**：重大升级应通过DAO治理投票决定

## 📞 联系方式

- **项目地址**：[GitHub Repository]
- **文档网站**：[Documentation Site]
- **社区讨论**：[Discord/Telegram]
- **问题反馈**：[GitHub Issues]

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## 🔍 常见问题（FAQ）

### Q: 如何计算我的预期收益？

A: 收益计算公式：
```
用户收益 = (用户质押量 / 池总质押量) × 池权重 × 每区块奖励 × 区块数
```

### Q: 为什么需要锁定期？

A: 锁定期的作用：
- 防止短期投机行为
- 维护系统稳定性
- 保护长期质押用户利益
- 减少频繁交易的gas消耗

### Q: 合约升级会影响我的资产吗？

A: 不会。UUPS升级模式确保：
- 用户资产安全存储在代理合约中
- 升级只改变业务逻辑，不影响数据
- 代理合约地址保持不变
- 用户无需进行任何操作

### Q: 如何监控系统运行状态？

A: 可以通过以下方式：
- 调用合约的查询函数
- 监听合约事件
- 使用区块浏览器查看交易
- 运行 `tokenInteract.js` 脚本

### Q: 遇到问题如何寻求帮助？

A: 请按以下步骤：
1. 查阅本文档和代码注释
2. 在GitHub Issues中搜索类似问题
3. 提交详细的问题报告
4. 加入社区讨论群组

---

*最后更新：2024年12月*
