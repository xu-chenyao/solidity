// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @dev 价格预言机接口，用于获取 ERC20 和 ETH 的美元价格
 */
interface IPriceOracle {
    /**
     * @dev 获取 ETH 的美元价格
     * @return price ETH 价格（以美元计价，8位小数）
     * @return decimals 价格小数位数
     */
    function getETHPrice() external view returns (int256 price, uint8 decimals);
    
    /**
     * @dev 获取指定 ERC20 代币的美元价格
     * @param token ERC20 代币地址
     * @return price 代币价格（以美元计价，8位小数）
     * @return decimals 价格小数位数
     */
    function getTokenPrice(address token) external view returns (int256 price, uint8 decimals);
    
    /**
     * @dev 将 ETH 金额转换为美元价值
     * @param ethAmount ETH 数量（wei 单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertETHToUSD(uint256 ethAmount) external view returns (uint256 usdValue);
    
    /**
     * @dev 将 ERC20 代币金额转换为美元价值
     * @param token ERC20 代币地址
     * @param tokenAmount 代币数量（代币最小单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertTokenToUSD(address token, uint256 tokenAmount) external view returns (uint256 usdValue);
    
    /**
     * @dev 检查代币是否受支持
     * @param token ERC20 代币地址
     * @return 是否受支持
     */
    function isTokenSupported(address token) external view returns (bool);
}
