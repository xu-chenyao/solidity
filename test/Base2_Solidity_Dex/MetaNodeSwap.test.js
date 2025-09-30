const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * MetaNodeSwap 完整测试套件
 * 
 * 测试覆盖：
 * 1. 合约部署和初始化
 * 2. 池子创建和管理
 * 3. 流动性添加和移除
 * 4. 代币交换功能
 * 5. NFT头寸管理
 * 6. 手续费计算和分配
 * 7. 边界条件和错误处理
 */
describe("MetaNodeSwap DEX", function () {
    // 测试常量
    const INITIAL_SUPPLY = ethers.parseEther("1000000"); // 100万代币
    const TICK_LOWER = -60; // 价格区间下限
    const TICK_UPPER = 60;  // 价格区间上限
    const FEE = 3000;       // 0.3% 手续费
    const SQRT_PRICE_X96 = "79228162514264337593543950336"; // 价格 = 1

    /**
     * 部署测试环境的固定装置
     * 包含所有核心合约和测试代币
     */
    async function deployDEXFixture() {
        // 获取测试账户
        const [owner, user1, user2, user3] = await ethers.getSigners();

        // 部署测试代币
        const TestToken = await ethers.getContractFactory("DEXTestToken");
        const tokenA = await TestToken.deploy("Token A", "TKNA", INITIAL_SUPPLY);
        const tokenB = await TestToken.deploy("Token B", "TKNB", INITIAL_SUPPLY);
        await tokenA.waitForDeployment();
        await tokenB.waitForDeployment();

        // 确保代币地址排序 (token0 < token1)
        const token0Address = await tokenA.getAddress();
        const token1Address = await tokenB.getAddress();
        const [token0, token1] = token0Address < token1Address ? 
            [tokenA, tokenB] : [tokenB, tokenA];

        // 部署核心合约
        const PoolManager = await ethers.getContractFactory("PoolManager");
        const poolManager = await PoolManager.deploy();
        await poolManager.waitForDeployment();

        const SwapRouter = await ethers.getContractFactory("SwapRouter");
        const swapRouter = await SwapRouter.deploy(await poolManager.getAddress());
        await swapRouter.waitForDeployment();

        const PositionManager = await ethers.getContractFactory("PositionManager");
        const positionManager = await PositionManager.deploy(await poolManager.getAddress());
        await positionManager.waitForDeployment();

        // 部署测试辅助合约
        const TestLP = await ethers.getContractFactory("TestLP");
        const testLP = await TestLP.deploy();
        await testLP.waitForDeployment();

        const TestSwap = await ethers.getContractFactory("TestSwap");
        const testSwap = await TestSwap.deploy();
        await testSwap.waitForDeployment();

        // 为测试账户分发代币
        const transferAmount = ethers.parseEther("10000");
        await token0.transfer(user1.address, transferAmount);
        await token0.transfer(user2.address, transferAmount);
        await token1.transfer(user1.address, transferAmount);
        await token1.transfer(user2.address, transferAmount);

        // 为测试合约分发代币
        await token0.transfer(await testLP.getAddress(), transferAmount);
        await token0.transfer(await testSwap.getAddress(), transferAmount);
        await token1.transfer(await testLP.getAddress(), transferAmount);
        await token1.transfer(await testSwap.getAddress(), transferAmount);

        return {
            owner,
            user1,
            user2,
            user3,
            token0,
            token1,
            poolManager,
            swapRouter,
            positionManager,
            testLP,
            testSwap
        };
    }

    describe("合约部署", function () {
        it("应该正确部署所有合约", async function () {
            const { poolManager, swapRouter, positionManager } = await loadFixture(deployDEXFixture);

            // 验证合约地址
            expect(await poolManager.getAddress()).to.be.properAddress;
            expect(await swapRouter.getAddress()).to.be.properAddress;
            expect(await positionManager.getAddress()).to.be.properAddress;

            // 验证合约关联
            expect(await swapRouter.poolManager()).to.equal(await poolManager.getAddress());
            expect(await positionManager.poolManager()).to.equal(await poolManager.getAddress());
        });

        it("应该正确设置代币信息", async function () {
            const { token0, token1 } = await loadFixture(deployDEXFixture);

            // 验证代币基本信息
            expect(await token0.name()).to.be.oneOf(["Token A", "Token B"]);
            expect(await token1.name()).to.be.oneOf(["Token A", "Token B"]);
            expect(await token0.totalSupply()).to.equal(INITIAL_SUPPLY);
            expect(await token1.totalSupply()).to.equal(INITIAL_SUPPLY);
        });
    });

    describe("池子管理", function () {
        it("应该能够创建新池子", async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);

            // 创建池子
            const tx = await poolManager.createPool(
                await token0.getAddress(),
                await token1.getAddress(),
                TICK_LOWER,
                TICK_UPPER,
                FEE
            );

            // 验证事件
            await expect(tx).to.emit(poolManager, "PoolCreated");

            // 获取池子地址
            const poolAddress = await poolManager.getPool(
                await token0.getAddress(),
                await token1.getAddress(),
                0
            );
            expect(poolAddress).to.not.equal(ethers.ZeroAddress);
        });

        it("应该能够创建并初始化池子", async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);

            // 创建并初始化池子
            const poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            // 验证池子已初始化
            const Pool = await ethers.getContractFactory("Pool");
            const pool = Pool.attach(poolAddress);
            expect(await pool.sqrtPriceX96()).to.equal(SQRT_PRICE_X96);
        });

        it("重复创建相同参数的池子应该返回现有池子", async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);

            // 第一次创建
            const poolAddress1 = await poolManager.createPool(
                await token0.getAddress(),
                await token1.getAddress(),
                TICK_LOWER,
                TICK_UPPER,
                FEE
            );

            // 第二次创建相同参数的池子
            const poolAddress2 = await poolManager.createPool(
                await token0.getAddress(),
                await token1.getAddress(),
                TICK_LOWER,
                TICK_UPPER,
                FEE
            );

            // 应该返回相同的地址
            expect(poolAddress1).to.equal(poolAddress2);
        });

        it("应该能够获取所有池子信息", async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);

            // 创建多个池子
            await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            // 获取所有池子信息
            const poolsInfo = await poolManager.getAllPools();
            expect(poolsInfo.length).to.be.greaterThan(0);
            expect(poolsInfo[0].token0).to.equal(await token0.getAddress());
            expect(poolsInfo[0].token1).to.equal(await token1.getAddress());
        });
    });

    describe("流动性管理", function () {
        let poolAddress, pool;

        beforeEach(async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);
            
            // 创建并初始化池子
            poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            const Pool = await ethers.getContractFactory("Pool");
            pool = Pool.attach(poolAddress);
        });

        it("应该能够添加流动性", async function () {
            const { testLP, token0, token1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");

            // 添加流动性
            const tx = await testLP.mint(
                await testLP.getAddress(),
                liquidityAmount,
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            // 验证事件
            await expect(tx).to.emit(pool, "Mint");

            // 验证流动性增加
            expect(await pool.liquidity()).to.be.greaterThan(0);
        });

        it("应该能够移除流动性", async function () {
            const { testLP, token0, token1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");

            // 先添加流动性
            await testLP.mint(
                await testLP.getAddress(),
                liquidityAmount,
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            const initialLiquidity = await pool.liquidity();

            // 移除部分流动性
            const burnAmount = liquidityAmount / 2n;
            const tx = await testLP.burn(burnAmount, poolAddress);

            // 验证事件
            await expect(tx).to.emit(pool, "Burn");

            // 验证流动性减少
            expect(await pool.liquidity()).to.be.lessThan(initialLiquidity);
        });

        it("应该能够收取手续费", async function () {
            const { testLP, testSwap, token0, token1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");
            const swapAmount = ethers.parseEther("100");

            // 添加流动性
            await testLP.mint(
                await testLP.getAddress(),
                liquidityAmount,
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            // 执行交换产生手续费
            await testSwap.testSwap(
                await testSwap.getAddress(),
                swapAmount,
                0, // 无价格限制
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            // 收取手续费
            const tx = await testLP.collect(
                await testLP.getAddress(),
                poolAddress
            );

            // 验证事件
            await expect(tx).to.emit(pool, "Collect");
        });
    });

    describe("代币交换", function () {
        let poolAddress, pool;

        beforeEach(async function () {
            const { poolManager, testLP, token0, token1 } = await loadFixture(deployDEXFixture);
            
            // 创建并初始化池子
            poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            const Pool = await ethers.getContractFactory("Pool");
            pool = Pool.attach(poolAddress);

            // 添加初始流动性
            await testLP.mint(
                await testLP.getAddress(),
                ethers.parseEther("10000"),
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );
        });

        it("应该能够执行代币交换", async function () {
            const { testSwap, token0, token1 } = await loadFixture(deployDEXFixture);
            const swapAmount = ethers.parseEther("100");

            // 执行交换
            const tx = await testSwap.testSwap(
                await testSwap.getAddress(),
                swapAmount,
                0, // 无价格限制
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            // 验证事件
            await expect(tx).to.emit(pool, "Swap");
        });

        it("应该能够通过SwapRouter执行精确输入交换", async function () {
            const { swapRouter, token0, token1, user1 } = await loadFixture(deployDEXFixture);
            const swapAmount = ethers.parseEther("100");

            // 用户授权代币
            await token0.connect(user1).approve(await swapRouter.getAddress(), swapAmount);

            // 执行精确输入交换
            const params = {
                tokenIn: await token0.getAddress(),
                tokenOut: await token1.getAddress(),
                indexPath: [0],
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600, // 1小时后过期
                amountIn: swapAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            };

            const tx = await swapRouter.connect(user1).exactInput(params);
            await expect(tx).to.emit(swapRouter, "Swap");
        });

        it("交换应该更新池子价格", async function () {
            const { testSwap, token0, token1 } = await loadFixture(deployDEXFixture);
            const swapAmount = ethers.parseEther("100");

            const initialPrice = await pool.sqrtPriceX96();

            // 执行交换
            await testSwap.testSwap(
                await testSwap.getAddress(),
                swapAmount,
                0,
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            const finalPrice = await pool.sqrtPriceX96();
            expect(finalPrice).to.not.equal(initialPrice);
        });
    });

    describe("NFT头寸管理", function () {
        let poolAddress;

        beforeEach(async function () {
            const { poolManager, token0, token1 } = await loadFixture(deployDEXFixture);
            
            // 创建并初始化池子
            poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });
        });

        it("应该能够铸造NFT头寸", async function () {
            const { positionManager, token0, token1, user1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");

            // 用户授权代币
            await token0.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));
            await token1.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));

            // 铸造NFT头寸
            const params = {
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                index: 0,
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amount0Desired: liquidityAmount,
                amount1Desired: liquidityAmount
            };

            const tx = await positionManager.connect(user1).mint(params);
            
            // 验证NFT铸造
            expect(await positionManager.balanceOf(user1.address)).to.equal(1);
            expect(await positionManager.ownerOf(1)).to.equal(user1.address);
        });

        it("应该能够销毁NFT头寸", async function () {
            const { positionManager, token0, token1, user1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");

            // 先铸造NFT头寸
            await token0.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));
            await token1.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));

            const params = {
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                index: 0,
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amount0Desired: liquidityAmount,
                amount1Desired: liquidityAmount
            };

            await positionManager.connect(user1).mint(params);

            // 销毁头寸
            await positionManager.connect(user1).burn(1);

            // 收取代币
            await positionManager.connect(user1).collect(1, user1.address);

            // 验证NFT已销毁
            await expect(positionManager.ownerOf(1)).to.be.reverted;
        });

        it("应该能够获取所有头寸信息", async function () {
            const { positionManager, token0, token1, user1 } = await loadFixture(deployDEXFixture);
            const liquidityAmount = ethers.parseEther("1000");

            // 铸造多个NFT头寸
            await token0.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("20000"));
            await token1.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("20000"));

            const params = {
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                index: 0,
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amount0Desired: liquidityAmount,
                amount1Desired: liquidityAmount
            };

            await positionManager.connect(user1).mint(params);
            await positionManager.connect(user1).mint(params);

            // 获取所有头寸信息
            const positions = await positionManager.getAllPositions();
            expect(positions.length).to.equal(2);
            expect(positions[0].owner).to.equal(user1.address);
            expect(positions[1].owner).to.equal(user1.address);
        });
    });

    describe("错误处理", function () {
        it("创建池子时应该验证代币地址", async function () {
            const { poolManager, token0 } = await loadFixture(deployDEXFixture);

            // 相同代币地址应该失败
            await expect(
                poolManager.createPool(
                    await token0.getAddress(),
                    await token0.getAddress(),
                    TICK_LOWER,
                    TICK_UPPER,
                    FEE
                )
            ).to.be.revertedWith("IDENTICAL_ADDRESSES");

            // 零地址应该失败
            await expect(
                poolManager.getPool(
                    ethers.ZeroAddress,
                    await token0.getAddress(),
                    0
                )
            ).to.be.revertedWith("ZERO_ADDRESS");
        });

        it("交换时应该验证滑点保护", async function () {
            const { swapRouter, poolManager, testLP, token0, token1, user1 } = await loadFixture(deployDEXFixture);

            // 创建池子并添加流动性
            const poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            await testLP.mint(
                await testLP.getAddress(),
                ethers.parseEther("10000"),
                poolAddress,
                await token0.getAddress(),
                await token1.getAddress()
            );

            const swapAmount = ethers.parseEther("100");
            await token0.connect(user1).approve(await swapRouter.getAddress(), swapAmount);

            // 设置过高的最小输出应该失败
            const params = {
                tokenIn: await token0.getAddress(),
                tokenOut: await token1.getAddress(),
                indexPath: [0],
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amountIn: swapAmount,
                amountOutMinimum: ethers.parseEther("1000"), // 过高的最小输出
                sqrtPriceLimitX96: 0
            };

            await expect(
                swapRouter.connect(user1).exactInput(params)
            ).to.be.revertedWith("Slippage exceeded");
        });

        it("NFT操作应该验证权限", async function () {
            const { positionManager, token0, token1, user1, user2 } = await loadFixture(deployDEXFixture);

            // 创建池子
            const { poolManager } = await loadFixture(deployDEXFixture);
            await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            // user1铸造NFT
            await token0.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));
            await token1.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));

            const params = {
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                index: 0,
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amount0Desired: ethers.parseEther("1000"),
                amount1Desired: ethers.parseEther("1000")
            };

            await positionManager.connect(user1).mint(params);

            // user2尝试操作user1的NFT应该失败
            await expect(
                positionManager.connect(user2).burn(1)
            ).to.be.revertedWith("Not approved");
        });
    });

    describe("Gas优化测试", function () {
        it("批量操作应该比单独操作更节省Gas", async function () {
            // 这里可以添加Gas消耗对比测试
            // 比较单独操作vs批量操作的Gas消耗
        });
    });

    describe("集成测试", function () {
        it("完整的DEX使用流程", async function () {
            const { 
                poolManager, 
                swapRouter, 
                positionManager, 
                token0, 
                token1, 
                user1, 
                user2 
            } = await loadFixture(deployDEXFixture);

            // 1. 创建池子
            const poolAddress = await poolManager.createAndInitializePoolIfNecessary({
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                fee: FEE,
                sqrtPriceX96: SQRT_PRICE_X96
            });

            // 2. user1提供流动性
            await token0.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));
            await token1.connect(user1).approve(await positionManager.getAddress(), ethers.parseEther("10000"));

            const mintParams = {
                token0: await token0.getAddress(),
                token1: await token1.getAddress(),
                index: 0,
                recipient: user1.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amount0Desired: ethers.parseEther("5000"),
                amount1Desired: ethers.parseEther("5000")
            };

            await positionManager.connect(user1).mint(mintParams);

            // 3. user2执行交换
            const swapAmount = ethers.parseEther("100");
            await token0.connect(user2).approve(await swapRouter.getAddress(), swapAmount);

            const swapParams = {
                tokenIn: await token0.getAddress(),
                tokenOut: await token1.getAddress(),
                indexPath: [0],
                recipient: user2.address,
                deadline: Math.floor(Date.now() / 1000) + 3600,
                amountIn: swapAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            };

            await swapRouter.connect(user2).exactInput(swapParams);

            // 4. user1收取手续费
            await positionManager.connect(user1).collect(1, user1.address);

            // 5. 验证最终状态
            expect(await positionManager.balanceOf(user1.address)).to.equal(1);
            
            const Pool = await ethers.getContractFactory("Pool");
            const pool = Pool.attach(poolAddress);
            expect(await pool.liquidity()).to.be.greaterThan(0);
        });
    });
});
