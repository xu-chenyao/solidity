# NFT项目 - 图文并茂的ERC721代币

## 📋 项目概述

本项目实现了一个完整的NFT（非同质化代币）解决方案，包括智能合约开发、测试、部署和交互。项目符合ERC721标准，支持图文并茂的NFT铸造，并可部署到以太坊测试网。

### ✅ 作业2：在测试网上发行一个图文并茂的 NFT
任务目标
1. 使用 Solidity 编写一个符合 ERC721 标准的 NFT 合约。
2. 将图文数据上传到 IPFS，生成元数据链接。
3. 将合约部署到以太坊测试网（如 Goerli 或 Sepolia）。
4. 铸造 NFT 并在测试网环境中查看。
任务步骤
1. 编写 NFT 合约
  - 使用 OpenZeppelin 的 ERC721 库编写一个 NFT 合约。
  - 合约应包含以下功能：
  - 构造函数：设置 NFT 的名称和符号。
  - mintNFT 函数：允许用户铸造 NFT，并关联元数据链接（tokenURI）。
  - 在 Remix IDE 中编译合约。
2. 准备图文数据
  - 准备一张图片，并将其上传到 IPFS（可以使用 Pinata 或其他工具）。
  - 创建一个 JSON 文件，描述 NFT 的属性（如名称、描述、图片链接等）。
  - 将 JSON 文件上传到 IPFS，获取元数据链接。
  - JSON文件参考 https://docs.opensea.io/docs/metadata-standards
3. 部署合约到测试网
  - 在 Remix IDE 中连接 MetaMask，并确保 MetaMask 连接到 Goerli 或 Sepolia 测试网。
  - 部署 NFT 合约到测试网，并记录合约地址。
4. 铸造 NFT
  - 使用 mintNFT 函数铸造 NFT：
  - 在 recipient 字段中输入你的钱包地址。
  - 在 tokenURI 字段中输入元数据的 IPFS 链接。
  - 在 MetaMask 中确认交易。
5. 查看 NFT
  - 打开 OpenSea 测试网 或 Etherscan 测试网。
  - 连接你的钱包，查看你铸造的 NFT。

### 🎯 项目目标

- ✅ 使用Solidity编写符合ERC721标准的NFT合约
- ✅ 支持IPFS元数据存储
- ✅ 部署到以太坊测试网（Sepolia）
- ✅ 铸造NFT并在测试网环境中查看
- ✅ 完整的测试覆盖和文档

### 🏗️ 项目结构

```
contracts/task2_2/
├── MyNFT.sol              # 主要NFT合约
├── README.md              # 项目文档
└── DEPLOYMENT_GUIDE.md    # 部署指南

test/task2_2/
└── MyNFT.test.js          # 合约测试文件

scripts/task2_2/
├── deploy.js              # 部署脚本
└── interact.js            # 交互脚本

deployments/               # 部署记录
└── mynft-*.json          # 部署信息文件
```

## 🚀 快速开始

### 1. 环境准备

确保您已安装以下依赖：

```bash
# 安装Node.js依赖
npm install

# 安装OpenZeppelin合约库
npm install @openzeppelin/contracts
```

### 2. 编译合约

```bash
npx hardhat compile
```

### 3. 运行测试

```bash
# 运行所有测试
npx hardhat test test/task2_2/MyNFT.test.js

# 查看测试覆盖率
npx hardhat coverage
```

### 4. 本地部署测试

```bash
# 启动本地网络
npx hardhat node

# 在新终端中部署合约
npx hardhat run scripts/task2_2/deploy.js --network localhost

# 测试合约交互
npx hardhat run scripts/task2_2/interact.js --network localhost
```

## 📝 合约详细说明

### MyNFT.sol 主要功能

#### 核心特性
- **ERC721标准兼容**: 完全符合ERC721标准
- **元数据存储**: 支持IPFS元数据链接
- **批量铸造**: 支持一次铸造多个NFT
- **权限管理**: 基于OpenZeppelin的Ownable
- **详细记录**: 记录铸造时间和铸造者

#### 主要函数

```solidity
// 铸造单个NFT
function mintNFT(address recipient, string memory uri) 
    public onlyOwner returns (uint256)

// 批量铸造NFT
function batchMintNFT(address[] memory recipients, string[] memory tokenURIs) 
    public onlyOwner returns (uint256[] memory)

// 获取NFT详细信息
function getNFTInfo(uint256 tokenId) 
    public view returns (address owner, string memory uri, uint256 mintTime, address minterAddress)

// 获取总供应量
function totalSupply() public view returns (uint256)
```

#### 事件

```solidity
event NFTMinted(
    uint256 indexed tokenId,
    address indexed recipient,
    string tokenURI,
    uint256 timestamp
);
```

## 🧪 测试说明

测试文件 `MyNFT.test.js` 包含以下测试用例：

### 测试覆盖范围

1. **部署和初始化测试**
   - NFT名称和符号设置
   - 所有者权限验证
   - 初始状态检查

2. **NFT铸造功能测试**
   - 成功铸造NFT
   - 权限控制测试
   - 参数验证测试
   - 铸造信息记录测试

3. **批量铸造功能测试**
   - 批量铸造成功案例
   - 参数验证测试
   - 错误处理测试

4. **查询功能测试**
   - NFT信息查询
   - 余额查询
   - 错误处理测试

5. **ERC721标准兼容性测试**
   - 接口支持验证
   - 转移功能测试
   - 批准功能测试

6. **Gas优化测试**
   - 单次铸造gas消耗
   - 批量铸造效率对比

### 运行测试

```bash
# 运行所有测试
npx hardhat test test/task2_2/MyNFT.test.js

# 运行特定测试
npx hardhat test test/task2_2/MyNFT.test.js --grep "铸造功能"

# 查看详细输出
npx hardhat test test/task2_2/MyNFT.test.js --verbose
```

## 🚀 部署指南

### 本地部署

```bash
# 1. 启动本地网络
npx hardhat node

# 2. 部署合约
npx hardhat run scripts/task2_2/deploy.js --network localhost
```

### 测试网部署（Sepolia）

```bash
# 1. 配置环境变量
# 在.env文件中设置：
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
# PRIVATE_KEY=your_private_key_here
# ETHERSCAN_API_KEY=your_etherscan_api_key

# 2. 部署到Sepolia测试网
npx hardhat run scripts/task2_2/deploy.js --network sepolia

# 3. 验证合约（可选）
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS "NFT_NAME" "NFT_SYMBOL"
```

### 部署输出说明

部署成功后，脚本会：
- 显示合约地址和部署交易信息
- 保存部署信息到 `deployments/` 目录
- 提供后续操作指引

## 🎨 NFT铸造和交互

### 使用交互脚本

```bash
# 本地网络交互
npx hardhat run scripts/task2_2/interact.js --network localhost

# 测试网交互
npx hardhat run scripts/task2_2/interact.js --network sepolia
```

### 手动交互示例

```javascript
// 获取合约实例
const MyNFT = await ethers.getContractFactory("MyNFT");
const contract = MyNFT.attach("CONTRACT_ADDRESS");

// 铸造NFT
const tx = await contract.mintNFT(
    "0x...", // 接收者地址
    "ipfs://QmYourHashHere/metadata.json" // 元数据URI
);
await tx.wait();

// 查询NFT信息
const [owner, uri, mintTime, minter] = await contract.getNFTInfo(1);
console.log("NFT所有者:", owner);
console.log("元数据URI:", uri);
```

## 📊 IPFS元数据标准

### JSON元数据格式

根据OpenSea标准，NFT元数据应包含以下结构：

```json
{
  "name": "My Awesome NFT #1",
  "description": "This is an amazing NFT with unique properties",
  "image": "ipfs://QmImageHashHere/image.png",
  "external_url": "https://mywebsite.com/nft/1",
  "attributes": [
    {
      "trait_type": "Color",
      "value": "Blue"
    },
    {
      "trait_type": "Rarity",
      "value": "Legendary"
    },
    {
      "trait_type": "Power",
      "value": 95,
      "max_value": 100
    }
  ]
}
```

### IPFS上传步骤

1. **准备图片文件**
   - 支持格式：PNG, JPG, GIF, SVG
   - 推荐尺寸：512x512 或更高

2. **上传到IPFS**
   - 使用Pinata: https://pinata.cloud/
   - 使用IPFS Desktop
   - 使用其他IPFS服务

3. **创建元数据JSON**
   - 使用上传后的图片IPFS链接
   - 添加NFT属性和描述

4. **上传元数据JSON**
   - 将JSON文件上传到IPFS
   - 获取元数据IPFS链接

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

## 📈 Gas优化建议

### 铸造成本分析

根据测试结果：
- 单次铸造：~195,900 gas
- 批量铸造：更高效，平均每个NFT约183,000 gas
- 部署成本：~1,669,000 gas

### 优化建议

1. **批量操作**: 使用 `batchMintNFT` 进行批量铸造
2. **元数据优化**: 使用IPFS减少链上存储
3. **合约优化**: 移除不必要的功能以降低部署成本

## 🔍 查看和验证

### 在区块链浏览器中查看

#### Sepolia测试网
- **Etherscan**: https://sepolia.etherscan.io/address/CONTRACT_ADDRESS
- **合约交互**: 在Etherscan上可以直接调用合约函数

#### 在NFT市场查看

- **OpenSea测试网**: https://testnets.opensea.io/assets/sepolia/CONTRACT_ADDRESS/TOKEN_ID
- **Rarible测试网**: https://testnet.rarible.com/

### 验证步骤

1. **合约验证**
   ```bash
   npx hardhat verify --network sepolia CONTRACT_ADDRESS "NFT_NAME" "NFT_SYMBOL"
   ```

2. **功能验证**
   - 检查合约所有者
   - 验证NFT元数据
   - 测试转移功能

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

4. **Gas估算错误**
   ```bash
   # 使用更高的gas限制
   npx hardhat run script.js --network sepolia --gas-limit 3000000
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

1. **白名单铸造**: 限制特定地址铸造
2. **销毁功能**: 允许销毁NFT
3. **版税功能**: 实现EIP-2981版税标准
4. **盲盒功能**: 延迟元数据揭示
5. **升级功能**: 使用代理合约模式

### 示例扩展代码

```solidity
// 白名单功能
mapping(address => bool) public whitelist;

function addToWhitelist(address[] memory addresses) public onlyOwner {
    for (uint i = 0; i < addresses.length; i++) {
        whitelist[addresses[i]] = true;
    }
}

modifier onlyWhitelisted() {
    require(whitelist[msg.sender], "Not whitelisted");
    _;
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
- 100%测试覆盖率

## 📄 许可证

MIT License - 详见LICENSE文件

## 🔗 相关链接

- [OpenZeppelin文档](https://docs.openzeppelin.com/)
- [ERC721标准](https://eips.ethereum.org/EIPS/eip-721)
- [OpenSea元数据标准](https://docs.opensea.io/docs/metadata-standards)
- [Hardhat文档](https://hardhat.org/docs)
- [IPFS文档](https://docs.ipfs.io/)

## 📞 支持

如有问题，请：
1. 查看故障排除部分
2. 检查相关文档
3. 提交Issue到项目仓库

---

**祝您NFT开发愉快！** 🎉
