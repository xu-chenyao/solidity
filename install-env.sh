#!/bin/bash

echo "🚀 开始安装和配置Solidity开发环境..."

# 1. 检查Node.js和npm
echo "📋 检查Node.js和npm版本..."
node --version
npm --version

# 2. 安装项目依赖
echo "📦 安装项目依赖..."
npm install

# 3. 安装额外的开发依赖
echo "🔧 安装额外的开发工具..."
npm install --save-dev dotenv
npm install --save-dev @openzeppelin/contracts
npm install --save-dev solhint
npm install --save-dev prettier prettier-plugin-solidity

# 4. 全局安装Solidity编译器（可选）
echo "🌐 安装全局Solidity编译器..."
npm install -g solc

# 5. 创建环境配置文件
echo "⚙️ 创建环境配置文件..."
if [ ! -f .env ]; then
    cat > .env << EOF
# 测试网配置（可选）
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=your_private_key_here

# 主网配置（生产环境使用）
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# API密钥（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key_here
EOF
    echo "✅ 创建了 .env 配置文件"
else
    echo "ℹ️  .env 文件已存在"
fi

# 6. 创建.gitignore文件
if [ ! -f .gitignore ]; then
    cat > .gitignore << EOF
node_modules
.env
coverage
coverage.json
typechain
typechain-types

# Hardhat files
cache
artifacts

# IDE files
.vscode
.idea

# OS files
.DS_Store
Thumbs.db
EOF
    echo "✅ 创建了 .gitignore 文件"
fi

# 7. 编译合约
echo "🔨 编译智能合约..."
npx hardhat compile

# 8. 运行测试
echo "🧪 运行测试..."
npx hardhat test

echo "🎉 Solidity环境安装完成！"
echo ""
echo "📋 可用命令："
echo "  npx hardhat compile     - 编译合约"
echo "  npx hardhat test        - 运行测试"
echo "  npx hardhat node        - 启动本地网络"
echo "  npx hardhat console     - 打开交互式控制台"
echo "  solcjs --version        - 检查Solidity版本"
echo ""
echo "📁 项目结构："
echo "  contracts/task1/        - 你的智能合约"
echo "  test/task1/            - 测试文件"
echo "  scripts/               - 部署脚本"
echo "  ignition/modules/      - Ignition部署模块"
