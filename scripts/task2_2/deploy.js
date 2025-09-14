const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * MyNFT合约部署脚本
 * 
 * 功能：
 * - 支持本地hardhat网络部署
 * - 支持测试网（Sepolia）部署
 * - 自动保存部署信息到JSON文件
 * - 验证部署结果
 * 
 * 使用方法：
 * 本地部署: npx hardhat run scripts/task2_2/deploy.js --network localhost
 * 测试网部署: npx hardhat run scripts/task2_2/deploy.js --network sepolia
 */

async function main() {
    console.log("🚀 开始部署MyNFT合约...");
    
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
    
    // NFT合约参数
    const nftName = "MyAwesome NFT Collection";
    const nftSymbol = "MANFT";
    
    console.log(`📝 NFT名称: ${nftName}`);
    console.log(`🏷️  NFT符号: ${nftSymbol}`);
    
    try {
        // 获取合约工厂
        console.log("🔨 编译合约...");
        const MyNFT = await ethers.getContractFactory("MyNFT");
        
        // 估算部署gas费用
        const deploymentData = MyNFT.interface.encodeDeploy([nftName, nftSymbol]);
        const estimatedGas = await ethers.provider.estimateGas({
            data: deploymentData,
        });
        console.log(`⛽ 预估Gas消耗: ${estimatedGas.toString()}`);
        
        // 部署合约
        console.log("🚀 正在部署合约...");
        const myNFT = await MyNFT.deploy(nftName, nftSymbol);
        
        // 等待部署完成
        console.log("⏳ 等待部署确认...");
        await myNFT.waitForDeployment();
        
        const contractAddress = await myNFT.getAddress();
        console.log(`✅ 合约部署成功！`);
        console.log(`📍 合约地址: ${contractAddress}`);
        
        // 获取部署交易信息
        const deployTx = myNFT.deploymentTransaction();
        if (deployTx) {
            console.log(`🔗 部署交易哈希: ${deployTx.hash}`);
            
            // 等待交易确认并获取receipt
            const receipt = await deployTx.wait();
            console.log(`📊 实际Gas消耗: ${receipt.gasUsed.toString()}`);
            console.log(`💸 Gas费用: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} ETH`);
        }
        
        // 验证合约部署
        console.log("🔍 验证合约部署...");
        const deployedName = await myNFT.name();
        const deployedSymbol = await myNFT.symbol();
        const owner = await myNFT.owner();
        const totalSupply = await myNFT.totalSupply();
        
        console.log(`✅ 合约验证成功:`);
        console.log(`   名称: ${deployedName}`);
        console.log(`   符号: ${deployedSymbol}`);
        console.log(`   所有者: ${owner}`);
        console.log(`   总供应量: ${totalSupply}`);
        
        // 保存部署信息
        const deploymentInfo = {
            network: network.name,
            chainId: network.chainId.toString(),
            contractAddress: contractAddress,
            contractName: "MyNFT",
            deployer: deployer.address,
            deploymentTime: new Date().toISOString(),
            transactionHash: deployTx ? deployTx.hash : null,
            gasUsed: deployTx ? (await deployTx.wait()).gasUsed.toString() : null,
            nftName: deployedName,
            nftSymbol: deployedSymbol,
            blockNumber: deployTx ? (await deployTx.wait()).blockNumber : null
        };
        
        // 创建deployments目录（如果不存在）
        const deploymentsDir = path.join(__dirname, "../../deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        // 保存部署信息到文件
        const timestamp = Date.now();
        const filename = `mynft-${network.name}-${timestamp}.json`;
        const filepath = path.join(deploymentsDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));
        console.log(`💾 部署信息已保存到: ${filepath}`);
        
        // 显示后续步骤提示
        console.log("\n🎉 部署完成！后续步骤:");
        console.log("1. 准备NFT图片并上传到IPFS");
        console.log("2. 创建符合OpenSea标准的元数据JSON文件");
        console.log("3. 将元数据上传到IPFS");
        console.log("4. 使用interact.js脚本铸造NFT");
        
        if (network.name === "sepolia") {
            console.log(`5. 在Etherscan查看合约: https://sepolia.etherscan.io/address/${contractAddress}`);
            console.log(`6. 在OpenSea测试网查看NFT: https://testnets.opensea.io/assets/sepolia/${contractAddress}/1`);
        }
        
        return {
            contract: myNFT,
            address: contractAddress,
            deploymentInfo: deploymentInfo
        };
        
    } catch (error) {
        console.error("❌ 部署失败:", error.message);
        
        // 提供常见错误的解决方案
        if (error.message.includes("insufficient funds")) {
            console.log("💡 解决方案: 请确保账户有足够的ETH支付gas费用");
        } else if (error.message.includes("nonce")) {
            console.log("💡 解决方案: 请重置MetaMask的账户nonce或等待之前的交易确认");
        } else if (error.message.includes("gas")) {
            console.log("💡 解决方案: 请调整gas价格或gas限制");
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
