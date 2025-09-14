# NFT项目部署指南

## 🚀 完整部署流程

### 第一步：环境准备

1. **安装依赖**
   ```bash
   cd /Users/xuchenyao/solidity
   npm install
   npm install @openzeppelin/contracts
   ```

2. **配置环境变量**
   
   创建或编辑 `.env` 文件：
   ```bash
   # Sepolia测试网配置
   SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
   PRIVATE_KEY=your_private_key_here
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

### 第二步：本地测试

1. **编译合约**
   ```bash
   npx hardhat compile
   ```

2. **运行测试**
   ```bash
   npx hardhat test test/task2_2/MyNFT.test.js
   ```

3. **本地部署测试**
   ```bash
   # 终端1：启动本地网络
   npx hardhat node
   
   # 终端2：部署合约
   npx hardhat run scripts/task2_2/deploy.js --network localhost
   
   # 终端2：测试交互
   npx hardhat run scripts/task2_2/interact.js --network localhost
   ```

### 第三步：准备IPFS元数据

1. **准备NFT图片**
   - 格式：PNG, JPG, GIF, SVG
   - 推荐尺寸：512x512或更高

2. **上传图片到IPFS**
   - 使用Pinata (https://pinata.cloud/)
   - 获取图片IPFS链接：`ipfs://QmImageHash/image.png`

3. **创建元数据JSON文件**
   ```json
   {
     "name": "My Awesome NFT #1",
     "description": "这是我的第一个NFT",
     "image": "ipfs://QmYourImageHash/image.png",
     "attributes": [
       {
         "trait_type": "颜色",
         "value": "蓝色"
       },
       {
         "trait_type": "稀有度",
         "value": "传奇"
       }
     ]
   }
   ```

4. **上传元数据到IPFS**
   - 上传JSON文件到IPFS
   - 获取元数据链接：`ipfs://QmMetadataHash/metadata.json`

### 第四步：测试网部署

1. **获取测试ETH**
   - 访问Sepolia水龙头：https://sepoliafaucet.com/
   - 获取至少0.1 ETH用于部署和交互

2. **部署到Sepolia测试网**
   ```bash
   npx hardhat run scripts/task2_2/deploy.js --network sepolia
   ```

3. **记录部署信息**
   - 合约地址会保存在 `deployments/` 目录
   - 记录合约地址用于后续操作

### 第五步：铸造NFT

1. **修改交互脚本配置**
   
   编辑 `scripts/task2_2/interact.js`，更新配置：
   ```javascript
   const CONFIG = {
       // 使用实际的IPFS链接
       SAMPLE_METADATA_URIS: [
           "ipfs://QmYourActualHash/metadata1.json",
           "ipfs://QmYourActualHash/metadata2.json",
           "ipfs://QmYourActualHash/metadata3.json"
       ],
       
       // 接收NFT的地址
       RECIPIENT_ADDRESSES: [
           "0xYourWalletAddress"
       ]
   };
   ```

2. **执行铸造**
   ```bash
   npx hardhat run scripts/task2_2/interact.js --network sepolia
   ```

### 第六步：验证和查看

1. **在Etherscan上验证合约**
   ```bash
   npx hardhat verify --network sepolia CONTRACT_ADDRESS "MyAwesome NFT Collection" "MANFT"
   ```

2. **查看NFT**
   - **Etherscan**: https://sepolia.etherscan.io/address/CONTRACT_ADDRESS
   - **OpenSea测试网**: https://testnets.opensea.io/assets/sepolia/CONTRACT_ADDRESS/1

## 📋 快速命令参考

### 开发命令
```bash
# 编译
npx hardhat compile

# 测试
npx hardhat test test/task2_2/MyNFT.test.js

# 清理
npx hardhat clean
```

### 部署命令
```bash
# 本地部署
npx hardhat node  # 终端1
npx hardhat run scripts/task2_2/deploy.js --network localhost  # 终端2

# 测试网部署
npx hardhat run scripts/task2_2/deploy.js --network sepolia
```

### 交互命令
```bash
# 本地交互
npx hardhat run scripts/task2_2/interact.js --network localhost

# 测试网交互
npx hardhat run scripts/task2_2/interact.js --network sepolia
```

### 验证命令
```bash
# 合约验证
npx hardhat verify --network sepolia CONTRACT_ADDRESS "NFT_NAME" "NFT_SYMBOL"
```

## 🔧 故障排除

### 常见错误及解决方案

1. **编译错误：找不到OpenZeppelin**
   ```bash
   npm install @openzeppelin/contracts
   ```

2. **部署失败：余额不足**
   - 确保钱包有足够的测试ETH
   - 访问Sepolia水龙头获取测试币

3. **交互失败：合约地址错误**
   - 检查 `deployments/` 目录中的部署记录
   - 确认使用正确的合约地址

4. **IPFS链接无法访问**
   - 确保IPFS链接格式正确：`ipfs://QmHash/file`
   - 验证文件已成功上传到IPFS

## 📊 成本估算

### Gas费用参考（Sepolia测试网）
- 合约部署：~1,670,000 gas
- 单次铸造：~196,000 gas  
- 批量铸造：~183,000 gas/NFT

### 实际成本（按当前gas价格）
- 部署成本：约0.002-0.005 ETH
- 铸造成本：约0.0002-0.0005 ETH/NFT

## 🎯 检查清单

部署前确认：
- [ ] 环境变量已配置
- [ ] 测试全部通过
- [ ] 钱包有足够余额
- [ ] IPFS元数据已准备

部署后验证：
- [ ] 合约地址已记录
- [ ] 合约在Etherscan上可见
- [ ] NFT铸造成功
- [ ] 元数据正确显示
- [ ] 在OpenSea上可见

## 🔗 有用链接

- [Sepolia水龙头](https://sepoliafaucet.com/)
- [Pinata IPFS](https://pinata.cloud/)
- [Sepolia Etherscan](https://sepolia.etherscan.io/)
- [OpenSea测试网](https://testnets.opensea.io/)
- [MetaMask设置](https://metamask.io/)

---

按照此指南，您可以成功部署和铸造您的第一个NFT！ 🎉
