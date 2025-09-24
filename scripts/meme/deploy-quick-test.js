const { ethers } = require("hardhat");

/**
 * 🚀 快速测试部署脚本
 * 
 * 用于快速部署核心合约进行开发测试
 * 包含基本配置，适合开发环境使用
 */
async function main() {
    console.log("🚀 快速测试部署开始...\\n");
    
    const [deployer, user1, user2] = await ethers.getSigners();
    console.log("部署者:", deployer.address);
    console.log("余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\\n");
    
    const contracts = {};
    
    // 1. 部署税收处理器
    console.log("📦 部署税收处理器...");
    const SimpleTaxHandler = await ethers.getContractFactory("SimpleTaxHandler");
    const taxHandler = await SimpleTaxHandler.deploy(deployer.address, ethers.ZeroAddress);
    await taxHandler.waitForDeployment();
    contracts.taxHandler = await taxHandler.getAddress();
    console.log("✅", contracts.taxHandler);
    
    // 2. 部署国库处理器
    console.log("\\n📦 部署国库处理器...");
    const SimpleTreasuryHandler = await ethers.getContractFactory("SimpleTreasuryHandler");
    const treasuryHandler = await SimpleTreasuryHandler.deploy(
        deployer.address,
        user1.address, // 营销钱包
        deployer.address, // 开发钱包
        deployer.address  // 流动性钱包
    );
    await treasuryHandler.waitForDeployment();
    contracts.treasuryHandler = await treasuryHandler.getAddress();
    console.log("✅", contracts.treasuryHandler);
    
    // 3. 部署FLOKI代币
    console.log("\\n📦 部署FLOKI代币...");
    const FLOKI = await ethers.getContractFactory("FLOKI");
    const floki = await FLOKI.deploy(
        "Floki Test",
        "FLOKI",
        contracts.taxHandler,
        contracts.treasuryHandler
    );
    await floki.waitForDeployment();
    contracts.floki = await floki.getAddress();
    console.log("✅", contracts.floki);
    
    // 4. 部署PEPE代币
    console.log("\\n📦 部署PEPE代币...");
    const PepeToken = await ethers.getContractFactory("PepeToken");
    const pepe = await PepeToken.deploy(ethers.parseUnits("1000000", 18));
    await pepe.waitForDeployment();
    contracts.pepe = await pepe.getAddress();
    console.log("✅", contracts.pepe);
    
    // 5. 部署流动性池
    console.log("\\n📦 部署流动性池...");
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy(contracts.floki, deployer.address);
    await liquidityPool.waitForDeployment();
    contracts.liquidityPool = await liquidityPool.getAddress();
    console.log("✅", contracts.liquidityPool);
    
    // 6. 基本配置
    console.log("\\n⚙️  基本配置...");
    await treasuryHandler.setTokenContract(contracts.floki);
    await treasuryHandler.setLiquidityPool(contracts.liquidityPool);
    
    // 设置基本税率
    await taxHandler.setDefaultTaxRate(500); // 5%
    
    // 设置交易限制
    await floki.setTradingLimits(
        true,
        ethers.parseUnits("100000", 9), // 最大交易10万FLOKI
        ethers.parseUnits("500000", 9), // 最大持币50万FLOKI
        10, // 每日10次交易
        30  // 30秒冷却
    );
    
    console.log("✅ 配置完成");
    
    // 7. 快速测试
    console.log("\\n🧪 快速功能测试...");
    
    // 测试转账和税收
    const transferAmount = ethers.parseUnits("1000", 9);
    await taxHandler.setTaxExemption(deployer.address, false);
    
    const balanceBefore = await floki.balanceOf(user2.address);
    const treasuryBefore = await floki.balanceOf(contracts.treasuryHandler);
    
    await floki.transfer(user2.address, transferAmount);
    
    const balanceAfter = await floki.balanceOf(user2.address);
    const treasuryAfter = await floki.balanceOf(contracts.treasuryHandler);
    
    const received = balanceAfter - balanceBefore;
    const tax = treasuryAfter - treasuryBefore;
    
    console.log(`转账: ${ethers.formatUnits(transferAmount, 9)} FLOKI`);
    console.log(`到账: ${ethers.formatUnits(received, 9)} FLOKI`);
    console.log(`税收: ${ethers.formatUnits(tax, 9)} FLOKI`);
    console.log(`税率: ${(Number(tax) * 100 / Number(transferAmount)).toFixed(2)}%`);
    
    await taxHandler.setTaxExemption(deployer.address, true);
    
    console.log("\\n🎉 快速部署测试完成！");
    console.log("\\n📋 合约地址:");
    Object.entries(contracts).forEach(([name, address]) => {
        console.log(`${name}: ${address}`);
    });
    
    return contracts;
}

main()
    .then((contracts) => {
        console.log("\\n✅ 快速部署成功！");
        process.exit(0);
    })
    .catch((error) => {
        console.error("\\n❌ 部署失败:", error);
        process.exit(1);
    });
