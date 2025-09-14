const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * MyNFT合约交互脚本
 * 
 * 功能：
 * - 铸造NFT
 * - 批量铸造NFT
 * - 查询NFT信息
 * - 查询合约状态
 * 
 * 使用方法：
 * 1. 先运行deploy.js部署合约
 * 2. 修改下面的CONTRACT_ADDRESS为实际部署的合约地址
 * 3. 运行: npx hardhat run scripts/task2_2/interact.js --network localhost
 */

// 配置区域 - 请根据实际情况修改
const CONFIG = {
    // 合约地址 - 请替换为实际部署的合约地址
    CONTRACT_ADDRESS: "YOUR_CONTRACT_ADDRESS_HERE",
    
    // 示例IPFS链接 - 请替换为实际的IPFS链接
    SAMPLE_METADATA_URIS: [
        "ipfs://bafybeifzgfc2vp6kxlre7yl3uuzetiwfx37bynx5wdae7rvcl2jcf4dpoy/metadata1.json",
        // "ipfs://bafybeieztx2mprr2ifd3tuzq5ms3mzyjtsfosci7z56l2czkxsypqoasqa/metadata.json",
        "ipfs://bafybeie45lx44fw4nte3ilqg56h5e4gisf3bs3sledflimqqwtotnqcijm/metadata2.json",
        // "ipfs://QmYourHashHere/metadata3.json"
    ],
    
    // 接收NFT的地址 - 可以是任何有效的以太坊地址
    RECIPIENT_ADDRESSES: [
        // 将自动使用部署者地址，也可以添加其他地址
    ]
};

/**
 * 自动检测最新部署的合约地址
 */
async function getLatestDeployedContract() {
    const deploymentsDir = path.join(__dirname, "../../deployments");
    
    if (!fs.existsSync(deploymentsDir)) {
        throw new Error("未找到deployments目录，请先运行deploy.js部署合约");
    }
    
    const files = fs.readdirSync(deploymentsDir)
        .filter(file => file.startsWith("mynft-") && file.endsWith(".json"))
        .sort((a, b) => {
            const aTime = parseInt(a.split("-").pop().replace(".json", ""));
            const bTime = parseInt(b.split("-").pop().replace(".json", ""));
            return bTime - aTime; // 降序排列，最新的在前
        });
    
    if (files.length === 0) {
        throw new Error("未找到部署记录，请先运行deploy.js部署合约");
    }
    
    const latestFile = files[0];
    const deploymentInfo = JSON.parse(fs.readFileSync(path.join(deploymentsDir, latestFile), "utf8"));
    
    console.log(`📋 使用最新部署的合约: ${latestFile}`);
    console.log(`📍 合约地址: ${deploymentInfo.contractAddress}`);
    
    return deploymentInfo;
}

/**
 * 获取合约实例
 */
async function getContractInstance(contractAddress) {
    const MyNFT = await ethers.getContractFactory("MyNFT");
    return MyNFT.attach(contractAddress);
}

/**
 * 显示合约基本信息
 */
async function showContractInfo(contract) {
    console.log("\n📊 合约信息:");
    console.log(`   名称: ${await contract.name()}`);
    console.log(`   符号: ${await contract.symbol()}`);
    console.log(`   所有者: ${await contract.owner()}`);
    console.log(`   总供应量: ${await contract.totalSupply()}`);
}

/**
 * 铸造单个NFT
 */
async function mintSingleNFT(contract, recipient, tokenURI) {
    console.log(`\n🎨 铸造NFT给 ${recipient}`);
    console.log(`🔗 元数据URI: ${tokenURI}`);
    
    try {
        // 估算gas费用
        const gasEstimate = await contract.mintNFT.estimateGas(recipient, tokenURI);
        console.log(`⛽ 预估Gas: ${gasEstimate.toString()}`);
        
        // 执行铸造
        const tx = await contract.mintNFT(recipient, tokenURI);
        console.log(`📝 交易哈希: ${tx.hash}`);
        console.log("⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`✅ 交易确认! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 解析事件获取tokenId
        const event = receipt.logs.find(log => {
            try {
                const parsed = contract.interface.parseLog(log);
                return parsed.name === 'NFTMinted';
            } catch {
                return false;
            }
        });
        
        if (event) {
            const parsedEvent = contract.interface.parseLog(event);
            const tokenId = parsedEvent.args.tokenId;
            console.log(`🎊 NFT铸造成功! Token ID: ${tokenId}`);
            return tokenId;
        }
        
    } catch (error) {
        console.error("❌ 铸造失败:", error.message);
        throw error;
    }
}

/**
 * 批量铸造NFT
 */
async function batchMintNFTs(contract, recipients, tokenURIs) {
    console.log(`\n🎨 批量铸造 ${recipients.length} 个NFT`);
    
    try {
        // 估算gas费用
        const gasEstimate = await contract.batchMintNFT.estimateGas(recipients, tokenURIs);
        console.log(`⛽ 预估Gas: ${gasEstimate.toString()}`);
        
        // 执行批量铸造
        const tx = await contract.batchMintNFT(recipients, tokenURIs);
        console.log(`📝 交易哈希: ${tx.hash}`);
        console.log("⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`✅ 交易确认! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 解析所有NFTMinted事件
        const events = receipt.logs
            .map(log => {
                try {
                    return contract.interface.parseLog(log);
                } catch {
                    return null;
                }
            })
            .filter(event => event && event.name === 'NFTMinted');
        
        console.log(`🎊 批量铸造成功! 共铸造 ${events.length} 个NFT:`);
        events.forEach((event, index) => {
            console.log(`   Token ID ${event.args.tokenId}: ${recipients[index]}`);
        });
        
        return events.map(event => event.args.tokenId);
        
    } catch (error) {
        console.error("❌ 批量铸造失败:", error.message);
        throw error;
    }
}

/**
 * 查询NFT详细信息
 */
async function queryNFTInfo(contract, tokenId) {
    console.log(`\n🔍 查询NFT信息 (Token ID: ${tokenId})`);
    
    try {
        const [owner, tokenURI, mintTime, minter] = await contract.getNFTInfo(tokenId);
        
        console.log(`   所有者: ${owner}`);
        console.log(`   元数据URI: ${tokenURI}`);
        console.log(`   铸造时间: ${new Date(Number(mintTime) * 1000).toLocaleString()}`);
        console.log(`   铸造者: ${minter}`);
        
        return { owner, tokenURI, mintTime, minter };
        
    } catch (error) {
        console.error(`❌ 查询NFT信息失败: ${error.message}`);
        return null;
    }
}

/**
 * 查询地址的NFT余额
 */
async function queryBalance(contract, address) {
    try {
        const balance = await contract.balanceOf(address);
        console.log(`💰 地址 ${address} 拥有 ${balance} 个NFT`);
        return balance;
    } catch (error) {
        console.error(`❌ 查询余额失败: ${error.message}`);
        return 0;
    }
}

/**
 * 销毁/删除NFT函数
 */
async function deleteNFT(contract, tokenId) {
    console.log(`\n🔥 销毁NFT #${tokenId}`);
    
    try {
        // 首先检查NFT是否存在
        const nftInfo = await contract.getNFTInfo(tokenId);
        console.log(`   📍 NFT所有者: ${nftInfo.owner}`);
        console.log(`   🔗 元数据URI: ${nftInfo.tokenURI}`);
        
        // 估算gas费用
        const gasEstimate = await contract.burnNFT.estimateGas(tokenId);
        console.log(`   ⛽ 预估Gas: ${gasEstimate.toString()}`);
        
        // 执行销毁
        console.log(`   🔥 正在销毁NFT...`);
        const tx = await contract.burnNFT(tokenId);
        console.log(`   📝 交易哈希: ${tx.hash}`);
        console.log("   ⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`   ✅ NFT销毁成功! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 解析销毁事件
        const event = receipt.logs.find(log => {
            try {
                const parsed = contract.interface.parseLog(log);
                return parsed.name === 'NFTBurned';
            } catch {
                return false;
            }
        });
        
        if (event) {
            const parsedEvent = contract.interface.parseLog(event);
            console.log(`   🎊 销毁事件确认:`);
            console.log(`      Token ID: ${parsedEvent.args.tokenId}`);
            console.log(`      原所有者: ${parsedEvent.args.previousOwner}`);
            console.log(`      销毁者: ${parsedEvent.args.burner}`);
        }
        
        // 验证NFT已被销毁
        try {
            await contract.getNFTInfo(tokenId);
            console.log(`   ❌ 警告: NFT似乎仍然存在`);
        } catch (error) {
            console.log(`   ✅ 确认: NFT已被成功销毁`);
        }
        
        return true;
        
    } catch (error) {
        console.error(`   ❌ 销毁NFT失败: ${error.message}`);
        
        // 提供常见错误的解决方案
        if (error.message.includes("token does not exist")) {
            console.log(`   💡 解决方案: NFT #${tokenId} 不存在或已被销毁`);
        } else if (error.message.includes("caller is not owner")) {
            console.log(`   💡 解决方案: 只有NFT所有者或合约所有者可以销毁NFT`);
        }
        
        return false;
    }
}

/**
 * 批量销毁NFT函数
 */
async function batchDeleteNFTs(contract, tokenIds) {
    console.log(`\n🔥 批量销毁 ${tokenIds.length} 个NFT`);
    console.log(`   Token IDs: [${tokenIds.join(', ')}]`);
    
    try {
        // 估算gas费用
        const gasEstimate = await contract.batchBurnNFT.estimateGas(tokenIds);
        console.log(`   ⛽ 预估Gas: ${gasEstimate.toString()}`);
        
        // 执行批量销毁
        const tx = await contract.batchBurnNFT(tokenIds);
        console.log(`   📝 交易哈希: ${tx.hash}`);
        console.log("   ⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`   ✅ 批量销毁成功! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 解析所有销毁事件
        const events = receipt.logs
            .map(log => {
                try {
                    return contract.interface.parseLog(log);
                } catch {
                    return null;
                }
            })
            .filter(event => event && event.name === 'NFTBurned');
        
        console.log(`   🎊 成功销毁 ${events.length} 个NFT:`);
        events.forEach((event) => {
            console.log(`      Token ID ${event.args.tokenId}: ${event.args.previousOwner}`);
        });
        
        return tokenIds;
        
    } catch (error) {
        console.error(`   ❌ 批量销毁失败: ${error.message}`);
        return [];
    }
}

/**
 * 查询所有已铸造的NFT信息
 */
async function queryAllNFTs(contract) {
    console.log(`\n🔍 查询所有已铸造的NFT信息`);
    
    try {
        // 获取总供应量
        const totalSupply = await contract.totalSupply();
        console.log(`📊 NFT总供应量: ${totalSupply}`);
        
        if (totalSupply == 0) {
            console.log(`💡 还没有铸造任何NFT`);
            return [];
        }
        
        console.log(`\n🎨 所有NFT详细信息:`);
        const allNFTs = [];
        
        // 遍历所有tokenId查询NFT信息
        for (let tokenId = 1; tokenId <= totalSupply; tokenId++) {
            try {
                console.log(`\n--- NFT #${tokenId} ---`);
                const nftInfo = await queryNFTInfo(contract, tokenId);
                
                if (nftInfo) {
                    // 添加IPFS访问链接
                    if (nftInfo.tokenURI.startsWith('ipfs://')) {
                        const ipfsHash = nftInfo.tokenURI.replace('ipfs://', '');
                        console.log(`   🌐 IPFS网关访问: https://ipfs.io/ipfs/${ipfsHash}`);
                        console.log(`   🌐 Pinata网关访问: https://gateway.pinata.cloud/ipfs/${ipfsHash}`);
                    }
                    
                    allNFTs.push({
                        tokenId: tokenId,
                        ...nftInfo
                    });
                }
            } catch (error) {
                console.log(`   ❌ NFT #${tokenId} 查询失败: ${error.message}`);
            }
        }
        
        // 统计信息
        console.log(`\n📈 NFT统计信息:`);
        console.log(`   总铸造数量: ${allNFTs.length}`);
        
        // 按所有者分组统计
        const ownerStats = {};
        allNFTs.forEach(nft => {
            if (!ownerStats[nft.owner]) {
                ownerStats[nft.owner] = 0;
            }
            ownerStats[nft.owner]++;
        });
        
        console.log(`   所有者分布:`);
        Object.entries(ownerStats).forEach(([owner, count]) => {
            console.log(`     ${owner}: ${count} 个NFT`);
        });
        
        // 按铸造时间排序显示最新的NFT
        const sortedNFTs = allNFTs.sort((a, b) => Number(b.mintTime) - Number(a.mintTime));
        if (sortedNFTs.length > 0) {
            console.log(`\n🆕 最新铸造的NFT:`);
            const latestNFT = sortedNFTs[0];
            console.log(`   Token ID: ${latestNFT.tokenId}`);
            console.log(`   所有者: ${latestNFT.owner}`);
            console.log(`   铸造时间: ${new Date(Number(latestNFT.mintTime) * 1000).toLocaleString()}`);
        }
        
        return allNFTs;
        
    } catch (error) {
        console.error(`❌ 查询所有NFT失败: ${error.message}`);
        return [];
    }
}

/**
 * 主函数
 */
async function main() {
    console.log("🚀 开始NFT交互演示...");
    
    // 获取网络信息
    const network = await ethers.provider.getNetwork();
    console.log(`📡 当前网络: ${network.name} (Chain ID: ${network.chainId})`);
    
    // 获取账户
    const [deployer, ...otherAccounts] = await ethers.getSigners();
    console.log(`👤 当前账户: ${deployer.address}`);
    
    try {
        // 获取合约地址
        let contractAddress;
        if (CONFIG.CONTRACT_ADDRESS === "YOUR_CONTRACT_ADDRESS_HERE") {
            console.log("🔍 自动检测最新部署的合约...");
            const deploymentInfo = await getLatestDeployedContract();
            contractAddress = deploymentInfo.contractAddress;
        } else {
            contractAddress = CONFIG.CONTRACT_ADDRESS;
            console.log(`📍 使用配置的合约地址: ${contractAddress}`);
        }
        
        // 获取合约实例
        const contract = await getContractInstance(contractAddress);
        
        // 显示合约信息
        await showContractInfo(contract);
        
        // 准备接收者地址
        const recipients = CONFIG.RECIPIENT_ADDRESSES.length > 0 
            ? CONFIG.RECIPIENT_ADDRESSES 
            : [deployer.address];
        
        console.log(`\n👥 NFT接收者: ${recipients.join(", ")}`);
        
        // // 演示1: 铸造单个NFT
        // console.log("\n" + "=".repeat(50));
        // console.log("演示1: 铸造单个NFT");
        // console.log("=".repeat(50));
        
        // const tokenId1 = await mintSingleNFT(
        //     contract, 
        //     recipients[0], 
        //     CONFIG.SAMPLE_METADATA_URIS[0]
        // );
    
        
        // 查询刚铸造的NFT信息
        // await queryNFTInfo(contract, tokenId1);
        
        // 演示2: 批量铸造NFT（如果有多个URI）
        // if (CONFIG.SAMPLE_METADATA_URIS.length > 1) {
        //     console.log("\n" + "=".repeat(50));
        //     console.log("演示2: 批量铸造NFT");
        //     console.log("=".repeat(50));
            
        //     const batchRecipients = recipients.slice(0, Math.min(recipients.length, CONFIG.SAMPLE_METADATA_URIS.length - 1));
        //     const batchURIs = CONFIG.SAMPLE_METADATA_URIS.slice(1, batchRecipients.length + 1);
            
        //     if (batchRecipients.length === 1 && CONFIG.SAMPLE_METADATA_URIS.length > 2) {
        //         // 如果只有一个接收者，给他铸造多个NFT
        //         batchRecipients.push(recipients[0]);
        //         batchURIs.push(CONFIG.SAMPLE_METADATA_URIS[2]);
        //     }
            
        //     const tokenIds = await batchMintNFTs(contract, batchRecipients, batchURIs);
            
        //     // 查询批量铸造的NFT信息
        //     for (const tokenId of tokenIds) {
        //         await queryNFTInfo(contract, tokenId);
        //     }
        // }
        
        // 销毁指定tokenId的NFT
        // console.log("\n" + "=".repeat(50));
        // console.log("演示5: 删除指定tokenId的NFT");
        // console.log("=".repeat(50));
        
        // await deleteNFT(contract, tokenId1);
        
        // 演示3: 查询余额
        console.log("\n" + "=".repeat(50));
        console.log("演示3: 查询账户余额");
        console.log("=".repeat(50));
        
        for (const recipient of recipients) {
            await queryBalance(contract, recipient);
        }
        // 演示4: 查询当前所有铸造的NFT信息
        console.log("\n" + "=".repeat(50));
        console.log("演示4: 查询所有已铸造的NFT");
        console.log("=".repeat(50));
        
        await queryAllNFTs(contract);
        
        // 显示最终合约状态
        console.log("\n" + "=".repeat(50));
        console.log("最终合约状态");
        console.log("=".repeat(50));
        await showContractInfo(contract);
        
        // 提供查看链接
        // if (network.name === "sepolia") {
        //     console.log("\n🔗 查看链接:");
        //     console.log(`Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
        //     console.log(`OpenSea: https://testnets.opensea.io/assets/sepolia/${contractAddress}/1`);
        // }
        
        console.log("\n🎉 交互演示完成！");
        
    } catch (error) {
        console.error("💥 交互失败:", error.message);
        
        // 提供常见错误的解决方案
        if (error.message.includes("contract not deployed")) {
            console.log("💡 解决方案: 请先运行deploy.js部署合约");
        } else if (error.message.includes("OwnableUnauthorizedAccount")) {
            console.log("💡 解决方案: 只有合约所有者可以铸造NFT");
        } else if (error.message.includes("insufficient funds")) {
            console.log("💡 解决方案: 账户余额不足，请充值ETH");
        }
        
        throw error;
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main()
        .then(() => {
            console.log("🎊 交互脚本执行完成！");
            process.exit(0);
        })
        .catch((error) => {
            console.error("💥 交互脚本执行失败:", error);
            process.exit(1);
        });
}

module.exports = { 
    main, 
    getLatestDeployedContract, 
    getContractInstance, 
    mintSingleNFT, 
    batchMintNFTs, 
    queryNFTInfo,
    queryAllNFTs,
    queryBalance,
    deleteNFT,
    batchDeleteNFTs
};
