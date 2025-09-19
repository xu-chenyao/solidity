# NFT 拍卖市场 - 完整实现

一个基于以太坊的去中心化 NFT 拍卖市场，集成 Chainlink 价格预言机，支持多种代币出价，使用 UUPS 代理模式实现合约升级。
### ✅  大作业：实现一个 NFT 拍卖市场
任务目标
1. 使用 Hardhat 框架开发一个 NFT 拍卖市场。
2. 使用 Chainlink 的 feedData 预言机功能，计算 ERC20 和以太坊到美元的价格。
3. 使用 UUPS/透明代理模式实现合约升级。
4. 使用类似于 Uniswap V2 的工厂模式管理每场拍卖。


任务步骤
1. 项目初始化
1. 使用 Hardhat 初始化项目：
npx hardhat init
2. 安装必要的依赖：
     npm install @openzeppelin/contracts @chainlink/contracts @nomiclabs/hardhat-ethers hardhat-deploy
2. 实现 NFT 拍卖市场
1. NFT 合约：
  - 使用 ERC721 标准实现一个 NFT 合约。
  - 支持 NFT 的铸造和转移。
2. 拍卖合约：
  - 实现一个拍卖合约，支持以下功能：
  - 创建拍卖：允许用户将 NFT 上架拍卖。
  - 出价：允许用户以 ERC20 或以太坊出价。
  - 结束拍卖：拍卖结束后，NFT 转移给出价最高者，资金转移给卖家。
3. 工厂模式：
  - 使用类似于 Uniswap V2 的工厂模式，管理每场拍卖。
  - 工厂合约负责创建和管理拍卖合约实例。
4. 集成 Chainlink 预言机
5. 价格计算：
  - 使用 Chainlink 的 feedData 预言机，获取 ERC20 和以太坊到美元的价格。
  - 在拍卖合约中，将出价金额转换为美元，方便用户比较。
6. 跨链拍卖：
  - 使用 Chainlink 的 CCIP 功能，实现 NFT 跨链拍卖。
  - 允许用户在不同链上参与拍卖。
7. 合约升级
  1. UUPS/透明代理：
  - 使用 UUPS 或透明代理模式实现合约升级。
  - 确保拍卖合约和工厂合约可以安全升级。
8. 测试与部署
  1. 测试：
  - 编写单元测试和集成测试，覆盖所有功能。
  2. 部署：
  - 使用 Hardhat 部署脚本，将合约部署到测试网（如 Goerli 或 Sepolia）。

任务要求
1. 代码质量：
  - 代码清晰、规范，符合 Solidity 最佳实践。
1. 功能完整性：
  - 实现所有要求的功能，包括 NFT 拍卖、价格计算和合约升级。
1. 测试覆盖率：
  - 编写全面的测试，覆盖所有功能。
1. 文档：
  - 提供详细的文档，包括项目结构、功能说明和部署步骤。

提交内容
1. 代码：提交完整的 Hardhat 项目代码。
2. 测试报告：提交测试报告，包括测试覆盖率和测试结果。
3. 部署地址：提交部署到测试网的合约地址。
4. 文档：提交项目文档，包括功能说明和部署步骤。

额外挑战（可选）
1. 动态手续费：根据拍卖金额动态调整手续费。

## 📋 项目概述

### 核心功能
- ✅ **ERC721 NFT 合约**：支持铸造、转移和拍卖状态管理
- ✅ **多币种拍卖系统**：支持 ETH 和 ERC20 代币出价
- ✅ **Chainlink 价格预言机集成**：实时价格转换和比较
- ✅ **工厂模式管理**：类似 Uniswap V2 的拍卖实例管理
- ✅ **UUPS 代理升级**：安全的合约升级机制
- ✅ **完整的测试覆盖**：单元测试和集成测试
- ✅ **自动化部署脚本**：支持本地和测试网部署

### 技术架构
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AuctionNFT    │    │  AuctionFactory  │    │ ChainlinkOracle │
│  (ERC721 + UUPS)│    │    (UUPS)        │    │   (UUPS)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────┐        ┌──────┴──────┐        ┌──────┘
                 │        │             │        │
         ┌───────▼────────▼─────────────▼────────▼───────┐
         │              NFTAuction                       │
         │         (Individual Auction)                  │
         └─────────────────────────────────────────────────┘
```

## 🏗️ 合约架构

### 1. AuctionNFT.sol
可升级的 ERC721 NFT 合约，支持：
- NFT 铸造和批量铸造
- 拍卖状态管理（防止拍卖中的 NFT 被转移）
- 授权拍卖合约操作
- UUPS 代理升级

### 2. AuctionFactory.sol
拍卖工厂合约，负责：
- 创建和管理拍卖实例
- 拍卖参数验证
- 拍卖统计和查询
- 批量操作支持

### 3. NFTAuction.sol
单个拍卖合约，实现：
- 多币种出价（ETH 和 ERC20）
- 价格预言机集成
- 自动延时防狙击
- 平台费用收取
- 出价退还机制

### 4. ChainlinkPriceOracle.sol / MockPriceOracle.sol
价格预言机合约：
- 实时价格数据获取
- 多币种价格转换
- 价格数据验证
- 测试环境模拟

### 5. TestToken.sol
测试用 ERC20 代币合约

## 🚀 快速开始

### 环境要求
- Node.js >= 16.0.0
- npm >= 8.0.0
- Hardhat >= 2.19.0

### 安装依赖
```bash
cd /Users/xuchenyao/solidity
npm install
```

### 编译合约
```bash
npx hardhat compile
```

### 运行测试
```bash
# 运行所有测试
npx hardhat test test/task3/NFTAuctionTest.js

# 运行测试并显示 gas 报告
REPORT_GAS=true npx hardhat test test/task3/NFTAuctionTest.js

# 运行测试并显示覆盖率
npx hardhat coverage --testfiles "test/task3/**/*.js"
```

### 本地部署
```bash
# 启动本地节点
npx hardhat node

# 在新终端中部署合约
npx hardhat run scripts/task3/deploy.js --network localhost

# 运行演示脚本
npx hardhat run scripts/task3/demo.js --network localhost
```

### 测试网部署
```bash
# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填入私钥和 RPC URL

# 部署到 Sepolia 测试网
npx hardhat run scripts/task3/deploy.js --network sepolia

# 验证合约
npx hardhat verify --network sepolia <DEPLOYED_CONTRACT_ADDRESS>
```

## 📖 使用指南

### 基本流程

#### 1. 铸造 NFT
```javascript
// 铸造单个 NFT
await auctionNFT.mint(owner, "https://ipfs.io/ipfs/QmHash");

// 批量铸造
await auctionNFT.batchMint(owner, [
  "https://ipfs.io/ipfs/QmHash1",
  "https://ipfs.io/ipfs/QmHash2",
  "https://ipfs.io/ipfs/QmHash3"
]);
```

#### 2. 创建拍卖
```javascript
// 授权拍卖工厂
await auctionNFT.setApprovalForAll(auctionFactory.address, true);

// 创建拍卖
const tx = await auctionFactory.createAuction(
  nftContract,        // NFT 合约地址
  tokenId,            // NFT ID
  startingPrice,      // 起拍价（美元，8位小数）
  reservePrice,       // 保留价（美元，8位小数）
  duration,           // 持续时间（秒）
  bidIncrement        // 最小加价幅度（美元，8位小数）
);
```

#### 3. 参与出价
```javascript
// 使用 ETH 出价
await auctionContract.bidWithETH({ value: ethers.parseEther("0.1") });

// 使用 ERC20 代币出价
await token.approve(auctionContract.address, amount);
await auctionContract.bidWithERC20(token.address, amount);
```

#### 4. 结束拍卖
```javascript
// 等待拍卖时间结束或卖家主动结束
await auctionContract.endAuction();
```

### 高级功能

#### 查询拍卖信息
```javascript
// 获取拍卖基本信息
const auctionInfo = await auctionContract.getAuctionInfo();

// 获取当前最高出价
const [bidder, amount, usdValue, bidType, token] = await auctionContract.getHighestBid();

// 获取所有出价记录
const allBids = await auctionContract.getAllBids();

// 获取拍卖统计
const stats = await auctionFactory.getAuctionStats();
```

#### 价格预言机操作
```javascript
// 获取 ETH 价格
const [ethPrice, decimals] = await priceOracle.getETHPrice();

// 获取代币价格
const [tokenPrice, decimals] = await priceOracle.getTokenPrice(tokenAddress);

// 转换价格
const usdValue = await priceOracle.convertETHToUSD(ethAmount);
const usdValue = await priceOracle.convertTokenToUSD(tokenAddress, tokenAmount);
```

#### 合约升级
```javascript
// 升级 NFT 合约
const AuctionNFTV2 = await ethers.getContractFactory("AuctionNFTV2");
const upgraded = await upgrades.upgradeProxy(auctionNFT.address, AuctionNFTV2);

// 升级拍卖工厂
const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactoryV2");
const upgraded = await upgrades.upgradeProxy(auctionFactory.address, AuctionFactoryV2);
```

## 🧪 测试说明

### 测试覆盖范围
- ✅ NFT 合约功能测试
- ✅ 价格预言机测试
- ✅ 拍卖工厂测试
- ✅ 完整拍卖流程测试
- ✅ 合约升级测试
- ✅ 边界情况和错误处理
- ✅ 价格波动处理

### 测试数据
```javascript
// 测试常量
const ETH_PRICE = ethers.parseUnits("2000", 8);      // $2000 per ETH
const TOKEN_PRICE = ethers.parseUnits("1", 8);       // $1 per token
const STARTING_PRICE = ethers.parseUnits("100", 8);  // $100 起拍价
const RESERVE_PRICE = ethers.parseUnits("200", 8);   // $200 保留价
const AUCTION_DURATION = 3600;                       // 1 hour
```

### 运行特定测试
```bash
# 测试 NFT 合约
npx hardhat test test/task3/NFTAuctionTest.js --grep "NFT 合约测试"

# 测试拍卖流程
npx hardhat test test/task3/NFTAuctionTest.js --grep "拍卖流程测试"

# 测试合约升级
npx hardhat test test/task3/NFTAuctionTest.js --grep "合约升级测试"
```

## 📊 Gas 优化

### Gas 使用统计
| 操作 | Gas 消耗 | 优化说明 |
|------|----------|----------|
| 铸造 NFT | ~100,000 | 使用批量铸造可节省 30% |
| 创建拍卖 | ~2,500,000 | 部署新合约的固定成本 |
| ETH 出价 | ~150,000 | 包含价格转换和事件 |
| ERC20 出价 | ~180,000 | 额外的代币转移成本 |
| 结束拍卖 | ~200,000 | 包含资金分配和退还 |

### 优化建议
1. **批量操作**：使用 `batchMint` 和 `createBatchAuctions` 节省 gas
2. **代理模式**：UUPS 代理比透明代理更节省 gas
3. **存储优化**：使用紧凑的数据结构
4. **事件优化**：合理使用 indexed 参数

## 🔒 安全考虑

### 安全特性
- ✅ **重入攻击防护**：使用 ReentrancyGuard
- ✅ **整数溢出保护**：Solidity 0.8+ 内置保护
- ✅ **访问控制**：基于角色的权限管理
- ✅ **价格操纵防护**：价格预言机数据验证
- ✅ **前端运行防护**：最小出价增量要求
- ✅ **时间操纵防护**：使用区块时间戳

### 已知风险和缓解措施
1. **价格预言机风险**
   - 风险：价格数据延迟或操纵
   - 缓解：多重验证、价格阈值检查

2. **网络拥堵风险**
   - 风险：交易延迟影响拍卖
   - 缓解：自动延时机制

3. **合约升级风险**
   - 风险：升级可能引入漏洞
   - 缓解：多重签名、时间锁、测试验证

## 🌐 网络配置

### 支持的网络
| 网络 | Chain ID | RPC URL | 区块浏览器 |
|------|----------|---------|------------|
| Hardhat | 31337 | http://127.0.0.1:8545 | - |
| Localhost | 31337 | http://127.0.0.1:8545 | - |
| Sepolia | 11155111 | https://sepolia.infura.io/v3/... | https://sepolia.etherscan.io |

### Chainlink 预言机地址
| 网络 | ETH/USD | LINK/USD |
|------|---------|----------|
| Sepolia | 0x694AA1769357215DE4FAC081bf1f309aDC325306 | 0xc59E3633BAAC79493d908e63626716e204A45EdF |

## 📁 项目结构
```
contracts/task3/
├── AuctionNFT.sol           # 可升级 ERC721 NFT 合约
├── AuctionFactory.sol       # 拍卖工厂合约
├── NFTAuction.sol          # 单个拍卖合约
├── ChainlinkPriceOracle.sol # Chainlink 价格预言机
├── MockPriceOracle.sol     # 模拟价格预言机（测试用）
├── TestToken.sol           # 测试用 ERC20 代币
├── IPriceOracle.sol        # 价格预言机接口
└── README.md               # 项目文档

test/task3/
└── NFTAuctionTest.js       # 完整测试套件

scripts/task3/
├── deploy.js               # 部署脚本
└── demo.js                 # 演示脚本

deployments/                # 部署记录
└── localhost-*.json        # 部署信息文件
```

## 🔧 配置文件

### 环境变量 (.env)
```bash
# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR-PROJECT-ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR-PROJECT-ID

# 私钥 (测试网使用，不要用于主网)
PRIVATE_KEY=your-private-key-here

# API 密钥
ETHERSCAN_API_KEY=your-etherscan-api-key
COINMARKETCAP_API_KEY=your-coinmarketcap-api-key

# Gas 报告
REPORT_GAS=true
```

### Hardhat 配置
```javascript
// hardhat.config.js
module.exports = {
  solidity: "0.8.20",
  networks: {
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

## 🎯 演示场景

运行 `npx hardhat run scripts/task3/demo.js --network localhost` 查看完整演示，包括：

1. **准备阶段**：铸造 NFT，分发测试代币
2. **创建拍卖**：设置拍卖参数，创建拍卖实例
3. **多轮出价**：
   - 出价者1：使用 ETH 出价 ($60)
   - 出价者2：使用 TEST1 代币出价 ($80)
   - 出价者3：使用 TEST2 代币出价 ($120)
4. **价格波动模拟**：模拟市场价格变化
5. **拍卖结束**：自动结算，资产转移
6. **结果验证**：检查最终状态

## 🐛 故障排除

### 常见问题

**Q: 编译失败，提示找不到 Chainlink 合约**
```bash
A: 安装 Chainlink 依赖
npm install @chainlink/contracts
```

**Q: 测试失败，提示 gas 不足**
```bash
A: 增加 gas limit
npx hardhat test --gas-limit 12000000
```

**Q: 部署失败，提示合约太大**
```bash
A: 启用 IR 编译器和优化器
// hardhat.config.js
solidity: {
  settings: {
    optimizer: { enabled: true, runs: 200 },
    viaIR: true
  }
}
```

**Q: 价格预言机返回过期数据**
```bash
A: 检查网络连接和预言机地址
// 对于测试，可以使用 MockPriceOracle
```

### 调试技巧

1. **使用 console.log**
```solidity
import "hardhat/console.sol";
console.log("Debug value:", value);
```

2. **查看交易详情**
```bash
npx hardhat run scripts/debug.js --network localhost
```

3. **Gas 跟踪**
```bash
REPORT_GAS=true npx hardhat test
```

## 📈 未来改进

### 计划功能
- [ ] **跨链拍卖**：使用 Chainlink CCIP
- [ ] **NFT 分片拍卖**：支持 NFT 所有权分片
- [ ] **动态拍卖参数**：根据市场调整参数
- [ ] **治理代币**：社区治理机制
- [ ] **流动性挖矿**：激励参与者

### 技术优化
- [ ] **Layer 2 集成**：降低交易成本
- [ ] **MetaTransaction**：用户体验优化
- [ ] **批量出价**：支持多个拍卖同时出价
- [ ] **自动化拍卖**：智能合约自动管理

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📞 联系方式

如有问题，请通过以下方式联系：

- GitHub Issues: [项目 Issues 页面]
- Email: [your-email@example.com]

---

**⚠️ 免责声明**: 本项目仅用于学习和演示目的。在生产环境中使用前，请进行充分的安全审计和测试。
