const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Task1 Contracts", function () {
  let voting, reverseString, intToRoman, romanToInt, mergeSortedArray, binarySearch;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署所有合约
    const Voting = await ethers.getContractFactory("Voting");
    voting = await Voting.deploy();

    const ReverseString = await ethers.getContractFactory("ReverseString");
    reverseString = await ReverseString.deploy();

    const IntToRoman = await ethers.getContractFactory("IntToRoman");
    intToRoman = await IntToRoman.deploy();

    const RomanToInt = await ethers.getContractFactory("RomanToInt");
    romanToInt = await RomanToInt.deploy();

    const MergeSortedArray = await ethers.getContractFactory("MergeSortedArray");
    mergeSortedArray = await MergeSortedArray.deploy();

    const BinarySearch = await ethers.getContractFactory("BinarySearch");
    binarySearch = await BinarySearch.deploy();
  });

  describe("Voting Contract", function () {
    it("应该能够投票给候选人", async function () {
      await voting.vote("Alice");
      expect(await voting.getVotes("Alice")).to.equal(1);
    });

    it("应该能够多次投票", async function () {
      await voting.vote("Alice");
      await voting.vote("Alice");
      await voting.vote("Bob");
      
      expect(await voting.getVotes("Alice")).to.equal(2);
      expect(await voting.getVotes("Bob")).to.equal(1);
    });

    it("应该能够重置投票", async function () {
      await voting.vote("Alice");
      await voting.vote("Bob");
      
      await voting.resetVotes();
      
      expect(await voting.getVotes("Alice")).to.equal(0);
      expect(await voting.getVotes("Bob")).to.equal(0);
      expect(await voting.getCandidateCount()).to.equal(0);
    });

    it("应该能够获取候选人列表", async function () {
      await voting.vote("Alice");
      await voting.vote("Bob");
      
      const candidates = await voting.getCandidates();
      expect(candidates).to.include("Alice");
      expect(candidates).to.include("Bob");
      expect(candidates.length).to.equal(2);
    });
  });

  describe("ReverseString Contract", function () {
    it("应该能够反转字符串", async function () {
      expect(await reverseString.reverseString("abcde")).to.equal("edcba");
      expect(await reverseString.reverseString("hello")).to.equal("olleh");
      expect(await reverseString.reverseString("")).to.equal("");
      expect(await reverseString.reverseString("a")).to.equal("a");
    });

    it("应该能够检查回文", async function () {
      expect(await reverseString.isPalindrome("aba")).to.be.true;
      expect(await reverseString.isPalindrome("abcba")).to.be.true;
      expect(await reverseString.isPalindrome("abc")).to.be.false;
      expect(await reverseString.isPalindrome("")).to.be.true;
    });

    it("应该能够批量反转字符串", async function () {
      const inputs = ["abc", "def", "ghi"];
      const results = await reverseString.reverseStringArray(inputs);
      expect(results[0]).to.equal("cba");
      expect(results[1]).to.equal("fed");
      expect(results[2]).to.equal("ihg");
    });
  });

  describe("IntToRoman Contract", function () {
    it("应该能够将整数转换为罗马数字", async function () {
      expect(await intToRoman.intToRoman(1)).to.equal("I");
      expect(await intToRoman.intToRoman(4)).to.equal("IV");
      expect(await intToRoman.intToRoman(9)).to.equal("IX");
      expect(await intToRoman.intToRoman(58)).to.equal("LVIII");
      expect(await intToRoman.intToRoman(1994)).to.equal("MCMXCIV");
      expect(await intToRoman.intToRoman(3999)).to.equal("MMMCMXCIX");
    });

    it("应该拒绝无效的数字", async function () {
      await expect(intToRoman.intToRoman(0)).to.be.revertedWith("Number must be between 1 and 3999");
      await expect(intToRoman.intToRoman(4000)).to.be.revertedWith("Number must be between 1 and 3999");
    });

    it("应该能够检查数字有效性", async function () {
      expect(await intToRoman.isValidNumber(1)).to.be.true;
      expect(await intToRoman.isValidNumber(3999)).to.be.true;
      expect(await intToRoman.isValidNumber(0)).to.be.false;
      expect(await intToRoman.isValidNumber(4000)).to.be.false;
    });

    it("应该能够批量转换", async function () {
      const nums = [1, 4, 9, 58];
      const results = await intToRoman.intArrayToRoman(nums);
      expect(results[0]).to.equal("I");
      expect(results[1]).to.equal("IV");
      expect(results[2]).to.equal("IX");
      expect(results[3]).to.equal("LVIII");
    });
  });

  describe("RomanToInt Contract", function () {
    it("应该能够将罗马数字转换为整数", async function () {
      expect(await romanToInt.romanToInt("I")).to.equal(1);
      expect(await romanToInt.romanToInt("IV")).to.equal(4);
      expect(await romanToInt.romanToInt("IX")).to.equal(9);
      expect(await romanToInt.romanToInt("LVIII")).to.equal(58);
      expect(await romanToInt.romanToInt("MCMXC")).to.equal(1990);
      expect(await romanToInt.romanToInt("MMCDXLIV")).to.equal(2444);
    });

    it("应该能够验证罗马数字", async function () {
      expect(await romanToInt.isValidRoman("IV")).to.be.true;
      expect(await romanToInt.isValidRoman("MCMXC")).to.be.true;
      expect(await romanToInt.isValidRoman("")).to.be.false;
    });

    it("应该拒绝无效字符", async function () {
      await expect(romanToInt.romanToInt("ABC")).to.be.revertedWith("Invalid roman character");
      await expect(romanToInt.romanToInt("")).to.be.revertedWith("Roman string cannot be empty");
    });

    it("应该能够批量转换", async function () {
      const romans = ["I", "IV", "IX", "LVIII"];
      const results = await romanToInt.romanArrayToInt(romans);
      expect(results[0]).to.equal(1);
      expect(results[1]).to.equal(4);
      expect(results[2]).to.equal(9);
      expect(results[3]).to.equal(58);
    });
  });

  describe("MergeSortedArray Contract", function () {
    it("应该能够合并两个有序数组", async function () {
      const nums1 = [1, 3, 5];
      const nums2 = [2, 4, 6];
      const result = await mergeSortedArray.mergeSortedArrays(nums1, nums2);
      expect(result.map(n => n.toString())).to.deep.equal(["1", "2", "3", "4", "5", "6"]);
    });

    it("应该能够处理空数组", async function () {
      const nums1 = [];
      const nums2 = [1, 2, 3];
      const result = await mergeSortedArray.mergeSortedArrays(nums1, nums2);
      expect(result.map(n => n.toString())).to.deep.equal(["1", "2", "3"]);
    });

    it("应该能够处理不同长度的数组", async function () {
      const nums1 = [1, 5, 9];
      const nums2 = [2, 3, 4, 6, 7, 8];
      const result = await mergeSortedArray.mergeSortedArrays(nums1, nums2);
      expect(result.map(n => n.toString())).to.deep.equal(["1", "2", "3", "4", "5", "6", "7", "8", "9"]);
    });

    it("应该能够检查数组是否有序", async function () {
      expect(await mergeSortedArray.isSorted([1, 2, 3, 4, 5])).to.be.true;
      expect(await mergeSortedArray.isSorted([1, 3, 2, 4, 5])).to.be.false;
      expect(await mergeSortedArray.isSorted([])).to.be.true;
      expect(await mergeSortedArray.isSorted([1])).to.be.true;
    });

    it("应该能够合并并去重", async function () {
      const nums1 = [1, 2, 3];
      const nums2 = [2, 3, 4];
      const result = await mergeSortedArray.mergeSortedArraysWithOption(nums1, nums2, true);
      expect(result.map(n => n.toString())).to.deep.equal(["1", "2", "3", "4"]);
    });
  });

  describe("BinarySearch Contract", function () {
    it("应该能够在有序数组中查找元素", async function () {
      const nums = [1, 3, 5, 7, 9, 11];
      expect(await binarySearch.binarySearch(nums, 5)).to.equal(2);
      expect(await binarySearch.binarySearch(nums, 1)).to.equal(0);
      expect(await binarySearch.binarySearch(nums, 11)).to.equal(5);
    });

    it("应该在元素不存在时返回最大值", async function () {
      const nums = [1, 3, 5, 7, 9, 11];
      const maxUint = ethers.MaxUint256;
      expect(await binarySearch.binarySearch(nums, 4)).to.equal(maxUint);
      expect(await binarySearch.binarySearch(nums, 0)).to.equal(maxUint);
      expect(await binarySearch.binarySearch(nums, 12)).to.equal(maxUint);
    });

    it("应该能够查找第一个和最后一个出现位置", async function () {
      const nums = [1, 2, 2, 2, 3, 4];
      expect(await binarySearch.findFirstOccurrence(nums, 2)).to.equal(1);
      expect(await binarySearch.findLastOccurrence(nums, 2)).to.equal(3);
      
      const [first, last] = await binarySearch.findRange(nums, 2);
      expect(first).to.equal(1);
      expect(last).to.equal(3);
    });

    it("应该能够查找插入位置", async function () {
      const nums = [1, 3, 5, 7];
      expect(await binarySearch.findInsertPosition(nums, 4)).to.equal(2);
      expect(await binarySearch.findInsertPosition(nums, 0)).to.equal(0);
      expect(await binarySearch.findInsertPosition(nums, 8)).to.equal(4);
    });

    it("应该能够检查数组是否有序", async function () {
      expect(await binarySearch.isSorted([1, 2, 3, 4, 5])).to.be.true;
      expect(await binarySearch.isSorted([1, 3, 2, 4, 5])).to.be.false;
    });

    it("应该能够批量查找", async function () {
      const nums = [1, 3, 5, 7, 9];
      const targets = [1, 5, 9, 4];
      const results = await binarySearch.batchSearch(nums, targets);
      const maxUint = ethers.MaxUint256;
      
      expect(results[0]).to.equal(0); // 1 在索引 0
      expect(results[1]).to.equal(2); // 5 在索引 2
      expect(results[2]).to.equal(4); // 9 在索引 4
      expect(results[3]).to.equal(maxUint); // 4 不存在
    });
  });

  describe("Integration Tests", function () {
    it("应该能够组合使用多个合约", async function () {
      // 测试整数转罗马数字再转回整数
      const num = 1994;
      const roman = await intToRoman.intToRoman(num);
      const backToInt = await romanToInt.romanToInt(roman);
      expect(backToInt).to.equal(num);
    });

    it("应该能够反转字符串并检查是否为回文", async function () {
      const str = "hello";
      const reversed = await reverseString.reverseString(str);
      const isPalindrome = await reverseString.isPalindrome(str);
      
      expect(reversed).to.equal("olleh");
      expect(isPalindrome).to.be.false;
    });

    it("应该能够合并数组后进行二分查找", async function () {
      const nums1 = [1, 5, 9];
      const nums2 = [3, 7, 11];
      const merged = await mergeSortedArray.mergeSortedArrays(nums1, nums2);
      // 将BigNumber数组转换为普通数组
      const mergedArray = merged.map(n => Number(n));
      const searchResult = await binarySearch.binarySearch(mergedArray, 7);
      
      expect(searchResult).to.equal(3); // 7 在合并后数组的索引 3
    });
  });
});
