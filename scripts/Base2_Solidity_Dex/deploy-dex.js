const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * MetaNodeSwap DEX 完整部署脚本
 * 
 * 部署流程：
 * 1. 部署测试代币（仅测试网）
 * 2. 部署核心DEX合约
 * 3. 验证合约部署
 * 4. 创建示例池子
 * 5. 保存部署信息
 */
async function main() {
    console.log("🚀 开始部署 MetaNodeSwap DEX...");
    
    // 获取部署账户
    const [deployer] = await ethers.getSigners();
    console.log("📝 部署账户:", deployer.address);
    console.log("💰 账户余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");

    // 获取网络信息
    const network = await ethers.provider.getNetwork();
    console.log("🌐 部署网络:", network.name, "Chain ID:", network.chainId.toString());

    const deploymentInfo = {
        network: network.name,
        chainId: network.chainId.toString(),
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {},
        transactions: []
    };

    try {
        // ==================== 第一步：部署测试代币（仅测试网） ====================
        let token0, token1;
        
        if (network.chainId === 1337n || network.chainId === 31337n || network.chainId === 11155111n) {
            console.log("\n📦 部署测试代币...");
            
            const TestToken = await ethers.getContractFactory("DEXTestToken");
            const initialSupply = ethers.parseEther("1000000"); // 100万代币
            
            // 部署Token A
            console.log("   部署 Token A...");
            const tokenA = await TestToken.deploy("Test Token A", "TKNA", initialSupply);
            await tokenA.waitForDeployment();
            const tokenAAddress = await tokenA.getAddress();
            console.log("   ✅ Token A 部署完成:", tokenAAddress);
            
            // 部署Token B  
            console.log("   部署 Token B...");
            const tokenB = await TestToken.deploy("Test Token B", "TKNB", initialSupply);
            await tokenB.waitForDeployment();
            const tokenBAddress = await tokenB.getAddress();
            console.log("   ✅ Token B 部署完成:", tokenBAddress);
            
            // 确保代币地址排序 (token0 < token1)
            [token0, token1] = tokenAAddress < tokenBAddress ? 
                [tokenA, tokenB] : [tokenB, tokenA];
                
            deploymentInfo.contracts.token0 = await token0.getAddress();
            deploymentInfo.contracts.token1 = await token1.getAddress();
            deploymentInfo.transactions.push({
                name: "TestToken A",
                hash: tokenA.deploymentTransaction().hash,
                address: await tokenA.getAddress()
            });
            deploymentInfo.transactions.push({
                name: "TestToken B", 
                hash: tokenB.deploymentTransaction().hash,
                address: await tokenB.getAddress()
            });
        } else {
            console.log("⚠️  主网部署：跳过测试代币部署");
            console.log("   请手动设置 token0 和 token1 地址");
        }

        // ==================== 第二步：部署核心DEX合约 ====================
        console.log("\n🏗️  部署核心DEX合约...");

        // 2.1 部署 PoolManager (包含 Factory 功能)
        console.log("   部署 PoolManager...");
        const PoolManager = await ethers.getContractFactory("PoolManager");
        const poolManager = await PoolManager.deploy();
        await poolManager.waitForDeployment();
        const poolManagerAddress = await poolManager.getAddress();
        console.log("   ✅ PoolManager 部署完成:", poolManagerAddress);
        
        deploymentInfo.contracts.poolManager = poolManagerAddress;
        deploymentInfo.transactions.push({
            name: "PoolManager",
            hash: poolManager.deploymentTransaction().hash,
            address: poolManagerAddress
        });

        // 2.2 部署 SwapRouter
        console.log("   部署 SwapRouter...");
        const SwapRouter = await ethers.getContractFactory("SwapRouter");
        const swapRouter = await SwapRouter.deploy(poolManagerAddress);
        await swapRouter.waitForDeployment();
        const swapRouterAddress = await swapRouter.getAddress();
        console.log("   ✅ SwapRouter 部署完成:", swapRouterAddress);
        
        deploymentInfo.contracts.swapRouter = swapRouterAddress;
        deploymentInfo.transactions.push({
            name: "SwapRouter",
            hash: swapRouter.deploymentTransaction().hash,
            address: swapRouterAddress
        });

        // 2.3 部署 PositionManager
        console.log("   部署 PositionManager...");
        const PositionManager = await ethers.getContractFactory("PositionManager");
        const positionManager = await PositionManager.deploy(poolManagerAddress);
        await positionManager.waitForDeployment();
        const positionManagerAddress = await positionManager.getAddress();
        console.log("   ✅ PositionManager 部署完成:", positionManagerAddress);
        
        deploymentInfo.contracts.positionManager = positionManagerAddress;
        deploymentInfo.transactions.push({
            name: "PositionManager",
            hash: positionManager.deploymentTransaction().hash,
            address: positionManagerAddress
        });

        // ==================== 第三步：验证合约部署 ====================
        console.log("\n🔍 验证合约部署...");
        
        // 验证 SwapRouter 配置
        const routerPoolManager = await swapRouter.poolManager();
        console.log("   SwapRouter.poolManager:", routerPoolManager);
        console.log("   配置正确:", routerPoolManager === poolManagerAddress ? "✅" : "❌");
        
        // 验证 PositionManager 配置
        const positionPoolManager = await positionManager.poolManager();
        console.log("   PositionManager.poolManager:", positionPoolManager);
        console.log("   配置正确:", positionPoolManager === poolManagerAddress ? "✅" : "❌");
        
        // 验证 PositionManager NFT 信息
        const nftName = await positionManager.name();
        const nftSymbol = await positionManager.symbol();
        console.log("   NFT名称:", nftName);
        console.log("   NFT符号:", nftSymbol);

        // ==================== 第四步：创建示例池子（仅测试网） ====================
        if (token0 && token1) {
            console.log("\n🏊 创建示例池子...");
            
            const TICK_LOWER = -60;    // 价格区间下限
            const TICK_UPPER = 60;     // 价格区间上限  
            const FEE = 3000;          // 0.3% 手续费
            const SQRT_PRICE_X96 = "79228162514264337593543950336"; // 价格 = 1
            
            // 创建并初始化池子
            console.log("   创建池子参数:");
            console.log("     Token0:", await token0.getAddress());
            console.log("     Token1:", await token1.getAddress());
            console.log("     TickLower:", TICK_LOWER);
            console.log("     TickUpper:", TICK_UPPER);
            console.log("     Fee:", FEE, "(0.3%)");
            
            const createPoolTx = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });
            
            const receipt = await createPoolTx.wait();
            console.log("   ✅ 池子创建交易:", createPoolTx.hash);
            
            // 获取池子地址
            const poolAddress = await poolManager.getPool(
                await token0.getAddress(),
                await token1.getAddress(),
                0
            );
            console.log("   ✅ 池子地址:", poolAddress);
            
            deploymentInfo.contracts.examplePool = poolAddress;
            deploymentInfo.transactions.push({
                name: "Example Pool Creation",
                hash: createPoolTx.hash,
                address: poolAddress
            });
            
            // 验证池子状态
            const Pool = await ethers.getContractFactory("Pool");
            const pool = Pool.attach(poolAddress);
            const poolSqrtPrice = await pool.sqrtPriceX96();
            const poolTick = await pool.tick();
            console.log("   池子价格 (sqrtPriceX96):", poolSqrtPrice.toString());
            console.log("   池子tick:", poolTick.toString());
        }

        // ==================== 第五步：保存部署信息 ====================
        console.log("\n💾 保存部署信息...");
        
        const deploymentsDir = path.join(__dirname, "../../deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        const filename = `metanodeswap-${network.name}-${timestamp}.json`;
        const filepath = path.join(deploymentsDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));
        console.log("   ✅ 部署信息已保存:", filename);

        // ==================== 部署完成总结 ====================
        console.log("\n🎉 MetaNodeSwap DEX 部署完成!");
        console.log("\n📋 部署总结:");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        if (token0 && token1) {
            console.log("🪙 测试代币:");
            console.log("   Token0:", await token0.getAddress());
            console.log("   Token1:", await token1.getAddress());
        }
        
        console.log("🏗️  核心合约:");
        console.log("   PoolManager:    ", poolManagerAddress);
        console.log("   SwapRouter:     ", swapRouterAddress);
        console.log("   PositionManager:", positionManagerAddress);
        
        if (deploymentInfo.contracts.examplePool) {
            console.log("🏊 示例池子:");
            console.log("   Pool Address:   ", deploymentInfo.contracts.examplePool);
        }
        
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        // ==================== 使用说明 ====================
        console.log("\n📖 使用说明:");
        console.log("1. 流动性提供:");
        console.log("   - 使用 PositionManager.mint() 添加流动性");
        console.log("   - 使用 PositionManager.burn() 移除流动性");
        console.log("   - 使用 PositionManager.collect() 收取手续费");
        
        console.log("\n2. 代币交换:");
        console.log("   - 使用 SwapRouter.exactInput() 进行精确输入交换");
        console.log("   - 使用 SwapRouter.exactOutput() 进行精确输出交换");
        console.log("   - 使用 SwapRouter.quoteExactInput() 进行价格查询");
        
        console.log("\n3. 池子管理:");
        console.log("   - 使用 PoolManager.createPool() 创建新池子");
        console.log("   - 使用 PoolManager.getAllPools() 查询所有池子");
        console.log("   - 使用 PoolManager.getPairs() 查询所有代币对");
        
        if (token0 && token1) {
            console.log("\n⚠️  注意事项:");
            console.log("   - 这是测试网部署，代币仅用于测试");
            console.log("   - 请勿在主网使用测试代币");
            console.log("   - 建议先在测试网充分测试后再部署到主网");
        }
        
        return {
            poolManager,
            swapRouter,
            positionManager,
            token0,
            token1,
            deploymentInfo
        };

    } catch (error) {
        console.error("\n❌ 部署失败:", error);
        
        // 保存错误信息
        deploymentInfo.error = {
            message: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        };
        
        const deploymentsDir = path.join(__dirname, "../../deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        const filename = `metanodeswap-${network.name}-${timestamp}-ERROR.json`;
        const filepath = path.join(deploymentsDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));
        console.log("   错误信息已保存:", filename);
        
        throw error;
    }
}

// 执行部署脚本
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = main;
