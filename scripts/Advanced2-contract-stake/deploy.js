// scripts/Advanced2-contract-stake/deploy.js
// MetaNode质押系统完整部署脚本

// 导入Hardhat的ethers库和upgrades插件
const { ethers, upgrades } = require("hardhat");

/**
 * @title MetaNode质押系统部署脚本
 * @dev 这个脚本负责部署完整的MetaNode质押挖矿系统
 * 
 * 部署流程：
 * 1. 部署MetaNodeToken代币合约（奖励代币）
 * 2. 部署MetaNodeStake质押合约（使用UUPS代理模式）
 * 3. 将所有MetaNode代币转移到质押合约作为奖励池
 * 4. 输出部署信息供后续使用
 */
async function main() {
  console.log("🚀 开始部署MetaNode质押系统...");
  
  // ============================= 第一步：获取部署账户 =============================
  
  // 获取部署者账户（第一个签名者）
  const [signer] = await ethers.getSigners();
  console.log("👤 部署账户:", signer.address);
  
  // 查询并显示账户余额
  const balance = await ethers.provider.getBalance(signer.address);
  console.log("💰 账户余额:", ethers.formatEther(balance), "ETH");

  // ============================= 第二步：部署MetaNodeToken代币 =============================
  
  console.log("\n🪙 第2步：部署MetaNodeToken奖励代币...");
  
  // 获取MetaNodeToken合约工厂
  const MetaNodeToken = await ethers.getContractFactory('MetaNodeToken');
  console.log("✅ MetaNodeToken合约工厂获取成功");
  
  // 部署MetaNodeToken合约（无构造函数参数）
  const metaNodeToken = await MetaNodeToken.deploy();
  console.log("⏳ 正在部署MetaNodeToken...");
  
  // 等待部署完成
  await metaNodeToken.waitForDeployment();
  console.log("✅ MetaNodeToken部署成功");
  
  // 获取部署后的合约地址
  const metaNodeTokenAddress = await metaNodeToken.getAddress();
  console.log("📍 MetaNodeToken地址:", metaNodeTokenAddress);
  
  // 查询代币基本信息
  const totalSupply = await metaNodeToken.totalSupply();
  console.log("📊 代币总供应量:", ethers.formatUnits(totalSupply, 18), "MetaNode");

  // ============================= 第三步：部署MetaNodeStake质押合约 =============================

  console.log("\n🏦 第3步：部署MetaNodeStake质押合约...");
  
  // 获取MetaNodeStake合约工厂
  const MetaNodeStake = await ethers.getContractFactory("MetaNodeStake");
  console.log("✅ MetaNodeStake合约工厂获取成功");

  // ============================= 配置初始化参数 =============================
  
  console.log("⚙️ 配置合约初始化参数...");
  
  // 质押挖矿开始区块（设置为较小值用于测试）
  const startBlock = 1;
  console.log("📅 开始区块号:", startBlock);
  
  // 质押挖矿结束区块（设置为极大值，基本不会结束）
  const endBlock = 999999999999;
  console.log("📅 结束区块号:", endBlock);
  
  // 每个区块的MetaNode奖励数量（1个代币，18位精度）
  const metaNodePerBlock = ethers.parseUnits("1", 18);
  console.log("🎁 每区块奖励:", ethers.formatUnits(metaNodePerBlock, 18), "MetaNode");

  // ============================= 部署可升级代理合约 =============================
  
  console.log("📦 部署UUPS代理合约...");
  console.log("📋 初始化参数:");
  console.log("  - MetaNode代币地址:", metaNodeTokenAddress);
  console.log("  - 开始区块:", startBlock);
  console.log("  - 结束区块:", endBlock);
  console.log("  - 每区块奖励:", ethers.formatUnits(metaNodePerBlock, 18));
  
  // 使用upgrades.deployProxy部署可升级合约
  const stake = await upgrades.deployProxy(
    MetaNodeStake,                                          // 合约工厂
    [metaNodeTokenAddress, startBlock, endBlock, metaNodePerBlock], // 初始化参数数组
    { initializer: "initialize" }                           // 初始化函数名
  );

  console.log("⏳ 等待代理合约部署...");
  // 等待代理合约部署完成
  await stake.waitForDeployment();
  console.log("✅ 代理合约部署成功");
  
  // 获取代理合约地址
  const stakeAddress = await stake.getAddress();
  console.log("📍 质押合约地址:", stakeAddress);

  // ============================= 第四步：转移代币到质押合约 =============================

  console.log("\n💰 第4步：转移代币到质押合约...");
  
  // 查询部署者当前的MetaNode余额
  const tokenAmount = await metaNodeToken.balanceOf(signer.address);
  console.log("📊 转移前部署者余额:", ethers.formatUnits(tokenAmount, 18), "MetaNode");
  console.log("📊 转移数量:", ethers.formatUnits(tokenAmount, 18), "MetaNode");
  console.log("📍 目标地址:", stakeAddress);
  
  // 执行代币转移交易
  console.log("⏳ 正在转移代币...");
  let tx = await metaNodeToken.connect(signer).transfer(stakeAddress, tokenAmount);
  
  // 等待交易确认
  const receipt = await tx.wait();
  console.log("✅ 代币转移成功");
  console.log("🔗 交易哈希:", receipt.hash);
  
  // 验证转移结果
  const stakeContractBalance = await metaNodeToken.balanceOf(stakeAddress);
  console.log("📊 转移后质押合约余额:", ethers.formatUnits(stakeContractBalance, 18), "MetaNode");

  // ============================= 第五步：输出部署总结 =============================

  console.log("\n🎉 ========== 部署完成总结 ==========");
  console.log("✅ 所有合约部署成功");
  console.log("✅ 代币转移完成");
  
  console.log("\n📋 重要地址信息:");
  console.log(`MetaNodeToken (代币): ${metaNodeTokenAddress}`);
  console.log(`MetaNodeStake (质押): ${stakeAddress}`);
  console.log(`部署者地址: ${signer.address}`);
  
  console.log("\n⚙️ 系统参数:");
  console.log(`挖矿期间: 区块 ${startBlock} - ${endBlock}`);
  console.log(`每区块奖励: ${ethers.formatUnits(metaNodePerBlock, 18)} MetaNode`);
  console.log(`总奖励池: ${ethers.formatUnits(stakeContractBalance, 18)} MetaNode`);
  
  console.log("\n📝 后续操作建议:");
  console.log("1. 运行 addPool.js 脚本添加资金池");
  console.log("2. 测试质押功能");
  console.log("3. 验证合约源码");
  
  // 最终输出主要地址（兼容原脚本格式）
  console.log("\nMetaNodeStake (proxy) deployed to:", stakeAddress);
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
    console.error("错误堆栈:", error.stack);
    process.exit(1);  // 错误退出
  });