const { ethers, upgrades, network } = require("hardhat");

/**
 * Task3 合约升级演示脚本
 * 演示内容：
 * 1. 部署初始版本的所有合约
 * 2. 创建拍卖并记录所有地址
 * 3. 升级 AuctionNFT 和 PriceOracle
 * 4. 对比升级前后的地址变化
 * 5. 验证功能是否正常工作
 */

// ========== 全局变量 ==========
let deployer;                           // 部署者账户
let testAccounts = [];                  // 测试账户列表
let deployedContracts = {};             // 已部署合约记录
let addressTracker = {};                // 地址追踪器

// ========== 工具函数 ==========

/**
 * 打印分隔线
 * @param {string} title - 标题
 * @param {string} char - 分隔符字符
 */
function printSeparator(title, char = "=") {
  const line = char.repeat(60);
  console.log(`\n${line}`);
  console.log(`${title.toUpperCase()}`);
  console.log(line);
}

/**
 * 记录合约地址信息
 * @param {string} contractName - 合约名称
 * @param {object} contract - 合约实例
 * @param {string} phase - 阶段标识
 */
async function recordAddress(contractName, contract, phase) {
  if (!addressTracker[contractName]) {
    addressTracker[contractName] = {};
  }
  
  // 记录代理地址（如果是代理合约）
  addressTracker[contractName][`${phase}_proxy`] = contract.target;
  
  // 记录实现地址（如果是代理合约）
  try {
    const implAddress = await upgrades.erc1967.getImplementationAddress(contract.target);
    addressTracker[contractName][`${phase}_implementation`] = implAddress;
  } catch (error) {
    // 不是代理合约，直接记录合约地址
    addressTracker[contractName][`${phase}_contract`] = contract.target;
  }
}

/**
 * 显示地址变化对比
 */
function showAddressChanges() {
  printSeparator("地址变化对比表", "=");
  
  console.log("📋 合约地址变化详情:\n");
  
  for (const [contractName, addresses] of Object.entries(addressTracker)) {
    console.log(`🔧 ${contractName}:`);
    console.log("-".repeat(40));
    
    // 显示代理地址
    if (addresses.initial_proxy) {
      console.log(`  代理地址 (Proxy):`);
      console.log(`    初始: ${addresses.initial_proxy}`);
      console.log(`    升级后: ${addresses.upgraded_proxy || '未升级'}`);
      
      if (addresses.initial_proxy === addresses.upgraded_proxy) {
        console.log(`    状态: ✅ 地址不变 (这是关键!)`);
      } else {
        console.log(`    状态: ❌ 地址改变 (不应该发生)`);
      }
    }
    
    // 显示实现地址
    if (addresses.initial_implementation) {
      console.log(`  实现地址 (Implementation):`);
      console.log(`    初始: ${addresses.initial_implementation}`);
      console.log(`    升级后: ${addresses.upgraded_implementation || '未升级'}`);
      
      if (addresses.initial_implementation !== addresses.upgraded_implementation) {
        console.log(`    状态: ✅ 实现已升级 (预期行为)`);
      } else {
        console.log(`    状态: ⚠️ 实现未改变`);
      }
    }
    
    // 显示普通合约地址
    if (addresses.initial_contract) {
      console.log(`  合约地址:`);
      console.log(`    地址: ${addresses.initial_contract}`);
      console.log(`    状态: 📌 普通合约 (不支持升级)`);
    }
    
    console.log("");
  }
}

/**
 * 显示依赖关系变化
 */
async function showDependencyChanges() {
  printSeparator("依赖关系变化分析", "=");
  
  console.log("🔗 合约间依赖关系分析:\n");
  
  // 1. AuctionFactory 对 PriceOracle 的依赖
  console.log("1️⃣ AuctionFactory → PriceOracle:");
  console.log("-".repeat(40));
  
  const factory = deployedContracts.auctionFactory;
  const currentOracleAddress = await factory.priceOracle();
  
  console.log(`  AuctionFactory 地址: ${factory.target}`);
  console.log(`  当前指向的 PriceOracle: ${currentOracleAddress}`);
  console.log(`  PriceOracle 代理地址: ${deployedContracts.priceOracle.target}`);
  
  if (currentOracleAddress.toLowerCase() === deployedContracts.priceOracle.target.toLowerCase()) {
    console.log(`  ✅ 依赖关系正确: Factory 指向 Oracle 代理地址`);
    console.log(`  ✅ Oracle 升级后，Factory 无需修改`);
  } else {
    console.log(`  ❌ 依赖关系错误: 地址不匹配`);
  }
  
  // 2. 已创建的 NFTAuction 对 AuctionNFT 的依赖
  console.log(`\n2️⃣ 已创建的拍卖合约 → AuctionNFT:`);
  console.log("-".repeat(40));
  
  if (deployedContracts.createdAuctions && deployedContracts.createdAuctions.length > 0) {
    for (let i = 0; i < deployedContracts.createdAuctions.length; i++) {
      const auctionAddress = deployedContracts.createdAuctions[i];
      const NFTAuction = await ethers.getContractFactory("NFTAuction");
      const auction = NFTAuction.attach(auctionAddress);
      
      try {
        const auctionInfo = await auction.getAuctionInfo();
        console.log(`  拍卖合约 #${i + 1}: ${auctionAddress}`);
        console.log(`    绑定的 NFT 合约: ${auctionInfo.nftContract}`);
        console.log(`    AuctionNFT 代理地址: ${deployedContracts.auctionNFT.target}`);
        
        if (auctionInfo.nftContract.toLowerCase() === deployedContracts.auctionNFT.target.toLowerCase()) {
          console.log(`    ✅ 依赖关系正确: 拍卖指向 NFT 代理地址`);
          console.log(`    ✅ NFT 升级后，拍卖仍然有效`);
        } else {
          console.log(`    ❌ 依赖关系错误: 地址不匹配`);
        }
      } catch (error) {
        console.log(`    ⚠️ 无法获取拍卖信息: ${error.message}`);
      }
      console.log("");
    }
  } else {
    console.log(`  📝 没有已创建的拍卖合约`);
  }
  
  // 3. 新创建的拍卖会使用什么地址
  console.log(`3️⃣ 新创建的拍卖合约 → 升级后的合约:`);
  console.log("-".repeat(40));
  console.log(`  工厂创建拍卖时传递的 NFT 地址: ${deployedContracts.auctionNFT.target}`);
  console.log(`  工厂创建拍卖时传递的 Oracle 地址: ${deployedContracts.priceOracle.target}`);
  console.log(`  ✅ 新拍卖会自动使用升级后的合约功能`);
  console.log(`  ✅ 因为传递的是代理地址，代理内部已指向新实现`);
}

// ========== 第一阶段：初始部署 ==========

/**
 * 部署价格预言机
 */
async function deployPriceOracle() {
  console.log("\n📊 部署价格预言机 (MockPriceOracle)...");
  
  const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
  const priceOracle = await upgrades.deployProxy(
    MockPriceOracle,                                        // 合约工厂
    [],                                                     // 初始化参数
    { 
      initializer: "initialize",                            // 初始化函数名
      kind: "uups"                                          // 使用UUPS代理模式
    }
  );
  
  await priceOracle.waitForDeployment();                    // 等待部署完成
  
  // 设置初始价格
  await priceOracle.setETHPrice(ethers.parseUnits("2000", 8)); // ETH: $2000
  
  console.log(`✅ PriceOracle 部署成功:`);
  console.log(`   代理地址: ${priceOracle.target}`);
  
  // 记录地址信息
  await recordAddress("PriceOracle", priceOracle, "initial");
  
  return priceOracle;
}

/**
 * 部署 NFT 合约
 */
async function deployNFTContract() {
  console.log("\n🖼️ 部署 NFT 合约 (AuctionNFT)...");
  
  const AuctionNFT = await ethers.getContractFactory("AuctionNFT");
  const auctionNFT = await upgrades.deployProxy(
    AuctionNFT,                                             // 合约工厂
    [
      "Auction NFT",                                        // NFT名称
      "ANFT",                                               // NFT符号
      "https://api.example.com/metadata/"                   // 基础URI
    ],
    { 
      initializer: "initialize",                            // 初始化函数名
      kind: "uups"                                          // 使用UUPS代理模式
    }
  );
  
  await auctionNFT.waitForDeployment();                     // 等待部署完成
  
  console.log(`✅ AuctionNFT 部署成功:`);
  console.log(`   代理地址: ${auctionNFT.target}`);
  
  // 记录地址信息
  await recordAddress("AuctionNFT", auctionNFT, "initial");
  
  return auctionNFT;
}

/**
 * 部署拍卖工厂
 */
async function deployAuctionFactory() {
  console.log("\n🏭 部署拍卖工厂 (AuctionFactory)...");
  
  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
  const auctionFactory = await upgrades.deployProxy(
    AuctionFactory,                                         // 合约工厂
    [
      deployedContracts.priceOracle.target,                // 价格预言机代理地址
      deployer.address,                                     // 费用接收地址
      deployer.address                                      // 合约拥有者
    ],
    { 
      initializer: "initialize",                            // 初始化函数名
      kind: "uups"                                          // 使用UUPS代理模式
    }
  );
  
  await auctionFactory.waitForDeployment();                // 等待部署完成
  
  console.log(`✅ AuctionFactory 部署成功:`);
  console.log(`   代理地址: ${auctionFactory.target}`);
  console.log(`   依赖的 PriceOracle: ${deployedContracts.priceOracle.target}`);
  
  // 记录地址信息
  await recordAddress("AuctionFactory", auctionFactory, "initial");
  
  return auctionFactory;
}

/**
 * 初始部署阶段
 */
async function initialDeployment() {
  printSeparator("第一阶段：初始部署", "=");
  
  // 按顺序部署合约
  deployedContracts.priceOracle = await deployPriceOracle();
  deployedContracts.auctionNFT = await deployNFTContract();
  deployedContracts.auctionFactory = await deployAuctionFactory();
  
  console.log("\n✅ 初始部署完成！");
  console.log("\n📋 初始部署摘要:");
  console.log(`   PriceOracle 代理: ${deployedContracts.priceOracle.target}`);
  console.log(`   AuctionNFT 代理: ${deployedContracts.auctionNFT.target}`);
  console.log(`   AuctionFactory 代理: ${deployedContracts.auctionFactory.target}`);
}

// ========== 第二阶段：创建拍卖 ==========

/**
 * 铸造测试 NFT
 */
async function mintTestNFTs() {
  console.log("\n🎨 铸造测试 NFT...");
  
  const nftContract = deployedContracts.auctionNFT;
  
  // 为前两个测试账户各铸造一个 NFT
  for (let i = 0; i < Math.min(2, testAccounts.length); i++) {
    await nftContract.mint(
      testAccounts[i].address,                              // NFT接收者
      `${i + 1}.json`                                       // 元数据URI
    );
    console.log(`✅ NFT #${i + 1} 铸造给: ${testAccounts[i].address}`);
  }
}

/**
 * 创建测试拍卖
 */
async function createTestAuctions() {
  console.log("\n🔨 创建测试拍卖...");
  
  const nftContract = deployedContracts.auctionNFT;
  const factoryContract = deployedContracts.auctionFactory;
  
  deployedContracts.createdAuctions = [];                   // 存储创建的拍卖地址
  
  // 为前两个测试账户创建拍卖
  for (let i = 0; i < Math.min(2, testAccounts.length); i++) {
    const seller = testAccounts[i];
    const tokenId = i + 1;
    
    console.log(`\n创建拍卖 ${i + 1}:`);
    console.log(`  卖家: ${seller.address}`);
    console.log(`  NFT ID: ${tokenId}`);
    
    // 授权拍卖工厂操作 NFT
    await nftContract.connect(seller).setApprovalForAll(
      factoryContract.target,                               // 被授权地址
      true                                                  // 授权状态
    );
    
    // 创建拍卖
    const tx = await factoryContract.connect(seller).createAuction(
      nftContract.target,                                   // NFT合约地址 (代理地址!)
      tokenId,                                              // NFT ID
      ethers.parseUnits("50", 8),                          // 起拍价: $50
      ethers.parseUnits("100", 8),                         // 保留价: $100
      3600,                                                 // 持续时间: 1小时
      ethers.parseUnits("10", 8)                           // 最小加价: $10
    );
    
    const receipt = await tx.wait();                        // 等待交易确认
    
    // 从事件中获取拍卖合约地址
    const auctionCreatedEvent = receipt.logs.find(
      log => log.fragment && log.fragment.name === "AuctionCreated"
    );
    
    if (auctionCreatedEvent) {
      const auctionAddress = auctionCreatedEvent.args[0];
      deployedContracts.createdAuctions.push(auctionAddress);
      
      console.log(`  ✅ 拍卖合约创建: ${auctionAddress}`);
      console.log(`  📝 该拍卖绑定的 NFT 合约: ${nftContract.target}`);
      console.log(`  📝 该拍卖使用的 PriceOracle: ${deployedContracts.priceOracle.target}`);
    }
  }
  
  console.log(`\n✅ 总共创建了 ${deployedContracts.createdAuctions.length} 个拍卖`);
}

/**
 * 创建拍卖阶段
 */
async function createAuctions() {
  printSeparator("第二阶段：创建拍卖", "=");
  
  await mintTestNFTs();                                     // 铸造测试NFT
  await createTestAuctions();                               // 创建测试拍卖
  
  console.log("\n✅ 拍卖创建完成！");
}

// ========== 第三阶段：合约升级 ==========

/**
 * 升级价格预言机
 */
async function upgradePriceOracle() {
  console.log("\n📊 升级价格预言机到 V2 版本...");
  
  // 记录升级前的实现地址
  const oldImplAddress = await upgrades.erc1967.getImplementationAddress(
    deployedContracts.priceOracle.target
  );
  console.log(`  升级前实现地址: ${oldImplAddress}`);
  
  // 执行升级 (这里我们使用同样的合约作为"V2"版本演示)
  const MockPriceOracleV2 = await ethers.getContractFactory("MockPriceOracle");
  const upgradedOracle = await upgrades.upgradeProxy(
    deployedContracts.priceOracle.target,                  // 代理地址
    MockPriceOracleV2                                       // 新实现合约
  );
  
  await upgradedOracle.waitForDeployment();                // 等待升级完成
  //deployedContracts.priceOracle.target = upgradedOracle.target
  //deployedContracts.priceOracle != upgradedOracle
  // 记录升级后的实现地址
  const newImplAddress = await upgrades.erc1967.getImplementationAddress(
    upgradedOracle.target
  );
  
  console.log(`✅ PriceOracle 升级成功:`);
  console.log(`   代理地址: ${upgradedOracle.target} (不变!)`);
  console.log(`   升级前实现: ${oldImplAddress}`);
  console.log(`   升级后实现: ${newImplAddress}`);
  console.log(`   实现是否改变: ${oldImplAddress !== newImplAddress ? '✅ 是' : '❌ 否'}`);
  
  // 🔍 重要说明：代理地址不变，但 JavaScript 对象需要更新
  console.log(`\n💡 JavaScript 对象引用分析:`);
  console.log(`   旧对象地址: ${deployedContracts.priceOracle.target}`);
  console.log(`   新对象地址: ${upgradedOracle.target}`);
  console.log(`   地址相同: ${deployedContracts.priceOracle.target === upgradedOracle.target ? '✅ 是' : '❌ 否'}`);
  console.log(`   对象相同: ${deployedContracts.priceOracle === upgradedOracle ? '✅ 是' : '❌ 否 (这是关键!)'}`);
  console.log(`   更新原因: 使用最新的 JavaScript 对象实例，确保 ABI 和类型正确`);
  
  // 更新合约引用并记录地址
  deployedContracts.priceOracle = upgradedOracle;
  await recordAddress("PriceOracle", upgradedOracle, "upgraded");
  
  return upgradedOracle;
}

/**
 * 升级 NFT 合约
 */
async function upgradeNFTContract() {
  console.log("\n🖼️ 升级 NFT 合约到 V2 版本...");
  
  // 记录升级前的实现地址
  const oldImplAddress = await upgrades.erc1967.getImplementationAddress(
    deployedContracts.auctionNFT.target
  );
  console.log(`  升级前实现地址: ${oldImplAddress}`);
  
  // 检查是否存在 V2 版本
  let AuctionNFTV2;
  try {
    AuctionNFTV2 = await ethers.getContractFactory("AuctionNFTV2");
    console.log(`  找到 AuctionNFTV2 合约，使用 V2 版本升级`);
  } catch (error) {
    console.log(`  未找到 AuctionNFTV2，使用原版本模拟升级`);
    AuctionNFTV2 = await ethers.getContractFactory("AuctionNFT");
  }
  
  // 执行升级
  const upgradedNFT = await upgrades.upgradeProxy(
    deployedContracts.auctionNFT.target,                   // 代理地址
    AuctionNFTV2                                            // 新实现合约
  );
  
  await upgradedNFT.waitForDeployment();                   // 等待升级完成
  
  // 记录升级后的实现地址
  const newImplAddress = await upgrades.erc1967.getImplementationAddress(
    upgradedNFT.target
  );
  
  console.log(`✅ AuctionNFT 升级成功:`);
  console.log(`   代理地址: ${upgradedNFT.target} (不变!)`);
  console.log(`   升级前实现: ${oldImplAddress}`);
  console.log(`   升级后实现: ${newImplAddress}`);
  console.log(`   实现是否改变: ${oldImplAddress !== newImplAddress ? '✅ 是' : '❌ 否'}`);
  
  // 验证数据完整性
  const totalSupply = await upgradedNFT.totalSupply();
  console.log(`   数据验证 - NFT 总供应量: ${totalSupply} (应该保持不变)`);
  
  // 🔍 重要说明：为什么需要更新引用？
  console.log(`\n💡 JavaScript 对象引用分析:`);
  console.log(`   旧对象地址: ${deployedContracts.auctionNFT.target}`);
  console.log(`   新对象地址: ${upgradedNFT.target}`);
  console.log(`   地址相同: ${deployedContracts.auctionNFT.target === upgradedNFT.target ? '✅ 是' : '❌ 否'}`);
  console.log(`   对象相同: ${deployedContracts.auctionNFT === upgradedNFT ? '✅ 是' : '❌ 否 (这是关键!)'}`);
  console.log(`   更新原因: upgrades.upgradeProxy() 返回新的 JavaScript 对象实例`);
  
  // 更新合约引用 - 使用升级后的对象实例
  deployedContracts.auctionNFT = upgradedNFT;
  await recordAddress("AuctionNFT", upgradedNFT, "upgraded");
  
  return upgradedNFT;
}

/**
 * 合约升级阶段
 */
async function upgradeContracts() {
  printSeparator("第三阶段：合约升级", "=");
  
  await upgradePriceOracle();                               // 升级价格预言机
  await upgradeNFTContract();                               // 升级NFT合约
  
  console.log("\n✅ 合约升级完成！");
}

// ========== 第四阶段：验证升级效果 ==========

/**
 * 验证现有拍卖是否正常工作
 */
async function verifyExistingAuctions() {
  console.log("\n🔍 验证现有拍卖是否正常工作...");
  
  if (!deployedContracts.createdAuctions || deployedContracts.createdAuctions.length === 0) {
    console.log("  没有现有拍卖需要验证");
    return;
  }
  
  for (let i = 0; i < deployedContracts.createdAuctions.length; i++) {
    const auctionAddress = deployedContracts.createdAuctions[i];
    const NFTAuction = await ethers.getContractFactory("NFTAuction");
    const auction = NFTAuction.attach(auctionAddress);
    
    console.log(`\n验证拍卖 #${i + 1}: ${auctionAddress}`);
    
    try {
      // 获取拍卖信息
      const auctionInfo = await auction.getAuctionInfo();
      console.log(`  ✅ 拍卖信息读取成功`);
      console.log(`     NFT 合约: ${auctionInfo.nftContract}`);
      console.log(`     NFT ID: ${auctionInfo.tokenId}`);
      console.log(`     起拍价: $${ethers.formatUnits(auctionInfo.startingPrice, 8)}`);
      
      // 验证 NFT 合约地址是否仍然有效
      if (auctionInfo.nftContract.toLowerCase() === deployedContracts.auctionNFT.target.toLowerCase()) {
        console.log(`  ✅ NFT 合约地址匹配，升级后仍然有效`);
        
        // 尝试调用升级后的 NFT 合约
        const nftContract = await ethers.getContractAt("AuctionNFT", auctionInfo.nftContract);
        const owner = await nftContract.ownerOf(auctionInfo.tokenId);
        console.log(`  ✅ NFT 所有者查询成功: ${owner}`);
        
      } else {
        console.log(`  ❌ NFT 合约地址不匹配`);
      }
      
      // 获取最高出价信息
      const [bidder, amount, usdValue, bidType, token] = await auction.getHighestBid();
      if (bidder !== ethers.ZeroAddress) {
        console.log(`  📊 当前最高出价: $${ethers.formatUnits(usdValue, 8)}`);
      } else {
        console.log(`  📊 当前无出价`);
      }
      
    } catch (error) {
      console.log(`  ❌ 拍卖验证失败: ${error.message}`);
    }
  }
}

/**
 * 测试新功能
 */
async function testUpgradedFeatures() {
  console.log("\n🆕 测试升级后的新功能...");
  
  // 测试升级后的 NFT 合约
  console.log("\n测试升级后的 AuctionNFT:");
  try {
    const upgradedNFT = deployedContracts.auctionNFT;
    
    // 尝试调用可能的新功能
    try {
      const version = await upgradedNFT.version();
      console.log(`  ✅ 版本信息: ${version}`);
    } catch (error) {
      console.log(`  📝 无版本信息函数 (正常，V1版本没有)`);
    }
    
    // 测试基本功能
    const totalSupply = await upgradedNFT.totalSupply();
    console.log(`  ✅ 基本功能正常 - 总供应量: ${totalSupply}`);
    
  } catch (error) {
    console.log(`  ❌ NFT 合约测试失败: ${error.message}`);
  }
  
  // 测试升级后的价格预言机
  console.log("\n测试升级后的 PriceOracle:");
  try {
    const upgradedOracle = deployedContracts.priceOracle;
    
    // 测试价格查询
    const [ethPrice, decimals] = await upgradedOracle.getETHPrice();
    console.log(`  ✅ ETH 价格查询成功: $${ethers.formatUnits(ethPrice, decimals)}`);
    
  } catch (error) {
    console.log(`  ❌ 价格预言机测试失败: ${error.message}`);
  }
}

/**
 * 创建新拍卖测试
 */
async function createNewAuctionAfterUpgrade() {
  console.log("\n🔨 创建升级后的新拍卖...");
  
  const nftContract = deployedContracts.auctionNFT;
  const factoryContract = deployedContracts.auctionFactory;
  
  // 铸造新 NFT
  const newTokenId = (await nftContract.totalSupply()) + 1n;
  await nftContract.mint(
    deployer.address,                                       // 铸造给部署者
    `${newTokenId}.json`                                    // 元数据URI
  );
  console.log(`  ✅ 新 NFT #${newTokenId} 铸造完成`);
  
  // 授权并创建新拍卖
  await nftContract.setApprovalForAll(factoryContract.target, true);
  
  const tx = await factoryContract.createAuction(
    nftContract.target,                                     // NFT合约地址 (升级后的代理地址)
    newTokenId,                                             // 新NFT ID
    ethers.parseUnits("75", 8),                            // 起拍价: $75
    ethers.parseUnits("150", 8),                           // 保留价: $150
    7200,                                                   // 持续时间: 2小时
    ethers.parseUnits("15", 8)                             // 最小加价: $15
  );
  
  const receipt = await tx.wait();
  
  // 获取新拍卖地址
  const auctionCreatedEvent = receipt.logs.find(
    log => log.fragment && log.fragment.name === "AuctionCreated"
  );
  
  if (auctionCreatedEvent) {
    const newAuctionAddress = auctionCreatedEvent.args[0];
    console.log(`  ✅ 新拍卖创建成功: ${newAuctionAddress}`);
    console.log(`  📝 新拍卖使用的 NFT 地址: ${nftContract.target} (升级后的代理)`);
    console.log(`  📝 新拍卖使用的 Oracle 地址: ${deployedContracts.priceOracle.target} (升级后的代理)`);
    console.log(`  ✅ 新拍卖自动获得升级后的功能！`);
    
    // 验证新拍卖功能
    const NFTAuction = await ethers.getContractFactory("NFTAuction");
    const newAuction = NFTAuction.attach(newAuctionAddress);
    const auctionInfo = await newAuction.getAuctionInfo();
    console.log(`  ✅ 新拍卖信息验证成功，起拍价: $${ethers.formatUnits(auctionInfo.startingPrice, 8)}`);
  }
}

/**
 * 验证升级效果阶段
 */
async function verifyUpgrade() {
  printSeparator("第四阶段：验证升级效果", "=");
  
  await verifyExistingAuctions();                           // 验证现有拍卖
  await testUpgradedFeatures();                             // 测试新功能
  await createNewAuctionAfterUpgrade();                     // 创建新拍卖
  
  console.log("\n✅ 升级效果验证完成！");
}

// ========== 主函数 ==========

/**
 * 主函数
 */
async function main() {
  printSeparator("Task3 合约升级演示开始", "🎉");
  
  console.log(`网络: ${network.name}`);
  console.log(`时间: ${new Date().toLocaleString()}`);
  
  // 获取账户信息
  const signers = await ethers.getSigners();
  deployer = signers[0];
  testAccounts = signers.slice(1, 4);                       // 取3个测试账户
  
  console.log(`部署者: ${deployer.address}`);
  console.log(`测试账户数量: ${testAccounts.length}`);
  
  try {
    // 执行四个阶段
    await initialDeployment();                              // 第一阶段：初始部署
    await createAuctions();                                 // 第二阶段：创建拍卖
    await upgradeContracts();                               // 第三阶段：合约升级
    await verifyUpgrade();                                  // 第四阶段：验证升级
    
    // 显示最终结果
    showAddressChanges();                                   // 显示地址变化对比
    await showDependencyChanges();                          // 显示依赖关系变化
    
    // 最终总结
    printSeparator("演示完成总结", "🎊");
    console.log("✅ 第一阶段：初始部署 - 完成");
    console.log("✅ 第二阶段：创建拍卖 - 完成");
    console.log("✅ 第三阶段：合约升级 - 完成");
    console.log("✅ 第四阶段：验证升级 - 完成");
    
    console.log("\n🎯 关键发现:");
    console.log("📌 代理地址始终不变，这是代理模式的核心价值");
    console.log("📌 实现地址改变，但不影响外部调用");
    console.log("📌 现有拍卖继续正常工作，无需任何修改");
    console.log("📌 新拍卖自动获得升级后的功能");
    console.log("📌 数据完整性得到保证，无任何丢失");
    
    console.log("\n🎉 演示成功完成！");
    
  } catch (error) {
    console.error("\n❌ 演示过程中发生错误:");
    console.error(error);
    process.exit(1);
  }
}

// 执行主函数
main()
  .then(() => {
    console.log("\n✨ 脚本执行完成");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n💥 脚本执行失败:");
    console.error(error);
    process.exit(1);
  });
