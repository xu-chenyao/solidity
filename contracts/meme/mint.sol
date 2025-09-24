// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入OpenZeppelin标准合约
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";           // ERC721 NFT标准实现
import "@openzeppelin/contracts/access/Ownable.sol";               // 所有权管理合约
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; // Merkle树证明验证
import "@openzeppelin/contracts/utils/Strings.sol";                // 字符串工具库

/**
 * @title 高级NFT铸造系统
 * @dev 基于ERC721标准的高级NFT合约，具有以下特性：
 *      - 标准ERC721功能（NFT转账、授权等）
 *      - 动态铸造权限管理（白名单 + 管理员授权）
 *      - Merkle树白名单验证（gas高效的大规模白名单）
 *      - 防女巫攻击机制（限制每个地址铸造数量）
 *      - 动态元数据生成（支持链上属性修改）
 *      - 付费铸造机制（防止垃圾铸造）
 *      - 所有权管理（管理员功能）
 * @notice 这是一个功能完整的NFT铸造系统，适合各种NFT项目使用
 */
contract AdvancedMintingSystem is ERC721, Ownable {
    
    // ========== 代币计数器 ==========
    
    /// @dev NFT代币ID计数器，用于生成唯一的tokenId
    /// @notice 从0开始递增，每次铸造后自动增加1
    uint256 private _tokenIdCounter;
    
    // ========== 动态铸造权限管理 ==========
    
    /// @dev 铸造权限映射表，记录哪些地址有直接铸造权限
    /// @notice 管理员可以授权特定地址进行铸造，无需Merkle证明
    mapping(address => bool) private _minters;
    
    /// @notice Merkle树根哈希，用于白名单验证
    /// @dev 支持大规模白名单的gas高效验证方案
    bytes32 public merkleRoot;
    
    // ========== 防女巫攻击机制 ==========
    
    /// @dev 记录每个地址已铸造的NFT数量
    /// @notice 用于限制单个地址的铸造次数，防止女巫攻击
    mapping(address => uint256) private _mintedCount;
    
    /// @notice 每个地址允许铸造的最大NFT数量
    /// @dev 默认为1，管理员可以调整
    uint256 public maxMintPerAddress = 1;
    
    // ========== 动态元数据系统 ==========
    
    /// @dev NFT基础URI，用于构建完整的tokenURI
    /// @notice 管理员可以更新，支持元数据迁移
    string private _baseTokenURI;
    
    /// @dev NFT属性映射表，记录每个tokenId的自定义属性
    /// @notice 支持为每个NFT设置独特的属性字符串
    mapping(uint256 => string) private _tokenAttributes;
    
    // ========== 经济模型 ==========
    
    /// @notice NFT铸造价格（以wei为单位）
    /// @dev 默认0.05 ETH，可以防止垃圾铸造和提供项目收入
    uint256 public mintPrice = 0.05 ether;
    
    // ========== 事件定义 ==========
    
    /// @notice 当铸造权限更新时触发
    /// @param minter 被授权/取消授权的地址
    /// @param allowed 是否被授权（true=授权，false=取消授权）
    event MintPermissionUpdated(address indexed minter, bool allowed);
    
    /// @notice 当Merkle根更新时触发
    /// @param newRoot 新的Merkle树根哈希
    event MerkleRootUpdated(bytes32 newRoot);
    
    /// @notice 当NFT元数据更新时触发
    /// @param tokenId 被更新的NFT ID
    /// @param attributes 新的属性字符串
    event MetadataUpdated(uint256 tokenId, string attributes);
    
    /**
     * @notice 高级NFT铸造系统构造函数
     * @dev 初始化ERC721合约和所有权管理
     * @param name NFT集合名称（如："Awesome NFTs"）
     * @param symbol NFT集合符号（如："ANFT"）
     * 
     * 构造函数执行流程：
     * 1. 调用ERC721构造函数设置NFT基本信息
     * 2. 调用Ownable构造函数设置部署者为owner
     * 3. 初始化所有状态变量为默认值
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}
    
    // ========== 动态铸造权限管理 ==========
    
    /**
     * @notice 设置Merkle树根哈希用于白名单验证
     * @dev 只有合约owner可以调用此函数
     * @param root 新的Merkle树根哈希
     * 
     * 功能说明：
     * - Merkle树是一种高效的白名单验证方案
     * - 可以支持数万个地址的白名单，而gas消耗很低
     * - 用户需要提供Merkle证明来验证自己在白名单中
     * - 管理员可以随时更新白名单（更新根哈希）
     */
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;                    // 更新Merkle树根哈希
        emit MerkleRootUpdated(root);         // 触发事件通知
    }
    
    /**
     * @notice 添加或移除地址的直接铸造权限
     * @dev 只有合约owner可以调用此函数
     * @param minter 要操作的地址
     * @param allowed true表示授权，false表示取消授权
     * 
     * 功能说明：
     * - 被授权的地址可以直接铸造，无需Merkle证明
     * - 适用于合作伙伴、团队成员等特殊地址
     * - 可以与Merkle白名单同时使用
     * - 管理员可以随时调整权限
     */
    function setMinter(address minter, bool allowed) external onlyOwner {
        _minters[minter] = allowed;                    // 更新铸造权限
        emit MintPermissionUpdated(minter, allowed);   // 触发事件通知
    }
    
    /**
     * @notice 验证调用者是否有铸造权限的修饰符
     * @dev 检查直接授权或Merkle证明验证
     * @param proof Merkle证明数组（如果有直接权限可以传空数组）
     * 
     * 验证逻辑：
     * 1. 检查调用者是否有直接铸造权限
     * 2. 如果没有直接权限，验证Merkle证明
     * 3. 两个条件满足其一即可通过验证
     */
    modifier onlyMinter(bytes32[] calldata proof) {
        require(
            _minters[msg.sender] ||   // 检查直接铸造权限
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender))), // 验证Merkle证明
            "Caller is not allowed to mint"  // 权限验证失败
        );
        _;  // 继续执行函数体
    }
    
    // ========== 防女巫攻击机制 ==========
    
    /**
     * @notice 设置每个地址允许铸造的最大NFT数量
     * @dev 只有合约owner可以调用此函数
     * @param max 新的最大铸造数量限制
     * 
     * 功能说明：
     * - 防止单个用户铸造过多NFT（防止女巫攻击）
     * - 可以根据项目需要动态调整限制
     * - 设置为0可以禁止所有铸造操作
     * - 适用于不同阶段的铸造策略
     */
    function setMaxMintPerAddress(uint256 max) external onlyOwner {
        maxMintPerAddress = max;  // 更新最大铸造数量限制
    }
    
    /**
     * @notice 检查调用者是否超过铸造数量限制的修饰符
     * @dev 在函数执行前检查，执行后增加计数
     * 
     * 检查逻辑：
     * 1. 验证当前已铸造数量是否小于最大限制
     * 2. 执行被修饰的函数
     * 3. 增加调用者的已铸造计数
     * 
     * 安全特性：
     * - 防止单个地址超量铸造
     * - 支持公平分配机制
     * - 防止机器人批量铸造
     */
    modifier checkMintLimit() {
        // 检查是否超过最大铸造数量限制
        require(
            _mintedCount[msg.sender] < maxMintPerAddress,
            "Exceeds maximum mint limit per address"
        );
        _;  // 执行被修饰的函数
        _mintedCount[msg.sender]++;  // 增加已铸造计数
    }
    
    // ========== 动态元数据管理系统 ==========
    
    /**
     * @notice 设置NFT元数据的基础URI
     * @dev 只有合约owner可以调用此函数
     * @param baseURI 新的基础URI地址（如："https://api.example.com/metadata/"）
     * 
     * 功能说明：
     * - 用于构建完整的NFT元数据URI
     * - 支持元数据迁移和更新
     * - 可以在项目不同阶段切换元数据存储方案
     * - 支持IPFS、中心化服务器等多种存储方式
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;  // 更新基础URI
    }
    
    /**
     * @notice 设置指定NFT的自定义属性
     * @dev 只有NFT所有者或被授权者可以调用
     * @param tokenId 要设置属性的NFT ID
     * @param attributes 属性字符串（可以是JSON、查询参数等格式）
     * 
     * 功能说明：
     * - 支持为每个NFT设置独特的属性
     * - 可扩展为链上或链下元数据生成
     * - 支持动态更新NFT属性
     * - 可用于游戏道具升级、成就系统等
     * 
     * 权限检查：
     * - 验证调用者是NFT所有者或被授权者
     * - 使用OpenZeppelin v5.0+的_isAuthorized函数
     */
    function setTokenAttributes(uint256 tokenId, string calldata attributes) external {
        // 检查调用者是否有权限修改此NFT的属性
        require(_isAuthorized(ownerOf(tokenId), msg.sender, tokenId), "Not owner nor approved");
        
        // 更新NFT属性
        _tokenAttributes[tokenId] = attributes;
        
        // 触发元数据更新事件
        emit MetadataUpdated(tokenId, attributes);
    }
    
    /**
     * @notice 获取指定NFT的元数据URI（重写ERC721标准函数）
     * @dev 实现动态元数据生成，支持自定义属性
     * @param tokenId 要查询的NFT ID
     * @return 完整的元数据URI字符串
     * 
     * URI构建逻辑：
     * 1. 验证NFT存在性
     * 2. 获取基础URI和自定义属性
     * 3. 如果有自定义属性，将其作为查询参数附加
     * 4. 返回完整的URI地址
     * 
     * URI格式示例：
     * - 无属性："https://api.example.com/metadata/1"
     * - 有属性："https://api.example.com/metadata/1?attributes=level:5,rarity:epic"
     * 
     * 特性优势：
     * - 支持动态元数据更新
     * - 兼容标准NFT市场和钱包
     * - 灵活的属性系统
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // 验证NFT存在性（OpenZeppelin v5.0+的新方法）
        _requireOwned(tokenId);
        
        // 获取基础URI（从内部函数获取）
        string memory baseURI = _baseURI();
        
        // 获取此NFT的自定义属性
        string memory attributes = _tokenAttributes[tokenId];
        
        // 如果有自定义属性，将其作为查询参数附加到URI中
        if(bytes(attributes).length > 0) {
            return string(abi.encodePacked(
                baseURI, 
                Strings.toString(tokenId), 
                "?attributes=", 
                attributes
            ));
        }
        
        // 没有自定义属性，返回标准URI
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }
    
    /**
     * @notice 获取NFT元数据的基础URI（内部函数）
     * @dev 重写ERC721的_baseURI函数，返回管理员设置的基础URI
     * @return 基础URI字符串
     * 
     * 功能说明：
     * - 为tokenURI函数提供基础URI
     * - 支持动态更新元数据存储位置
     * - 可以指向IPFS、中心化服务器等不同存储方案
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;  // 返回管理员设置的基础URI
    }
    
    // ========== 铸造功能 ==========
    
    /**
     * @notice 公开NFT铸造函数
     * @dev 用户可以通过此函数铸造NFT，需要满足权限和支付要求
     * @param proof Merkle证明数组（如果有直接权限可传空数组）
     * @param initialAttributes NFT的初始属性字符串（可选）
     * 
     * 铸造条件：
     * 1. 权限验证：必须有直接铸造权限或提供有效的Merkle证明
     * 2. 数量限制：不能超过每个地址的最大铸造数量
     * 3. 支付要求：必须支付足够的ETH作为铸造费用
     * 
     * 铸造流程：
     * 1. 验证调用者权限（onlyMinter修饰符）
     * 2. 检查铸造数量限制（checkMintLimit修饰符）
     * 3. 验证支付金额
     * 4. 生成新的tokenId并铸造NFT
     * 5. 设置初始属性（如果提供）
     * 
     * @notice 此函数需要支付mintPrice数量的ETH
     * @notice 每个地址只能铸造maxMintPerAddress个NFT
     */
    function mint(bytes32[] calldata proof, string calldata initialAttributes) 
        external 
        payable 
        onlyMinter(proof)      // 验证铸造权限
        checkMintLimit         // 检查数量限制
    {
        // 验证支付金额是否足够
        require(msg.value >= mintPrice, "Insufficient payment");
        
        // 生成新的tokenId
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;  // 递增计数器
        
        // 安全铸造NFT给调用者
        _safeMint(msg.sender, tokenId);
        
        // 如果提供了初始属性，则设置
        if(bytes(initialAttributes).length > 0) {
            _tokenAttributes[tokenId] = initialAttributes;
        }
    }
    
    // ========== 资金管理 ==========

    /**
     * @notice 提取合约中的所有ETH资金
     * @dev 只有合约owner可以调用此函数
     * 
     * 功能说明：
     * - 将合约中的所有ETH转账给合约所有者
     * - 用于提取铸造费用和其他收入
     * - 使用transfer方法确保安全性
     * 
     * 安全考量：
     * - 只有owner可以调用，防止资金被盗
     * - 使用transfer而非call，限制gas防止重入攻击
     * - 建议定期提取资金以降低风险
     * 
     * 注意事项：
     * - 确保接收地址能够接收ETH
     * - 考虑使用多签钱包作为owner增强安全性
     */
    function withdraw() external onlyOwner {
        // 将合约中的所有ETH转账给合约所有者
        payable(owner()).transfer(address(this).balance);
    }
}