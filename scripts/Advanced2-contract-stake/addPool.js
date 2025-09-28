// scripts/Advanced2-contract-stake/addPool.js
// 添加资金池脚本 - 为MetaNode质押系统添加新的质押池

// 导入Hardhat的ethers库
const { ethers } = require("hardhat");

/**
 * @title 添加资金池脚本
 * @dev 这个脚本用于向已部署的MetaNodeStake合约添加新的资金池
 * 
 * 功能说明：
 * 1. 连接到已部署的MetaNodeStake合约
 * 2. 添加ETH质押池（第一个池必须是ETH池）
 * 3. 配置池权重、最小质押量、锁定期等参数
 * 
 * 重要说明：
 * - 第一个池（ID=0）必须是ETH池，stTokenAddress为address(0)
 * - 每个池的权重决定了奖励分配比例
 * - 锁定期防止短期投机，建议设置合理的锁定时间
 * - 最小质押量防止粉尘攻击和gas浪费
 */

/**
 * 主执行函数
 */
async function main() {
  console.log("🏊 开始添加资金池...");
  
  // ============================= 第一步：连接合约 =============================
  
  console.log("🔗 连接到MetaNodeStake合约...");
  
  // 注意：这里需要替换为实际部署的合约地址
  // 生产环境中应该从配置文件或环境变量中读取
  const METANODE_STAKE_ADDRESS = "0xF136927bB54709e548fC77F7ee9947b5Ef3136ff";
  
  // 用于本地测试的地址示例：
  // 如果在本地测试网运行，请使用以下地址格式：
  // 1. 启动本地节点: npx hardhat node
  // 2. 部署合约: npx hardhat run scripts/deploy.js --network localhost
  // 3. 使用部署后获得的合约地址替换上面的地址
  // const METANODE_STAKE_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  
  console.log("📍 目标合约地址:", METANODE_STAKE_ADDRESS);
  
  // 获取合约实例
  // getContractAt会根据ABI和地址创建合约实例，无需重新部署
  const MetaNodeStake = await ethers.getContractAt("MetaNodeStake", METANODE_STAKE_ADDRESS);
  console.log("✅ 合约连接成功");
  
  // 获取调用者账户信息
  const [signer] = await ethers.getSigners();
  console.log("👤 调用者地址:", signer.address);

  // ============================= 第二步：配置资金池参数 =============================
  
  console.log("\n⚙️ 配置新资金池参数...");
  
  // 资金池配置参数
  const poolConfig = {
    // 质押代币地址：ethers.ZeroAddress (address(0)) 表示ETH池
    stTokenAddress: ethers.ZeroAddress,
    
    // 池权重：决定该池在总奖励中的分配比例
    // 例如：总权重1000，该池权重500，则该池获得50%的奖励
    poolWeight: 500,
    
    // 最小质押数量：防止粉尘攻击和gas浪费
    // 这里设置为100 wei（极小值，主要用于测试）
    minDepositAmount: 100,
    
    // 提取锁定区块数：用户申请提取后需要等待的区块数
    // 20个区块，假设15秒一个区块，约5分钟锁定期
    unstakeLockedBlocks: 20,
    
    // 是否在添加池时更新所有池的奖励状态
    // true: 会消耗更多gas但确保奖励计算准确
    withUpdate: true
  };
  
  console.log("📋 资金池配置:");
  console.log(`  质押代币地址: ${poolConfig.stTokenAddress} (${poolConfig.stTokenAddress === ethers.ZeroAddress ? 'ETH池' : 'ERC20池'})`);
  console.log(`  池权重: ${poolConfig.poolWeight}`);
  console.log(`  最小质押量: ${poolConfig.minDepositAmount} wei`);
  console.log(`  锁定区块数: ${poolConfig.unstakeLockedBlocks} 个区块`);
  console.log(`  同时更新池: ${poolConfig.withUpdate ? '是' : '否'}`);

  // ============================= 第三步：添加资金池 =============================
  
  console.log("\n🏊 添加资金池...");
  
  try {
    console.log("📤 发送添加资金池交易...");
    console.log("📋 交易参数:");
    console.log(`  stTokenAddress: ${poolConfig.stTokenAddress}`);
    console.log(`  poolWeight: ${poolConfig.poolWeight}`);
    console.log(`  minDepositAmount: ${poolConfig.minDepositAmount}`);
    console.log(`  unstakeLockedBlocks: ${poolConfig.unstakeLockedBlocks}`);
    console.log(`  withUpdate: ${poolConfig.withUpdate}`);
    
    // 调用addPool函数
    const tx = await MetaNodeStake.addPool(
      poolConfig.stTokenAddress,      // 质押代币地址（ETH为零地址）
      poolConfig.poolWeight,          // 池权重
      poolConfig.minDepositAmount,    // 最小质押量
      poolConfig.unstakeLockedBlocks, // 锁定区块数
      poolConfig.withUpdate           // 是否更新所有池
    );
    
    console.log("✅ 交易已发送");
    console.log("🔗 交易哈希:", tx.hash);
    
    // 等待交易确认
    console.log("⏳ 等待交易确认...");
    const receipt = await tx.wait();
    
    console.log("✅ 交易已确认");
    console.log("📦 区块号:", receipt.blockNumber);
    console.log("⛽ Gas消耗:", receipt.gasUsed.toString());
    
    // 输出交易对象（兼容原脚本）
    console.log("\n📄 交易详情:");
    console.log(tx);
    
  } catch (error) {
    console.error("❌ 添加资金池失败:");
    console.error("💥 错误信息:", error.message);
    
    // 常见错误处理提示
    if (error.message.includes("admin_role")) {
      console.log("💡 可能原因：没有管理员权限");
    } else if (error.message.includes("invalid staking token address")) {
      console.log("💡 可能原因：第一个池必须是ETH池（地址为0），其他池不能是ETH池");
    } else if (error.message.includes("Already ended")) {
      console.log("💡 可能原因：挖矿已结束，无法添加新资金池");
    } else if (error.message.includes("insufficient funds")) {
      console.log("💡 可能原因：账户余额不足支付gas费");
    }
    
    throw error; // 重新抛出错误以便外层处理
  }

  // ============================= 第四步：验证添加结果 =============================
  
  console.log("\n🔍 验证资金池添加结果...");
  
  try {
    // 查询更新后的合约状态
    const poolLength = await MetaNodeStake.poolLength();
    const totalPoolWeight = await MetaNodeStake.totalPoolWeight();
    
    console.log("📊 更新后状态:");
    console.log(`  资金池数量: ${poolLength}`);
    console.log(`  总池权重: ${totalPoolWeight}`);
    
    // 查询新添加的资金池信息（假设是第一个池）
    if (poolLength > 0) {
      const newPoolId = poolLength - 1n; // 最新池的ID
      const poolInfo = await MetaNodeStake.pool(newPoolId);
      
      console.log(`\n📋 新资金池信息 (ID: ${newPoolId}):`);
      console.log(`  质押代币地址: ${poolInfo.stTokenAddress}`);
      console.log(`  池权重: ${poolInfo.poolWeight}`);
      console.log(`  上次奖励区块: ${poolInfo.lastRewardBlock}`);
      console.log(`  累积奖励: ${poolInfo.accMetaNodePerST}`);
      console.log(`  质押总量: ${poolInfo.stTokenAmount}`);
      console.log(`  最小质押量: ${poolInfo.minDepositAmount}`);
      console.log(`  锁定区块数: ${poolInfo.unstakeLockedBlocks}`);
    }
    
  } catch (error) {
    console.warn("⚠️ 验证失败，但资金池可能已成功添加:", error.message);
  }

  console.log("\n🎉 资金池添加完成！");
  console.log("📝 后续操作:");
  console.log("1. 用户现在可以调用 depositETH() 函数质押ETH");
  console.log("2. 用户可以调用 claim() 函数领取奖励");
  console.log("3. 用户可以调用 unstake() 和 withdraw() 函数提取质押");
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