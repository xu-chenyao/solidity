# Task1 Solidity 合约集合

这个目录包含了6个不同功能的Solidity智能合约，每个合约都实现了特定的算法或功能。
/Users/xuchenyao/solidity/
├── contracts/task1/          # 你的合约目录
│   ├── Voting.sol           # 投票合约
│   ├── ReverseString.sol    # 字符串反转
│   ├── IntToRoman.sol       # 整数转罗马数字
│   ├── RomanToInt.sol       # 罗马数字转整数
│   ├── MergeSortedArray.sol # 合并有序数组
│   ├── BinarySearch.sol     # 二分查找
│   └── README.md            # 详细文档
├── test/task1/              # 测试文件
│   └── AllContracts.test.js # 综合测试
├── scripts/
│   └── demo.js              # 演示脚本
└── hardhat.config.js        # Hardhat配置

要求：
✅ 创建一个名为Voting的合约，包含以下功能：
一个mapping来存储候选人的得票数
一个vote函数，允许用户投票给某个候选人
一个getVotes函数，返回某个候选人的得票数
一个resetVotes函数，重置所有候选人的得票数
✅ 反转字符串 (Reverse String)
题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
✅  用 solidity 实现整数转罗马数字
题目描述在 https://leetcode.cn/problems/roman-to-integer/description/3.
✅  用 solidity 实现罗马数字转数整数
题目描述在 https://leetcode.cn/problems/integer-to-roman/description/
✅  合并两个有序数组 (Merge Sorted Array)
题目描述：将两个有序数组合并为一个有序数组。
✅  二分查找 (Binary Search)
题目描述：在一个有序数组中查找目标值。

## 合约列表

### 1. Voting.sol - 投票合约
**功能描述：** 一个简单的投票系统
- `vote(string candidate)` - 为候选人投票
- `getVotes(string candidate)` - 获取候选人得票数
- `resetVotes()` - 重置所有投票
- `getCandidates()` - 获取所有候选人列表
- `getCandidateCount()` - 获取候选人总数

**特性：**
- 支持动态添加候选人
- 事件记录投票和重置操作
- 防止重复候选人

### 2. ReverseString.sol - 字符串反转合约
**功能描述：** 反转字符串功能
- `reverseString(string input)` - 反转单个字符串
- `reverseStringArray(string[] inputs)` - 批量反转字符串数组
- `isPalindrome(string input)` - 检查是否为回文

**示例：**
- 输入: "abcde" → 输出: "edcba"
- 输入: "hello" → 输出: "olleh"

### 3. IntToRoman.sol - 整数转罗马数字合约
**功能描述：** 将整数转换为罗马数字
- `intToRoman(uint256 num)` - 转换单个整数
- `intArrayToRoman(uint256[] nums)` - 批量转换
- `isValidNumber(uint256 num)` - 检查数字是否在有效范围内
- `getSupportedRange()` - 获取支持的数字范围 (1-3999)

**示例：**
- 1 → "I"
- 4 → "IV"
- 1994 → "MCMXCIV"

### 4. RomanToInt.sol - 罗马数字转整数合约
**功能描述：** 将罗马数字转换为整数
- `romanToInt(string roman)` - 转换单个罗马数字
- `romanArrayToInt(string[] romans)` - 批量转换
- `isValidRoman(string roman)` - 验证罗马数字格式
- `getSupportedCharacters()` - 获取支持的罗马字符

**示例：**
- "IV" → 4
- "LVIII" → 58
- "MCMXC" → 1990

### 5. MergeSortedArray.sol - 合并有序数组合约
**功能描述：** 合并有序数组
- `mergeSortedArrays(uint256[] nums1, uint256[] nums2)` - 合并两个有序数组
- `mergeMultipleSortedArrays(uint256[][] arrays)` - 合并多个有序数组
- `mergeSortedArraysWithOption(nums1, nums2, removeDuplicates)` - 合并并可选去重
- `isSorted(uint256[] nums)` - 检查数组是否有序

**示例：**
- [1,3,5] + [2,4,6] → [1,2,3,4,5,6]

### 6. BinarySearch.sol - 二分查找合约
**功能描述：** 在有序数组中进行二分查找
- `binarySearch(uint256[] nums, uint256 target)` - 基本二分查找
- `findFirstOccurrence(nums, target)` - 查找第一个出现位置
- `findLastOccurrence(nums, target)` - 查找最后一个出现位置
- `findRange(nums, target)` - 查找目标值的范围
- `findInsertPosition(nums, target)` - 查找插入位置
- `batchSearch(nums, targets)` - 批量查找

**特性：**
- 支持重复元素的查找
- 返回 `type(uint256).max` 表示未找到
- 时间复杂度 O(log n)

## 使用方法

### 编译合约
```bash
npx hardhat compile
```

### 运行测试
```bash
npx hardhat test test/task1/AllContracts.test.js
```

### 部署合约
```bash
npx hardhat run scripts/deploy.js --network localhost
```

## 测试覆盖

所有合约都包含了全面的测试用例：
- ✅ 29个测试用例全部通过
- ✅ 包含边界条件测试
- ✅ 包含错误处理测试
- ✅ 包含集成测试

## Gas 使用情况

| 合约 | 部署Gas | 占区块限制 |
|------|---------|------------|
| Voting | 882,137 | 2.9% |
| ReverseString | 517,518 | 1.7% |
| IntToRoman | 1,265,390 | 4.2% |
| RomanToInt | 924,219 | 3.1% |
| MergeSortedArray | 968,915 | 3.2% |
| BinarySearch | 777,650 | 2.6% |

## 技术特性

- **Solidity版本：** ^0.8.19
- **许可证：** MIT
- **优化：** 未启用（开发环境）
- **安全性：** 包含输入验证和错误处理
- **可扩展性：** 支持批量操作
- **事件记录：** 关键操作都有事件记录