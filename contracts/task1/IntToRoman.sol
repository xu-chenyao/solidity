// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IntToRoman
 * @dev 整数转罗马数字的合约
 */
contract IntToRoman {
    
    // 罗马数字映射表
    uint256[] private values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    string[] private symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];
    
    /**
     * @dev 将整数转换为罗马数字
     * @param num 输入整数 (1-3999)
     * @return 罗马数字字符串
     */
    function intToRoman(uint256 num) public view returns (string memory) {
        require(num > 0 && num <= 3999, "Number must be between 1 and 3999");
        
        string memory result = "";
        
        for (uint256 i = 0; i < values.length; i++) {
            while (num >= values[i]) {
                result = string(abi.encodePacked(result, symbols[i]));
                num -= values[i];
            }
        }
        
        return result;
    }
    
    /**
     * @dev 批量转换整数数组为罗马数字数组
     * @param nums 输入整数数组
     * @return 罗马数字字符串数组
     */
    function intArrayToRoman(uint256[] memory nums) public view returns (string[] memory) {
        string[] memory results = new string[](nums.length);
        
        for (uint256 i = 0; i < nums.length; i++) {
            results[i] = intToRoman(nums[i]);
        }
        
        return results;
    }
    
    /**
     * @dev 获取支持的数字范围
     * @return min 最小值, max 最大值
     */
    function getSupportedRange() public pure returns (uint256 min, uint256 max) {
        return (1, 3999);
    }
    
    /**
     * @dev 检查数字是否在支持范围内
     * @param num 要检查的数字
     * @return 是否在支持范围内
     */
    function isValidNumber(uint256 num) public pure returns (bool) {
        return num > 0 && num <= 3999;
    }
}
