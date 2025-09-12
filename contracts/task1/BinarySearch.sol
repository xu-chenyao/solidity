// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BinarySearch
 * @dev 二分查找的合约
 */
contract BinarySearch {
    
    /**
     * @dev 在有序数组中进行二分查找
     * @param nums 有序数组
     * @param target 目标值
     * @return 目标值的索引，如果不存在返回 type(uint256).max
     */
    function binarySearch(uint256[] memory nums, uint256 target) 
        public 
        pure 
        returns (uint256) 
    {
        if (nums.length == 0) {
            return type(uint256).max;
        }
        
        uint256 left = 0;
        uint256 right = nums.length - 1;
        
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            
            if (nums[mid] == target) {
                return mid;
            } else if (nums[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) break; // 防止下溢
                right = mid - 1;
            }
        }
        
        return type(uint256).max; // 未找到
    }
    
    /**
     * @dev 查找目标值的第一个出现位置（左边界）
     * @param nums 有序数组（可能包含重复元素）
     * @param target 目标值
     * @return 第一个出现位置的索引，如果不存在返回 type(uint256).max
     */
    function findFirstOccurrence(uint256[] memory nums, uint256 target) 
        public 
        pure 
        returns (uint256) 
    {
        if (nums.length == 0) {
            return type(uint256).max;
        }
        
        uint256 left = 0;
        uint256 right = nums.length - 1;
        uint256 result = type(uint256).max;
        
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            
            if (nums[mid] == target) {
                result = mid;
                if (mid == 0) break;
                right = mid - 1; // 继续在左半部分查找
            } else if (nums[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) break;
                right = mid - 1;
            }
        }
        
        return result;
    }
    
    /**
     * @dev 查找目标值的最后一个出现位置（右边界）
     * @param nums 有序数组（可能包含重复元素）
     * @param target 目标值
     * @return 最后一个出现位置的索引，如果不存在返回 type(uint256).max
     */
    function findLastOccurrence(uint256[] memory nums, uint256 target) 
        public 
        pure 
        returns (uint256) 
    {
        if (nums.length == 0) {
            return type(uint256).max;
        }
        
        uint256 left = 0;
        uint256 right = nums.length - 1;
        uint256 result = type(uint256).max;
        
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            
            if (nums[mid] == target) {
                result = mid;
                left = mid + 1; // 继续在右半部分查找
            } else if (nums[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) break;
                right = mid - 1;
            }
        }
        
        return result;
    }
    
    /**
     * @dev 查找目标值的范围（第一个和最后一个出现位置）
     * @param nums 有序数组
     * @param target 目标值
     * @return first 第一个出现位置, last 最后一个出现位置
     */
    function findRange(uint256[] memory nums, uint256 target) 
        public 
        pure 
        returns (uint256 first, uint256 last) 
    {
        first = findFirstOccurrence(nums, target);
        last = findLastOccurrence(nums, target);
        return (first, last);
    }
    
    /**
     * @dev 查找插入位置（如果目标值不存在，返回应该插入的位置）
     * @param nums 有序数组
     * @param target 目标值
     * @return 插入位置的索引
     */
    function findInsertPosition(uint256[] memory nums, uint256 target) 
        public 
        pure 
        returns (uint256) 
    {
        if (nums.length == 0) {
            return 0;
        }
        
        uint256 left = 0;
        uint256 right = nums.length - 1;
        
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            
            if (nums[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) break;
                right = mid - 1;
            }
        }
        
        return left;
    }
    
    /**
     * @dev 检查数组是否有序
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
     * @dev 批量查找多个目标值
     * @param nums 有序数组
     * @param targets 目标值数组
     * @return 每个目标值的索引数组
     */
    function batchSearch(uint256[] memory nums, uint256[] memory targets) 
        public 
        pure 
        returns (uint256[] memory) 
    {
        uint256[] memory results = new uint256[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = binarySearch(nums, targets[i]);
        }
        
        return results;
    }
}
