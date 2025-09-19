// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IPriceOracle.sol";

/**
 * @title ChainlinkPriceOracle
 * @dev 使用 Chainlink 价格预言机获取实时价格数据的合约
 * 支持 ETH 和多种 ERC20 代币的价格查询
 */
contract ChainlinkPriceOracle is 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    IPriceOracle 
{
    /// @dev ETH/USD 价格预言机接口
    AggregatorV3Interface public ethUsdPriceFeed;
    
    /// @dev ERC20 代币地址到价格预言机的映射
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    
    /// @dev 支持的代币列表
    address[] public supportedTokens;
    
    /// @dev 价格数据最大过期时间（秒）
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600; // 1小时

    // 事件定义
    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event ETHPriceFeedUpdated(address indexed priceFeed);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数
     * @param _ethUsdPriceFeed ETH/USD 价格预言机地址
     * @param _owner 合约拥有者地址
     */
    function initialize(
        address _ethUsdPriceFeed,
        address _owner
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        require(_ethUsdPriceFeed != address(0), "ChainlinkPriceOracle: zero ETH price feed");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        
        emit ETHPriceFeedUpdated(_ethUsdPriceFeed);
    }

    /**
     * @dev 设置 ETH/USD 价格预言机
     * @param _ethUsdPriceFeed 新的 ETH/USD 价格预言机地址
     */
    function setETHPriceFeed(address _ethUsdPriceFeed) external onlyOwner {
        require(_ethUsdPriceFeed != address(0), "ChainlinkPriceOracle: zero address");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        emit ETHPriceFeedUpdated(_ethUsdPriceFeed);
    }

    /**
     * @dev 添加或更新 ERC20 代币价格预言机
     * @param _token ERC20 代币地址
     * @param _priceFeed 价格预言机地址
     */
    function setTokenPriceFeed(address _token, address _priceFeed) external onlyOwner {
        require(_token != address(0), "ChainlinkPriceOracle: zero token address");
        require(_priceFeed != address(0), "ChainlinkPriceOracle: zero price feed address");
        
        // 如果是新代币，添加到支持列表
        if (address(tokenPriceFeeds[_token]) == address(0)) {
            supportedTokens.push(_token);
        }
        
        tokenPriceFeeds[_token] = AggregatorV3Interface(_priceFeed);
        emit PriceFeedUpdated(_token, _priceFeed);
    }

    /**
     * @dev 移除 ERC20 代币价格预言机
     * @param _token ERC20 代币地址
     */
    function removeTokenPriceFeed(address _token) external onlyOwner {
        require(address(tokenPriceFeeds[_token]) != address(0), "ChainlinkPriceOracle: token not supported");
        
        // 从支持列表中移除
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
        
        delete tokenPriceFeeds[_token];
        emit PriceFeedUpdated(_token, address(0));
    }

    /**
     * @dev 获取 ETH 的美元价格
     * @return price ETH 价格（8位小数）
     * @return decimals 价格小数位数
     */
    function getETHPrice() external view override returns (int256 price, uint8 decimals) {
        (price, decimals) = _getLatestPrice(ethUsdPriceFeed);
    }

    /**
     * @dev 获取指定 ERC20 代币的美元价格
     * @param token ERC20 代币地址
     * @return price 代币价格（8位小数）
     * @return decimals 价格小数位数
     */
    function getTokenPrice(address token) external view override returns (int256 price, uint8 decimals) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "ChainlinkPriceOracle: token not supported");
        
        (price, decimals) = _getLatestPrice(priceFeed);
    }

    /**
     * @dev 将 ETH 金额转换为美元价值
     * @param ethAmount ETH 数量（wei 单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertETHToUSD(uint256 ethAmount) external view override returns (uint256 usdValue) {
        (int256 price, uint8 decimals) = _getLatestPrice(ethUsdPriceFeed);
        require(price > 0, "ChainlinkPriceOracle: invalid ETH price");
        
        // ETH 有 18 位小数，价格有 decimals 位小数
        // 最终结果需要 8 位小数
        usdValue = (ethAmount * uint256(price)) / (10 ** (18 + decimals - 8));
    }

    /**
     * @dev 将 ERC20 代币金额转换为美元价值
     * @param token ERC20 代币地址
     * @param tokenAmount 代币数量（代币最小单位）
     * @return usdValue 美元价值（8位小数）
     */
    function convertTokenToUSD(address token, uint256 tokenAmount) external view override returns (uint256 usdValue) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "ChainlinkPriceOracle: token not supported");
        
        (int256 price, uint8 decimals) = _getLatestPrice(priceFeed);
        require(price > 0, "ChainlinkPriceOracle: invalid token price");
        
        // 假设代币有 18 位小数（标准 ERC20），价格有 decimals 位小数
        // 最终结果需要 8 位小数
        usdValue = (tokenAmount * uint256(price)) / (10 ** (18 + decimals - 8));
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
        return address(tokenPriceFeeds[token]) != address(0);
    }

    /**
     * @dev 内部函数：从价格预言机获取最新价格
     * @param priceFeed 价格预言机接口
     * @return price 价格
     * @return decimals 小数位数
     */
    function _getLatestPrice(AggregatorV3Interface priceFeed) 
        internal 
        view 
        returns (int256 price, uint8 decimals) 
    {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        require(roundId > 0, "ChainlinkPriceOracle: round not complete");
        require(answer > 0, "ChainlinkPriceOracle: invalid price");
        require(updatedAt > 0, "ChainlinkPriceOracle: round not complete");
        require(answeredInRound >= roundId, "ChainlinkPriceOracle: stale price");
        require(block.timestamp - updatedAt <= PRICE_STALENESS_THRESHOLD, "ChainlinkPriceOracle: price too old");
        
        price = answer;
        decimals = priceFeed.decimals();
    }

    /**
     * @dev 授权升级函数（仅合约拥有者可调用）
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
