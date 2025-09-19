const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * BeggingContract合约交互脚本
 * 
 * 功能：
 * - 演示捐赠功能
 * - 演示提款功能
 * - 查询合约状态和统计信息
 * - 测试各种边界条件
 */

/**
 * 获取最新部署的合约信息
 */
async function getLatestDeployedContract() {
    const deploymentsDir = path.join(__dirname, "../../deployments");
    
    if (!fs.existsSync(deploymentsDir)) {
        throw new Error("未找到deployments目录，请先运行deploy.js部署合约");
    }
    
    const files = fs.readdirSync(deploymentsDir)
        .filter(file => file.startsWith("begging-") && file.endsWith(".json"))
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
    const BeggingContract = await ethers.getContractFactory("BeggingContract");
    return BeggingContract.attach(contractAddress);
}

/**
 * 显示合约基本信息
 */
async function showContractInfo(contract) {
    console.log("\n📊 合约信息:");
    
    const owner = await contract.owner();
    const [totalReceived, currentBalance, totalWithdrawn, donorCount] = await contract.getDonationStats();
    
    console.log(`   所有者: ${owner}`);
    console.log(`   总接收金额: ${ethers.formatEther(totalReceived)} ETH`);
    console.log(`   当前余额: ${ethers.formatEther(currentBalance)} ETH`);
    console.log(`   已提取金额: ${ethers.formatEther(totalWithdrawn)} ETH`);
    console.log(`   捐赠者数量: ${donorCount}`);
    
    if (donorCount > 0) {
        const averageDonation = await contract.getAverageDonation();
        console.log(`   平均捐赠: ${ethers.formatEther(averageDonation)} ETH`);
    }
}

/**
 * 执行捐赠
 */
async function makeDonation(contract, donor, amount, message) {
    console.log(`\n💰 ${donor.address} 正在捐赠 ${ethers.formatEther(amount)} ETH`);
    console.log(`📝 留言: "${message}"`);
    
    try {
        // 获取捐赠前的余额
        const balanceBefore = await ethers.provider.getBalance(donor.address);
        
        // 执行捐赠
        const tx = await contract.connect(donor).donate(message, { value: amount });
        console.log(`📝 交易哈希: ${tx.hash}`);
        console.log("⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`✅ 捐赠成功! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 计算实际花费（包括gas费用）
        const balanceAfter = await ethers.provider.getBalance(donor.address);
        const totalCost = balanceBefore - balanceAfter;
        const gasCost = totalCost - amount;
        
        console.log(`💸 Gas费用: ${ethers.formatEther(gasCost)} ETH`);
        console.log(`💸 总花费: ${ethers.formatEther(totalCost)} ETH`);
        
        // 验证捐赠记录
        const donationAmount = await contract.getDonation(donor.address);
        console.log(`📊 该地址累计捐赠: ${ethers.formatEther(donationAmount)} ETH`);
        
        return receipt;
        
    } catch (error) {
        console.error(`❌ 捐赠失败: ${error.message}`);
        throw error;
    }
}

/**
 * 执行提款
 */
async function makeWithdrawal(contract, owner, amount) {
    console.log(`\n💳 所有者正在提取 ${ethers.formatEther(amount)} ETH`);
    
    try {
        // 获取提款前的余额
        const balanceBefore = await ethers.provider.getBalance(owner.address);
        const contractBalanceBefore = await contract.getContractBalance();
        
        // 执行提款
        const tx = await contract.connect(owner).withdraw(amount);
        console.log(`📝 交易哈希: ${tx.hash}`);
        console.log("⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`✅ 提款成功! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 计算实际收益（减去gas费用）
        const balanceAfter = await ethers.provider.getBalance(owner.address);
        const actualGain = balanceAfter - balanceBefore;
        const gasCost = amount - actualGain;
        
        console.log(`💸 Gas费用: ${ethers.formatEther(gasCost)} ETH`);
        console.log(`💰 净收益: ${ethers.formatEther(actualGain)} ETH`);
        
        // 验证合约余额变化
        const contractBalanceAfter = await contract.getContractBalance();
        const balanceReduction = contractBalanceBefore - contractBalanceAfter;
        console.log(`📊 合约余额减少: ${ethers.formatEther(balanceReduction)} ETH`);
        
        return receipt;
        
    } catch (error) {
        console.error(`❌ 提款失败: ${error.message}`);
        throw error;
    }
}

/**
 * 显示捐赠者排行榜
 */
async function showTopDonors(contract, count = 5) {
    console.log(`\n🏆 捐赠排行榜 (前${count}名):`);
    
    try {
        const [topDonors, amounts] = await contract.getTopDonors(count);
        
        if (topDonors.length === 0) {
            console.log("   暂无捐赠记录");
            return;
        }
        
        for (let i = 0; i < topDonors.length; i++) {
            const rank = i + 1;
            const address = topDonors[i];
            const amount = amounts[i];
            
            console.log(`   ${rank}. ${address}: ${ethers.formatEther(amount)} ETH`);
        }
        
    } catch (error) {
        console.error(`❌ 获取排行榜失败: ${error.message}`);
    }
}

/**
 * 显示所有捐赠者
 */
async function showAllDonors(contract) {
    console.log(`\n👥 所有捐赠者:`);
    
    try {
        const donors = await contract.getAllDonors();
        
        if (donors.length === 0) {
            console.log("   暂无捐赠记录");
            return;
        }
        
        for (let i = 0; i < donors.length; i++) {
            const donor = donors[i];
            const amount = await contract.getDonation(donor);
            
            console.log(`   ${i + 1}. ${donor}: ${ethers.formatEther(amount)} ETH`);
        }
        
    } catch (error) {
        console.error(`❌ 获取捐赠者列表失败: ${error.message}`);
    }
}

/**
 * 测试直接转账功能
 */
async function testDirectTransfer(contract, sender, amount) {
    console.log(`\n📤 测试直接转账功能:`);
    console.log(`   发送者: ${sender.address}`);
    console.log(`   金额: ${ethers.formatEther(amount)} ETH`);
    
    try {
        // 直接向合约地址转账
        const tx = await sender.sendTransaction({
            to: await contract.getAddress(),
            value: amount
        });
        
        console.log(`📝 交易哈希: ${tx.hash}`);
        console.log("⏳ 等待交易确认...");
        
        const receipt = await tx.wait();
        console.log(`✅ 直接转账成功! Gas消耗: ${receipt.gasUsed.toString()}`);
        
        // 验证捐赠记录
        const donationAmount = await contract.getDonation(sender.address);
        console.log(`📊 该地址累计捐赠: ${ethers.formatEther(donationAmount)} ETH`);
        
        return receipt;
        
    } catch (error) {
        console.error(`❌ 直接转账失败: ${error.message}`);
        throw error;
    }
}

/**
 * 主函数
 */
async function main() {
    console.log("🚀 开始BeggingContract交互演示...");
    
    // 获取网络信息
    const network = await ethers.provider.getNetwork();
    console.log(`📡 当前网络: ${network.name} (Chain ID: ${network.chainId})`);
    
    // 获取账户
    const [deployer, donor1, donor2, donor3, ...others] = await ethers.getSigners();
    console.log(`👤 部署者/所有者: ${deployer.address}`);
    console.log(`👤 捐赠者1: ${donor1.address}`);
    console.log(`👤 捐赠者2: ${donor2.address}`);
    console.log(`👤 捐赠者3: ${donor3.address}`);
    
    try {
        // 获取合约地址
        console.log("🔍 自动检测最新部署的合约...");
        const deploymentInfo = await getLatestDeployedContract();
        const contractAddress = deploymentInfo.contractAddress;
        
        // 获取合约实例
        const contract = await getContractInstance(contractAddress);
        
        // 显示初始合约信息
        await showContractInfo(contract);
        
        // 演示1: 多个用户进行捐赠
        console.log("\n" + "=".repeat(60));
        console.log("演示1: 多用户捐赠功能");
        console.log("=".repeat(60));
        
        await makeDonation(contract, donor1, ethers.parseEther("1.0"), "支持你的项目！");
        await makeDonation(contract, donor2, ethers.parseEther("2.5"), "希望项目越来越好");
        await makeDonation(contract, donor3, ethers.parseEther("0.5"), "小小心意，不成敬意");
        
        // 显示更新后的合约信息
        await showContractInfo(contract);
        
        // 演示2: 同一用户多次捐赠
        console.log("\n" + "=".repeat(60));
        console.log("演示2: 重复捐赠功能");
        console.log("=".repeat(60));
        
        await makeDonation(contract, donor1, ethers.parseEther("0.3"), "再次支持！");
        
        // 演示3: 直接转账功能
        console.log("\n" + "=".repeat(60));
        console.log("演示3: 直接转账功能");
        console.log("=".repeat(60));
        
        await testDirectTransfer(contract, donor2, ethers.parseEther("0.2"));
        
        // 显示捐赠统计
        await showContractInfo(contract);
        await showTopDonors(contract, 3);
        await showAllDonors(contract);
        
        // 演示4: 提款功能
        console.log("\n" + "=".repeat(60));
        console.log("演示4: 提款功能");
        console.log("=".repeat(60));
        
        const withdrawAmount = ethers.parseEther("1.0");
        await makeWithdrawal(contract, deployer, withdrawAmount);
        
        // 显示提款后的状态
        await showContractInfo(contract);
        
        // 演示5: 提取所有资金
        console.log("\n" + "=".repeat(60));
        console.log("演示5: 提取所有资金");
        console.log("=".repeat(60));
        
        const remainingBalance = await contract.getContractBalance();
        if (remainingBalance > 0) {
            console.log(`💰 准备提取剩余的 ${ethers.formatEther(remainingBalance)} ETH`);
            
            const tx = await contract.connect(deployer).withdrawAll();
            console.log(`📝 交易哈希: ${tx.hash}`);
            await tx.wait();
            console.log("✅ 提取完成!");
        } else {
            console.log("💡 合约余额为0，无需提取");
        }
        
        // 显示最终状态
        console.log("\n" + "=".repeat(60));
        console.log("最终合约状态");
        console.log("=".repeat(60));
        await showContractInfo(contract);
        
        // 提供查看链接
        if (network.name === "sepolia") {
            console.log("\n🔗 查看链接:");
            console.log(`Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
        }
        
        console.log("\n🎉 交互演示完成！");
        
        // 提供使用建议
        console.log("\n💡 使用建议:");
        console.log("1. 在生产环境中，建议设置最小捐赠金额");
        console.log("2. 考虑添加捐赠手续费机制");
        console.log("3. 可以添加捐赠目标和进度显示");
        console.log("4. 建议定期提取资金，避免合约余额过大");
        
    } catch (error) {
        console.error("💥 交互失败:", error.message);
        
        // 提供常见错误的解决方案
        if (error.message.includes("未找到")) {
            console.log("💡 解决方案: 请先运行deploy.js部署合约");
        } else if (error.message.includes("insufficient funds")) {
            console.log("💡 解决方案: 账户余额不足，请充值ETH");
        } else if (error.message.includes("OwnableUnauthorizedAccount")) {
            console.log("💡 解决方案: 只有合约所有者可以提取资金");
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
    makeDonation, 
    makeWithdrawal, 
    showContractInfo 
};
