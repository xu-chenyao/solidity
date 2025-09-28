// scripts/Advanced2-contract-stake/tokenInteract.js
// MetaNodeStake合约交互脚本 - 用于查询和测试合约功能

// 导入Hardhat的ethers库
const { ethers } = require('hardhat')

/**
 * @title MetaNodeStake合约交互脚本
 * @dev 这个脚本用于与已部署的MetaNodeStake合约进行交互和测试
 * 
 * 主要功能：
 * 1. 连接到已部署的MetaNodeStake合约
 * 2. 查询合约状态和配置信息
 * 3. 测试合约的各种功能
 * 4. 演示如何与合约进行交互
 * 
 * 使用场景：
 * - 验证合约部署是否成功
 * - 查询合约配置参数
 * - 测试合约功能是否正常
 * - 调试合约问题
 */

/**
 * 主执行函数
 */
async function main() {
  console.log("🔍 开始与MetaNodeStake合约交互...");

  // ============================= 第一步：连接合约 =============================
  
  console.log("🔗 连接到MetaNodeStake合约...");
  
  // MetaNodeStake合约地址
  // 注意：这个地址需要替换为实际部署的合约地址
  const STAKE_CONTRACT_ADDRESS = '0x62b7C03E5A42fedE09D1b862Cb7936B26fDc5c1e';
  console.log("📍 目标合约地址:", STAKE_CONTRACT_ADDRESS);
  
  try {
    // 获取合约实例
    // 注意：原代码缺少await关键字，这里已修复
    const stakeContract = await ethers.getContractAt('MetaNodeStake', STAKE_CONTRACT_ADDRESS);
    console.log("✅ 合约连接成功");

    // ============================= 第二步：查询MetaNode代币地址 =============================
    
    console.log("\n📊 查询合约基本信息...");
    
    // 查询MetaNode代币地址
    console.log("🔍 查询MetaNode代币地址...");
    const data = await stakeContract.MetaNode();
    console.log("📍 MetaNode代币地址:", data);
    
    // 兼容原脚本输出格式
    console.log("原始查询结果:", data);

    // ============================= 第三步：查询更多合约信息 =============================
    
    console.log("\n📋 查询更多合约状态信息...");
    
    try {
      // 查询挖矿参数
      const startBlock = await stakeContract.startBlock();
      const endBlock = await stakeContract.endBlock();
      const metaNodePerBlock = await stakeContract.MetaNodePerBlock();
      
      console.log("⚙️ 挖矿参数:");
      console.log(`  开始区块: ${startBlock}`);
      console.log(`  结束区块: ${endBlock}`);
      console.log(`  每区块奖励: ${ethers.formatUnits(metaNodePerBlock, 18)} MetaNode`);
      
      // 查询资金池信息
      const poolLength = await stakeContract.poolLength();
      const totalPoolWeight = await stakeContract.totalPoolWeight();
      
      console.log("🏊 资金池信息:");
      console.log(`  资金池数量: ${poolLength}`);
      console.log(`  总池权重: ${totalPoolWeight}`);
      
      // 查询暂停状态
      const withdrawPaused = await stakeContract.withdrawPaused();
      const claimPaused = await stakeContract.claimPaused();
      
      console.log("⏸️ 暂停状态:");
      console.log(`  提取暂停: ${withdrawPaused ? '是' : '否'}`);
      console.log(`  领取暂停: ${claimPaused ? '是' : '否'}`);
      
    } catch (error) {
      console.warn("⚠️ 查询部分信息失败:", error.message);
    }

    // ============================= 第四步：查询资金池详情 =============================
    
    console.log("\n🏊 查询资金池详情...");
    
    try {
      const poolLength = await stakeContract.poolLength();
      
      if (poolLength > 0) {
        // 查询第一个资金池（通常是ETH池）
        const poolInfo = await stakeContract.pool(0);
        
        console.log("📋 资金池 0 详情:");
        console.log(`  质押代币地址: ${poolInfo.stTokenAddress} ${poolInfo.stTokenAddress === ethers.ZeroAddress ? '(ETH池)' : '(ERC20池)'}`);
        console.log(`  池权重: ${poolInfo.poolWeight}`);
        console.log(`  上次奖励区块: ${poolInfo.lastRewardBlock}`);
        console.log(`  累积奖励: ${poolInfo.accMetaNodePerST}`);
        console.log(`  质押总量: ${ethers.formatEther(poolInfo.stTokenAmount)} ${poolInfo.stTokenAddress === ethers.ZeroAddress ? 'ETH' : 'tokens'}`);
        console.log(`  最小质押量: ${poolInfo.minDepositAmount}`);
        console.log(`  锁定区块数: ${poolInfo.unstakeLockedBlocks}`);
      } else {
        console.log("📭 暂无资金池");
      }
      
    } catch (error) {
      console.warn("⚠️ 查询资金池信息失败:", error.message);
    }

    // ============================= 第五步：查询当前用户信息 =============================
    
    console.log("\n👤 查询当前用户信息...");
    
    try {
      const [signer] = await ethers.getSigners();
      console.log("📍 当前用户地址:", signer.address);
      
      const poolLength = await stakeContract.poolLength();
      
      if (poolLength > 0) {
        // 查询用户在第一个池的信息
        const userInfo = await stakeContract.user(0, signer.address);
        const stakingBalance = await stakeContract.stakingBalance(0, signer.address);
        
        console.log("📊 用户在池 0 的信息:");
        console.log(`  质押数量: ${ethers.formatEther(userInfo.stAmount)} ETH`);
        console.log(`  已结算奖励: ${ethers.formatUnits(userInfo.finishedMetaNode, 18)} MetaNode`);
        console.log(`  待领取奖励: ${ethers.formatUnits(userInfo.pendingMetaNode, 18)} MetaNode`);
        console.log(`  提取请求数: ${userInfo.requests.length}`);
        console.log(`  质押余额确认: ${ethers.formatEther(stakingBalance)} ETH`);
        
        // 查询实时待领取奖励
        try {
          const pendingReward = await stakeContract.pendingMetaNode(0, signer.address);
          console.log(`  实时待领取: ${ethers.formatUnits(pendingReward, 18)} MetaNode`);
        } catch (error) {
          console.warn("  ⚠️ 无法查询实时奖励:", error.message);
        }
      }
      
    } catch (error) {
      console.warn("⚠️ 查询用户信息失败:", error.message);
    }

  } catch (error) {
    console.error("❌ 合约连接失败:");
    console.error("💥 错误信息:", error.message);
    
    // 常见错误处理提示
    if (error.message.includes("could not detect network")) {
      console.log("💡 可能原因：网络配置问题");
    } else if (error.message.includes("invalid address")) {
      console.log("💡 可能原因：合约地址无效");
    } else if (error.message.includes("contract not deployed")) {
      console.log("💡 可能原因：合约未部署或地址错误");
    }
    
    throw error;
  }

  console.log("\n🎉 合约交互完成！");
  console.log("\n📝 可用的交互操作:");
  console.log("1. depositETH() - 质押ETH");
  console.log("2. claim(poolId) - 领取奖励");
  console.log("3. unstake(poolId, amount) - 申请提取");
  console.log("4. withdraw(poolId) - 提取已解锁的代币");
  console.log("5. pendingMetaNode(poolId, user) - 查询待领取奖励");
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