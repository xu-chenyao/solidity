const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * BeggingContract合约部署脚本
 * 
 * 功能：
 * - 支持本地hardhat网络部署
 * - 支持测试网（Sepolia）部署
 * - 自动保存部署信息到JSON文件
 * - 验证部署结果
 * - 显示合约使用指南
 * 
 * 使用方法：
 * 本地部署: npx hardhat run scripts/task2_3/deploy.js --network localhost
 * 测试网部署: npx hardhat run scripts/task2_3/deploy.js --network sepolia
 */

async function main() {
    console.log("🚀 开始部署BeggingContract合约...");
    
    // 获取网络信息
    const network = await ethers.provider.getNetwork();
    console.log(`📡 当前网络: ${network.name} (Chain ID: ${network.chainId})`);
    
    // 获取部署账户
    const [deployer] = await ethers.getSigners();
    console.log(`👤 部署账户: ${deployer.address}`);
    
    // 检查账户余额
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`💰 账户余额: ${ethers.formatEther(balance)} ETH`);
    
    // 确保有足够的余额进行部署
    const minBalance = ethers.parseEther("0.01"); // 最少需要0.01 ETH
    if (balance < minBalance) {
        throw new Error(`❌ 余额不足！至少需要 ${ethers.formatEther(minBalance)} ETH`);
    }
    
    console.log(`🏗️  准备部署讨饭合约...`);
    console.log(`📋 合约所有者将设置为: ${deployer.address}`);
    
    try {
        // 获取合约工厂
        console.log("🔨 编译合约...");
        const BeggingContract = await ethers.getContractFactory("BeggingContract");
        
        // 估算部署gas费用
        const deploymentData = BeggingContract.interface.encodeDeploy([deployer.address]);
        const estimatedGas = await ethers.provider.estimateGas({
            data: deploymentData,
        });
        console.log(`⛽ 预估Gas消耗: ${estimatedGas.toString()}`);
        
        // 部署合约
        console.log("🚀 正在部署合约...");
        const beggingContract = await BeggingContract.deploy(deployer.address);
        
        // 等待部署完成
        console.log("⏳ 等待部署确认...");
        await beggingContract.waitForDeployment();
        
        const contractAddress = await beggingContract.getAddress();
        console.log(`✅ 合约部署成功！`);
        console.log(`📍 合约地址: ${contractAddress}`);
        
        // 获取部署交易信息
        const deployTx = beggingContract.deploymentTransaction();
        if (deployTx) {
            console.log(`🔗 部署交易哈希: ${deployTx.hash}`);
            
            // 等待交易确认并获取receipt
            const receipt = await deployTx.wait();
            console.log(`📊 实际Gas消耗: ${receipt.gasUsed.toString()}`);
            console.log(`💸 Gas费用: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} ETH`);
        }
        
        // 验证合约部署
        console.log("🔍 验证合约部署...");
        const owner = await beggingContract.owner();
        const totalDonations = await beggingContract.totalDonations();
        const contractBalance = await beggingContract.getContractBalance();
        const donorCount = await beggingContract.getDonorCount();
        
        console.log(`✅ 合约验证成功:`);
        console.log(`   所有者: ${owner}`);
        console.log(`   总捐赠金额: ${ethers.formatEther(totalDonations)} ETH`);
        console.log(`   合约余额: ${ethers.formatEther(contractBalance)} ETH`);
        console.log(`   捐赠者数量: ${donorCount}`);
        
        // 保存部署信息
        const deploymentInfo = {
            network: network.name,
            chainId: network.chainId.toString(),
            contractAddress: contractAddress,
            contractName: "BeggingContract",
            deployer: deployer.address,
            owner: owner,
            deploymentTime: new Date().toISOString(),
            transactionHash: deployTx ? deployTx.hash : null,
            gasUsed: deployTx ? (await deployTx.wait()).gasUsed.toString() : null,
            blockNumber: deployTx ? (await deployTx.wait()).blockNumber : null
        };
        
        // 创建deployments目录（如果不存在）
        const deploymentsDir = path.join(__dirname, "../../deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        // 保存部署信息到文件
        const timestamp = Date.now();
        const filename = `begging-${network.name}-${timestamp}.json`;
        const filepath = path.join(deploymentsDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));
        console.log(`💾 部署信息已保存到: ${filepath}`);
        
        // 显示使用指南
        console.log("\n" + "=".repeat(60));
        console.log("🎉 部署完成！使用指南:");
        console.log("=".repeat(60));
        
        console.log("\n📝 合约功能:");
        console.log("1. donate(message) - 捐赠ETH到合约");
        console.log("2. withdraw(amount) - 提取指定金额（仅所有者）");
        console.log("3. withdrawAll() - 提取所有资金（仅所有者）");
        console.log("4. getDonation(address) - 查询地址的捐赠金额");
        console.log("5. getDonationStats() - 获取捐赠统计信息");
        
        console.log("\n🔧 测试命令:");
        console.log(`# 运行交互脚本`);
        if (network.name === "localhost") {
            console.log(`npx hardhat run scripts/task2_3/interact.js --network localhost`);
        } else {
            console.log(`npx hardhat run scripts/task2_3/interact.js --network ${network.name}`);
        }
        
        console.log("\n💡 捐赠示例:");
        console.log("// 在Hardhat控制台中");
        console.log(`const contract = await ethers.getContractAt("BeggingContract", "${contractAddress}");`);
        console.log(`await contract.donate("Hello World!", { value: ethers.parseEther("0.1") });`);
        
        if (network.name === "sepolia") {
            console.log(`\n🔍 区块链浏览器:`);
            console.log(`Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
            
            console.log(`\n📱 MetaMask交互:`);
            console.log(`1. 在MetaMask中添加合约地址: ${contractAddress}`);
            console.log(`2. 直接向合约地址转账即可捐赠`);
            console.log(`3. 使用Etherscan的Write Contract功能调用函数`);
        }
        
        console.log("\n⚠️  重要提醒:");
        console.log("- 只有合约所有者可以提取资金");
        console.log("- 所有捐赠都会被永久记录在区块链上");
        console.log("- 请妥善保管私钥，丢失后无法找回");
        
        return {
            contract: beggingContract,
            address: contractAddress,
            deploymentInfo: deploymentInfo
        };
        
    } catch (error) {
        console.error("❌ 部署失败:", error.message);
        
        // 提供常见错误的解决方案
        if (error.message.includes("insufficient funds")) {
            console.log("💡 解决方案: 请确保账户有足够的ETH支付gas费用");
            if (network.name === "sepolia") {
                console.log("   获取测试ETH: https://sepoliafaucet.com/");
            }
        } else if (error.message.includes("nonce")) {
            console.log("💡 解决方案: 请重置MetaMask的账户nonce或等待之前的交易确认");
        } else if (error.message.includes("gas")) {
            console.log("💡 解决方案: 请调整gas价格或gas限制");
        } else if (error.message.includes("network")) {
            console.log("💡 解决方案: 请检查网络连接和RPC配置");
        }
        
        throw error;
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main()
        .then(() => {
            console.log("🎊 部署脚本执行完成！");
            process.exit(0);
        })
        .catch((error) => {
            console.error("💥 部署脚本执行失败:", error);
            process.exit(1);
        });
}

module.exports = { main };
