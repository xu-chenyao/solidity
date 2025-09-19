// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @dev 测试用的 ERC20 代币合约
 * 用于拍卖系统中的 ERC20 代币出价测试
 */
contract TestToken is ERC20, Ownable {
    /// @dev 代币小数位数
    uint8 private _decimals;

    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _tokenDecimals 代币小数位数
     * @param _initialSupply 初始供应量
     * @param _owner 合约拥有者地址
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _tokenDecimals,
        uint256 _initialSupply,
        address _owner
    ) ERC20(_name, _symbol) Ownable(_owner) {
        _decimals = _tokenDecimals;
        _mint(_owner, _initialSupply * 10**_decimals);
    }

    /**
     * @dev 返回代币小数位数
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev 铸造代币（仅合约拥有者可调用）
     * @param _to 接收者地址
     * @param _amount 铸造数量
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /**
     * @dev 销毁代币（仅合约拥有者可调用）
     * @param _from 销毁地址
     * @param _amount 销毁数量
     */
    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }

    /**
     * @dev 批量转账
     * @param _recipients 接收者地址数组
     * @param _amounts 转账数量数组
     */
    function batchTransfer(address[] memory _recipients, uint256[] memory _amounts) external {
        require(_recipients.length == _amounts.length, "TestToken: arrays length mismatch");
        require(_recipients.length <= 100, "TestToken: batch size too large");

        for (uint256 i = 0; i < _recipients.length; i++) {
            transfer(_recipients[i], _amounts[i]);
        }
    }

    /**
     * @dev 空投代币（仅合约拥有者可调用）
     * @param _recipients 接收者地址数组
     * @param _amount 每个地址接收的数量
     */
    function airdrop(address[] memory _recipients, uint256 _amount) external onlyOwner {
        require(_recipients.length <= 1000, "TestToken: airdrop size too large");

        for (uint256 i = 0; i < _recipients.length; i++) {
            _mint(_recipients[i], _amount);
        }
    }
}
