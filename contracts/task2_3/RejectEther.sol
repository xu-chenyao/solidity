// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RejectEther
 * @dev 辅助测试合约 - 拒绝接收ETH，用于测试转账失败的情况
 */
contract RejectEther {
    // 拒绝接收ETH
    receive() external payable {
        revert("Reject ETH");
    }
    
    fallback() external payable {
        revert("Reject ETH");
    }
}
