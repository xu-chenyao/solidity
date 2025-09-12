# 🚀 Solidity开发环境安装指南

## 📋 环境要求

- **Node.js**: >= 18.0.0 (推荐 20.x)
- **npm**: >= 8.0.0
- **操作系统**: macOS, Linux, Windows

## 🔧 快速安装

### 方法1: 使用安装脚本（推荐）

```bash
# 给脚本执行权限
chmod +x install-env.sh

# 运行安装脚本
./install-env.sh
```

### 方法2: 手动安装

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

# 全局Solidity编译器
npm install -g solc
```

#### 4. 创建环境配置文件
```bash
cp .env.example .env
# 然后编辑 .env 文件填入你的配置
```

## 🎯 验证安装

### 1. 编译合约
```bash
npm run compile
# 或者
npx hardhat compile
```

### 2. 运行测试
```bash
npm run test
# 或者
npm run test:task1
```

### 3. 运行演示
```bash
npm run demo
```

### 4. 检查Solidity版本
```bash
solcjs --version
```

## 📁 项目结构

```
solidity/
├── contracts/task1/          # 智能合约源码
│   ├── Voting.sol           # 投票合约
│   ├── ReverseString.sol    # 字符串反转
│   ├── IntToRoman.sol       # 整数转罗马数字
│   ├── RomanToInt.sol       # 罗马数字转整数
│   ├── MergeSortedArray.sol # 合并有序数组
│   ├── BinarySearch.sol     # 二分查找
│   └── README.md            # 合约说明文档
├── test/task1/              # 测试文件
│   └── AllContracts.test.js # 综合测试
├── scripts/                 # 部署和演示脚本
│   └── demo.js              # 功能演示脚本
├── ignition/modules/        # Ignition部署模块
│   └── Lock.js              # 示例部署模块
├── hardhat.config.js        # Hardhat配置
├── package.json             # 项目配置
└── .env                     # 环境变量（需要创建）
```

## 🚀 常用命令

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

## 🌐 网络配置

### 本地开发网络（默认）
```bash
npm run demo
```

### 测试网部署（需要配置.env）
```bash
npm run demo:sepolia
```

### 启动本地网络节点
```bash
npm run node
# 在另一个终端运行
npm run demo -- --network localhost
```

## 🔍 故障排除

### 问题1: 编译失败
```bash
# 清理缓存重新编译
npm run clean
npm run compile
```

### 问题2: 测试失败
```bash
# 检查依赖是否完整
npm install
npm run test
```

### 问题3: Gas费用问题
```bash
# 检查hardhat.config.js中的gas配置
# 确保本地网络有足够的测试ETH
```

### 问题4: 网络连接问题
```bash
# 检查.env文件中的RPC URL配置
# 确保网络连接正常
```

## 📚 学习资源

- [Hardhat官方文档](https://hardhat.org/docs)
- [Solidity官方文档](https://docs.soliditylang.org/)
- [OpenZeppelin合约库](https://docs.openzeppelin.com/contracts/)
- [Ethers.js文档](https://docs.ethers.org/)

## 🎉 下一步

1. 阅读 `contracts/task1/README.md` 了解合约功能
2. 运行 `npm run demo` 查看演示
3. 修改合约代码并重新测试
4. 尝试部署到测试网

## 💡 提示

- 始终在本地测试后再部署到测试网或主网
- 保护好你的私钥，不要提交到版本控制
- 使用测试网进行学习和实验
- 定期备份重要的合约代码
