const { ethers } = require("hardhat");

/**
 * @title MyToken合约交互脚本
 * @dev 与已部署到Sepolia测试网的MyToken合约进行交互
 * @author xuchenyao
 */

async function main() {
  console.log("🔗 开始与已部署的MyToken合约交互...\n");

  // 已部署的合约地址 (从部署记录中获取)
  const CONTRACT_ADDRESS = "0x0A81015f205D4cBA59BA7996a9ce4362c2bfD5f0";
  
  // 获取网络信息
  const network = await ethers.provider.getNetwork();
  console.log("📡 连接网络:", network.name, `(Chain ID: ${network.chainId})`);

  // 获取签名者账户
  const [signer] = await ethers.getSigners();
  console.log("👤 当前账户:", signer.address);

  // 检查账户余额
  const balance = await ethers.provider.getBalance(signer.address);
  console.log("💰 账户余额:", ethers.formatEther(balance), "ETH");

  try {
    // 连接到已部署的合约
    console.log("\n🔌 连接到合约:", CONTRACT_ADDRESS);
    const MyToken = await ethers.getContractFactory("MyToken");
    const myToken = MyToken.attach(CONTRACT_ADDRESS);

    console.log("\n📊 === 合约基本信息 ===");
    
    // 读取合约基本信息
    const name = await myToken.name();
    const symbol = await myToken.symbol();
    const decimals = await myToken.decimals();
    const totalSupply = await myToken.totalSupply();
    const owner = await myToken.owner();

    console.log(`代币名称: ${name}`);
    console.log(`代币符号: ${symbol}`);
    console.log(`代币精度: ${decimals}`);
    console.log(`总供应量: ${ethers.formatUnits(totalSupply, decimals)} ${symbol}`);
    console.log(`合约所有者: ${owner}`);

    console.log("\n💰 === 账户余额查询 ===");
    
    // 查询当前账户的代币余额
    const myBalance = await myToken.balanceOf(signer.address);
    console.log(`我的${symbol}余额: ${ethers.formatUnits(myBalance, decimals)} ${symbol}`);

    // 查询所有者的代币余额
    const ownerBalance = await myToken.balanceOf(owner);
    console.log(`所有者${symbol}余额: ${ethers.formatUnits(ownerBalance, decimals)} ${symbol}`);

    console.log("\n🔄 === 合约交互示例 ===");

    // 示例1: 转账 (如果当前账户有代币)
    if (myBalance > 0) {
      console.log("\n💸 执行转账操作...");
      const transferAmount = ethers.parseUnits("10", decimals); // 转账10个代币
      const recipientAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6".toLowerCase(); // 示例地址
      
      console.log(`准备转账 ${ethers.formatUnits(transferAmount, decimals)} ${symbol} 到 ${recipientAddress}`);
      
      // 注意: 这里只是演示，实际执行需要确认
      // const transferTx = await myToken.transfer(recipientAddress, transferAmount);
      // console.log("转账交易哈希:", transferTx.hash);
      // await transferTx.wait();
      // console.log("✅ 转账完成!");
      
      console.log("⚠️  转账代码已注释，如需执行请取消注释");
    }

    // 示例2: 授权操作
    console.log("\n🔐 查询授权信息...");
    const spenderAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6".toLowerCase(); // 示例地址
    const allowance = await myToken.allowance(signer.address, spenderAddress);
    console.log(`授权给 ${spenderAddress} 的金额: ${ethers.formatUnits(allowance, decimals)} ${symbol}`);

    // 示例3: 增发代币 (仅所有者可以执行)
    if (signer.address.toLowerCase() === owner.toLowerCase()) {
      console.log("\n🏭 所有者权限检测到，可以执行增发操作");
      console.log("⚠️  增发代码已注释，如需执行请取消注释");
      
      // const mintAmount = ethers.parseUnits("1000", decimals);
      // const mintTx = await myToken.mint(signer.address, mintAmount);
      // console.log("增发交易哈希:", mintTx.hash);
      // await mintTx.wait();
      // console.log("✅ 增发完成!");
    } else {
      console.log("\n⚠️  当前账户不是合约所有者，无法执行增发操作");
    }

    // 示例4: 批量转账
    console.log("\n📦 批量转账示例...");
    const recipients = [
      "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6",
      "0x8ba1f109551bD432803012645Hac136c30C6756M"
    ];
    const amounts = [
      ethers.parseUnits("5", decimals),
      ethers.parseUnits("3", decimals)
    ];
    
    console.log("批量转账目标:");
    recipients.forEach((addr, index) => {
      console.log(`  ${addr}: ${ethers.formatUnits(amounts[index], decimals)} ${symbol}`);
    });
    console.log("⚠️  批量转账代码已注释，如需执行请取消注释");

    // const batchTx = await myToken.batchTransfer(recipients, amounts);
    // console.log("批量转账交易哈希:", batchTx.hash);
    // await batchTx.wait();
    // console.log("✅ 批量转账完成!");

    console.log("\n🎉 合约交互演示完成!");
    console.log("\n💡 提示:");
    console.log("- 取消注释相应代码行即可执行实际交易");
    console.log("- 执行交易前请确保账户有足够的ETH支付gas费");
    console.log("- 在测试网上操作是安全的，不会消耗真实资金");

  } catch (error) {
    console.error("\n❌ 合约交互失败:", error.message);
    
    if (error.message.includes("call revert exception")) {
      console.error("💡 可能的原因:");
      console.error("- 合约地址不正确");
      console.error("- 网络连接问题");
      console.error("- 合约方法调用参数错误");
    }
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

module.exports = { main };
