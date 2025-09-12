// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RomanToInt
 * @dev 罗马数字转整数的合约
 */
contract RomanToInt {
    
    /**
     * @dev 获取单个罗马字符的数值
     * @param c 罗马字符
     * @return 对应的数值
     */
    function getRomanValue(bytes1 c) private pure returns (uint256) {
        if (c == 'I') return 1;
        if (c == 'V') return 5;
        if (c == 'X') return 10;
        if (c == 'L') return 50;
        if (c == 'C') return 100;
        if (c == 'D') return 500;
        if (c == 'M') return 1000;
        return 0;
    }
    
    /**
     * @dev 将罗马数字转换为整数
     * @param roman 罗马数字字符串
     * @return 对应的整数
     */
    function romanToInt(string memory roman) public pure returns (uint256) {
        bytes memory romanBytes = bytes(roman);
        require(romanBytes.length > 0, "Roman string cannot be empty");
        
        uint256 result = 0;
        uint256 length = romanBytes.length;
        uint256 prevValue = 0;
        
        // 从右到左遍历
        for (uint256 i = length; i > 0; i--) {
            uint256 currentValue = getRomanValue(romanBytes[i - 1]);
            require(currentValue > 0, "Invalid roman character");
            
            if (currentValue < prevValue) {
                result -= currentValue;
            } else {
                result += currentValue;
            }
            
            prevValue = currentValue;
        }
        
        return result;
    }
    
    /**
     * @dev 批量转换罗马数字数组为整数数组
     * @param romans 罗马数字字符串数组
     * @return 整数数组
     */
    function romanArrayToInt(string[] memory romans) public pure returns (uint256[] memory) {
        uint256[] memory results = new uint256[](romans.length);
        
        for (uint256 i = 0; i < romans.length; i++) {
            results[i] = romanToInt(romans[i]);
        }
        
        return results;
    }
    
    /**
     * @dev 验证罗马数字字符串是否有效
     * @param roman 罗马数字字符串
     * @return 是否有效
     */
    function isValidRoman(string memory roman) public pure returns (bool) {
        bytes memory romanBytes = bytes(roman);
        
        if (romanBytes.length == 0) {
            return false;
        }
        
        for (uint256 i = 0; i < romanBytes.length; i++) {
            uint256 value = getRomanValue(romanBytes[i]);
            if (value == 0) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * @dev 获取支持的罗马字符
     * @return 支持的罗马字符数组
     */
    function getSupportedCharacters() public pure returns (string[] memory) {
        string[] memory chars = new string[](7);
        chars[0] = "I";
        chars[1] = "V";
        chars[2] = "X";
        chars[3] = "L";
        chars[4] = "C";
        chars[5] = "D";
        chars[6] = "M";
        return chars;
    }
}
