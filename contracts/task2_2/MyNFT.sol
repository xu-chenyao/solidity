// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyNFT
 * @dev 符合ERC721标准的NFT合约，支持图文并茂的NFT铸造
 * 
 * 主要功能：
 * - 铸造NFT并关联IPFS元数据
 * - 支持批量铸造
 * - 所有者权限管理
 * - 查询NFT详细信息
 */
contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    // NFT计数器，用于生成唯一的tokenId
    uint256 private _nextTokenId;
    
    // 记录每个NFT的铸造时间
    mapping(uint256 => uint256) public mintTimestamp;
    
    // 记录每个NFT的铸造者
    mapping(uint256 => address) public minter;
    
    // 事件：NFT铸造成功
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        string tokenURI,
        uint256 timestamp
    );
    
    /**
     * @dev 构造函数
     * @param name NFT集合的名称
     * @param symbol NFT集合的符号
     */
    constructor(string memory name, string memory symbol) 
        ERC721(name, symbol) 
        Ownable(msg.sender)
    {
        // 从tokenId 1开始，0通常保留
        _nextTokenId = 1;
    }
    
    /**
     * @dev 铸造NFT函数
     * @param recipient NFT接收者地址
     * @param uri NFT元数据的IPFS链接（JSON格式）
     * @return tokenId 新铸造的NFT的ID
     * 
     * tokenURI应该指向一个JSON文件，包含以下结构：
     * {
     *   "name": "NFT名称",
     *   "description": "NFT描述",
     *   "image": "IPFS图片链接",
     *   "attributes": [...]
     * }
     */
    function mintNFT(address recipient, string memory uri) 
        public 
        onlyOwner 
        returns (uint256) 
    {
        require(recipient != address(0), "MyNFT: recipient cannot be zero address");
        require(bytes(uri).length > 0, "MyNFT: tokenURI cannot be empty");
        
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        
        // 铸造NFT
        _safeMint(recipient, tokenId);
        
        // 设置元数据URI
        _setTokenURI(tokenId, uri);
        
        // 记录铸造信息
        mintTimestamp[tokenId] = block.timestamp;
        minter[tokenId] = msg.sender;
        
        // 触发事件
        emit NFTMinted(tokenId, recipient, uri, block.timestamp);
        
        return tokenId;
    }
    
    /**
     * @dev 批量铸造NFT
     * @param recipients NFT接收者地址数组
     * @param tokenURIs NFT元数据IPFS链接数组
     * @return tokenIds 新铸造的NFT ID数组
     */
    function batchMintNFT(
        address[] memory recipients, 
        string[] memory tokenURIs
    ) 
        public 
        onlyOwner 
        returns (uint256[] memory) 
    {
        require(recipients.length == tokenURIs.length, "MyNFT: arrays length mismatch");
        require(recipients.length > 0, "MyNFT: empty arrays");
        
        uint256[] memory tokenIds = new uint256[](recipients.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            tokenIds[i] = mintNFT(recipients[i], tokenURIs[i]);
        }
        
        return tokenIds;
    }
    
    /**
     * @dev 获取当前NFT总供应量
     * @return 已铸造的NFT数量
     */
    function totalSupply() public view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    /**
     * @dev 获取NFT的详细信息
     * @param tokenId NFT的ID
     * @return owner NFT所有者地址
     * @return uri NFT元数据链接
     * @return mintTime 铸造时间戳
     * @return minterAddress 铸造者地址
     */
    function getNFTInfo(uint256 tokenId) 
        public 
        view 
        returns (
            address owner,
            string memory uri,
            uint256 mintTime,
            address minterAddress
        ) 
    {
        require(_ownerOf(tokenId) != address(0), "MyNFT: token does not exist");
        
        return (
            ownerOf(tokenId),
            super.tokenURI(tokenId),
            mintTimestamp[tokenId],
            minter[tokenId]
        );
    }
    
    /**
     * @dev 检查地址是否拥有NFT
     * @param owner 要检查的地址
     * @return 该地址拥有的NFT数量
     */
    function balanceOf(address owner) public view override(ERC721, IERC721) returns (uint256) {
        require(owner != address(0), "MyNFT: address zero is not a valid owner");
        return super.balanceOf(owner);
    }
    
    /**
     * @dev 销毁NFT函数
     * @param tokenId 要销毁的NFT的ID
     * 
     * 注意：销毁后的NFT将永远无法恢复
     * 只有NFT所有者或合约所有者可以销毁NFT
     */
    function burnNFT(uint256 tokenId) public {
        require(_ownerOf(tokenId) != address(0), "MyNFT: token does not exist");
        
        address tokenOwner = _ownerOf(tokenId);
        require(
            msg.sender == tokenOwner || msg.sender == owner(),
            "MyNFT: caller is not owner nor approved"
        );
        
        // 清除铸造记录（可选，节省gas）
        delete mintTimestamp[tokenId];
        delete minter[tokenId];
        
        // 销毁NFT
        _burn(tokenId);
        
        // 触发销毁事件
        emit NFTBurned(tokenId, tokenOwner, msg.sender, block.timestamp);
    }
    
    /**
     * @dev 批量销毁NFT
     * @param tokenIds 要销毁的NFT ID数组
     */
    function batchBurnNFT(uint256[] memory tokenIds) public {
        require(tokenIds.length > 0, "MyNFT: empty tokenIds array");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            burnNFT(tokenIds[i]);
        }
    }
    
    // 销毁事件
    event NFTBurned(
        uint256 indexed tokenId,
        address indexed previousOwner,
        address indexed burner,
        uint256 timestamp
    );
    
    // 重写必要的函数以支持ERC721URIStorage
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
