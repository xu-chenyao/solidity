# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:
## 🚀 常用命令
```shell
REPORT_GAS=true npx hardhat test

npx hardhat help
#运行测试
npx hardhat test test/task2/MyToken.test.js
#启动本地测试网络
npx hardhat node 

npx hardhat run scripts/task2/deploy.js --network localhost
npx hardhat run scripts/task2/deploy.js --network sepolia

# 本地部署
npx hardhat ignition deploy ./ignition/modules/Lock.js 
npx hardhat ignition deploy ./ignition/modules/Lock.js --network localhost
# 测试网部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia 
# 测试网强制重新部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia --reset
# 主网部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network mainnet 
```

```bash
| 命令 | 说明 |
|------|------|
| `npm run compile` | 编译所有合约 |
| `npm run test` | 运行所有测试 |
| `npm run test:task1` | 只运行Task1测试 |
| `npm run demo` | 运行功能演示 |
| `npm run node` | 启动本地区块链网络 |
| `npm run console` | 打开Hardhat控制台 |
| `npm run clean` | 清理编译缓存 |
| `npm run lint` | 检查代码规范 |
| `npm run format` | 格式化代码 |
```

## 环境安装
#### 1. 检查Node.js和npm
```bash
node --version  # 应该显示 v20.x.x
npm --version   # 应该显示 10.x.x
```

#### 2. 安装项目依赖
```bash
npm install
```

#### 3. 安装额外开发工具
```bash
# 环境变量管理
npm install --save-dev dotenv

# OpenZeppelin合约库（可选）
npm install --save-dev @openzeppelin/contracts

# 代码质量工具
npm install --save-dev solhint prettier prettier-plugin-solidity
```

## git链接
```bash
git init                                    # 初始化仓库
git remote add origin <your-repo>          # 添加远程仓库
git add .                                   # 添加所有文件
git commit -m "项目完整提交"                 # 提交更改
git push -f origin main                     # 强制推送覆盖远程
```