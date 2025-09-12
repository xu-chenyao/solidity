// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MergeSortedArray
 * @dev 合并有序数组的合约
 */
contract MergeSortedArray {
    
    /**
     * @dev 合并两个有序数组
     * @param nums1 第一个有序数组
     * @param nums2 第二个有序数组
     * @return 合并后的有序数组
     */
    function mergeSortedArrays(uint256[] memory nums1, uint256[] memory nums2) 
        public 
        pure 
        returns (uint256[] memory) 
    {
        uint256 len1 = nums1.length;
        uint256 len2 = nums2.length;
        uint256[] memory result = new uint256[](len1 + len2);
        
        uint256 i = 0; // nums1的指针
        uint256 j = 0; // nums2的指针
        uint256 k = 0; // result的指针
        
        // 合并两个数组
        while (i < len1 && j < len2) {
            if (nums1[i] <= nums2[j]) {
                result[k] = nums1[i];
                i++;
            } else {
                result[k] = nums2[j];
                j++;
            }
            k++;
        }
        
        // 复制nums1剩余元素
        while (i < len1) {
            result[k] = nums1[i];
            i++;
            k++;
        }
        
        // 复制nums2剩余元素
        while (j < len2) {
            result[k] = nums2[j];
            j++;
            k++;
        }
        
        return result;
    }
    
    /**
     * @dev 合并多个有序数组
     * @param arrays 有序数组的数组
     * @return 合并后的有序数组
     */
    function mergeMultipleSortedArrays(uint256[][] memory arrays) 
        public 
        pure 
        returns (uint256[] memory) 
    {
        if (arrays.length == 0) {
            return new uint256[](0);
        }
        
        uint256[] memory result = arrays[0];
        
        for (uint256 i = 1; i < arrays.length; i++) {
            result = mergeSortedArrays(result, arrays[i]);
        }
        
        return result;
    }
    
    /**
     * @dev 检查数组是否有序（升序）
     * @param nums 要检查的数组
     * @return 是否有序
     */
    function isSorted(uint256[] memory nums) public pure returns (bool) {
        if (nums.length <= 1) {
            return true;
        }
        
        for (uint256 i = 1; i < nums.length; i++) {
            if (nums[i] < nums[i - 1]) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * @dev 合并两个有序数组（支持重复元素去重）
     * @param nums1 第一个有序数组
     * @param nums2 第二个有序数组
     * @param removeDuplicates 是否去重
     * @return 合并后的数组
     */
    function mergeSortedArraysWithOption(
        uint256[] memory nums1, 
        uint256[] memory nums2, 
        bool removeDuplicates
    ) 
        public 
        pure 
        returns (uint256[] memory) 
    {
        if (!removeDuplicates) {
            return mergeSortedArrays(nums1, nums2);
        }
        
        uint256 len1 = nums1.length;
        uint256 len2 = nums2.length;
        uint256[] memory temp = new uint256[](len1 + len2);
        
        uint256 i = 0; // nums1的指针
        uint256 j = 0; // nums2的指针
        uint256 k = 0; // temp的指针
        
        // 合并并去重
        while (i < len1 && j < len2) {
            if (nums1[i] < nums2[j]) {
                if (k == 0 || temp[k - 1] != nums1[i]) {
                    temp[k] = nums1[i];
                    k++;
                }
                i++;
            } else if (nums1[i] > nums2[j]) {
                if (k == 0 || temp[k - 1] != nums2[j]) {
                    temp[k] = nums2[j];
                    k++;
                }
                j++;
            } else {
                // nums1[i] == nums2[j]
                if (k == 0 || temp[k - 1] != nums1[i]) {
                    temp[k] = nums1[i];
                    k++;
                }
                i++;
                j++;
            }
        }
        
        // 处理剩余元素
        while (i < len1) {
            if (k == 0 || temp[k - 1] != nums1[i]) {
                temp[k] = nums1[i];
                k++;
            }
            i++;
        }
        
        while (j < len2) {
            if (k == 0 || temp[k - 1] != nums2[j]) {
                temp[k] = nums2[j];
                k++;
            }
            j++;
        }
        
        // 创建正确大小的结果数组
        uint256[] memory result = new uint256[](k);
        for (uint256 idx = 0; idx < k; idx++) {
            result[idx] = temp[idx];
        }
        
        return result;
    }
}
