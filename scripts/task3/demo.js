const { ethers } = require("hardhat");

/**
 * NFT 拍卖市场演示脚本
 * 展示完整的拍卖流程：创建拍卖、出价、结束拍卖
 */

async function main() {
  console.log("🎭 NFT 拍卖市场演示开始...");
  
  // 获取账户
  const [deployer, seller, bidder1, bidder2, bidder3] = await ethers.getSigners();
  console.log("参与者:");
  console.log("  部署者:", deployer.address);
  console.log("  卖家:", seller.address);
  console.log("  出价者1:", bidder1.address);
  console.log("  出价者2:", bidder2.address);
  console.log("  出价者3:", bidder3.address);

  // 读取最新的部署信息
  const fs = require('fs');
  const path = require('path');
  const deployDir = path.join(__dirname, '..', '..', 'deployments');
  
  const deployFiles = fs.readdirSync(deployDir)
    .filter(f => f.startsWith('localhost-') && f.endsWith('.json'))
    .sort()
    .reverse();
  
  if (deployFiles.length === 0) {
    console.error("❌ 未找到部署文件，请先运行部署脚本");
    return;
  }
  
  const deploymentInfo = JSON.parse(
    fs.readFileSync(path.join(deployDir, deployFiles[0]), 'utf8')
  );
  
  console.log("\n📄 使用部署信息:", deployFiles[0]);

  // 获取合约实例
  const auctionNFT = await ethers.getContractAt("AuctionNFT", deploymentInfo.contracts.auctionNFT);
  const auctionFactory = await ethers.getContractAt("AuctionFactory", deploymentInfo.contracts.auctionFactory);
  const priceOracle = await ethers.getContractAt("MockPriceOracle", deploymentInfo.contracts.priceOracle);
  const testToken1 = await ethers.getContractAt("TestToken", deploymentInfo.contracts.testToken1);
  const testToken2 = await ethers.getContractAt("TestToken", deploymentInfo.contracts.testToken2);

  try {
    // 1. 准备阶段
    console.log("\n🛠️  准备演示数据...");
    
    // 给卖家铸造一个特殊的 NFT
    const specialNFTURI = "https://gateway.pinata.cloud/ipfs/bafybeihxwrls2uzs2xnn77rwcqpetfe6ethnqkdkmcbk6xok3bxztvhmta";
    await auctionNFT.mint(seller.address, specialNFTURI);
    const tokenId = await auctionNFT.totalSupply();
    console.log(`✅ 为卖家铸造了特殊 NFT #${tokenId}`);

    // 给出价者分发测试代币
    const tokenAmount = ethers.parseUnits("1000", 18);
    await testToken1.transfer(bidder1.address, tokenAmount);
    await testToken1.transfer(bidder2.address, tokenAmount);
    await testToken2.transfer(bidder3.address, tokenAmount);
    console.log("✅ 已分发测试代币给出价者");

    // 2. 创建拍卖
    console.log("\n🏗️  创建拍卖...");
    
    // 卖家授权拍卖工厂
    await auctionNFT.connect(seller).setApprovalForAll(auctionFactory.target, true);
    console.log("✅ 卖家已授权拍卖工厂");

    // 创建拍卖参数
    const startingPrice = ethers.parseUnits("50", 8);   // $50
    const reservePrice = ethers.parseUnits("100", 8);   // $100
    const duration = 3600;                              // 1 hour
    const bidIncrement = ethers.parseUnits("10", 8);    // $10

    const tx = await auctionFactory.connect(seller).createAuction(
      auctionNFT.target,
      tokenId,
      startingPrice,
      reservePrice,
      duration,
      bidIncrement
    );

    const receipt = await tx.wait();
    const auctionCreatedEvent = receipt.logs.find(log => {
      try {
        return auctionFactory.interface.parseLog(log).name === "AuctionCreated";
      } catch {
        return false;
      }
    });

    const auctionId = auctionCreatedEvent.args[0];
    const auctionAddress = await auctionFactory.getAuction(auctionId);
    const auctionContract = await ethers.getContractAt("NFTAuction", auctionAddress);

    console.log(`✅ 拍卖创建成功!`);
    console.log(`   拍卖 ID: ${auctionId}`);
    console.log(`   拍卖合约: ${auctionAddress}`);
    console.log(`   起拍价: $${ethers.formatUnits(startingPrice, 8)}`);
    console.log(`   保留价: $${ethers.formatUnits(reservePrice, 8)}`);

    // 3. 查看拍卖信息
    console.log("\n📊 拍卖信息:");
    const auctionInfo = await auctionContract.getAuctionInfo();
    console.log(`   卖家: ${auctionInfo.seller}`);
    console.log(`   NFT: ${auctionInfo.nftContract} #${auctionInfo.tokenId}`);
    console.log(`   状态: ${["进行中", "已结束", "已取消"][auctionInfo.status]}`);
    console.log(`   结束时间: ${new Date(Number(auctionInfo.endTime) * 1000).toLocaleString()}`);

    // 4. 出价阶段
    console.log("\n💰 开始出价...");

    // 出价者1: 使用 ETH 出价
    console.log("\n👤 出价者1 使用 ETH 出价...");
    const ethBidAmount = ethers.parseEther("0.03"); // 0.03 ETH
    const ethUsdValue = await priceOracle.convertETHToUSD(ethBidAmount);
    console.log(`   出价: ${ethers.formatEther(ethBidAmount)} ETH (约 $${ethers.formatUnits(ethUsdValue, 8)})`);
    
    await auctionContract.connect(bidder1).bidWithETH({ value: ethBidAmount });
    console.log("✅ ETH 出价成功");

    // 查看当前最高出价
    let [highestBidder, amount, usdValue, bidType] = await auctionContract.getHighestBid();
    console.log(`   当前最高出价者: ${highestBidder}`);
    console.log(`   出价金额: ${bidType === 0 ? ethers.formatEther(amount) + " ETH" : ethers.formatUnits(amount, 18) + " tokens"}`);
    console.log(`   美元价值: $${ethers.formatUnits(usdValue, 8)}`);

    // 出价者2: 使用 ERC20 代币出价
    console.log("\n👤 出价者2 使用 TEST1 代币出价...");
    const tokenBidAmount = ethers.parseUnits("80", 18); // 80 TEST1 tokens
    const tokenUsdValue = await priceOracle.convertTokenToUSD(testToken1.target, tokenBidAmount);
    console.log(`   出价: ${ethers.formatUnits(tokenBidAmount, 18)} TEST1 (约 $${ethers.formatUnits(tokenUsdValue, 8)})`);
    
    await testToken1.connect(bidder2).approve(auctionContract.target, tokenBidAmount);
    await auctionContract.connect(bidder2).bidWithERC20(testToken1.target, tokenBidAmount);
    console.log("✅ ERC20 出价成功");

    // 查看更新后的最高出价
    [highestBidder, amount, usdValue, bidType] = await auctionContract.getHighestBid();
    console.log(`   当前最高出价者: ${highestBidder}`);
    console.log(`   出价金额: ${bidType === 0 ? ethers.formatEther(amount) + " ETH" : ethers.formatUnits(amount, 18) + " tokens"}`);
    console.log(`   美元价值: $${ethers.formatUnits(usdValue, 8)}`);

    // 出价者3: 使用更高价值的代币出价
    console.log("\n👤 出价者3 使用 TEST2 代币出价...");
    const higherTokenBidAmount = ethers.parseUnits("1.2", 18); // 1.2 TEST2 tokens (worth $120)
    const higherTokenUsdValue = await priceOracle.convertTokenToUSD(testToken2.target, higherTokenBidAmount);
    console.log(`   出价: ${ethers.formatUnits(higherTokenBidAmount, 18)} TEST2 (约 $${ethers.formatUnits(higherTokenUsdValue, 8)})`);
    
    await testToken2.connect(bidder3).approve(auctionContract.target, higherTokenBidAmount);
    await auctionContract.connect(bidder3).bidWithERC20(testToken2.target, higherTokenBidAmount);
    console.log("✅ ERC20 出价成功");

    // 查看最终最高出价
    [highestBidder, amount, usdValue, bidType, token] = await auctionContract.getHighestBid();
    console.log(`   当前最高出价者: ${highestBidder}`);
    console.log(`   出价金额: ${bidType === 0 ? ethers.formatEther(amount) + " ETH" : ethers.formatUnits(amount, 18) + " tokens"}`);
    console.log(`   代币地址: ${token || "ETH"}`);
    console.log(`   美元价值: $${ethers.formatUnits(usdValue, 8)}`);

    // 5. 查看所有出价
    console.log("\n📜 所有出价记录:");
    const allBids = await auctionContract.getAllBids();
    for (let i = 0; i < allBids.length; i++) {
      const bid = allBids[i];
      console.log(`   出价 ${i + 1}:`);
      console.log(`     出价者: ${bid.bidder}`);
      console.log(`     金额: ${bid.bidType === 0 ? ethers.formatEther(bid.amount) + " ETH" : ethers.formatUnits(bid.amount, 18) + " tokens"}`);
      console.log(`     美元价值: $${ethers.formatUnits(bid.usdValue, 8)}`);
      console.log(`     时间: ${new Date(Number(bid.timestamp) * 1000).toLocaleString()}`);
    }

    // 6. 模拟价格波动
    console.log("\n📈 模拟价格波动...");
    
    // ETH 价格上涨 10%
    const currentETHPrice = (await priceOracle.getETHPrice())[0];
    const newETHPrice = currentETHPrice * BigInt(110) / BigInt(100);
    await priceOracle.setETHPrice(newETHPrice);
    console.log(`✅ ETH 价格更新: $${ethers.formatUnits(currentETHPrice, 8)} → $${ethers.formatUnits(newETHPrice, 8)}`);

    // 测试代币价格变化
    await priceOracle.simulatePriceFluctuation(
      0, // ETH 价格不变（已经手动更新）
      [testToken1.target, testToken2.target],
      [500, -200] // TEST1 上涨 5%, TEST2 下跌 2%
    );
    console.log("✅ 代币价格已更新");

    // 7. 等待一段时间（模拟）
    console.log("\n⏰ 模拟时间流逝...");
    await ethers.provider.send("evm_increaseTime", [3610]); // 增加 1 小时 10 分钟
    await ethers.provider.send("evm_mine"); // 挖一个新块
    console.log("✅ 拍卖时间已结束");

    // 8. 结束拍卖
    console.log("\n🏁 结束拍卖...");
    
    // 记录结束前的余额
    const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
    const winnerBalanceBefore = await testToken2.balanceOf(bidder3.address);
    
    await auctionContract.endAuction();
    console.log("✅ 拍卖已结束");

    // 9. 检查结果
    console.log("\n🎉 拍卖结果:");
    
    // 检查 NFT 所有权
    const newNFTOwner = await auctionNFT.ownerOf(tokenId);
    console.log(`   NFT #${tokenId} 新拥有者: ${newNFTOwner}`);
    
    // 检查资金转移
    const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
    const winnerBalanceAfter = await testToken2.balanceOf(bidder3.address);
    
    console.log(`   卖家获得资金: ${ethers.formatUnits(sellerBalanceAfter - sellerBalanceBefore, 18)} tokens`);
    console.log(`   获胜者剩余代币: ${ethers.formatUnits(winnerBalanceAfter, 18)} TEST2`);

    // 10. 查看拍卖统计
    console.log("\n📈 拍卖统计:");
    const stats = await auctionFactory.getAuctionStats();
    console.log(`   总拍卖数: ${stats.totalAuctions}`);
    console.log(`   活跃拍卖: ${stats.activeAuctions}`);
    console.log(`   已结束拍卖: ${stats.endedAuctions}`);
    console.log(`   已取消拍卖: ${stats.cancelledAuctions}`);

    // 11. 获取拍卖摘要
    console.log("\n📋 拍卖摘要:");
    const summary = await auctionFactory.getAuctionSummary(auctionId);
    console.log(`   拍卖 ID: ${summary.auctionId}`);
    console.log(`   最终最高出价: $${ethers.formatUnits(summary.currentHighestBid, 8)}`);
    console.log(`   获胜者: ${summary.currentHighestBidder}`);
    console.log(`   状态: ${["进行中", "已结束", "已取消"][summary.status]}`);

    console.log("\n🎊 演示完成！拍卖流程执行成功！");
    
  } catch (error) {
    console.error("\n❌ 演示过程中发生错误:", error.message);
    if (error.transaction) {
      console.error("交易哈希:", error.transaction.hash);
    }
    throw error;
  }
}

// 处理未捕获的异常
process.on('unhandledRejection', (reason, promise) => {
  console.error('未处理的 Promise 拒绝:', reason);
  process.exit(1);
});

if (require.main === module) {
  main()
    .then(() => {
      console.log("\n✨ 演示脚本执行完成!");
      process.exit(0);
    })
    .catch((error) => {
      console.error("演示脚本执行失败:", error);
      process.exit(1);
    });
}

module.exports = { main };
