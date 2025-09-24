const { ethers } = require("hardhat");

/**
 * 🚀 Meme项目完整生态系统部署脚本
 * 
 * 功能特性：
 * ✅ 代币税收系统 (高级税收策略)
 * ✅ 流动性池集成 (自动流动性管理)  
 * ✅ 交易限制功能 (防止恶意操纵)
 * ✅ NFT铸造系统 (Merkle树白名单)
 * ✅ 治理功能 (投票委托)
 * ✅ 国库管理 (自动化资金分配)
 * 
 * 部署顺序：
 * 1. 税收处理器 (SimpleTaxHandler)
 * 2. 国库处理器 (SimpleTreasuryHandler) 
 * 3. FLOKI代币 (带治理和税收)
 * 4. PEPE代币 (带交易限制)
 * 5. NFT铸造系统 (AdvancedMintingSystem)
 * 6. 流动性池 (LiquidityPool)
 * 7. 配置和初始化
 */
async function main() {
    console.log("🚀 开始部署Meme项目完整生态系统...\\n");
    console.log("=" .repeat(80));
    
    // ========== 获取部署账户 ==========
    const [deployer, marketingWallet, devWallet, liquidityWallet, user1, user2] = await ethers.getSigners();
    
    console.log("📝 部署配置:");
    console.log(`   部署者: ${deployer.address}`);
    console.log(`   营销钱包: ${marketingWallet.address}`);
    console.log(`   开发钱包: ${devWallet.address}`);
    console.log(`   流动性钱包: ${liquidityWallet.address}`);
    console.log(`   部署者余额: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))} ETH\\n`);
    
    const deploymentAddresses = {};
    const deploymentConfig = {
        // FLOKI配置
        floki: {
            name: "Floki Inu",
            symbol: "FLOKI",
            totalSupply: ethers.parseUnits("10000000000000", 9), // 10万亿
        },
        // PEPE配置  
        pepe: {
            name: "Pepe",
            symbol: "PEPE",
            totalSupply: ethers.parseUnits("420690000000000", 18), // 420.69万亿
        },
        // NFT配置
        nft: {
            name: "Meme NFT Collection",
            symbol: "MNFT",
            mintPrice: ethers.parseEther("0.01"), // 0.01 ETH
        },
        // 税收配置
        tax: {
            defaultRate: 500,   // 5%
            buyRate: 300,       // 3%
            sellRate: 700,      // 7%
            largeTxRate: 1000,  // 10%
            largeTxThreshold: ethers.parseUnits("1000000", 9), // 100万FLOKI
        },
        // 交易限制配置
        tradingLimits: {
            floki: {
                maxTransaction: ethers.parseUnits("1000000", 9), // 100万FLOKI
                maxWallet: ethers.parseUnits("2000000", 9),      // 200万FLOKI
                dailyLimit: 50,
                cooldown: 60, // 1分钟
            },
            pepe: {
                maxTransaction: ethers.parseUnits("10000000", 18), // 1000万PEPE
                dailyLimit: 100,
                cooldown: 30, // 30秒
            }
        },
        // 流动性配置
        liquidity: {
            initialTokenAmount: ethers.parseUnits("1000000", 9), // 100万FLOKI
            initialEthAmount: ethers.parseEther("10"), // 10 ETH
            autoLiquidityThreshold: ethers.parseEther("0.1"), // 0.1 ETH
            lockDuration: 30 * 24 * 3600, // 30天
        }
    };
    
    // ========== 第一步：部署税收处理器 ==========
    console.log("📦 第一步：部署税收处理器...");
    
    const SimpleTaxHandler = await ethers.getContractFactory("SimpleTaxHandler");
    const taxHandler = await SimpleTaxHandler.deploy(deployer.address, ethers.ZeroAddress);
    await taxHandler.waitForDeployment();
    
    deploymentAddresses.taxHandler = await taxHandler.getAddress();
    console.log(`✅ 税收处理器部署成功: ${deploymentAddresses.taxHandler}`);
    
    // 配置税收策略
    await taxHandler.setDefaultTaxRate(deploymentConfig.tax.defaultRate);
    await taxHandler.setBuyTaxRate(deploymentConfig.tax.buyRate);
    await taxHandler.setSellTaxRate(deploymentConfig.tax.sellRate);
    
    // 设置高级税收策略
    await taxHandler.setAdvancedTaxStrategies(
        deploymentConfig.tax.largeTxRate,
        deploymentConfig.tax.largeTxThreshold,
        800, // 8% 频繁交易税率
        300, // 5分钟窗口
        3    // 3次交易阈值
    );
    
    await taxHandler.setAntiMEVSettings(true, 1500); // 15% 反MEV税率
    console.log("   ⚙️  税收策略配置完成");
    
    // ========== 第二步：部署国库处理器 ==========
    console.log("\\n📦 第二步：部署国库处理器...");
    
    const SimpleTreasuryHandler = await ethers.getContractFactory("SimpleTreasuryHandler");
    const treasuryHandler = await SimpleTreasuryHandler.deploy(
        deployer.address,
        marketingWallet.address,
        devWallet.address,
        liquidityWallet.address
    );
    await treasuryHandler.waitForDeployment();
    
    deploymentAddresses.treasuryHandler = await treasuryHandler.getAddress();
    console.log(`✅ 国库处理器部署成功: ${deploymentAddresses.treasuryHandler}`);
    
    // ========== 第三步：部署FLOKI代币 ==========
    console.log("\\n📦 第三步：部署FLOKI代币...");
    
    const FLOKI = await ethers.getContractFactory("FLOKI");
    const floki = await FLOKI.deploy(
        deploymentConfig.floki.name,
        deploymentConfig.floki.symbol,
        deploymentAddresses.taxHandler,
        deploymentAddresses.treasuryHandler
    );
    await floki.waitForDeployment();
    
    deploymentAddresses.floki = await floki.getAddress();
    console.log(`✅ FLOKI代币部署成功: ${deploymentAddresses.floki}`);
    console.log(`   📊 总供应量: ${ethers.formatUnits(await floki.totalSupply(), 9)} FLOKI`);
    
    // 配置FLOKI交易限制
    await floki.setTradingLimits(
        true, // 启用交易限制
        deploymentConfig.tradingLimits.floki.maxTransaction,
        deploymentConfig.tradingLimits.floki.maxWallet,
        deploymentConfig.tradingLimits.floki.dailyLimit,
        deploymentConfig.tradingLimits.floki.cooldown
    );
    console.log("   ⚙️  FLOKI交易限制配置完成");
    
    // ========== 第四步：部署PEPE代币 ==========
    console.log("\\n📦 第四步：部署PEPE代币...");
    
    const PepeToken = await ethers.getContractFactory("PepeToken");
    const pepe = await PepeToken.deploy(deploymentConfig.pepe.totalSupply);
    await pepe.waitForDeployment();
    
    deploymentAddresses.pepe = await pepe.getAddress();
    console.log(`✅ PEPE代币部署成功: ${deploymentAddresses.pepe}`);
    console.log(`   📊 总供应量: ${ethers.formatUnits(await pepe.totalSupply(), 18)} PEPE`);
    
    // 配置PEPE交易限制
    await pepe.setAdvancedTradingLimits(
        deploymentConfig.tradingLimits.pepe.maxTransaction,
        deploymentConfig.tradingLimits.pepe.dailyLimit,
        deploymentConfig.tradingLimits.pepe.cooldown
    );
    console.log("   ⚙️  PEPE交易限制配置完成");
    
    // ========== 第五步：部署NFT铸造系统 ==========
    console.log("\\n📦 第五步：部署NFT铸造系统...");
    
    const AdvancedMintingSystem = await ethers.getContractFactory("AdvancedMintingSystem");
    const nft = await AdvancedMintingSystem.deploy(
        deploymentConfig.nft.name,
        deploymentConfig.nft.symbol
    );
    await nft.waitForDeployment();
    
    deploymentAddresses.nft = await nft.getAddress();
    console.log(`✅ NFT铸造系统部署成功: ${deploymentAddresses.nft}`);
    
    // 配置NFT铸造参数
    await nft.setMintPrice(deploymentConfig.nft.mintPrice);
    await nft.setPublicMintingEnabled(true);
    await nft.setMaxTokensPerAddress(10); // 每个地址最多10个NFT
    console.log("   ⚙️  NFT铸造参数配置完成");
    
    // ========== 第六步：部署流动性池 ==========
    console.log("\\n📦 第六步：部署流动性池...");
    
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy(deploymentAddresses.floki, deployer.address);
    await liquidityPool.waitForDeployment();
    
    deploymentAddresses.liquidityPool = await liquidityPool.getAddress();
    console.log(`✅ 流动性池部署成功: ${deploymentAddresses.liquidityPool}`);
    
    // ========== 第七步：配置合约关联 ==========
    console.log("\\n⚙️  第七步：配置合约关联...");
    
    // 配置国库处理器
    await treasuryHandler.setTokenContract(deploymentAddresses.floki);
    await treasuryHandler.setLiquidityPool(deploymentAddresses.liquidityPool);
    await treasuryHandler.setLiquidityConfig(
        true, // 启用自动流动性
        deploymentConfig.liquidity.autoLiquidityThreshold,
        deploymentConfig.liquidity.lockDuration
    );
    console.log("   ✅ 国库处理器配置完成");
    
    // 配置税收豁免地址
    const exemptAddresses = [
        deployer.address,
        deploymentAddresses.treasuryHandler,
        deploymentAddresses.liquidityPool,
        marketingWallet.address,
        devWallet.address,
        liquidityWallet.address
    ];
    
    for (const address of exemptAddresses) {
        await taxHandler.setTaxExemption(address, true);
        await floki.setTradingLimitExempt(address, true);
        await pepe.setTradingLimitExempt(address, true);
    }
    console.log("   ✅ 税收和交易限制豁免配置完成");
    
    // ========== 第八步：初始化流动性池 ==========
    console.log("\\n🏊 第八步：初始化流动性池...");
    
    const tokenAmount = deploymentConfig.liquidity.initialTokenAmount;
    const ethAmount = deploymentConfig.liquidity.initialEthAmount;
    
    // 授权流动性池使用FLOKI代币
    await floki.approve(deploymentAddresses.liquidityPool, tokenAmount);
    console.log("   ✅ 代币授权完成");
    
    // 添加初始流动性
    const addLiquidityTx = await liquidityPool.addLiquidity(
        tokenAmount,
        tokenAmount * 95n / 100n, // 5% 滑点容忍度
        ethAmount * 95n / 100n,   // 5% 滑点容忍度
        deploymentConfig.liquidity.lockDuration, // 30天锁定
        { value: ethAmount }
    );
    await addLiquidityTx.wait();
    
    const lpBalance = await liquidityPool.getLPBalance(deployer.address);
    const [tokenReserve, ethReserve] = await liquidityPool.getReserves();
    
    console.log("   ✅ 初始流动性添加成功");
    console.log(`   📊 LP代币获得: ${ethers.formatUnits(lpBalance, 18)}`);
    console.log(`   📊 代币储备: ${ethers.formatUnits(tokenReserve, 9)} FLOKI`);
    console.log(`   📊 ETH储备: ${ethers.formatEther(ethReserve)} ETH`);
    
    // ========== 第九步：功能演示 ==========
    console.log("\\n🎯 第九步：功能演示...");
    
    // 1. 演示税收功能
    console.log("\\n1️⃣ 演示税收功能:");
    await taxHandler.setTaxExemption(deployer.address, false); // 临时取消豁免
    
    const demoTransferAmount = ethers.parseUnits("10000", 9);
    const treasuryBalanceBefore = await floki.balanceOf(deploymentAddresses.treasuryHandler);
    
    await floki.transfer(user1.address, demoTransferAmount);
    
    const treasuryBalanceAfter = await floki.balanceOf(deploymentAddresses.treasuryHandler);
    const taxCollected = treasuryBalanceAfter - treasuryBalanceBefore;
    
    console.log(`   转账金额: ${ethers.formatUnits(demoTransferAmount, 9)} FLOKI`);
    console.log(`   税收收入: ${ethers.formatUnits(taxCollected, 9)} FLOKI`);
    console.log(`   税收比例: ${(Number(taxCollected) * 100 / Number(demoTransferAmount)).toFixed(2)}%`);
    
    await taxHandler.setTaxExemption(deployer.address, true); // 恢复豁免
    
    // 2. 演示NFT铸造
    console.log("\\n2️⃣ 演示NFT铸造:");
    const mintPrice = await nft.mintPrice();
    await nft.connect(user1).mint([], "Demo NFT #1", { value: mintPrice });
    
    const nftBalance = await nft.balanceOf(user1.address);
    console.log(`   铸造价格: ${ethers.formatEther(mintPrice)} ETH`);
    console.log(`   用户NFT余额: ${nftBalance}`);
    
    // 3. 演示治理功能
    console.log("\\n3️⃣ 演示治理功能:");
    await floki.delegate(user2.address); // 委托投票权给user2
    
    const user2Votes = await floki.getVotesAtBlock(user2.address, await ethers.provider.getBlockNumber());
    console.log(`   User2获得投票权: ${ethers.formatUnits(user2Votes, 9)} FLOKI`);
    
    // 4. 演示国库管理
    console.log("\\n4️⃣ 演示国库管理:");
    if (treasuryBalanceAfter > 0) {
        // 向国库发送ETH用于流动性管理
        await deployer.sendTransaction({
            to: deploymentAddresses.treasuryHandler,
            value: ethers.parseEther("0.5")
        });
        
        const lpBalanceBefore = await treasuryHandler.getLiquidityBalance();
        await treasuryHandler.processTax();
        const lpBalanceAfter = await treasuryHandler.getLiquidityBalance();
        
        console.log(`   国库LP变化: ${ethers.formatUnits(lpBalanceBefore, 18)} → ${ethers.formatUnits(lpBalanceAfter, 18)}`);
    }
    
    // ========== 部署总结 ==========
    console.log("\\n🎉 部署完成！\\n");
    console.log("=" .repeat(80));
    console.log("📋 合约地址总结:");
    console.log("=" .repeat(80));
    console.log(`税收处理器:     ${deploymentAddresses.taxHandler}`);
    console.log(`国库处理器:     ${deploymentAddresses.treasuryHandler}`);
    console.log(`FLOKI代币:      ${deploymentAddresses.floki}`);
    console.log(`PEPE代币:       ${deploymentAddresses.pepe}`);
    console.log(`NFT铸造系统:    ${deploymentAddresses.nft}`);
    console.log(`流动性池:       ${deploymentAddresses.liquidityPool}`);
    console.log("=" .repeat(80));
    
    // ========== 功能特性总结 ==========
    console.log("\\n🎯 功能特性总结:");
    console.log("=" .repeat(80));
    console.log("✅ 代币税收系统:");
    console.log("   • 基础税率: 买入3% / 卖出7% / 转账5%");
    console.log("   • 大额交易税率: 10% (超过100万FLOKI)");
    console.log("   • 频繁交易税率: 8% (5分钟内3次交易)");
    console.log("   • 反MEV税率: 15% (防止套利机器人)");
    console.log("");
    console.log("✅ 交易限制功能:");
    console.log("   • FLOKI: 单笔最大100万, 持币最大200万, 每日50次, 冷却60秒");
    console.log("   • PEPE: 单笔最大1000万, 每日100次, 冷却30秒");
    console.log("");
    console.log("✅ 流动性池集成:");
    console.log("   • 自动流动性管理 (阈值0.1 ETH)");
    console.log("   • 流动性锁定保护 (30天)");
    console.log("   • 滑点保护机制 (5%)");
    console.log("   • LP代币奖励系统");
    console.log("");
    console.log("✅ NFT铸造系统:");
    console.log("   • Merkle树白名单支持");
    console.log("   • 动态铸造价格 (当前0.01 ETH)");
    console.log("   • 防女巫攻击机制");
    console.log("   • 每地址限制10个NFT");
    console.log("");
    console.log("✅ 治理功能:");
    console.log("   • 投票权委托");
    console.log("   • 历史投票查询");
    console.log("   • EIP-712签名支持");
    console.log("");
    console.log("✅ 国库管理:");
    console.log("   • 自动税收分配 (30%营销+20%开发+30%流动性+20%回购)");
    console.log("   • 自动流动性添加");
    console.log("   • 手动流动性管理");
    console.log("=" .repeat(80));
    
    // ========== 使用指南 ==========
    console.log("\\n📖 使用指南:");
    console.log("=" .repeat(80));
    console.log("🔹 代币交易:");
    console.log("   await floki.transfer(recipient, amount);");
    console.log("   await pepe.transfer(recipient, amount);");
    console.log("");
    console.log("🔹 流动性操作:");
    console.log("   await liquidityPool.addLiquidity(tokenAmount, minToken, minEth, lockDuration, {value: ethAmount});");
    console.log("   await liquidityPool.removeLiquidity(lpAmount, minToken, minEth);");
    console.log("");
    console.log("🔹 NFT铸造:");
    console.log("   await nft.mint(merkleProof, attributes, {value: mintPrice});");
    console.log("");
    console.log("🔹 治理操作:");
    console.log("   await floki.delegate(delegatee);");
    console.log("   await floki.getVotesAtBlock(account, blockNumber);");
    console.log("");
    console.log("🔹 管理员操作:");
    console.log("   await taxHandler.setDefaultTaxRate(rate);");
    console.log("   await floki.setTradingLimits(enabled, maxTx, maxWallet, dailyLimit, cooldown);");
    console.log("   await treasuryHandler.processTax();");
    console.log("=" .repeat(80));
    
    // ========== 验证脚本 ==========
    console.log("\\n🧪 验证部署:");
    console.log("npx hardhat test test/meme/ComprehensiveTests.js --network localhost");
    console.log("");
    console.log("🚀 生态系统已完全部署并配置完成！");
    
    return deploymentAddresses;
}

// 执行部署
main()
    .then((addresses) => {
        console.log("\\n✅ 部署脚本执行成功！");
        console.log("🎯 所有合约地址:", addresses);
        process.exit(0);
    })
    .catch((error) => {
        console.error("\\n❌ 部署失败:", error);
        process.exit(1);
    });
