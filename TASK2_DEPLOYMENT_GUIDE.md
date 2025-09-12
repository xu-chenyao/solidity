# 🚀 Task2 ERC20代币部署指南

## 📋 项目完成状态

✅ **已完成的内容**：
- [x] ERC20代币合约实现 (`contracts/task2/MyToken.sol`)
- [x] 完整测试套件 (`test/task2/MyToken.test.js`)
- [x] 部署脚本 (`scripts/task2/deploy.js`)
- [x] 功能演示脚本 (`scripts/task2/demo.js`)
- [x] 综合测试脚本 (`scripts/task2/test-and-deploy.js`)
- [x] 详细文档 (`contracts/task2/README.md`)

## 🎯 本地测试

### 1. 编译合约
```bash
npm run compile
```

### 2. 运行测试
```bash
# 运行Task2测试
npm run test:task2

# 运行所有测试
npm run test:all
```

### 3. 本地部署和演示
```bash
# 完整功能测试和部署
npm run task2:full

# 功能演示
npm run demo:task2

# 单独部署
npm run deploy:task2
```

## 🌐 部署到Sepolia测试网

### 1. 环境配置

创建 `.env` 文件：
```bash
# Sepolia测试网RPC URL
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# 部署账户私钥（不要使用主账户）
PRIVATE_KEY=your_private_key_without_0x_prefix

# Etherscan API密钥（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 2. 获取测试ETH

访问以下水龙头获取Sepolia测试ETH：
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- [Infura Sepolia Faucet](https://www.infura.io/faucet)

### 3. 部署到Sepolia

```bash
# 完整测试和部署
npm run task2:full:sepolia

# 功能演示
npm run demo:task2:sepolia

# 单独部署
npm run deploy:task2:sepolia
```

### 4. 验证部署

部署成功后，你会看到类似输出：
```
✅ 合约部署成功!
📍 合约地址: 0x1234567890123456789012345678901234567890

🌐 Sepolia测试网信息:
   Etherscan: https://sepolia.etherscan.io/address/0x1234567890123456789012345678901234567890
```

## 📱 导入到MetaMask钱包

### 1. 添加Sepolia网络（如果还没有）

- **网络名称**: Sepolia Test Network
- **RPC URL**: https://sepolia.infura.io/v3/YOUR_PROJECT_ID
- **链ID**: 11155111
- **货币符号**: ETH
- **区块浏览器**: https://sepolia.etherscan.io

### 2. 导入代币

1. 打开MetaMask钱包
2. 确保已切换到Sepolia测试网
3. 点击"导入代币"
4. 选择"自定义代币"
5. 输入合约信息：
   - **代币合约地址**: 部署后获得的地址
   - **代币符号**: MTK
   - **小数精度**: 18
6. 点击"添加自定义代币"
7. 确认添加

### 3. 验证代币

导入成功后，你应该能在钱包中看到：
- 代币名称：MyToken
- 代币符号：MTK
- 余额：1,000,000 MTK（如果你是部署者）

## 🔧 故障排除

### 常见问题

1. **编译失败**
   ```bash
   npm run clean
   npm run compile
   ```

2. **测试失败**
   - 检查合约代码是否正确
   - 确保所有依赖已安装

3. **部署失败 - 余额不足**
   - 确保账户有足够的Sepolia ETH
   - 至少需要0.01 ETH用于部署

4. **部署失败 - 网络连接**
   - 检查`.env`文件中的RPC URL
   - 确保网络连接正常

5. **MetaMask导入失败**
   - 确保合约地址正确
   - 确保网络切换到Sepolia
   - 检查代币信息是否正确

### 调试命令

```bash
# 检查网络连接
npx hardhat console --network sepolia

# 查看账户余额
npx hardhat run scripts/check-balance.js --network sepolia

# 清理缓存重新编译
npm run clean && npm run compile
```

## 📊 合约功能总结

### ERC20标准功能
- ✅ `balanceOf()` - 查询余额
- ✅ `transfer()` - 转账
- ✅ `approve()` - 授权
- ✅ `allowance()` - 查询授权额度
- ✅ `transferFrom()` - 代扣转账

### 扩展功能
- ✅ `mint()` - 增发代币（仅所有者）
- ✅ `increaseAllowance()` - 增加授权
- ✅ `decreaseAllowance()` - 减少授权
- ✅ `batchTransfer()` - 批量转账
- ✅ `transferOwnership()` - 转移所有权
- ✅ `renounceOwnership()` - 放弃所有权

### 安全特性
- ✅ 零地址检查
- ✅ 余额验证
- ✅ 权限控制
- ✅ 事件记录
- ✅ 溢出保护

## 🎉 项目完成检查清单

- [x] 合约实现所有ERC20标准功能
- [x] 包含mint增发功能
- [x] 使用event记录所有操作
- [x] 完整的测试覆盖（30+测试用例）
- [x] 本地测试通过
- [x] 部署脚本完成
- [x] 文档完整
- [ ] 部署到Sepolia测试网
- [ ] 导入到MetaMask钱包

## 🔗 相关链接

- [ERC20标准文档](https://eips.ethereum.org/EIPS/eip-20)
- [Sepolia测试网信息](https://sepolia.dev/)
- [MetaMask使用指南](https://metamask.io/faqs/)
- [Hardhat文档](https://hardhat.org/docs)

## 📞 技术支持

如果遇到问题，可以：
1. 查看错误日志
2. 检查网络配置
3. 验证环境变量
4. 查阅相关文档

---

**恭喜！🎉 你已经完成了一个完整的ERC20代币项目！**
