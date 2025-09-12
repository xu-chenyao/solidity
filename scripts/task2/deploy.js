const { ethers } = require("hardhat");

/**
 * @title MyToken部署脚本
 * @dev 部署ERC20代币合约到指定网络
 * @author xuchenyao
 */

async function main() {
  console.log("🚀 开始部署MyToken ERC20合约...\n");

  // 获取网络信息
  const network = await ethers.provider.getNetwork();
  console.log("📡 目标网络:", network.name, `(Chain ID: ${network.chainId})`);

  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("👤 部署账户:", deployer.address);

  // 检查账户余额
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 账户余额:", ethers.formatEther(balance), "ETH");

  // 确保有足够的余额进行部署
  const minBalance = ethers.parseEther("0.01"); // 最少需要0.01 ETH
  if (balance < minBalance) {
    console.error("❌ 账户余额不足，至少需要0.01 ETH进行部署");
    process.exit(1);
  }

  console.log("\n📋 代币配置信息:");
  
  // 代币配置参数
  const tokenConfig = {
    name: "MyToken",           // 代币名称
    symbol: "MTK",             // 代币符号  
    decimals: 18,              // 代币精度（18位小数）
    initialSupply: 1000000     // 初始供应量（100万代币）
  };

  console.log(`   名称: ${tokenConfig.name}`);
  console.log(`   符号: ${tokenConfig.symbol}`);
  console.log(`   精度: ${tokenConfig.decimals} 位小数`);
  console.log(`   初始供应量: ${tokenConfig.initialSupply.toLocaleString()} ${tokenConfig.symbol}`);
  console.log(`   总供应量: ${ethers.formatUnits(ethers.parseUnits(tokenConfig.initialSupply.toString(), tokenConfig.decimals), tokenConfig.decimals)} ${tokenConfig.symbol}`);

  try {
    console.log("\n🔨 开始编译和部署合约...");

    // 获取合约工厂
    const MyToken = await ethers.getContractFactory("MyToken");
    
    // 估算部署gas费用
    const deploymentData = MyToken.interface.encodeDeploy([
      tokenConfig.name,
      tokenConfig.symbol,
      tokenConfig.decimals,
      tokenConfig.initialSupply
    ]);
    
    const estimatedGas = await ethers.provider.estimateGas({
      data: deploymentData
    });
    
    console.log(`⛽ 预估Gas用量: ${estimatedGas.toString()}`);

    // 部署合约
    console.log("📦 正在部署合约...");
    const myToken = await MyToken.deploy(
      tokenConfig.name,
      tokenConfig.symbol,
      tokenConfig.decimals,
      tokenConfig.initialSupply
    );

    // 等待部署完成
    console.log("⏳ 等待部署确认...");
    await myToken.waitForDeployment();

    const contractAddress = await myToken.getAddress();
    console.log("✅ 合约部署成功!");
    console.log("📍 合约地址:", contractAddress);

    // 获取部署交易信息
    const deployTx = myToken.deploymentTransaction();
    if (deployTx) {
      console.log("🔗 部署交易哈希:", deployTx.hash);
      console.log("⛽ 实际Gas用量:", deployTx.gasLimit.toString());
      
      // 等待交易确认
      const receipt = await deployTx.wait();
      console.log("📊 交易确认:", receipt.status === 1 ? "成功" : "失败");
      console.log("🧱 区块号:", receipt.blockNumber);
      console.log("⛽ Gas消耗:", receipt.gasUsed.toString());
    }

    console.log("\n🔍 验证合约部署结果...");

    // 验证合约基本信息
    const deployedName = await myToken.name();
    const deployedSymbol = await myToken.symbol();
    const deployedDecimals = await myToken.decimals();
    const deployedTotalSupply = await myToken.totalSupply();
    const deployedOwner = await myToken.owner();
    const deployerBalance = await myToken.balanceOf(deployer.address);

    console.log("✅ 合约验证结果:");
    console.log(`   名称: ${deployedName}`);
    console.log(`   符号: ${deployedSymbol}`);
    console.log(`   精度: ${deployedDecimals}`);
    console.log(`   总供应量: ${ethers.formatUnits(deployedTotalSupply, deployedDecimals)} ${deployedSymbol}`);
    console.log(`   合约所有者: ${deployedOwner}`);
    console.log(`   部署者余额: ${ethers.formatUnits(deployerBalance, deployedDecimals)} ${deployedSymbol}`);

    // 验证部署者是否拥有所有代币
    if (deployerBalance.toString() === deployedTotalSupply.toString()) {
      console.log("✅ 初始代币分配正确");
    } else {
      console.log("❌ 初始代币分配异常");
    }

    // 网络特定的后续操作
    if (network.chainId === 11155111n) { // Sepolia测试网
      console.log("\n🌐 Sepolia测试网部署完成!");
      console.log("📱 添加到钱包的信息:");
      console.log(`   合约地址: ${contractAddress}`);
      console.log(`   代币符号: ${deployedSymbol}`);
      console.log(`   小数位数: ${deployedDecimals}`);
      
      console.log("\n🔗 区块链浏览器链接:");
      console.log(`   Sepolia Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
      
      console.log("\n💡 导入钱包步骤:");
      console.log("   1. 打开MetaMask钱包");
      console.log("   2. 切换到Sepolia测试网");
      console.log("   3. 点击'导入代币'");
      console.log("   4. 输入合约地址:", contractAddress);
      console.log("   5. 确认代币信息并添加");
      
    } else if (network.chainId === 1337n || network.chainId === 31337n) { // 本地网络
      console.log("\n🏠 本地网络部署完成!");
      console.log("🧪 可以开始本地测试了");
      
    } else if (network.chainId === 1n) { // 主网
      console.log("\n🌍 主网部署完成!");
      console.log("⚠️  请谨慎操作，这是真实的以太坊主网");
      console.log(`   Etherscan: https://etherscan.io/address/${contractAddress}`);
    }

    // 保存部署信息到文件
    const deploymentInfo = {
      network: network.name,
      chainId: network.chainId.toString(),
      contractAddress: contractAddress,
      deployerAddress: deployer.address,
      deploymentTime: new Date().toISOString(),
      transactionHash: deployTx?.hash,
      blockNumber: deployTx ? (await deployTx.wait()).blockNumber : null,
      tokenConfig: tokenConfig,
      gasUsed: deployTx ? (await deployTx.wait()).gasUsed.toString() : null
    };

    // 写入部署信息文件
    const fs = require('fs');
    const path = require('path');
    
    const deploymentDir = path.join(__dirname, '../../deployments');
    if (!fs.existsSync(deploymentDir)) {
      fs.mkdirSync(deploymentDir, { recursive: true });
    }
    
    const deploymentFile = path.join(deploymentDir, `mytoken-${network.name}-${Date.now()}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    
    console.log(`\n📄 部署信息已保存到: ${deploymentFile}`);

    console.log("\n🎉 部署流程完成!");
    
    // 返回合约实例供其他脚本使用
    return {
      contract: myToken,
      address: contractAddress,
      deploymentInfo: deploymentInfo
    };

  } catch (error) {
    console.error("\n❌ 部署失败:", error.message);
    
    // 详细错误信息
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error("💰 余额不足，请确保账户有足够的ETH支付gas费用");
    } else if (error.code === 'NETWORK_ERROR') {
      console.error("🌐 网络连接错误，请检查网络配置");
    } else if (error.message.includes('gas')) {
      console.error("⛽ Gas相关错误，请检查gas设置");
    }
    
    console.error("\n🔍 错误详情:", error);
    process.exit(1);
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main()
    .then(() => {
      console.log("\n✅ 脚本执行完成");
      process.exit(0);
    })
    .catch((error) => {
      console.error("\n❌ 脚本执行失败:", error);
      process.exit(1);
    });
}

// 导出main函数供其他脚本使用
module.exports = { main };
