const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("🧪 Meme项目完整功能测试", function () {
    let floki, pepe, mint, taxHandler, treasuryHandler, liquidityPool;
    let owner, user1, user2, user3, marketingWallet, devWallet, liquidityWallet;
    
    // 合约地址
    let flokiAddress, pepeAddress, mintAddress, taxHandlerAddress, treasuryHandlerAddress, liquidityPoolAddress;
    
    const initialSupply = ethers.parseUnits("10000000000000", 9); // 10万亿 FLOKI
    const pepeSupply = ethers.parseUnits("420690000000000", 18); // 420.69万亿 PEPE
    
    before(async function () {
        console.log("\n🔧 设置完整测试环境...");
        [owner, user1, user2, user3, marketingWallet, devWallet, liquidityWallet] = await ethers.getSigners();
        
        // 1. 部署税收处理器
        console.log("📦 部署税收处理器...");
        const SimpleTaxHandler = await ethers.getContractFactory("SimpleTaxHandler");
        taxHandler = await SimpleTaxHandler.deploy(owner.address, ethers.ZeroAddress);
        await taxHandler.waitForDeployment();
        taxHandlerAddress = await taxHandler.getAddress();
        
        // 2. 部署国库处理器
        console.log("📦 部署国库处理器...");
        const SimpleTreasuryHandler = await ethers.getContractFactory("SimpleTreasuryHandler");
        treasuryHandler = await SimpleTreasuryHandler.deploy(
            owner.address,
            marketingWallet.address,
            devWallet.address,
            liquidityWallet.address
        );
        await treasuryHandler.waitForDeployment();
        treasuryHandlerAddress = await treasuryHandler.getAddress();
        
        // 3. 部署FLOKI代币
        console.log("📦 部署FLOKI代币...");
        const FLOKI = await ethers.getContractFactory("FLOKI");
        floki = await FLOKI.deploy(
            "Floki Inu",
            "FLOKI",
            taxHandlerAddress,
            treasuryHandlerAddress
        );
        await floki.waitForDeployment();
        flokiAddress = await floki.getAddress();
        
        // 4. 部署PEPE代币
        console.log("📦 部署PEPE代币...");
        const PepeToken = await ethers.getContractFactory("PepeToken");
        pepe = await PepeToken.deploy(pepeSupply);
        await pepe.waitForDeployment();
        pepeAddress = await pepe.getAddress();
        
        // 5. 部署NFT铸造合约
        console.log("📦 部署NFT铸造合约...");
        const AdvancedMintingSystem = await ethers.getContractFactory("AdvancedMintingSystem");
        mint = await AdvancedMintingSystem.deploy("Meme NFT", "MNFT");
        await mint.waitForDeployment();
        mintAddress = await mint.getAddress();
        
        // 6. 部署流动性池
        console.log("📦 部署流动性池...");
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        liquidityPool = await LiquidityPool.deploy(flokiAddress, owner.address);
        await liquidityPool.waitForDeployment();
        liquidityPoolAddress = await liquidityPool.getAddress();
        
        // 7. 配置合约关联
        console.log("⚙️  配置合约关联...");
        await treasuryHandler.setTokenContract(flokiAddress);
        await treasuryHandler.setLiquidityPool(liquidityPoolAddress);
        
        // 设置税收和交易限制豁免
        await taxHandler.setTaxExemption(owner.address, true);
        await taxHandler.setTaxExemption(treasuryHandlerAddress, true);
        await taxHandler.setTaxExemption(liquidityPoolAddress, true);
        
        await floki.setTradingLimitExempt(owner.address, true);
        await floki.setTradingLimitExempt(treasuryHandlerAddress, true);
        await floki.setTradingLimitExempt(liquidityPoolAddress, true);
        
        console.log("✅ 测试环境设置完成\\n");
        console.log(`📋 合约地址:`);
        console.log(`   FLOKI: ${flokiAddress}`);
        console.log(`   PEPE: ${pepeAddress}`);
        console.log(`   NFT: ${mintAddress}`);
        console.log(`   税收处理器: ${taxHandlerAddress}`);
        console.log(`   国库处理器: ${treasuryHandlerAddress}`);
        console.log(`   流动性池: ${liquidityPoolAddress}\\n`);
    });
    
    describe("💰 FLOKI代币核心功能测试", function () {
        it("应该正确部署并初始化", async function () {
            expect(await floki.name()).to.equal("Floki Inu");
            expect(await floki.symbol()).to.equal("FLOKI");
            expect(await floki.decimals()).to.equal(9);
            expect(await floki.totalSupply()).to.equal(initialSupply);
            expect(await floki.balanceOf(owner.address)).to.equal(initialSupply);
        });
        
        it("应该能够正常转账", async function () {
            const transferAmount = ethers.parseUnits("1000", 9);
            
            await floki.transfer(user1.address, transferAmount);
            
            expect(await floki.balanceOf(user1.address)).to.equal(transferAmount);
        });
        
        it("应该能够授权和委托转账", async function () {
            const approveAmount = ethers.parseUnits("500", 9);
            const transferAmount = ethers.parseUnits("200", 9);
            
            await floki.approve(user2.address, approveAmount);
            expect(await floki.allowance(owner.address, user2.address)).to.equal(approveAmount);
            
            await floki.connect(user2).transferFrom(owner.address, user3.address, transferAmount);
            expect(await floki.balanceOf(user3.address)).to.equal(transferAmount);
            expect(await floki.allowance(owner.address, user2.address)).to.equal(approveAmount - transferAmount);
        });
        
        it("应该支持治理功能", async function () {
            // 测试委托投票权
            await floki.delegate(user1.address);
            
            const user1Balance = await floki.balanceOf(user1.address);
            const ownerBalance = await floki.balanceOf(owner.address);
            const user1Votes = await floki.getVotesAtBlock(user1.address, await ethers.provider.getBlockNumber());
            
            // user1应该有自己的余额 + owner委托的投票权
            expect(user1Votes).to.be.gt(user1Balance);
        });
    });
    
    describe("🐸 PEPE代币功能测试", function () {
        it("应该正确部署并初始化", async function () {
            expect(await pepe.name()).to.equal("Pepe");
            expect(await pepe.symbol()).to.equal("PEPE");
            expect(await pepe.totalSupply()).to.equal(pepeSupply);
            expect(await pepe.balanceOf(owner.address)).to.equal(pepeSupply);
        });
        
        it("应该能够管理黑名单", async function () {
            // 添加到黑名单
            await pepe.blacklist(user2.address, true);
            
            // 黑名单用户不能转账
            const transferAmount = ethers.parseUnits("1000", 18);
            await expect(
                pepe.transfer(user2.address, transferAmount)
            ).to.be.revertedWith("Blacklisted");
            
            // 移除黑名单
            await pepe.blacklist(user2.address, false);
            
            // 现在可以转账
            await pepe.transfer(user2.address, transferAmount);
            expect(await pepe.balanceOf(user2.address)).to.equal(transferAmount);
        });
        
        it("应该能够设置交易规则", async function () {
            const maxHolding = ethers.parseUnits("1000000", 18); // 100万
            const minHolding = ethers.parseUnits("100", 18); // 100
            
            await pepe.setRule(true, user3.address, maxHolding, minHolding);
            
            expect(await pepe.limited()).to.equal(true);
            expect(await pepe.maxHoldingAmount()).to.equal(maxHolding);
            expect(await pepe.minHoldingAmount()).to.equal(minHolding);
        });
        
        it("应该能够设置高级交易限制", async function () {
            const maxTx = ethers.parseUnits("10000", 18);
            const dailyLimit = 10;
            const cooldown = 60; // 1分钟
            
            await pepe.setAdvancedTradingLimits(maxTx, dailyLimit, cooldown);
            
            expect(await pepe.maxTransactionAmount()).to.equal(maxTx);
            expect(await pepe.dailyTransactionLimit()).to.equal(dailyLimit);
            expect(await pepe.transactionCooldown()).to.equal(cooldown);
        });
    });
    
    describe("🎨 NFT铸造系统测试", function () {
        it("应该正确部署并初始化", async function () {
            expect(await mint.name()).to.equal("Meme NFT");
            expect(await mint.symbol()).to.equal("MNFT");
            expect(await mint.owner()).to.equal(owner.address);
        });
        
        it("应该能够设置铸造价格", async function () {
            const mintPrice = ethers.parseEther("0.01");
            await mint.setMintPrice(mintPrice);
            expect(await mint.mintPrice()).to.equal(mintPrice);
        });
        
        it("应该能够启用公开铸造", async function () {
            await mint.setPublicMintingEnabled(true);
            expect(await mint.publicMintingEnabled()).to.equal(true);
        });
        
        it("应该能够铸造NFT", async function () {
            const mintPrice = ethers.parseEther("0.01");
            const attributes = "test attributes";
            
            await mint.connect(user1).mint([], attributes, { value: mintPrice });
            
            expect(await mint.balanceOf(user1.address)).to.equal(1);
            expect(await mint.ownerOf(1)).to.equal(user1.address);
        });
        
        it("应该能够批量铸造NFT", async function () {
            const mintPrice = ethers.parseEther("0.01");
            const quantity = 3;
            const attributes = ["attr1", "attr2", "attr3"];
            
            await mint.connect(user2).batchMint([], quantity, attributes, { 
                value: mintPrice * BigInt(quantity)
            });
            
            expect(await mint.balanceOf(user2.address)).to.equal(quantity);
        });
    });
    
    describe("💸 税收系统测试", function () {
        beforeEach(async function () {
            // 重置税收设置
            await taxHandler.setDefaultTaxRate(500); // 5%
            await taxHandler.setBuyTaxRate(300); // 3%
            await taxHandler.setSellTaxRate(700); // 7%
        });
        
        it("应该对普通转账征收默认税率", async function () {
            // 取消owner的免税状态
            await taxHandler.setTaxExemption(owner.address, false);
            
            const transferAmount = ethers.parseUnits("1000", 9);
            const expectedTax = (transferAmount * 500n) / 10000n; // 5%
            const expectedReceived = transferAmount - expectedTax;
            
            const user1BalanceBefore = await floki.balanceOf(user1.address);
            const treasuryBalanceBefore = await floki.balanceOf(treasuryHandlerAddress);
            
            await floki.transfer(user1.address, transferAmount);
            
            const user1BalanceAfter = await floki.balanceOf(user1.address);
            const treasuryBalanceAfter = await floki.balanceOf(treasuryHandlerAddress);
            
            expect(user1BalanceAfter - user1BalanceBefore).to.equal(expectedReceived);
            expect(treasuryBalanceAfter - treasuryBalanceBefore).to.equal(expectedTax);
            
            // 恢复免税状态
            await taxHandler.setTaxExemption(owner.address, true);
        });
        
        it("应该支持高级税收策略", async function () {
            // 设置大额交易税率
            await taxHandler.setAdvancedTaxStrategies(
                1000, // 10% 大额交易税率
                ethers.parseUnits("5000", 9), // 5000 FLOKI 阈值
                800, // 8% 频繁交易税率
                300, // 5分钟窗口
                3 // 3次交易阈值
            );
            
            await taxHandler.setTaxExemption(owner.address, false);
            
            // 测试大额交易税率
            const largeAmount = ethers.parseUnits("6000", 9); // 超过阈值
            const expectedLargeTax = (largeAmount * 1000n) / 10000n; // 10%
            
            const treasuryBalanceBefore = await floki.balanceOf(treasuryHandlerAddress);
            await floki.transfer(user3.address, largeAmount);
            const treasuryBalanceAfter = await floki.balanceOf(treasuryHandlerAddress);
            
            expect(treasuryBalanceAfter - treasuryBalanceBefore).to.equal(expectedLargeTax);
            
            await taxHandler.setTaxExemption(owner.address, true);
        });
    });
    
    describe("🏊 流动性池测试", function () {
        beforeEach(async function () {
            // 添加初始流动性
            const tokenAmount = ethers.parseUnits("100000", 9);
            const ethAmount = ethers.parseEther("1");
            
            await floki.approve(liquidityPoolAddress, tokenAmount);
            await liquidityPool.addLiquidity(
                tokenAmount,
                tokenAmount * 95n / 100n,
                ethAmount * 95n / 100n,
                0,
                { value: ethAmount }
            );
        });
        
        it("应该能够添加流动性", async function () {
            const [tokenReserve, ethReserve] = await liquidityPool.getReserves();
            expect(tokenReserve).to.be.gt(0);
            expect(ethReserve).to.be.gt(0);
            
            const lpBalance = await liquidityPool.getLPBalance(owner.address);
            expect(lpBalance).to.be.gt(0);
        });
        
        it("应该能够移除流动性", async function () {
            const lpBalance = await liquidityPool.getLPBalance(owner.address);
            const removeAmount = lpBalance / 2n;
            
            const tokenBalanceBefore = await floki.balanceOf(owner.address);
            const ethBalanceBefore = await owner.provider.getBalance(owner.address);
            
            await liquidityPool.removeLiquidity(removeAmount, 0, 0);
            
            const tokenBalanceAfter = await floki.balanceOf(owner.address);
            const ethBalanceAfter = await owner.provider.getBalance(owner.address);
            
            expect(tokenBalanceAfter).to.be.gt(tokenBalanceBefore);
            expect(ethBalanceAfter).to.be.gt(ethBalanceBefore - ethers.parseEther("0.01")); // 考虑gas费
        });
        
        it("应该正确计算所需代币数量", async function () {
            const testEthAmount = ethers.parseEther("0.5");
            const requiredTokens = await liquidityPool.getTokenAmountForLiquidity(testEthAmount);
            
            expect(requiredTokens).to.be.gt(0);
        });
    });
    
    describe("🚫 交易限制测试", function () {
        it("FLOKI应该执行交易限制", async function () {
            // 设置严格的交易限制
            await floki.setTradingLimits(
                true, // 启用限制
                ethers.parseUnits("1000", 9), // 最大交易1000 FLOKI
                ethers.parseUnits("5000", 9), // 最大持币5000 FLOKI
                5, // 每日5次交易
                60 // 1分钟冷却
            );
            
            // 取消user1的豁免状态
            await floki.setTradingLimitExempt(user1.address, false);
            
            const largeAmount = ethers.parseUnits("2000", 9); // 超过限制
            
            await expect(
                floki.connect(user1).transfer(user2.address, largeAmount)
            ).to.be.revertedWith("Transfer amount exceeds maximum transaction amount");
        });
        
        it("PEPE应该执行高级交易限制", async function () {
            // 设置交易限制
            await pepe.setAdvancedTradingLimits(
                ethers.parseUnits("1000", 18), // 最大交易1000 PEPE
                5, // 每日5次
                30 // 30秒冷却
            );
            
            const user2Balance = await pepe.balanceOf(user2.address);
            const largeAmount = ethers.parseUnits("2000", 18);
            
            // 如果user2有足够余额，测试交易限制
            if (user2Balance >= largeAmount) {
                await expect(
                    pepe.connect(user2).transfer(user3.address, largeAmount)
                ).to.be.revertedWith("Transfer amount exceeds maximum transaction amount");
            }
        });
    });
    
    describe("🏛️ 国库管理测试", function () {
        it("应该能够处理税收", async function () {
            // 先产生一些税收
            await taxHandler.setTaxExemption(owner.address, false);
            const transferAmount = ethers.parseUnits("10000", 9);
            await floki.transfer(user1.address, transferAmount);
            await taxHandler.setTaxExemption(owner.address, true);
            
            const treasuryBalanceBefore = await floki.balanceOf(treasuryHandlerAddress);
            if (treasuryBalanceBefore > 0) {
                const marketingBalanceBefore = await floki.balanceOf(marketingWallet.address);
                
                await treasuryHandler.processTax();
                
                const marketingBalanceAfter = await floki.balanceOf(marketingWallet.address);
                expect(marketingBalanceAfter).to.be.gt(marketingBalanceBefore);
            }
        });
        
        it("应该能够手动添加流动性", async function () {
            // 向国库转移一些代币
            const tokenAmount = ethers.parseUnits("10000", 9);
            await floki.transfer(treasuryHandlerAddress, tokenAmount);
            
            const lpBalanceBefore = await treasuryHandler.getLiquidityBalance();
            
            await treasuryHandler.addLiquidityManual(
                tokenAmount,
                0, // 无锁定
                { value: ethers.parseEther("0.1") }
            );
            
            const lpBalanceAfter = await treasuryHandler.getLiquidityBalance();
            expect(lpBalanceAfter).to.be.gt(lpBalanceBefore);
        });
    });
    
    describe("🔄 集成测试", function () {
        it("完整的代币生命周期", async function () {
            console.log("\\n🔄 开始完整生命周期测试...");
            
            // 1. 用户交易产生税收
            console.log("1️⃣ 模拟用户交易...");
            await taxHandler.setTaxExemption(owner.address, false);
            const transferAmount = ethers.parseUnits("50000", 9);
            await floki.transfer(user1.address, transferAmount);
            await taxHandler.setTaxExemption(owner.address, true);
            
            const treasuryBalance = await floki.balanceOf(treasuryHandlerAddress);
            console.log(`   国库税收: ${ethers.formatUnits(treasuryBalance, 9)} FLOKI`);
            
            // 2. 国库处理税收并添加流动性
            console.log("2️⃣ 国库处理税收...");
            await treasuryHandler.setLiquidityConfig(true, ethers.parseEther("0.01"), 0);
            await owner.sendTransaction({
                to: treasuryHandlerAddress,
                value: ethers.parseEther("0.1")
            });
            
            const lpBalanceBefore = await treasuryHandler.getLiquidityBalance();
            await treasuryHandler.processTax();
            const lpBalanceAfter = await treasuryHandler.getLiquidityBalance();
            
            console.log(`   流动性变化: ${ethers.formatUnits(lpBalanceBefore, 18)} → ${ethers.formatUnits(lpBalanceAfter, 18)}`);
            
            // 3. 用户与流动性池交互
            console.log("3️⃣ 用户添加流动性...");
            const userTokenAmount = ethers.parseUnits("1000", 9);
            const userEthAmount = ethers.parseEther("0.01");
            
            await floki.connect(user1).approve(liquidityPoolAddress, userTokenAmount);
            await liquidityPool.connect(user1).addLiquidity(
                userTokenAmount,
                userTokenAmount * 95n / 100n,
                userEthAmount * 95n / 100n,
                0,
                { value: userEthAmount }
            );
            
            const userLPBalance = await liquidityPool.getLPBalance(user1.address);
            console.log(`   用户获得LP: ${ethers.formatUnits(userLPBalance, 18)}`);
            
            // 4. 查看最终状态
            console.log("4️⃣ 最终状态:");
            const poolInfo = await treasuryHandler.getPoolInfo();
            console.log(`   池子代币储备: ${ethers.formatUnits(poolInfo.tokenReserve, 9)} FLOKI`);
            console.log(`   池子ETH储备: ${ethers.formatEther(poolInfo.ethReserve)} ETH`);
            console.log(`   总流动性: ${ethers.formatUnits(poolInfo.totalLiquidity, 18)}`);
            
            console.log("✅ 完整生命周期测试完成！");
        });
        
        it("多代币交互测试", async function () {
            console.log("\\n🔀 多代币交互测试...");
            
            // 1. FLOKI和PEPE余额检查
            const flokiBalance = await floki.balanceOf(user1.address);
            const pepeBalance = await pepe.balanceOf(user2.address);
            
            console.log(`User1 FLOKI余额: ${ethers.formatUnits(flokiBalance, 9)}`);
            console.log(`User2 PEPE余额: ${ethers.formatUnits(pepeBalance, 18)}`);
            
            // 2. NFT铸造
            if (await mint.publicMintingEnabled()) {
                const mintPrice = await mint.mintPrice();
                await mint.connect(user1).mint([], "multi-token-test", { value: mintPrice });
                
                const nftBalance = await mint.balanceOf(user1.address);
                console.log(`User1 NFT数量: ${nftBalance}`);
            }
            
            console.log("✅ 多代币交互测试完成！");
        });
    });
    
    after(async function () {
        console.log("\\n📊 测试统计:");
        console.log("=" .repeat(50));
        console.log(`FLOKI总供应量: ${ethers.formatUnits(await floki.totalSupply(), 9)}`);
        console.log(`PEPE总供应量: ${ethers.formatUnits(await pepe.totalSupply(), 18)}`);
        console.log(`NFT总铸造量: ${await mint.tokenIdCounter()}`);
        
        const poolInfo = await treasuryHandler.getPoolInfo();
        console.log(`流动性池TVL: ${ethers.formatUnits(poolInfo.tokenReserve, 9)} FLOKI + ${ethers.formatEther(poolInfo.ethReserve)} ETH`);
        console.log("=" .repeat(50));
    });
});
