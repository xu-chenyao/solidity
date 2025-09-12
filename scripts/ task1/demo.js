const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 开始部署和演示所有Task1合约...\n");

  // 获取部署账户信息
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署账户:", deployer.address);
  console.log("💰 账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // 部署所有合约
  const contracts = {};
  
  console.log("📦 开始部署合约...");
  
  try {
    const Voting = await ethers.getContractFactory("Voting");
    contracts.voting = await Voting.deploy();
    await contracts.voting.waitForDeployment();
    console.log("✅ Voting 合约部署完成:", await contracts.voting.getAddress());

    const ReverseString = await ethers.getContractFactory("ReverseString");
    contracts.reverseString = await ReverseString.deploy();
    await contracts.reverseString.waitForDeployment();
    console.log("✅ ReverseString 合约部署完成:", await contracts.reverseString.getAddress());

    const IntToRoman = await ethers.getContractFactory("IntToRoman");
    contracts.intToRoman = await IntToRoman.deploy();
    await contracts.intToRoman.waitForDeployment();
    console.log("✅ IntToRoman 合约部署完成:", await contracts.intToRoman.getAddress());

    const RomanToInt = await ethers.getContractFactory("RomanToInt");
    contracts.romanToInt = await RomanToInt.deploy();
    await contracts.romanToInt.waitForDeployment();
    console.log("✅ RomanToInt 合约部署完成:", await contracts.romanToInt.getAddress());

    const MergeSortedArray = await ethers.getContractFactory("MergeSortedArray");
    contracts.mergeSortedArray = await MergeSortedArray.deploy();
    await contracts.mergeSortedArray.waitForDeployment();
    console.log("✅ MergeSortedArray 合约部署完成:", await contracts.mergeSortedArray.getAddress());

    const BinarySearch = await ethers.getContractFactory("BinarySearch");
    contracts.binarySearch = await BinarySearch.deploy();
    await contracts.binarySearch.waitForDeployment();
    console.log("✅ BinarySearch 合约部署完成:", await contracts.binarySearch.getAddress());

  } catch (error) {
    console.error("❌ 部署失败:", error.message);
    return;
  }

  console.log("\n🎯 开始功能演示...\n");

  try {
    // 1. 投票合约演示
    console.log("=== 1. 投票合约演示 ===");
    await contracts.voting.vote("Alice");
    await contracts.voting.vote("Bob");
    await contracts.voting.vote("Alice");
    
    console.log(`Alice 得票数: ${await contracts.voting.getVotes("Alice")}`);
    console.log(`Bob 得票数: ${await contracts.voting.getVotes("Bob")}`);
    console.log(`候选人列表: ${await contracts.voting.getCandidates()}`);

    // 2. 字符串反转演示
    console.log("\n=== 2. 字符串反转演示 ===");
    const originalString = "hello world";
    const reversedString = await contracts.reverseString.reverseString(originalString);
    const isPalindrome = await contracts.reverseString.isPalindrome("aba");
    
    console.log(`原字符串: "${originalString}"`);
    console.log(`反转后: "${reversedString}"`);
    console.log(`"aba" 是回文吗? ${isPalindrome}`);

    // 3. 整数转罗马数字演示
    console.log("\n=== 3. 整数转罗马数字演示 ===");
    const numbers = [1, 4, 9, 58, 1994];
    for (const num of numbers) {
      const roman = await contracts.intToRoman.intToRoman(num);
      console.log(`${num} → ${roman}`);
    }

    // 4. 罗马数字转整数演示
    console.log("\n=== 4. 罗马数字转整数演示 ===");
    const romans = ["I", "IV", "IX", "LVIII", "MCMXCIV"];
    for (const roman of romans) {
      const num = await contracts.romanToInt.romanToInt(roman);
      console.log(`${roman} → ${num}`);
    }

    // 5. 合并有序数组演示
    console.log("\n=== 5. 合并有序数组演示 ===");
    const array1 = [1, 3, 5, 7];
    const array2 = [2, 4, 6, 8];
    const merged = await contracts.mergeSortedArray.mergeSortedArrays(array1, array2);
    console.log(`数组1: [${array1.join(', ')}]`);
    console.log(`数组2: [${array2.join(', ')}]`);
    console.log(`合并后: [${merged.map(n => n.toString()).join(', ')}]`);

    // 6. 二分查找演示
    console.log("\n=== 6. 二分查找演示 ===");
    const sortedArray = [1, 3, 5, 7, 9, 11, 13];
    const target = 7;
    const notFound = 6;
    
    const foundIndex = await contracts.binarySearch.binarySearch(sortedArray, target);
    const notFoundIndex = await contracts.binarySearch.binarySearch(sortedArray, notFound);
    const insertPos = await contracts.binarySearch.findInsertPosition(sortedArray, notFound);
    
    console.log(`数组: [${sortedArray.join(', ')}]`);
    console.log(`查找 ${target}: 索引 ${foundIndex}`);
    console.log(`查找 ${notFound}: ${notFoundIndex.toString() === ethers.MaxUint256.toString() ? '未找到' : `索引 ${notFoundIndex}`}`);
    console.log(`${notFound} 应插入位置: 索引 ${insertPos}`);

    console.log("\n🎉 所有演示完成！");
    
    // 输出合约地址摘要
    console.log("\n📋 合约部署摘要:");
    console.log("┌─────────────────┬──────────────────────────────────────────────┐");
    console.log("│ 合约名称        │ 地址                                         │");
    console.log("├─────────────────┼──────────────────────────────────────────────┤");
    console.log(`│ Voting          │ ${await contracts.voting.getAddress()}         │`);
    console.log(`│ ReverseString   │ ${await contracts.reverseString.getAddress()}  │`);
    console.log(`│ IntToRoman      │ ${await contracts.intToRoman.getAddress()}     │`);
    console.log(`│ RomanToInt      │ ${await contracts.romanToInt.getAddress()}     │`);
    console.log(`│ MergeSortedArray│ ${await contracts.mergeSortedArray.getAddress()}│`);
    console.log(`│ BinarySearch    │ ${await contracts.binarySearch.getAddress()}   │`);
    console.log("└─────────────────┴──────────────────────────────────────────────┘");

  } catch (error) {
    console.error("❌ 演示过程中出错:", error.message);
  }
}

// 错误处理
main()
  .then(() => {
    console.log("\n✅ 脚本执行完成");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 脚本执行失败:", error);
    process.exit(1);
  });
