# 讨饭合约项目 - BeggingContract

## 📋 项目概述

本项目实现了一个完整的讨饭合约（BeggingContract），允许用户向合约捐赠以太币，合约所有者可以提取资金。项目包含完整的智能合约开发、测试、部署和交互功能。

### ✅作业3：编写一个讨饭合约
任务目标
使用 Solidity 编写一个合约，允许用户向合约地址发送以太币。
记录每个捐赠者的地址和捐赠金额。
允许合约所有者提取所有捐赠的资金。

任务步骤
编写合约
创建一个名为 BeggingContract 的合约。
合约应包含以下功能：
一个 mapping 来记录每个捐赠者的捐赠金额。
一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
一个 withdraw 函数，允许合约所有者提取所有资金。
一个 getDonation 函数，允许查询某个地址的捐赠金额。
使用 payable 修饰符和 address.transfer 实现支付和提款。
部署合约
在 Remix IDE 中编译合约。
部署合约到 Goerli 或 Sepolia 测试网。
测试合约
使用 MetaMask 向合约发送以太币，测试 donate 功能。
调用 withdraw 函数，测试合约所有者是否可以提取资金。
调用 getDonation 函数，查询某个地址的捐赠金额。

任务要求
合约代码：
使用 mapping 记录捐赠者的地址和金额。
使用 payable 修饰符实现 donate 和 withdraw 函数。
使用 onlyOwner 修饰符限制 withdraw 函数只能由合约所有者调用。
测试网部署：
合约必须部署到 Goerli 或 Sepolia 测试网。
功能测试：
确保 donate、withdraw 和 getDonation 函数正常工作。

提交内容
合约代码：提交 Solidity 合约文件（如 BeggingContract.sol）。
合约地址：提交部署到测试网的合约地址。
测试截图：提交在 Remix 或 Etherscan 上测试合约的截图。

额外挑战（可选）
捐赠事件：添加 Donation 事件，记录每次捐赠的地址和金额。
捐赠排行榜：实现一个功能，显示捐赠金额最多的前 3 个地址。
时间限制：添加一个时间限制，只有在特定时间段内才能捐赠。

**任务目标**
1. 使用 Solidity 编写一个合约，允许用户向合约地址发送以太币
2. 记录每个捐赠者的地址和捐赠金额
3. 允许合约所有者提取所有捐赠的资金

**任务步骤**
1. 编写合约 - 创建BeggingContract合约，包含donate、withdraw、getDonation等功能
2. 部署合约 - 部署合约到Sepolia测试网
3. 测试合约 - 使用MetaMask测试donate、withdraw、getDonation功能

**任务要求**
- ✅ 使用mapping记录捐赠者的地址和金额
- ✅ 使用payable修饰符实现donate和withdraw函数
- ✅ 使用onlyOwner修饰符限制withdraw函数只能由合约所有者调用
- ✅ 确保donate、withdraw和getDonation函数正常工作

### 🎯 项目特色

- **完整功能**: 捐赠、提款、查询、统计等完整功能
- **安全保护**: 防重入攻击、权限控制、参数验证
- **用户友好**: 详细的事件日志、错误提示、使用指南
- **高效优化**: Gas优化、批量操作、智能排序
- **全面测试**: 28个测试用例，覆盖所有功能和边界条件

### 🏗️ 项目结构

```
contracts/task2_3/
├── BeggingContract.sol     # 主要讨饭合约
├── RejectEther.sol         # 测试辅助合约
├── README.md               # 项目文档
└── DEPLOYMENT_GUIDE.md     # 部署指南

test/task2_3/
└── BeggingContract.test.js # 完整测试套件

scripts/task2_3/
├── deploy.js               # 部署脚本
└── interact.js             # 交互脚本

deployments/                # 部署记录目录
└── begging-*.json         # 自动生成的部署信息
```

## 🚀 快速开始

### 1. 环境准备

确保您已安装以下依赖：

```bash
# 安装Node.js依赖
npm install

# 安装OpenZeppelin合约库（如果还没有）
npm install @openzeppelin/contracts
```

### 2. 编译合约

```bash
npx hardhat compile
```

### 3. 运行测试

```bash
# 运行所有测试
npx hardhat test test/task2_3/BeggingContract.test.js

# 查看测试覆盖率
npx hardhat coverage
```

### 4. 本地部署测试

```bash
# 启动本地网络
npx hardhat node

# 在新终端中部署合约
npx hardhat run scripts/task2_3/deploy.js --network localhost

# 测试合约交互
npx hardhat run scripts/task2_3/interact.js --network localhost
```

## 📝 合约详细说明

### BeggingContract.sol 主要功能

#### 核心特性
- **安全捐赠**: 支持payable函数和直接转账
- **权限管理**: 基于OpenZeppelin的Ownable
- **防重入保护**: 使用ReentrancyGuard防止攻击
- **详细记录**: 记录捐赠时间、金额、捐赠者信息
- **统计分析**: 提供排行榜、平均值等统计功能

#### 主要函数

```solidity
// 捐赠函数
function donate(string memory message) public payable

// 直接接收ETH
receive() external payable

// 提取指定金额（仅所有者）
function withdraw(uint256 amount) public onlyOwner nonReentrant

// 提取所有资金（仅所有者）
function withdrawAll() public onlyOwner nonReentrant

// 紧急提款（仅所有者）
function emergencyWithdraw() public onlyOwner

// 查询捐赠金额
function getDonation(address donor) public view returns (uint256)

// 获取捐赠统计
function getDonationStats() public view returns (uint256, uint256, uint256, uint256)

// 获取捐赠排行榜
function getTopDonors(uint256 count) public view returns (address[] memory, uint256[] memory)
```

#### 事件

```solidity
event DonationReceived(
    address indexed donor,
    uint256 amount,
    uint256 timestamp,
    string message
);

event Withdrawal(
    address indexed owner,
    uint256 amount,
    uint256 timestamp
);

event EmergencyWithdrawal(
    address indexed owner,
    uint256 amount,
    uint256 timestamp
);
```

#### 状态变量

```solidity
mapping(address => uint256) public donations;      // 捐赠记录
address[] public donors;                           // 捐赠者列表
mapping(address => bool) public hasDonated;        // 是否已捐赠
uint256 public totalDonations;                     // 总捐赠金额
uint256 public totalWithdrawn;                     // 已提取金额
```

## 🧪 测试说明

测试文件 `BeggingContract.test.js` 包含以下测试用例：

### 测试覆盖范围

1. **部署和初始化测试** (3个测试)
   - 合约所有者设置
   - 初始状态验证
   - 初始捐赠记录检查

2. **捐赠功能测试** (8个测试)
   - 成功接收捐赠
   - 多次捐赠累计
   - 多用户捐赠
   - 直接转账功能
   - 零金额捐赠拒绝
   - 事件触发验证

3. **提款功能测试** (7个测试)
   - 所有者提款权限
   - 提取所有资金
   - 非所有者权限拒绝
   - 余额不足检查
   - 零金额提款拒绝
   - 事件触发验证
   - 紧急提款功能

4. **查询功能测试** (5个测试)
   - 捐赠统计信息
   - 捐赠者列表
   - 平均捐赠计算
   - 排行榜功能
   - 空合约处理

5. **边界条件测试** (3个测试)
   - 最小金额处理
   - 大量捐赠者处理
   - 空合约提款

6. **安全性测试** (3个测试)
   - 重入攻击防护
   - 转账失败处理
   - 所有权转移

7. **Gas优化测试** (2个测试)
   - 捐赠操作gas消耗
   - 提款操作gas消耗

### 运行测试

```bash
# 运行所有测试
npx hardhat test test/task2_3/BeggingContract.test.js

# 运行特定测试
npx hardhat test test/task2_3/BeggingContract.test.js --grep "捐赠功能"

# 查看详细输出
npx hardhat test test/task2_3/BeggingContract.test.js --verbose
```

### 测试结果示例

```
BeggingContract
  部署和初始化
    ✔ 应该正确设置合约所有者
    ✔ 初始状态应该正确
    ✔ 初始捐赠记录应该为空
  捐赠功能
    ✔ 应该能够成功接收捐赠
    ✔ 应该能够接收多次捐赠
    ✔ 应该能够接收多个捐赠者的捐赠
    ... (更多测试)

28 passing (966ms)
1 pending

Gas消耗报告:
捐赠操作Gas消耗: 136090
提款操作Gas消耗: 57193
```

## 🚀 部署指南

### 本地部署

```bash
# 1. 启动本地网络
npx hardhat node

# 2. 部署合约
npx hardhat run scripts/task2_3/deploy.js --network localhost
```

### 测试网部署（Sepolia）

```bash
# 1. 配置环境变量
# 在.env文件中设置：
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
# PRIVATE_KEY=your_private_key_here
# ETHERSCAN_API_KEY=your_etherscan_api_key

# 2. 获取测试ETH
# 访问: https://sepoliafaucet.com/

# 3. 部署到Sepolia测试网
npx hardhat run scripts/task2_3/deploy.js --network sepolia

# 4. 验证合约（可选）
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS OWNER_ADDRESS
```

### 部署输出说明

部署成功后，脚本会：
- 显示合约地址和部署交易信息
- 保存部署信息到 `deployments/` 目录
- 提供使用指南和测试命令
- 显示合约功能说明

## 🎮 合约交互

### 使用交互脚本

```bash
# 本地网络交互
npx hardhat run scripts/task2_3/interact.js --network localhost

# 测试网交互
npx hardhat run scripts/task2_3/interact.js --network sepolia
```

### 手动交互示例

```javascript
// 获取合约实例
const BeggingContract = await ethers.getContractFactory("BeggingContract");
const contract = BeggingContract.attach("CONTRACT_ADDRESS");

// 捐赠ETH
const tx = await contract.donate("支持你的项目！", {
    value: ethers.parseEther("0.1")
});
await tx.wait();

// 查询捐赠记录
const donation = await contract.getDonation("0x...");
console.log("捐赠金额:", ethers.formatEther(donation), "ETH");

// 提取资金（仅所有者）
const withdrawTx = await contract.withdraw(ethers.parseEther("0.05"));
await withdrawTx.wait();

// 获取统计信息
const [totalReceived, currentBalance, totalWithdrawn, donorCount] = 
    await contract.getDonationStats();
```

### MetaMask交互

1. **添加合约到MetaMask**
   - 复制合约地址
   - 在MetaMask中添加代币（可选）

2. **进行捐赠**
   - 直接向合约地址转账
   - 或使用Etherscan的Write Contract功能

3. **查看交易记录**
   - 在Etherscan上查看交易历史
   - 查看事件日志

## 📊 功能演示

### 交互脚本演示内容

1. **多用户捐赠功能**
   - 3个不同用户分别捐赠不同金额
   - 显示gas消耗和实际花费

2. **重复捐赠功能**
   - 同一用户多次捐赠
   - 验证金额累计

3. **直接转账功能**
   - 测试receive函数
   - 验证自动记录

4. **提款功能**
   - 部分提款演示
   - 提取所有资金

5. **查询和统计**
   - 捐赠排行榜
   - 统计信息显示
   - 所有捐赠者列表

### 演示输出示例

```
============================================================
演示1: 多用户捐赠功能
============================================================

💰 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 正在捐赠 1.0 ETH
📝 留言: "支持你的项目！"
✅ 捐赠成功! Gas消耗: 136246
📊 该地址累计捐赠: 1.0 ETH

🏆 捐赠排行榜 (前3名):
   1. 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC: 2.7 ETH
   2. 0x70997970C51812dc3A010C7d01b50e0d17dc79C8: 1.3 ETH
   3. 0x90F79bf6EB2c4f870365E785982E1f101E93b906: 0.5 ETH
```

## 🔧 配置说明

### Hardhat配置

确保 `hardhat.config.js` 包含正确的网络配置：

```javascript
module.exports = {
  solidity: "0.8.28",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
```

### 环境变量

创建 `.env` 文件：

```bash
# Sepolia测试网RPC URL
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# 部署账户私钥（不要在主网使用！）
PRIVATE_KEY=your_private_key_here

# Etherscan API密钥（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 📈 Gas优化分析

### Gas消耗统计

根据测试结果：
- **合约部署**: ~1,130,000 gas
- **首次捐赠**: ~136,000 gas
- **重复捐赠**: ~37,500 gas
- **直接转账**: ~36,400 gas
- **提款操作**: ~57,200 gas

### 优化建议

1. **批量操作**: 考虑添加批量捐赠功能
2. **存储优化**: 使用packed结构减少存储槽
3. **事件优化**: 合理使用indexed参数
4. **函数优化**: 减少不必要的状态读取

## 🔍 查看和验证

### 在区块链浏览器中查看

#### Sepolia测试网
- **Etherscan**: https://sepolia.etherscan.io/address/CONTRACT_ADDRESS
- **合约交互**: 在Etherscan上可以直接调用合约函数
- **事件查看**: 查看DonationReceived和Withdrawal事件

#### 验证步骤

1. **合约验证**
   ```bash
   npx hardhat verify --network sepolia CONTRACT_ADDRESS OWNER_ADDRESS
   ```

2. **功能验证**
   - 检查合约所有者
   - 验证捐赠记录
   - 测试提款功能

## 🛠️ 故障排除

### 常见问题

1. **编译错误**
   ```bash
   # 清理缓存重新编译
   npx hardhat clean
   npx hardhat compile
   ```

2. **部署失败**
   - 检查账户余额是否足够
   - 验证网络配置
   - 检查私钥格式

3. **交互失败**
   - 确认合约地址正确
   - 检查函数调用权限
   - 验证参数格式

4. **权限错误**
   ```
   OwnableUnauthorizedAccount: 只有合约所有者可以提取资金
   ```

### 调试技巧

```bash
# 查看详细错误信息
npx hardhat run script.js --show-stack-traces

# 使用console.log调试
console.log("Debug info:", variable);

# 检查交易状态
npx hardhat console --network sepolia
```

## 📚 扩展功能

### 可添加的功能

1. **捐赠目标**: 设置筹款目标和进度显示
2. **时间限制**: 添加捐赠截止时间
3. **最小金额**: 设置最小捐赠金额限制
4. **手续费**: 添加平台手续费机制
5. **退款功能**: 在特定条件下允许退款
6. **多币种**: 支持ERC20代币捐赠

### 示例扩展代码

```solidity
// 捐赠目标功能
uint256 public fundingGoal;
uint256 public deadline;

modifier onlyBeforeDeadline() {
    require(block.timestamp < deadline, "Funding period ended");
    _;
}

function donate(string memory message) public payable onlyBeforeDeadline {
    // 现有捐赠逻辑
}

// 最小金额限制
uint256 public minimumDonation = 0.001 ether;

function donate(string memory message) public payable {
    require(msg.value >= minimumDonation, "Donation too small");
    // 现有逻辑
}
```

## 🤝 贡献指南

### 开发流程

1. Fork项目
2. 创建功能分支
3. 编写测试
4. 提交代码
5. 创建Pull Request

### 代码规范

- 使用Solidity 0.8.x
- 遵循OpenZeppelin标准
- 添加详细注释
- 保持测试覆盖率

## 📄 许可证

MIT License - 详见LICENSE文件

## 🔗 相关链接

- [OpenZeppelin文档](https://docs.openzeppelin.com/)
- [Solidity文档](https://docs.soliditylang.org/)
- [Hardhat文档](https://hardhat.org/docs)
- [Etherscan](https://etherscan.io/)
- [Sepolia水龙头](https://sepoliafaucet.com/)

## 📞 支持

如有问题，请：
1. 查看故障排除部分
2. 检查相关文档
3. 提交Issue到项目仓库

---

**祝您讨饭合约开发愉快！** 🎉💰
