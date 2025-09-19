// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AuctionNFT
 * @dev 可升级的 ERC721 NFT 合约，支持铸造和拍卖功能
 * 使用 UUPS 代理模式实现合约升级
 */
contract AuctionNFT is 
    Initializable, 
    ERC721Upgradeable, 
    ERC721URIStorageUpgradeable, 
    OwnableUpgradeable, 
    UUPSUpgradeable 
{
    /// @dev NFT 计数器，用于生成唯一的 tokenId
    uint256 private _nextTokenId;
    
    /// @dev 记录每个 NFT 是否正在拍卖中
    mapping(uint256 => bool) public isTokenInAuction;
    
    /// @dev 授权的拍卖合约地址映射
    mapping(address => bool) public authorizedAuctions;

    // 事件定义
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event AuctionAuthorized(address indexed auction, bool authorized);
    event TokenAuctionStatusChanged(uint256 indexed tokenId, bool inAuction);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param _name NFT 集合名称
     * @param _symbol NFT 集合符号
     * @param _owner 合约拥有者地址
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _owner
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721URIStorage_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        _nextTokenId = 1; // 从 1 开始计数
    }

    /**
     * @dev 铸造新的 NFT
     * @param _to 接收者地址
     * @param _tokenURI NFT 元数据 URI
     * @return tokenId 新铸造的 NFT ID
     */
    function mint(address _to, string memory _tokenURI) 
        public 
        onlyOwner 
        returns (uint256) 
    {
        require(_to != address(0), "AuctionNFT: mint to zero address");
        require(bytes(_tokenURI).length > 0, "AuctionNFT: empty token URI");

        uint256 tokenId = _nextTokenId++;
        _mint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        emit NFTMinted(_to, tokenId, _tokenURI);
        return tokenId;
    }

    /**
     * @dev 批量铸造 NFT
     * @param _to 接收者地址
     * @param _tokenURIs NFT 元数据 URI 数组
     * @return tokenIds 新铸造的 NFT ID 数组
     */
    function batchMint(address _to, string[] memory _tokenURIs) 
        public 
        onlyOwner 
        returns (uint256[] memory) 
    {
        require(_to != address(0), "AuctionNFT: mint to zero address");
        require(_tokenURIs.length > 0, "AuctionNFT: empty token URIs array");
        require(_tokenURIs.length <= 20, "AuctionNFT: batch size too large");

        uint256[] memory tokenIds = new uint256[](_tokenURIs.length);
        
        for (uint256 i = 0; i < _tokenURIs.length; i++) {
            require(bytes(_tokenURIs[i]).length > 0, "AuctionNFT: empty token URI");
            
            uint256 tokenId = _nextTokenId++;
            _mint(_to, tokenId);
            _setTokenURI(tokenId, _tokenURIs[i]);
            tokenIds[i] = tokenId;
            
            emit NFTMinted(_to, tokenId, _tokenURIs[i]);
        }
        
        return tokenIds;
    }

    /**
     * @dev 授权拍卖合约
     * @param _auction 拍卖合约地址
     * @param _authorized 是否授权
     */
    function setAuctionAuthorization(address _auction, bool _authorized) 
        external 
        onlyOwner 
    {
        require(_auction != address(0), "AuctionNFT: zero address");
        authorizedAuctions[_auction] = _authorized;
        emit AuctionAuthorized(_auction, _authorized);
    }

    /**
     * @dev 设置 NFT 拍卖状态（仅授权的拍卖合约可调用）
     * @param _tokenId NFT ID
     * @param _inAuction 是否在拍卖中
     */
    function setTokenAuctionStatus(uint256 _tokenId, bool _inAuction) 
        external 
    {
        require(authorizedAuctions[msg.sender], "AuctionNFT: unauthorized caller");
        require(_ownerOf(_tokenId) != address(0), "AuctionNFT: token does not exist");
        
        isTokenInAuction[_tokenId] = _inAuction;
        emit TokenAuctionStatusChanged(_tokenId, _inAuction);
    }

    /**
     * @dev 检查 NFT 是否可以转移（不在拍卖中）
     * @param _tokenId NFT ID
     */
    function _requireNotInAuction(uint256 _tokenId) internal view {
        require(!isTokenInAuction[_tokenId], "AuctionNFT: token is in auction");
    }

    /**
     * @dev 重写转移函数，确保拍卖中的 NFT 不能被转移
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        
        // 如果不是铸造操作，检查是否在拍卖中
        if (from != address(0)) {
            _requireNotInAuction(tokenId);
        }
        
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev 获取下一个 token ID
     * @return 下一个将要铸造的 token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev 获取已铸造的 NFT 总数
     * @return 已铸造的 NFT 总数
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    /**
     * @dev 检查 NFT 是否存在
     * @param _tokenId NFT ID
     * @return 是否存在
     */
    function exists(uint256 _tokenId) external view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    // 重写必要的函数以支持多重继承
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
