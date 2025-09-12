// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ReverseString
 * @dev 反转字符串的合约
 */
contract ReverseString {
    
    /**
     * @dev 反转字符串
     * @param input 输入字符串
     * @return 反转后的字符串
     */
    function reverseString(string memory input) public pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        uint256 length = inputBytes.length;
        
        if (length == 0) {
            return input;
        }
        
        bytes memory reversed = new bytes(length);
        
        for (uint256 i = 0; i < length; i++) {
            reversed[i] = inputBytes[length - 1 - i];
        }
        
        return string(reversed);
    }
    
    /**
     * @dev 批量反转字符串数组
     * @param inputs 输入字符串数组
     * @return 反转后的字符串数组
     */
    function reverseStringArray(string[] memory inputs) public pure returns (string[] memory) {
        string[] memory results = new string[](inputs.length);
        
        for (uint256 i = 0; i < inputs.length; i++) {
            results[i] = reverseString(inputs[i]);
        }
        
        return results;
    }
    
    /**
     * @dev 检查字符串是否为回文
     * @param input 输入字符串
     * @return 是否为回文
     */
    function isPalindrome(string memory input) public pure returns (bool) {
        string memory reversed = reverseString(input);
        return keccak256(bytes(input)) == keccak256(bytes(reversed));
    }
}
