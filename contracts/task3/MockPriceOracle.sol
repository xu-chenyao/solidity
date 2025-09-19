// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPriceOracle.sol";

/**
 * @title MockPriceOracle
 * @dev 模拟价格预言机合约，用于测试
 * 提供固定的价格数据，方便测试拍卖功能
 */
contract MockPriceOracle is IPriceOracle {
    /// @dev ETH 价格（美元，8位小数）
    int256 public ethPrice;

    /// @dev ERC20 代币价格映射（美元，8位小数）
    mapping(address => int256) public tokenPrices;

    /// @dev 支持的代币列表
    address[] public supportedTokens;

    /// @dev 价格小数位数
    uint8 public constant DECIMALS = 8;

    // 事件定义
    event ETHPriceUpdated(int256 newPrice);
    event TokenPriceUpdated(address indexed token, int256 newPrice);

    /**
     * @dev 构造函数
     * @param _ethPrice 初始 ETH 价格（美元，8位小数）
     */
    constructor(int256 _ethPrice) {
        require(_ethPrice > 0, "MockPriceOracle: invalid ETH price");
        ethPrice = _ethPrice;
    }

    /**
     * @dev 设置 ETH 价格
     * @param _price 新的 ETH 价格（美元，8位小数）
     */
    function setETHPrice(int256 _price) external {
        require(_price > 0, "MockPriceOracle: invalid price");
        ethPrice = _price;
        emit ETHPriceUpdated(_price);
    }

    /**
     * @dev 设置 ERC20 代币价格
     * @param _token ERC20 代币地址
     * @param _price 代币价格（美元，8位小数）
     */
    function setTokenPrice(address _token, int256 _price) external {
        require(_token != address(0), "MockPriceOracle: zero token address");
        require(_price > 0, "MockPriceOracle: invalid price");

        // 如果是新代币，添加到支持列表
        if (tokenPrices[_token] == 0) {
            supportedTokens.push(_token);
        }

        tokenPrices[_token] = _price;
        emit TokenPriceUpdated(_token, _price);
    }

    /**
     * @dev 批量设置代币价格
     * @param _tokens 代币地址数组
     * @param _prices 价格数组（美元，8位小数）
     */
    function setBatchTokenPrices(address[] memory _tokens, int256[] memory _prices) external {
        require(_tokens.length == _prices.length, "MockPriceOracle: arrays length mismatch");
        require(_tokens.length <= 50, "MockPriceOracle: batch size too large");

        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "MockPriceOracle: zero token address");
            require(_prices[i] > 0, "MockPriceOracle: invalid price");

            // 如果是新代币，添加到支持列表
            if (tokenPrices[_tokens[i]] == 0) {
                supportedTokens.push(_tokens[i]);
            }

            tokenPrices[_tokens[i]] = _prices[i];
            emit TokenPriceUpdated(_tokens[i], _prices[i]);
        }
    }

    /**
     * @dev 获取 ETH 的美元价格
     * @return price ETH 价格（8位小数）
     * @return decimals 价格小数位数
     */
    function getETHPrice() external view override returns (int256 price, uint8 decimals) {
        return (ethPrice, DECIMALS);
    }

    /**
     * @dev 获取指定 ERC20 代币的美元价格
     * @param token ERC20 代币地址
     * @return price 代币价格（8位小数）
     * @return decimals 价格小数位数
     */
    function getTokenPrice(address token) external view override returns (int256 price, uint8 decimals) {
        require(tokenPrices[token] > 0, "MockPriceOracle: token not supported");
        return (tokenPrices[token], DECIMALS);
    }

    /**
     * @dev 将 ETH 金额转换为美元价值
     * @param ethAmount ETH 数量（wei 单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertETHToUSD(uint256 ethAmount) external view override returns (uint256 usdValue) {
        require(ethPrice > 0, "MockPriceOracle: invalid ETH price");
        
        // ETH 有 18 位小数，价格有 8 位小数
        // 最终结果需要 8 位小数
        usdValue = (ethAmount * uint256(ethPrice)) / (10 ** (18 + DECIMALS - 8));
    }

    /**
     * @dev 将 ERC20 代币金额转换为美元价值
     * @param token ERC20 代币地址
     * @param tokenAmount 代币数量（代币最小单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertTokenToUSD(address token, uint256 tokenAmount) external view override returns (uint256 usdValue) {
        require(tokenPrices[token] > 0, "MockPriceOracle: token not supported");
        
        // 假设代币有 18 位小数（标准 ERC20），价格有 8 位小数
        // 最终结果需要 8 位小数
        usdValue = (tokenAmount * uint256(tokenPrices[token])) / (10 ** (18 + DECIMALS - 8));
    }

    /**
     * @dev 获取支持的代币列表
     * @return 支持的代币地址数组
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev 检查代币是否受支持
     * @param token ERC20 代币地址
     * @return 是否受支持
     */
    function isTokenSupported(address token) external view returns (bool) {
        return tokenPrices[token] > 0;
    }

    /**
     * @dev 移除代币支持
     * @param _token 要移除的代币地址
     */
    function removeTokenSupport(address _token) external {
        require(tokenPrices[_token] > 0, "MockPriceOracle: token not supported");

        // 从支持列表中移除
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        delete tokenPrices[_token];
        emit TokenPriceUpdated(_token, 0);
    }

    /**
     * @dev 模拟价格波动
     * @param _ethPriceChange ETH 价格变化百分比（基点，10000 = 100%）
     * @param _tokens 要调整价格的代币数组
     * @param _priceChanges 价格变化百分比数组（基点）
     */
    function simulatePriceFluctuation(
        int256 _ethPriceChange,
        address[] memory _tokens,
        int256[] memory _priceChanges
    ) external {
        require(_tokens.length == _priceChanges.length, "MockPriceOracle: arrays length mismatch");

        // 调整 ETH 价格
        if (_ethPriceChange != 0) {
            int256 newEthPrice = ethPrice + (ethPrice * _ethPriceChange / 10000);
            require(newEthPrice > 0, "MockPriceOracle: invalid new ETH price");
            ethPrice = newEthPrice;
            emit ETHPriceUpdated(newEthPrice);
        }

        // 调整代币价格
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (tokenPrices[_tokens[i]] > 0 && _priceChanges[i] != 0) {
                int256 newPrice = tokenPrices[_tokens[i]] + (tokenPrices[_tokens[i]] * _priceChanges[i] / 10000);
                require(newPrice > 0, "MockPriceOracle: invalid new token price");
                tokenPrices[_tokens[i]] = newPrice;
                emit TokenPriceUpdated(_tokens[i], newPrice);
            }
        }
    }
}
