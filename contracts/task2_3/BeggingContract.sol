// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BeggingContract
 * @dev 讨饭合约 - 允许用户捐赠以太币，合约所有者可以提取资金
 * 
 * 主要功能：
 * - 接收用户捐赠的以太币
 * - 记录每个捐赠者的地址和捐赠金额
 * - 允许合约所有者提取所有资金
 * - 查询捐赠记录和统计信息
 * - 防重入攻击保护
 */
contract BeggingContract is Ownable, ReentrancyGuard {
    
    // 记录每个地址的总捐赠金额
    mapping(address => uint256) public donations;
    
    // 记录所有捐赠者地址（用于遍历）
    address[] public donors;
    
    // 记录地址是否已经捐赠过（避免重复添加到donors数组）
    mapping(address => bool) public hasDonated;
    
    // 合约总接收金额
    uint256 public totalDonations;
    
    // 合约所有者已提取的总金额
    uint256 public totalWithdrawn;
    
    // 捐赠事件
    event DonationReceived(
        address indexed donor,
        uint256 amount,
        uint256 timestamp,
        string message
    );
    
    // 提款事件
    event Withdrawal(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    
    // 紧急提款事件
    event EmergencyWithdrawal(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev 构造函数
     * @param initialOwner 合约初始所有者地址
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // 构造函数中可以添加初始化逻辑
    }
    
    /**
     * @dev 捐赠函数 - 允许用户向合约发送以太币
     * @param message 捐赠留言（可选）
     * 
     * 要求：
     * - 捐赠金额必须大于0
     * - 自动记录捐赠者地址和金额
     * - 触发捐赠事件
     */
    function donate(string memory message) public payable {
        require(msg.value > 0, "BeggingContract: donation amount must be greater than 0");
        
        // 记录捐赠金额
        donations[msg.sender] += msg.value;
        totalDonations += msg.value;
        
        // 如果是首次捐赠，添加到捐赠者列表
        if (!hasDonated[msg.sender]) {
            donors.push(msg.sender);
            hasDonated[msg.sender] = true;
        }
        
        // 触发捐赠事件
        emit DonationReceived(msg.sender, msg.value, block.timestamp, message);
    }
    
    /**
     * @dev 直接接收以太币（fallback函数）
     * 当有人直接向合约地址转账时调用
     */
    receive() external payable {
        donate("Direct transfer");
    }
    
    /**
     * @dev 提取资金函数 - 只有合约所有者可以调用
     * @param amount 要提取的金额（wei）
     * 
     * 要求：
     * - 只有合约所有者可以调用
     * - 提取金额不能超过合约余额
     * - 防重入攻击保护
     */
    function withdraw(uint256 amount) public onlyOwner nonReentrant {
        require(amount > 0, "BeggingContract: withdrawal amount must be greater than 0");
        require(address(this).balance >= amount, "BeggingContract: insufficient contract balance");
        
        // 更新已提取金额
        totalWithdrawn += amount;
        
        // 转账给合约所有者
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "BeggingContract: withdrawal failed");
        
        // 触发提款事件
        emit Withdrawal(owner(), amount, block.timestamp);
    }
    
    /**
     * @dev 提取所有资金
     * 提取合约中的所有余额
     */
    function withdrawAll() public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "BeggingContract: no funds to withdraw");
        
        // 更新已提取金额
        totalWithdrawn += balance;
        
        // 转账给合约所有者
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "BeggingContract: withdrawal failed");
        
        // 触发提款事件
        emit Withdrawal(owner(), balance, block.timestamp);
    }
    
    /**
     * @dev 紧急提款函数 - 在紧急情况下使用
     * 直接提取所有资金，绕过一些检查
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "BeggingContract: no funds to withdraw");
        
        totalWithdrawn += balance;
        
        // 使用transfer进行紧急提款
        payable(owner()).transfer(balance);
        
        emit EmergencyWithdrawal(owner(), balance, block.timestamp);
    }
    
    /**
     * @dev 查询某个地址的捐赠金额
     * @param donor 捐赠者地址
     * @return 该地址的总捐赠金额
     */
    function getDonation(address donor) public view returns (uint256) {
        return donations[donor];
    }
    
    /**
     * @dev 获取合约余额
     * @return 合约当前余额
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取捐赠者数量
     * @return 总捐赠者数量
     */
    function getDonorCount() public view returns (uint256) {
        return donors.length;
    }
    
    /**
     * @dev 获取所有捐赠者地址
     * @return 捐赠者地址数组
     */
    function getAllDonors() public view returns (address[] memory) {
        return donors;
    }
    
    /**
     * @dev 获取捐赠统计信息
     * @return totalReceived 总接收金额
     * @return currentBalance 当前余额
     * @return totalWithdrawnAmount 总提取金额
     * @return donorCount 捐赠者数量
     */
    function getDonationStats() public view returns (
        uint256 totalReceived,
        uint256 currentBalance,
        uint256 totalWithdrawnAmount,
        uint256 donorCount
    ) {
        return (
            totalDonations,
            address(this).balance,
            totalWithdrawn,
            donors.length
        );
    }
    
    /**
     * @dev 获取前N名捐赠者信息
     * @param count 要返回的捐赠者数量
     * @return topDonors 捐赠者地址数组
     * @return amounts 对应的捐赠金额数组
     */
    function getTopDonors(uint256 count) public view returns (
        address[] memory topDonors,
        uint256[] memory amounts
    ) {
        uint256 donorCount = donors.length;
        if (count > donorCount) {
            count = donorCount;
        }
        
        // 创建临时数组用于排序
        address[] memory tempDonors = new address[](donorCount);
        uint256[] memory tempAmounts = new uint256[](donorCount);
        
        // 复制数据
        for (uint256 i = 0; i < donorCount; i++) {
            tempDonors[i] = donors[i];
            tempAmounts[i] = donations[donors[i]];
        }
        
        // 简单的冒泡排序（按捐赠金额降序）
        for (uint256 i = 0; i < donorCount - 1; i++) {
            for (uint256 j = 0; j < donorCount - i - 1; j++) {
                if (tempAmounts[j] < tempAmounts[j + 1]) {
                    // 交换金额
                    uint256 tempAmount = tempAmounts[j];
                    tempAmounts[j] = tempAmounts[j + 1];
                    tempAmounts[j + 1] = tempAmount;
                    
                    // 交换地址
                    address tempDonor = tempDonors[j];
                    tempDonors[j] = tempDonors[j + 1];
                    tempDonors[j + 1] = tempDonor;
                }
            }
        }
        
        // 返回前count名
        topDonors = new address[](count);
        amounts = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            topDonors[i] = tempDonors[i];
            amounts[i] = tempAmounts[i];
        }
        
        return (topDonors, amounts);
    }
    
    /**
     * @dev 检查地址是否已捐赠
     * @param donor 要检查的地址
     * @return 是否已捐赠
     */
    function hasAddressDonated(address donor) public view returns (bool) {
        return hasDonated[donor];
    }
    
    /**
     * @dev 获取平均捐赠金额
     * @return 平均捐赠金额
     */
    function getAverageDonation() public view returns (uint256) {
        if (donors.length == 0) {
            return 0;
        }
        return totalDonations / donors.length;
    }
}
