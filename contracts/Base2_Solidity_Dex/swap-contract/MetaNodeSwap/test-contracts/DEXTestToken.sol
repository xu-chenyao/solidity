// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title DEXTestToken - DEX测试专用代币
 * @notice 用于MetaNodeSwap DEX测试的ERC20代币
 * @dev 支持自定义名称、符号和初始供应量
 */
contract DEXTestToken is ERC20 {
    /**
     * @notice 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        // 向部署者铸造初始供应量
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice 铸造代币
     * @param recipient 接收者地址
     * @param amount 铸造数量
     */
    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }

    /**
     * @notice 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
