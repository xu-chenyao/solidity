const { ethers, upgrades, network } = require("hardhat");

/**
 * NFT 拍卖市场部署脚本
 * 支持本地测试网和 Sepolia 测试网部署
 * 包含完整的初始化和配置流程
 */

// 网络配置
const NETWORK_CONFIG = {
  localhost: {
    name: "本地测试网",
    ethUsdPriceFeed: null, // 使用模拟预言机
    supportedTokens: [], // 将部署测试代币
    initialETHPrice: ethers.parseUnits("2000", 8), // $2000 per ETH
    initialTokenPrices: [
      ethers.parseUnits("1", 8),    // Test Token 1: $1
      ethers.parseUnits("100", 8),  // Test Token 2: $100
    ]
  },
  sepolia: {
    name: "Sepolia 测试网",
    ethUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306", // Chainlink ETH/USD
    supportedTokens: [
      {
        address: "0x779877A7B0D9E8603169DdbD7836e478b4624789", // LINK on Sepolia
        priceFeed: "0xc59E3633BAAC79493d908e63626716e204A45EdF"  // LINK/USD
      }
    ],
    initialETHPrice: null, // 使用真实预言机
    initialTokenPrices: []
  }
};

async function main() {
  console.log("🚀 开始部署 NFT 拍卖市场...");
  console.log("网络:", network.name);
  
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  const config = NETWORK_CONFIG[network.name] || NETWORK_CONFIG.localhost;
  console.log("使用配置:", config.name);

  const deployedContracts = {};

  try {
    // 1. 部署价格预言机
    console.log("\n📊 部署价格预言机...");
    let priceOracle;
    
    if (config.ethUsdPriceFeed) {
      // 部署 Chainlink 价格预言机
      console.log("部署 Chainlink 价格预言机");
      const ChainlinkPriceOracle = await ethers.getContractFactory("ChainlinkPriceOracle");
      priceOracle = await upgrades.deployProxy(
        ChainlinkPriceOracle,
        [config.ethUsdPriceFeed, deployer.address],
        { initializer: "initialize" }
      );
      await priceOracle.waitForDeployment();
      
      // 添加支持的代币价格预言机
      for (const token of config.supportedTokens) {
        console.log(`添加代币价格预言机: ${token.address} -> ${token.priceFeed}`);
        await priceOracle.setTokenPriceFeed(token.address, token.priceFeed);
      }
    } else {
      // 部署模拟价格预言机
      console.log("部署模拟价格预言机");
      const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
      priceOracle = await MockPriceOracle.deploy(config.initialETHPrice);
      await priceOracle.waitForDeployment();
    }
    
    deployedContracts.priceOracle = await priceOracle.getAddress();
    console.log("✅ 价格预言机部署完成:", deployedContracts.priceOracle);

    // 2. 部署测试代币（仅本地网络）
    if (network.name === "localhost" || network.name === "hardhat") {
      console.log("\n🪙 部署测试代币...");
      
      const TestToken = await ethers.getContractFactory("TestToken");
      
      // 部署测试代币 1
      const testToken1 = await TestToken.deploy(
        "Test Token 1",
        "TEST1",
        18,
        1000000, // 1M tokens
        deployer.address
      );
      await testToken1.waitForDeployment();
      deployedContracts.testToken1 = await testToken1.getAddress();
      
      // 部署测试代币 2
      const testToken2 = await TestToken.deploy(
        "Test Token 2",
        "TEST2",
        18,
        1000000, // 1M tokens
        deployer.address
      );
      await testToken2.waitForDeployment();
      deployedContracts.testToken2 = await testToken2.getAddress();
      
      // 在价格预言机中设置代币价格
      await priceOracle.setTokenPrice(deployedContracts.testToken1, config.initialTokenPrices[0]);
      await priceOracle.setTokenPrice(deployedContracts.testToken2, config.initialTokenPrices[1]);
      
      console.log("✅ 测试代币部署完成:");
      console.log("  Test Token 1:", deployedContracts.testToken1);
      console.log("  Test Token 2:", deployedContracts.testToken2);
    }

    // 3. 部署 NFT 合约
    console.log("\n🖼️  部署 NFT 合约...");
    const AuctionNFT = await ethers.getContractFactory("AuctionNFT");
    const auctionNFT = await upgrades.deployProxy(
      AuctionNFT,
      ["Auction NFT Collection", "ANFT", deployer.address],
      { 
        initializer: "initialize",
        kind: "uups"
      }
    );
    await auctionNFT.waitForDeployment();
    deployedContracts.auctionNFT = await auctionNFT.getAddress();
    console.log("✅ NFT 合约部署完成:", deployedContracts.auctionNFT);

    // 4. 部署拍卖工厂合约
    console.log("\n🏭 部署拍卖工厂合约...");
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const auctionFactory = await upgrades.deployProxy(
      AuctionFactory,
      [deployedContracts.priceOracle, deployer.address, deployer.address],
      { 
        initializer: "initialize",
        kind: "uups"
      }
    );
    await auctionFactory.waitForDeployment();
    deployedContracts.auctionFactory = await auctionFactory.getAddress();
    console.log("✅ 拍卖工厂合约部署完成:", deployedContracts.auctionFactory);

    // 5. 配置合约
    console.log("\n⚙️  配置合约...");
    
    // 授权拍卖工厂操作 NFT
    await auctionNFT.setAuctionAuthorization(deployedContracts.auctionFactory, true);
    console.log("✅ 已授权拍卖工厂操作 NFT");

    // 6. 初始化数据（仅本地网络）
    if (network.name === "localhost" || network.name === "hardhat") {
      console.log("\n📝 初始化测试数据...");
      
      // 铸造一些测试 NFT
      const testNFTURIs = [
        "https://gateway.pinata.cloud/ipfs/QmYourHash1",
        "https://gateway.pinata.cloud/ipfs/QmYourHash2",
        "https://gateway.pinata.cloud/ipfs/QmYourHash3"
      ];
      
      for (let i = 0; i < testNFTURIs.length; i++) {
        await auctionNFT.mint(deployer.address, testNFTURIs[i]);
        console.log(`✅ 已铸造测试 NFT ${i + 1}`);
      }

      // 分发一些测试代币给部署者
      const testToken1Contract = await ethers.getContractAt("TestToken", deployedContracts.testToken1);
      const testToken2Contract = await ethers.getContractAt("TestToken", deployedContracts.testToken2);
      
      console.log("✅ 测试数据初始化完成");
    }

    // 7. 验证部署
    console.log("\n🔍 验证部署...");
    
    // 验证 NFT 合约
    const nftName = await auctionNFT.name();
    const nftSymbol = await auctionNFT.symbol();
    const nftOwner = await auctionNFT.owner();
    console.log(`NFT 合约: ${nftName} (${nftSymbol}), 拥有者: ${nftOwner}`);
    
    // 验证拍卖工厂
    const factoryOwner = await auctionFactory.owner();
    const factoryOracle = await auctionFactory.priceOracle();
    console.log(`拍卖工厂拥有者: ${factoryOwner}, 价格预言机: ${factoryOracle}`);
    
    // 验证价格预言机
    const [ethPrice, decimals] = await priceOracle.getETHPrice();
    console.log(`ETH 价格: $${ethers.formatUnits(ethPrice, decimals)}`);

    // 8. 保存部署信息
    console.log("\n💾 保存部署信息...");
    const deploymentInfo = {
      network: network.name,
      chainId: (await ethers.provider.getNetwork()).chainId.toString(),
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: deployedContracts,
      transactionHashes: {
        // 这里可以添加交易哈希记录
      }
    };

    const fs = require('fs');
    const path = require('path');
    const deployDir = path.join(__dirname, '..', '..', 'deployments');
    
    if (!fs.existsSync(deployDir)) {
      fs.mkdirSync(deployDir, { recursive: true });
    }
    
    const filename = `${network.name}-${Date.now()}.json`;
    fs.writeFileSync(
      path.join(deployDir, filename),
      JSON.stringify(deploymentInfo, null, 2)
    );
    
    console.log(`✅ 部署信息已保存到: deployments/${filename}`);

    // 9. 输出使用说明
    console.log("\n📋 部署完成！合约地址:");
    console.log("=" .repeat(60));
    for (const [name, address] of Object.entries(deployedContracts)) {
      console.log(`${name.padEnd(20)}: ${address}`);
    }
    console.log("=" .repeat(60));

    if (network.name === "localhost" || network.name === "hardhat") {
      console.log("\n🧪 测试命令:");
      console.log("npx hardhat test test/task3/NFTAuctionTest.js --network localhost");
      
      console.log("\n🎯 示例交互:");
      console.log("1. 铸造 NFT:");
      console.log(`   auctionNFT.mint("地址", "URI")`);
      console.log("2. 创建拍卖:");
      console.log(`   auctionFactory.createAuction(...)`);
      console.log("3. 参与出价:");
      console.log(`   auctionContract.bidWithETH() 或 bidWithERC20(...)`);
    } else {
      console.log("\n🌐 区块链浏览器:");
      console.log(`查看合约: https://sepolia.etherscan.io/address/${deployedContracts.auctionFactory}`);
    }

    return deployedContracts;

  } catch (error) {
    console.error("\n❌ 部署失败:", error.message);
    if (error.transaction) {
      console.error("交易哈希:", error.transaction.hash);
    }
    process.exit(1);
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
      console.log("\n🎉 部署脚本执行完成!");
      process.exit(0);
    })
    .catch((error) => {
      console.error("部署脚本执行失败:", error);
      process.exit(1);
    });
}

module.exports = { main };
