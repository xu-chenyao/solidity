// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Voting
 * @dev 一个简单的投票合约
 */
contract Voting {
    // 存储候选人的得票数
    mapping(string => uint256) private votes;
    
    // 存储所有候选人名单
    string[] public candidates;
    
    // 事件：投票事件
    event VoteCast(string candidate, uint256 newVoteCount);
    
    // 事件：重置投票事件
    event VotesReset();
    
    /**
     * @dev 投票给某个候选人
     * @param candidate 候选人名称
     */
    function vote(string memory candidate) public {
        // 如果是新候选人，添加到候选人列表
        if (votes[candidate] == 0) {
            bool exists = false;
            for (uint i = 0; i < candidates.length; i++) {
                if (keccak256(bytes(candidates[i])) == keccak256(bytes(candidate))) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                candidates.push(candidate);
            }
        }
        
        votes[candidate]++;
        emit VoteCast(candidate, votes[candidate]);
    }
    
    /**
     * @dev 获取某个候选人的得票数
     * @param candidate 候选人名称
     * @return 得票数
     */
    function getVotes(string memory candidate) public view returns (uint256) {
        return votes[candidate];
    }
    
    /**
     * @dev 重置所有候选人的得票数
     */
    function resetVotes() public {
        for (uint i = 0; i < candidates.length; i++) {
            votes[candidates[i]] = 0;
        }
        delete candidates;
        emit VotesReset();
    }
    
    /**
     * @dev 获取所有候选人列表
     * @return 候选人名称数组
     */
    function getCandidates() public view returns (string[] memory) {
        return candidates;
    }
    
    /**
     * @dev 获取候选人总数
     * @return 候选人数量
     */
    function getCandidateCount() public view returns (uint256) {
        return candidates.length;
    }
}
