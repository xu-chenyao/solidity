// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AuctionNFT.sol";

/**
 * @title AuctionNFTV2
 * @dev AuctionNFT 的升级版本 - 演示如何安全升级合约
 * 
 * 升级注意事项：
 * 1. 不能修改现有状态变量的顺序和类型
 * 2. 只能在末尾添加新的状态变量
 * 3. 不能删除现有的状态变量
 * 4. 可以添加新的函数
 * 5. 可以修改现有函数的实现（但要保持接口兼容）
 */
contract AuctionNFTV2 is AuctionNFT {
    
    // ============ 新增状态变量（只能在末尾添加） ============
    
    /// @dev NFT 版税信息映射 (tokenId => royaltyInfo)
    mapping(uint256 => RoyaltyInfo) public royalties;
    
    /// @dev 版税信息结构体
    struct RoyaltyInfo {
        address recipient;  // 版税接收者
        uint96 percentage;  // 版税百分比（基点，10000 = 100%）
    }
    
    /// @dev NFT 元数据扩展信息
    mapping(uint256 => MetadataExtension) public metadataExtensions;
    
    /// @dev 元数据扩展结构体
    struct MetadataExtension {
        string description;     // NFT 描述
        string externalUrl;     // 外部链接
        string animationUrl;    // 动画链接
        uint256 createdAt;      // 创建时间
    }
    
    /// @dev 批量操作限制
    uint256 public maxBatchSize;
    
    /// @dev 铸造费用（wei）
    uint256 public mintFee;
    
    /// @dev 版本号
    string public constant VERSION = "2.0.0";

    // ============ 新增事件 ============
    
    event RoyaltySet(uint256 indexed tokenId, address indexed recipient, uint96 percentage);
    event MetadataExtensionSet(uint256 indexed tokenId, string description, string externalUrl);
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);
    event BatchSizeUpdated(uint256 oldSize, uint256 newSize);

    // ============ 新增函数 ============
    
    /**
     * @dev 初始化 V2 版本的新功能
     * 注意：这不是构造函数，而是升级后的初始化函数
     */
    function initializeV2() public reinitializer(2) {
        maxBatchSize = 50;  // 默认批量操作限制
        mintFee = 0;        // 默认免费铸造
    }
    
    /**
     * @dev 带版税的铸造函数
     * @param _to 接收者地址
     * @param _tokenURI NFT 元数据 URI
     * @param _royaltyRecipient 版税接收者
     * @param _royaltyPercentage 版税百分比（基点）
     * @return tokenId 新铸造的 NFT ID
     */
    function mintWithRoyalty(
        address _to,
        string memory _tokenURI,
        address _royaltyRecipient,
        uint96 _royaltyPercentage
    ) public payable onlyOwner returns (uint256) {
        require(msg.value >= mintFee, "AuctionNFTV2: insufficient mint fee");
        require(_royaltyPercentage <= 1000, "AuctionNFTV2: royalty too high"); // 最大 10%
        
        uint256 tokenId = mint(_to, _tokenURI);
        
        // 设置版税信息
        if (_royaltyRecipient != address(0) && _royaltyPercentage > 0) {
            royalties[tokenId] = RoyaltyInfo({
                recipient: _royaltyRecipient,
                percentage: _royaltyPercentage
            });
            
            emit RoyaltySet(tokenId, _royaltyRecipient, _royaltyPercentage);
        }
        
        return tokenId;
    }
    
    /**
     * @dev 设置 NFT 版税信息
     * @param _tokenId NFT ID
     * @param _recipient 版税接收者
     * @param _percentage 版税百分比（基点）
     */
    function setRoyalty(
        uint256 _tokenId,
        address _recipient,
        uint96 _percentage
    ) external {
        require(_ownerOf(_tokenId) != address(0), "AuctionNFTV2: token does not exist");
        require(
            msg.sender == ownerOf(_tokenId) || msg.sender == owner(),
            "AuctionNFTV2: not authorized"
        );
        require(_percentage <= 1000, "AuctionNFTV2: royalty too high");
        
        royalties[_tokenId] = RoyaltyInfo({
            recipient: _recipient,
            percentage: _percentage
        });
        
        emit RoyaltySet(_tokenId, _recipient, _percentage);
    }
    
    /**
     * @dev 获取 NFT 版税信息
     * @param _tokenId NFT ID
     * @param _salePrice 销售价格
     * @return receiver 版税接收者
     * @return royaltyAmount 版税金额
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = royalties[_tokenId];
        if (royalty.recipient == address(0)) {
            return (address(0), 0);
        }
        
        royaltyAmount = (_salePrice * royalty.percentage) / 10000;
        return (royalty.recipient, royaltyAmount);
    }
    
    /**
     * @dev 设置 NFT 扩展元数据
     * @param _tokenId NFT ID
     * @param _description 描述
     * @param _externalUrl 外部链接
     * @param _animationUrl 动画链接
     */
    function setMetadataExtension(
        uint256 _tokenId,
        string memory _description,
        string memory _externalUrl,
        string memory _animationUrl
    ) external {
        require(_ownerOf(_tokenId) != address(0), "AuctionNFTV2: token does not exist");
        require(
            msg.sender == ownerOf(_tokenId) || msg.sender == owner(),
            "AuctionNFTV2: not authorized"
        );
        
        metadataExtensions[_tokenId] = MetadataExtension({
            description: _description,
            externalUrl: _externalUrl,
            animationUrl: _animationUrl,
            createdAt: block.timestamp
        });
        
        emit MetadataExtensionSet(_tokenId, _description, _externalUrl);
    }
    
    /**
     * @dev 获取 NFT 扩展元数据
     * @param _tokenId NFT ID
     * @return 扩展元数据结构体
     */
    function getMetadataExtension(uint256 _tokenId)
        external
        view
        returns (MetadataExtension memory)
    {
        return metadataExtensions[_tokenId];
    }
    
    /**
     * @dev 设置铸造费用（仅合约拥有者）
     * @param _mintFee 新的铸造费用
     */
    function setMintFee(uint256 _mintFee) external onlyOwner {
        uint256 oldFee = mintFee;
        mintFee = _mintFee;
        emit MintFeeUpdated(oldFee, _mintFee);
    }
    
    /**
     * @dev 设置批量操作限制（仅合约拥有者）
     * @param _maxBatchSize 新的批量限制
     */
    function setMaxBatchSize(uint256 _maxBatchSize) external onlyOwner {
        require(_maxBatchSize > 0, "AuctionNFTV2: invalid batch size");
        uint256 oldSize = maxBatchSize;
        maxBatchSize = _maxBatchSize;
        emit BatchSizeUpdated(oldSize, _maxBatchSize);
    }
    
    /**
     * @dev 增强版批量铸造（带费用检查）
     * @param _to 接收者地址
     * @param _tokenURIs NFT 元数据 URI 数组
     * @return tokenIds 新铸造的 NFT ID 数组
     */
    function batchMintV2(address _to, string[] memory _tokenURIs)
        public
        payable
        onlyOwner
        returns (uint256[] memory)
    {
        require(_tokenURIs.length <= maxBatchSize, "AuctionNFTV2: batch size too large");
        require(msg.value >= mintFee * _tokenURIs.length, "AuctionNFTV2: insufficient mint fee");
        
        return batchMint(_to, _tokenURIs);
    }
    
    /**
     * @dev 提取合约中的 ETH（仅合约拥有者）
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "AuctionNFTV2: no funds to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev 检查是否支持特定接口（EIP-165）
     * @param interfaceId 接口 ID
     * @return 是否支持
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        // EIP-2981 NFT Royalty Standard
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev 获取合约版本信息
     * @return 版本字符串
     */
    function getVersion() external pure returns (string memory) {
        return VERSION;
    }
    
    /**
     * @dev 获取升级历史信息
     * @return 升级信息数组
     */
    function getUpgradeHistory() external pure returns (string[] memory) {
        string[] memory history = new string[](2);
        history[0] = "V1.0.0: Initial implementation with basic NFT functionality";
        history[1] = "V2.0.0: Added royalty support, metadata extensions, and mint fees";
        return history;
    }
}
