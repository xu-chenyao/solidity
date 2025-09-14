const { ethers } = require("hardhat");

/**
 * @title MyToken功能演示脚本
 * @dev 演示ERC20代币的各种功能
 * @author xuchenyao
 */

async function main() {
  console.log("🎯 MyToken ERC20代币功能演示\n");

  // 获取测试账户
  const [owner, user1, user2, user3] = await ethers.getSigners();
  
  console.log("👥 测试账户:");
  console.log(`   所有者: ${owner.address}`);
  console.log(`   用户1: ${user1.address}`);
  console.log(`   用户2: ${user2.address}`);
  console.log(`   用户3: ${user3.address}\n`);

  try {
    // 部署合约
    console.log("📦 部署MyToken合约...");
    const MyToken = await ethers.getContractFactory("MyToken");
    const myToken = await MyToken.deploy(
      "MyToken",    // 名称
      "MTK",        // 符号
      18,           // 精度
      1000000       // 初始供应量100万
    );
    await myToken.waitForDeployment();
    
    const contractAddress = await myToken.getAddress();
    console.log("✅ 合约部署成功:", contractAddress);

    // 获取代币基本信息
    console.log("\n📋 代币基本信息:");
    console.log(`   名称: ${await myToken.name()}`);
    console.log(`   符号: ${await myToken.symbol()}`);
    console.log(`   精度: ${await myToken.decimals()}`);
    console.log(`   总供应量: ${ethers.formatUnits(await myToken.totalSupply(), 18)} MTK`);
    console.log(`   合约所有者: ${await myToken.owner()}`);

    // 1. 余额查询演示
    console.log("\n=== 1. 余额查询演示 ===");
    const ownerBalance = await myToken.balanceOf(owner.address);
    console.log(`所有者余额: ${ethers.formatUnits(ownerBalance, 18)} MTK`);
    console.log(`用户1余额: ${ethers.formatUnits(await myToken.balanceOf(user1.address), 18)} MTK`);

    // 2. 转账功能演示
    console.log("\n=== 2. 转账功能演示 ===");
    const transferAmount = ethers.parseUnits("1000", 18); // 转账1000 MTK
    
    console.log(`转账前 - 所有者: ${ethers.formatUnits(await myToken.balanceOf(owner.address), 18)} MTK`);
    console.log(`转账前 - 用户1: ${ethers.formatUnits(await myToken.balanceOf(user1.address), 18)} MTK`);
    
    const transferTx = await myToken.transfer(user1.address, transferAmount);
    await transferTx.wait();
    console.log("✅ 转账成功!");
    
    console.log(`转账后 - 所有者: ${ethers.formatUnits(await myToken.balanceOf(owner.address), 18)} MTK`);
    console.log(`转账后 - 用户1: ${ethers.formatUnits(await myToken.balanceOf(user1.address), 18)} MTK`);

    // 3. 授权功能演示
    console.log("\n=== 3. 授权功能演示 ===");
    const approveAmount = ethers.parseUnits("500", 18); // 授权500 MTK
    
    console.log(`授权前 - 用户2对所有者的授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);
    
    const approveTx = await myToken.approve(user2.address, approveAmount);
    await approveTx.wait();
    console.log("✅ 授权成功!");
    
    console.log(`授权后 - 用户2对所有者的授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);

    // 4. 代扣转账功能演示
    console.log("\n=== 4. 代扣转账功能演示 ===");
    const transferFromAmount = ethers.parseUnits("200", 18); // 代扣转账200 MTK
    
    console.log(`代扣转账前 - 所有者: ${ethers.formatUnits(await myToken.balanceOf(owner.address), 18)} MTK`);
    console.log(`代扣转账前 - 用户3: ${ethers.formatUnits(await myToken.balanceOf(user3.address), 18)} MTK`);
    console.log(`代扣转账前 - 剩余授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);
    
    // 用户2代表所有者转账给用户3
    const transferFromTx = await myToken.connect(user2).transferFrom(owner.address, user3.address, transferFromAmount);
    await transferFromTx.wait();
    console.log("✅ 代扣转账成功!");
    
    console.log(`代扣转账后 - 所有者: ${ethers.formatUnits(await myToken.balanceOf(owner.address), 18)} MTK`);
    console.log(`代扣转账后 - 用户3: ${ethers.formatUnits(await myToken.balanceOf(user3.address), 18)} MTK`);
    console.log(`代扣转账后 - 剩余授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);

    // 5. 增发功能演示
    console.log("\n=== 5. 增发功能演示 ===");
    const mintAmount = ethers.parseUnits("10000", 18); // 增发10000 MTK
    
    console.log(`增发前 - 总供应量: ${ethers.formatUnits(await myToken.totalSupply(), 18)} MTK`);
    console.log(`增发前 - 用户1余额: ${ethers.formatUnits(await myToken.balanceOf(user1.address), 18)} MTK`);
    
    const mintTx = await myToken.mint(user1.address, mintAmount);
    await mintTx.wait();
    console.log("✅ 增发成功!");
    
    console.log(`增发后 - 总供应量: ${ethers.formatUnits(await myToken.totalSupply(), 18)} MTK`);
    console.log(`增发后 - 用户1余额: ${ethers.formatUnits(await myToken.balanceOf(user1.address), 18)} MTK`);

    // 6. 辅助功能演示
    console.log("\n=== 6. 辅助功能演示 ===");
    
    // 增加授权额度
    const increaseAmount = ethers.parseUnits("100", 18);
    console.log(`增加授权前 - 授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);
    
    const increaseTx = await myToken.increaseAllowance(user2.address, increaseAmount);
    await increaseTx.wait();
    console.log("✅ 增加授权额度成功!");
    
    console.log(`增加授权后 - 授权额度: ${ethers.formatUnits(await myToken.allowance(owner.address, user2.address), 18)} MTK`);

    // 批量转账
    console.log("\n--- 批量转账演示 ---");
    const recipients = [user1.address, user2.address, user3.address];
    const amounts = [
      ethers.parseUnits("50", 18),
      ethers.parseUnits("75", 18),
      ethers.parseUnits("25", 18)
    ];
    
    console.log("批量转账前余额:");
    for (let i = 0; i < recipients.length; i++) {
      const balance = await myToken.balanceOf(recipients[i]);
      console.log(`   用户${i+1}: ${ethers.formatUnits(balance, 18)} MTK`);
    }
    
    const batchTx = await myToken.batchTransfer(recipients, amounts);
    await batchTx.wait();
    console.log("✅ 批量转账成功!");
    
    console.log("批量转账后余额:");
    for (let i = 0; i < recipients.length; i++) {
      const balance = await myToken.balanceOf(recipients[i]);
      console.log(`   用户${i+1}: ${ethers.formatUnits(balance, 18)} MTK`);
    }

    // 7. 所有权管理演示
    console.log("\n=== 7. 所有权管理演示 ===");
    console.log(`当前所有者: ${await myToken.owner()}`);
    
    // 转移所有权给用户1
    const transferOwnershipTx = await myToken.transferOwnership(user1.address);
    await transferOwnershipTx.wait();
    console.log("✅ 所有权转移成功!");
    
    console.log(`新所有者: ${await myToken.owner()}`);
    
    // 新所有者尝试增发
    const newMintAmount = ethers.parseUnits("5000", 18);
    const newMintTx = await myToken.connect(user1).mint(user2.address, newMintAmount);
    await newMintTx.wait();
    console.log("✅ 新所有者增发成功!");
    
    console.log(`增发后 - 用户2余额: ${ethers.formatUnits(await myToken.balanceOf(user2.address), 18)} MTK`);
    console.log(`增发后 - 总供应量: ${ethers.formatUnits(await myToken.totalSupply(), 18)} MTK`);

    // 8. 最终状态总结
    console.log("\n=== 8. 最终状态总结 ===");
    console.log("📊 所有账户余额:");
    const finalOwnerBalance = await myToken.balanceOf(owner.address);
    const finalUser1Balance = await myToken.balanceOf(user1.address);
    const finalUser2Balance = await myToken.balanceOf(user2.address);
    const finalUser3Balance = await myToken.balanceOf(user3.address);
    const finalTotalSupply = await myToken.totalSupply();
    
    console.log(`   原所有者: ${ethers.formatUnits(finalOwnerBalance, 18)} MTK`);
    console.log(`   用户1(新所有者): ${ethers.formatUnits(finalUser1Balance, 18)} MTK`);
    console.log(`   用户2: ${ethers.formatUnits(finalUser2Balance, 18)} MTK`);
    console.log(`   用户3: ${ethers.formatUnits(finalUser3Balance, 18)} MTK`);
    console.log(`   总供应量: ${ethers.formatUnits(finalTotalSupply, 18)} MTK`);
    
    // 验证总供应量等于所有余额之和
    const totalBalances = finalOwnerBalance + finalUser1Balance + finalUser2Balance + finalUser3Balance;
    console.log(`\n🔍 验证: 总余额 = ${ethers.formatUnits(totalBalances, 18)} MTK`);
    console.log(`   ${totalBalances.toString() === finalTotalSupply.toString() ? '✅ 余额验证通过' : '❌ 余额验证失败'}`);

    // 9. 事件日志演示
    console.log("\n=== 9. 事件日志演示 ===");
    
    // 查询最近的Transfer事件
    const transferFilter = myToken.filters.Transfer();
    const transferEvents = await myToken.queryFilter(transferFilter, -2); 
    
    console.log(`📝 最近的Transfer事件 (${transferEvents.length}个):`);
    transferEvents.slice(-3).forEach((event, index) => {
      const args = event.args;
      console.log(`   ${index + 1}. ${args.from} → ${args.to}: ${ethers.formatUnits(args.value, 18)} MTK`);
    });

    console.log("\n🎉 所有功能演示完成!");
    
    // 返回合约地址供后续使用
    return {
      contractAddress: contractAddress,
      contract: myToken
    };

  } catch (error) {
    console.error("\n❌ 演示过程中出错:", error.message);
    console.error("错误详情:", error);
    throw error;
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main()
    .then(() => {
      console.log("\n✅ 演示脚本执行完成");
      process.exit(0);
    })
    .catch((error) => {
      console.error("\n❌ 演示脚本执行失败:", error);
      process.exit(1);
    });
}

// 导出main函数供其他脚本使用
module.exports = { main };
