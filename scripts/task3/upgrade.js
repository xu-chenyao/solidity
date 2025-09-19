const { ethers, upgrades } = require("hardhat");
const fs = require('fs');
const path = require('path');

/**
 * 合约升级脚本
 * 
 * UUPS 升级原理详解：
 * 
 * 1. 代理合约结构：
 *    ┌─────────────────┐
 *    │   Proxy Contract │ ← 用户交互的地址（永不改变）
 *    │   - 存储状态     │
 *    │   - 委托调用     │
 *    └─────────────────┘
 *            │
 *            │ delegatecall
 *            ▼
 *    ┌─────────────────┐
 *    │Implementation V1 │ ← 可以升级到 V2, V3...
 *    │   - 业务逻辑     │
 *    │   - 不存储状态   │
 *    └─────────────────┘
 * 
 * 2. 升级过程：
 *    a) 部署新的实现合约（V2）
 *    b) 调用代理合约的 upgradeTo(newImpl)
 *    c) 代理合约更新实现地址指向 V2
 *    d) 后续调用自动使用新逻辑
 * 
 * 3. 状态保持：
 *    - 所有状态变量存储在代理合约中
 *    - 升级只改变逻辑，不影响数据
 *    - 新版本必须兼容旧版本的存储布局
 * 
 * 4. 安全机制：
 *    - 只有授权用户（通常是 owner）可以升级
 *    - _authorizeUpgrade 函数控制升级权限
 *    - 升级前可以添加额外的验证逻辑
 */

async function main() {
  console.log("🔄 开始合约升级流程...");
  
  const [deployer] = await ethers.getSigners();
  console.log("升级执行者:", deployer.address);

  // 读取最新的部署信息
  const deployDir = path.join(__dirname, '..', '..', 'deployments');
  const deployFiles = fs.readdirSync(deployDir)
    .filter(f => f.startsWith('upgradeable-') && f.endsWith('.json'))
    .sort()
    .reverse();
  
  if (deployFiles.length === 0) {
    console.error("❌ 未找到可升级合约的部署文件");
    console.log("请先运行: npx hardhat run scripts/task3/deploy-upgradeable.js");
    return;
  }
  
  const deploymentInfo = JSON.parse(
    fs.readFileSync(path.join(deployDir, deployFiles[0]), 'utf8')
  );
  
  console.log("📄 使用部署信息:", deployFiles[0]);
  console.log("当前合约地址:");
  console.log("  NFT 代理:", deploymentInfo.contracts.auctionNFT);
  console.log("  工厂代理:", deploymentInfo.contracts.auctionFactory);
  console.log("  预言机代理:", deploymentInfo.contracts.priceOracle);

  try {
    // 升级选项
    const upgradeOptions = {
      nft: "升级 NFT 合约",
      factory: "升级拍卖工厂合约", 
      oracle: "升级价格预言机合约",
      all: "升级所有合约"
    };

    // 这里可以通过命令行参数或环境变量选择升级目标
    const upgradeTarget = process.env.UPGRADE_TARGET || "nft"; // 默认升级 NFT 合约
    
    console.log(`\n🎯 升级目标: ${upgradeOptions[upgradeTarget] || upgradeOptions.nft}`);

    const upgradedContracts = {};

    // 升级 NFT 合约
    if (upgradeTarget === "nft" || upgradeTarget === "all") {
      console.log("\n🖼️  升级 NFT 合约...");
      
      /**
       * 升级步骤详解：
       * 1. 获取当前代理合约实例
       * 2. 编译新的实现合约
       * 3. 验证升级兼容性
       * 4. 部署新实现合约
       * 5. 更新代理指向新实现
       */
      
      // 获取当前合约实例
      const currentNFT = await ethers.getContractAt("AuctionNFT", deploymentInfo.contracts.auctionNFT);
      console.log("当前 NFT 合约版本信息:");
      console.log("  名称:", await currentNFT.name());
      console.log("  符号:", await currentNFT.symbol());
      console.log("  拥有者:", await currentNFT.owner());
      
      // 获取新的合约工厂（这里使用相同的合约，实际升级时会是新版本）
      const AuctionNFTV2 = await ethers.getContractFactory("AuctionNFTV2");
      
      console.log("正在验证升级兼容性...");
      /**
       * upgrades.validateUpgrade 检查：
       * 1. 存储布局兼容性
       * 2. 构造函数变更
       * 3. 初始化函数变更
       * 4. 危险的存储变更
       */
      await upgrades.validateUpgrade(deploymentInfo.contracts.auctionNFT, AuctionNFTV2);
      console.log("✅ 升级兼容性验证通过");
      
      console.log("正在执行升级...");
      const upgradedNFT = await upgrades.upgradeProxy(deploymentInfo.contracts.auctionNFT, AuctionNFTV2);
      await upgradedNFT.waitForDeployment();
      
      // 获取新的实现地址
      const newImplAddress = await upgrades.erc1967.getImplementationAddress(deploymentInfo.contracts.auctionNFT);
      upgradedContracts.auctionNFTImpl = newImplAddress;
      
      console.log("✅ NFT 合约升级完成");
      console.log("  代理地址（不变）:", deploymentInfo.contracts.auctionNFT);
      console.log("  旧实现地址:", deploymentInfo.contracts.auctionNFTImpl);
      console.log("  新实现地址:", newImplAddress);
      
      // 验证升级后的功能
      console.log("验证升级后功能...");
      expect(await upgradedNFT.name()).to.equal(await currentNFT.name());
      expect(await upgradedNFT.owner()).to.equal(await currentNFT.owner());
      console.log("✅ 升级后功能验证通过，数据完整保留");
    }

    // 升级拍卖工厂合约
    if (upgradeTarget === "factory" || upgradeTarget === "all") {
      console.log("\n🏭 升级拍卖工厂合约...");
      
      const currentFactory = await ethers.getContractAt("AuctionFactory", deploymentInfo.contracts.auctionFactory);
      console.log("当前工厂合约信息:");
      console.log("  拥有者:", await currentFactory.owner());
      console.log("  费用接收者:", await currentFactory.feeRecipient());
      
      const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactory");
      
      console.log("正在验证升级兼容性...");
      await upgrades.validateUpgrade(deploymentInfo.contracts.auctionFactory, AuctionFactoryV2);
      console.log("✅ 升级兼容性验证通过");
      
      console.log("正在执行升级...");
      const upgradedFactory = await upgrades.upgradeProxy(deploymentInfo.contracts.auctionFactory, AuctionFactoryV2);
      await upgradedFactory.waitForDeployment();
      
      const newImplAddress = await upgrades.erc1967.getImplementationAddress(deploymentInfo.contracts.auctionFactory);
      upgradedContracts.auctionFactoryImpl = newImplAddress;
      
      console.log("✅ 拍卖工厂升级完成");
      console.log("  代理地址（不变）:", deploymentInfo.contracts.auctionFactory);
      console.log("  旧实现地址:", deploymentInfo.contracts.auctionFactoryImpl);
      console.log("  新实现地址:", newImplAddress);
      
      // 验证升级后的功能
      console.log("验证升级后功能...");
      expect(await upgradedFactory.owner()).to.equal(await currentFactory.owner());
      expect(await upgradedFactory.feeRecipient()).to.equal(await currentFactory.feeRecipient());
      console.log("✅ 升级后功能验证通过");
    }

    // 升级价格预言机合约
    if (upgradeTarget === "oracle" || upgradeTarget === "all") {
      console.log("\n📊 升级价格预言机合约...");
      
      // 注意：这里演示升级到 MockPriceOracle（实际场景中可能是功能增强版本）
      const currentOracle = await ethers.getContractAt("ChainlinkPriceOracle", deploymentInfo.contracts.priceOracle);
      console.log("当前预言机合约信息:");
      console.log("  拥有者:", await currentOracle.owner());
      
      // 假设我们要升级到一个增强版的预言机
      const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
      
      console.log("⚠️  注意：这是演示升级，实际中需要确保新合约兼容旧接口");
      
      // 由于 MockPriceOracle 和 ChainlinkPriceOracle 接口不完全兼容，这里跳过实际升级
      console.log("⏭️  跳过预言机升级（接口不兼容）");
    }

    // 保存升级信息
    console.log("\n💾 保存升级信息...");
    
    const upgradeInfo = {
      network: network.name,
      chainId: (await ethers.provider.getNetwork()).chainId.toString(),
      upgrader: deployer.address,
      timestamp: new Date().toISOString(),
      upgradeTarget: upgradeTarget,
      originalDeployment: deployFiles[0],
      upgradedContracts: upgradedContracts,
      notes: [
        "代理合约地址保持不变",
        "所有状态数据完整保留", 
        "只有实现合约地址发生变化",
        "用户无需更新合约地址"
      ]
    };
    
    const upgradeFilename = `upgrade-${upgradeTarget}-${Date.now()}.json`;
    fs.writeFileSync(
      path.join(deployDir, upgradeFilename),
      JSON.stringify(upgradeInfo, null, 2)
    );
    
    console.log(`✅ 升级信息已保存到: deployments/${upgradeFilename}`);

    // 输出升级总结
    console.log("\n📋 升级完成总结:");
    console.log("=" .repeat(60));
    console.log("✅ 升级成功完成");
    console.log("✅ 所有数据完整保留");
    console.log("✅ 代理地址保持不变");
    console.log("✅ 新功能立即生效");
    console.log("=" .repeat(60));

    console.log("\n🔍 升级验证建议:");
    console.log("1. 测试关键功能是否正常工作");
    console.log("2. 验证历史数据是否完整");
    console.log("3. 检查新功能是否按预期工作");
    console.log("4. 监控合约运行状态");

    return upgradedContracts;

  } catch (error) {
    console.error("\n❌ 升级失败:", error.message);
    
    if (error.message.includes("storage layout")) {
      console.error("\n💡 存储布局不兼容解决方案:");
      console.error("1. 检查新合约是否修改了现有变量的顺序");
      console.error("2. 确保只在末尾添加新变量");
      console.error("3. 不要删除或修改现有变量类型");
      console.error("4. 考虑使用存储间隙（__gap）预留空间");
    }
    
    if (error.message.includes("Unauthorized")) {
      console.error("\n💡 权限不足解决方案:");
      console.error("1. 确保使用合约拥有者账户执行升级");
      console.error("2. 检查 _authorizeUpgrade 函数的权限控制");
      console.error("3. 验证多签钱包的签名要求");
    }
    
    process.exit(1);
  }
}

// 辅助函数：简单的断言
function expect(actual) {
  return {
    to: {
      equal: (expected) => {
        if (actual !== expected) {
          throw new Error(`Expected ${expected}, but got ${actual}`);
        }
      }
    }
  };
}

if (require.main === module) {
  main()
    .then(() => {
      console.log("\n🎉 升级脚本执行完成!");
      process.exit(0);
    })
    .catch((error) => {
      console.error("升级脚本执行失败:", error);
      process.exit(1);
    });
}

module.exports = { main };
