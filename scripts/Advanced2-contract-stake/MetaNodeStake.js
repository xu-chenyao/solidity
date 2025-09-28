// scripts/Advanced2-contract-stake/MetaNodeStake.js
// MetaNodeStake合约部署脚本（Sepolia网络版本）

// 导入Hardhat的ethers库和upgrades插件
const { ethers, upgrades } = require("hardhat");

/**
 * @title MetaNodeStake Sepolia网络部署脚本
 * @dev 这是一个专门用于Sepolia测试网的部署脚本
 * 
 * 与主部署脚本的区别：
 * 1. 使用预设的MetaNodeToken地址（假设已在Sepolia上部署）
 * 2. 使用Sepolia网络的实际区块高度
 * 3. 配置适合测试网的参数
 * 4. 简化的部署流程
 * 
 * 注意：这个脚本假设MetaNodeToken已经部署并且地址已知
 */

/**
 * 主执行函数
 */
async function main() {
  console.log("🚀 开始部署MetaNodeStake到Sepolia测试网...");
  
  // ============================= 第一步：配置部署参数 =============================
  
  console.log("⚙️ 配置部署参数...");
  
  // MetaNodeToken地址（假设已在Sepolia上部署）
  // 注意：这个地址需要替换为实际部署的MetaNodeToken地址
  const MetaNodeToken = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  console.log("📍 MetaNodeToken地址:", MetaNodeToken);
  
  // 质押挖矿开始区块高度
  // 可以通过访问 https://sepolia.etherscan.io/ 获取最新区块高度
  const startBlock = 6529999;
  console.log("📅 开始区块:", startBlock);
  
  // 质押挖矿结束区块高度
  // Sepolia网络出块时间约12秒
  // 计算公式：如果想要质押合约运行 x 秒，那么 endBlock = startBlock + x/12
  // 这里设置为运行约100天：(9529999 - 6529999) * 12秒 / (24*3600) ≈ 41.7天
  const endBlock = 9529999;
  console.log("📅 结束区块:", endBlock);
  
  // 计算运行时间
  const durationBlocks = endBlock - startBlock;
  const durationDays = (durationBlocks * 12) / (24 * 3600);
  console.log(`⏰ 预计运行时间: ${durationBlocks} 个区块 (约 ${durationDays.toFixed(1)} 天)`);
  
  // 每个区块奖励的MetaNode代币数量
  // "20000000000000000" = 0.02 MetaNode (18位精度)
  const MetaNodePerBlock = "20000000000000000";
  console.log("🎁 每区块奖励:", ethers.formatUnits(MetaNodePerBlock, 18), "MetaNode");
  
  // 计算总奖励量
  const totalRewards = BigInt(durationBlocks) * BigInt(MetaNodePerBlock);
  console.log("🏆 总奖励池:", ethers.formatUnits(totalRewards, 18), "MetaNode");

  // ============================= 第二步：获取合约工厂 =============================
  
  console.log("\n🏭 获取合约工厂...");
  
  // 获取MetaNodeStake合约工厂
  // 注意：这里使用了全局变量hre，也可以直接使用ethers
  const Stake = await hre.ethers.getContractFactory("MetaNodeStake");
  console.log("✅ MetaNodeStake合约工厂获取成功");

  // ============================= 第三步：部署可升级合约 =============================
  
  console.log("\n📦 部署可升级代理合约...");
  console.log("Deploying MetaNodeStake...");
  
  console.log("📋 初始化参数:");
  console.log(`  MetaNodeToken: ${MetaNodeToken}`);
  console.log(`  startBlock: ${startBlock}`);
  console.log(`  endBlock: ${endBlock}`);
  console.log(`  MetaNodePerBlock: ${MetaNodePerBlock}`);
  
  try {
    // 使用upgrades.deployProxy部署可升级合约
    const s = await upgrades.deployProxy(
      Stake,                                                    // 合约工厂
      [MetaNodeToken, startBlock, endBlock, MetaNodePerBlock], // 初始化参数数组
      { initializer: "initialize" }                            // 初始化函数名
    );
    
    console.log("⏳ 等待合约部署完成...");
    // 注意：在新版本的ethers中，不需要调用deployed()
    // await s.deployed(); // 这行在新版本中已被弃用
    
    // 获取合约地址
    const contractAddress = await s.getAddress();
    console.log("✅ 合约部署成功");
    console.log("📍 MetaNodeStake地址:", contractAddress);
    
    // 兼容原脚本输出格式
    console.log("Box deployed to:", contractAddress);
    
  } catch (error) {
    console.error("❌ 合约部署失败:");
    console.error("💥 错误信息:", error.message);
    
    // 常见错误处理提示
    if (error.message.includes("invalid parameters")) {
      console.log("💡 可能原因：初始化参数无效");
    } else if (error.message.includes("insufficient funds")) {
      console.log("💡 可能原因：账户余额不足");
    } else if (error.message.includes("network")) {
      console.log("💡 可能原因：网络连接问题");
    }
    
    throw error;
  }

  // ============================= 第四步：输出部署信息 =============================
  
  console.log("\n🎉 ========== 部署完成 ==========");
  console.log("✅ MetaNodeStake合约部署成功");
  
  console.log("\n📊 部署参数总结:");
  console.log(`网络: Sepolia测试网`);
  console.log(`MetaNodeToken: ${MetaNodeToken}`);
  console.log(`开始区块: ${startBlock}`);
  console.log(`结束区块: ${endBlock}`);
  console.log(`每区块奖励: ${ethers.formatUnits(MetaNodePerBlock, 18)} MetaNode`);
  console.log(`预计运行: ${durationDays.toFixed(1)} 天`);
  console.log(`总奖励池: ${ethers.formatUnits(totalRewards, 18)} MetaNode`);
  
  console.log("\n📝 后续步骤:");
  console.log("1. 确保MetaNodeStake合约有足够的MetaNode代币作为奖励");
  console.log("2. 运行addPool脚本添加资金池");
  console.log("3. 测试质押和奖励功能");
  console.log("4. 在Etherscan上验证合约代码");
  
  console.log("\n⚠️ 重要提醒:");
  console.log("- 请确认MetaNodeToken地址正确");
  console.log("- 确保有足够的Sepolia ETH支付gas费");
  console.log("- 在主网部署前请充分测试");
}

// ============================= 脚本执行入口 =============================

// 执行主函数并处理结果
main()
  .then(() => {
    console.log("\n🎊 脚本成功完成");
    process.exit(0);  // 正常退出
  })
  .catch((error) => {
    console.error("\n💥 脚本执行失败:");
    console.error("错误信息:", error.message);
    process.exit(1);  // 错误退出
  });