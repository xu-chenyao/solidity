// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NFTAuction.sol";
import "./IPriceOracle.sol";

/**
 * @title AuctionFactory
 * @dev 拍卖工厂合约，使用类似 Uniswap V2 的工厂模式管理拍卖
 * 支持创建、管理和查询拍卖合约实例
 */
contract AuctionFactory is 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    /// @dev 拍卖状态统计结构体
    struct AuctionStats {
        uint256 totalAuctions;      // 总拍卖数量
        uint256 activeAuctions;     // 活跃拍卖数量
        uint256 endedAuctions;      // 已结束拍卖数量
        uint256 cancelledAuctions;  // 已取消拍卖数量
    }

    /// @dev 拍卖摘要信息结构体
    struct AuctionSummary {
        uint256 auctionId;          // 拍卖 ID
        address auctionContract;    // 拍卖合约地址
        address seller;             // 卖家地址
        address nftContract;        // NFT 合约地址
        uint256 tokenId;            // NFT ID
        uint256 startingPrice;      // 起拍价（美元）
        uint256 reservePrice;       // 保留价（美元）
        uint256 startTime;          // 开始时间
        uint256 endTime;            // 结束时间
        uint256 currentHighestBid;  // 当前最高出价（美元）
        address currentHighestBidder; // 当前最高出价者
        NFTAuction.AuctionStatus status; // 拍卖状态
    }

    /// @dev 拍卖 ID 计数器
    uint256 public nextAuctionId;

    /// @dev 拍卖 ID 到拍卖合约地址的映射
    mapping(uint256 => address) public auctions;

    /// @dev NFT 合约和 token ID 到拍卖 ID 的映射
    mapping(address => mapping(uint256 => uint256)) public nftToAuction;

    /// @dev 用户创建的拍卖列表
    mapping(address => uint256[]) public userAuctions;

    /// @dev 所有拍卖 ID 列表
    uint256[] public allAuctions;

    /// @dev 价格预言机合约
    IPriceOracle public priceOracle;

    /// @dev 平台费用接收地址
    address public feeRecipient;

    /// @dev 最小拍卖持续时间（秒）
    uint256 public minAuctionDuration;

    /// @dev 最大拍卖持续时间（秒）
    uint256 public maxAuctionDuration;

    /// @dev 最小起拍价（美元，8位小数）
    uint256 public minStartingPrice;

    // 事件定义
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed auctionContract,
        address indexed seller,
        address nftContract,
        uint256 tokenId
    );
    
    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event AuctionParametersUpdated(
        uint256 minDuration,
        uint256 maxDuration,
        uint256 minStartingPrice
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数
     * @param _priceOracle 价格预言机地址
     * @param _feeRecipient 平台费用接收地址
     * @param _owner 合约拥有者地址
     */
    function initialize(
        address _priceOracle,
        address _feeRecipient,
        address _owner
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_priceOracle != address(0), "AuctionFactory: zero oracle address");
        require(_feeRecipient != address(0), "AuctionFactory: zero fee recipient");

        priceOracle = IPriceOracle(_priceOracle);
        feeRecipient = _feeRecipient;
        nextAuctionId = 1;

        // 设置默认参数
        minAuctionDuration = 1 hours;       // 最小 1 小时
        maxAuctionDuration = 7 days;        // 最大 7 天
        minStartingPrice = 1 * 10**8;       // 最小 1 美元
    }

    /**
     * @dev 创建新的拍卖
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT ID
     * @param _startingPrice 起拍价（美元，8位小数）
     * @param _reservePrice 保留价（美元，8位小数）
     * @param _duration 拍卖持续时间（秒）
     * @param _bidIncrement 最小加价幅度（美元，8位小数）
     * @return auctionId 新创建的拍卖 ID
     */
    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _bidIncrement
    ) external nonReentrant returns (uint256) {
        require(_nftContract != address(0), "AuctionFactory: zero NFT contract");
        require(_startingPrice >= minStartingPrice, "AuctionFactory: starting price too low");
        require(_reservePrice >= _startingPrice, "AuctionFactory: invalid reserve price");
        require(_duration >= minAuctionDuration, "AuctionFactory: duration too short");
        require(_duration <= maxAuctionDuration, "AuctionFactory: duration too long");
        require(_bidIncrement > 0, "AuctionFactory: zero bid increment");

        // 验证 NFT 所有权
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "AuctionFactory: not NFT owner");
        
        // 检查 NFT 是否已在拍卖中
        require(nftToAuction[_nftContract][_tokenId] == 0, "AuctionFactory: NFT already in auction");

        // 验证 NFT 已授权给工厂合约
        require(
            IERC721(_nftContract).isApprovedForAll(msg.sender, address(this)) ||
            IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "AuctionFactory: NFT not approved"
        );

        uint256 auctionId = nextAuctionId++;

        // 创建拍卖合约
        NFTAuction auction = new NFTAuction(
            auctionId,
            msg.sender,
            _nftContract,
            _tokenId,
            _startingPrice,
            _reservePrice,
            _duration,
            _bidIncrement,
            address(priceOracle),
            feeRecipient
        );

        // 将 NFT 转移到拍卖合约
        IERC721(_nftContract).safeTransferFrom(msg.sender, address(auction), _tokenId);

        // 记录拍卖信息
        auctions[auctionId] = address(auction);
        nftToAuction[_nftContract][_tokenId] = auctionId;
        userAuctions[msg.sender].push(auctionId);
        allAuctions.push(auctionId);

        emit AuctionCreated(auctionId, address(auction), msg.sender, _nftContract, _tokenId);

        return auctionId;
    }

    /**
     * @dev 批量创建拍卖
     * @param _nftContract NFT 合约地址
     * @param _tokenIds NFT ID 数组
     * @param _startingPrice 起拍价（美元，8位小数）
     * @param _reservePrice 保留价（美元，8位小数）
     * @param _duration 拍卖持续时间（秒）
     * @param _bidIncrement 最小加价幅度（美元，8位小数）
     * @return auctionIds 新创建的拍卖 ID 数组
     */
    function createBatchAuctions(
        address _nftContract,
        uint256[] memory _tokenIds,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _bidIncrement
    ) external nonReentrant returns (uint256[] memory) {
        require(_tokenIds.length > 0, "AuctionFactory: empty token IDs");
        require(_tokenIds.length <= 10, "AuctionFactory: batch size too large");

        uint256[] memory auctionIds = new uint256[](_tokenIds.length);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // 验证每个 NFT
            require(IERC721(_nftContract).ownerOf(_tokenIds[i]) == msg.sender, "AuctionFactory: not NFT owner");
            require(nftToAuction[_nftContract][_tokenIds[i]] == 0, "AuctionFactory: NFT already in auction");

            uint256 auctionId = nextAuctionId++;

            // 创建拍卖合约
            NFTAuction auction = new NFTAuction(
                auctionId,
                msg.sender,
                _nftContract,
                _tokenIds[i],
                _startingPrice,
                _reservePrice,
                _duration,
                _bidIncrement,
                address(priceOracle),
                feeRecipient
            );

            // 将 NFT 转移到拍卖合约
            IERC721(_nftContract).safeTransferFrom(msg.sender, address(auction), _tokenIds[i]);

            // 记录拍卖信息
            auctions[auctionId] = address(auction);
            nftToAuction[_nftContract][_tokenIds[i]] = auctionId;
            userAuctions[msg.sender].push(auctionId);
            allAuctions.push(auctionId);
            auctionIds[i] = auctionId;

            emit AuctionCreated(auctionId, address(auction), msg.sender, _nftContract, _tokenIds[i]);
        }

        return auctionIds;
    }

    /**
     * @dev 获取拍卖合约地址
     * @param _auctionId 拍卖 ID
     * @return 拍卖合约地址
     */
    function getAuction(uint256 _auctionId) external view returns (address) {
        return auctions[_auctionId];
    }

    /**
     * @dev 获取 NFT 对应的拍卖 ID
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT ID
     * @return 拍卖 ID（0 表示不存在）
     */
    function getAuctionByNFT(address _nftContract, uint256 _tokenId) external view returns (uint256) {
        return nftToAuction[_nftContract][_tokenId];
    }

    /**
     * @dev 获取用户创建的拍卖列表
     * @param _user 用户地址
     * @return 拍卖 ID 数组
     */
    function getUserAuctions(address _user) external view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    /**
     * @dev 获取所有拍卖 ID
     * @return 拍卖 ID 数组
     */
    function getAllAuctions() external view returns (uint256[] memory) {
        return allAuctions;
    }

    /**
     * @dev 获取拍卖统计信息
     * @return 拍卖统计结构体
     */
    function getAuctionStats() external view returns (AuctionStats memory) {
        uint256 active = 0;
        uint256 ended = 0;
        uint256 cancelled = 0;

        for (uint256 i = 0; i < allAuctions.length; i++) {
            address auctionContract = auctions[allAuctions[i]];
            if (auctionContract != address(0)) {
                NFTAuction.AuctionInfo memory info = NFTAuction(payable(auctionContract)).getAuctionInfo();
                
                if (info.status == NFTAuction.AuctionStatus.Active) {
                    active++;
                } else if (info.status == NFTAuction.AuctionStatus.Ended) {
                    ended++;
                } else if (info.status == NFTAuction.AuctionStatus.Cancelled) {
                    cancelled++;
                }
            }
        }

        return AuctionStats({
            totalAuctions: allAuctions.length,
            activeAuctions: active,
            endedAuctions: ended,
            cancelledAuctions: cancelled
        });
    }

    /**
     * @dev 获取拍卖摘要信息
     * @param _auctionId 拍卖 ID
     * @return 拍卖摘要结构体
     */
    function getAuctionSummary(uint256 _auctionId) external view returns (AuctionSummary memory) {
        address auctionContract = auctions[_auctionId];
        require(auctionContract != address(0), "AuctionFactory: auction not found");

        NFTAuction auction = NFTAuction(payable(auctionContract));
        NFTAuction.AuctionInfo memory info = auction.getAuctionInfo();
        
        (address bidder, , uint256 usdValue, , ) = auction.getHighestBid();

        return AuctionSummary({
            auctionId: _auctionId,
            auctionContract: auctionContract,
            seller: info.seller,
            nftContract: info.nftContract,
            tokenId: info.tokenId,
            startingPrice: info.startingPrice,
            reservePrice: info.reservePrice,
            startTime: info.startTime,
            endTime: info.endTime,
            currentHighestBid: usdValue,
            currentHighestBidder: bidder,
            status: info.status
        });
    }

    /**
     * @dev 获取多个拍卖的摘要信息
     * @param _auctionIds 拍卖 ID 数组
     * @return 拍卖摘要数组
     */
    function getBatchAuctionSummaries(uint256[] memory _auctionIds) 
        external 
        view 
        returns (AuctionSummary[] memory) 
    {
        AuctionSummary[] memory summaries = new AuctionSummary[](_auctionIds.length);
        
        for (uint256 i = 0; i < _auctionIds.length; i++) {
            address auctionContract = auctions[_auctionIds[i]];
            if (auctionContract != address(0)) {
                summaries[i] = this.getAuctionSummary(_auctionIds[i]);
            }
        }
        
        return summaries;
    }

    /**
     * @dev 获取活跃拍卖列表
     * @param _offset 偏移量
     * @param _limit 限制数量
     * @return 拍卖摘要数组
     */
    function getActiveAuctions(uint256 _offset, uint256 _limit) 
        external 
        view 
        returns (AuctionSummary[] memory) 
    {
        require(_limit > 0 && _limit <= 100, "AuctionFactory: invalid limit");

        // 收集活跃拍卖
        uint256[] memory activeAuctionIds = new uint256[](allAuctions.length);
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allAuctions.length; i++) {
            address auctionContract = auctions[allAuctions[i]];
            if (auctionContract != address(0)) {
                NFTAuction.AuctionInfo memory info = NFTAuction(payable(auctionContract)).getAuctionInfo();
                if (info.status == NFTAuction.AuctionStatus.Active && block.timestamp <= info.endTime) {
                    activeAuctionIds[activeCount] = allAuctions[i];
                    activeCount++;
                }
            }
        }

        // 计算返回数量
        uint256 start = _offset;
        if (start >= activeCount) {
            return new AuctionSummary[](0);
        }

        uint256 end = start + _limit;
        if (end > activeCount) {
            end = activeCount;
        }

        uint256 resultCount = end - start;
        AuctionSummary[] memory result = new AuctionSummary[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = this.getAuctionSummary(activeAuctionIds[start + i]);
        }

        return result;
    }

    /**
     * @dev 清理已结束的拍卖记录（释放存储空间）
     * @param _auctionId 拍卖 ID
     */
    function cleanupAuction(uint256 _auctionId) external {
        address auctionContract = auctions[_auctionId];
        require(auctionContract != address(0), "AuctionFactory: auction not found");

        NFTAuction.AuctionInfo memory info = NFTAuction(auctionContract).getAuctionInfo();
        require(
            info.status == NFTAuction.AuctionStatus.Ended || 
            info.status == NFTAuction.AuctionStatus.Cancelled,
            "AuctionFactory: auction still active"
        );

        // 清理 NFT 映射
        delete nftToAuction[info.nftContract][info.tokenId];
    }

    /**
     * @dev 设置价格预言机
     * @param _priceOracle 新的价格预言机地址
     */
    function setPriceOracle(address _priceOracle) external onlyOwner {
        require(_priceOracle != address(0), "AuctionFactory: zero address");
        address oldOracle = address(priceOracle);
        priceOracle = IPriceOracle(_priceOracle);
        emit PriceOracleUpdated(oldOracle, _priceOracle);
    }

    /**
     * @dev 设置平台费用接收地址
     * @param _feeRecipient 新的费用接收地址
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "AuctionFactory: zero address");
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    /**
     * @dev 设置拍卖参数
     * @param _minDuration 最小拍卖持续时间
     * @param _maxDuration 最大拍卖持续时间
     * @param _minStartingPrice 最小起拍价
     */
    function setAuctionParameters(
        uint256 _minDuration,
        uint256 _maxDuration,
        uint256 _minStartingPrice
    ) external onlyOwner {
        require(_minDuration > 0, "AuctionFactory: zero min duration");
        require(_maxDuration > _minDuration, "AuctionFactory: invalid max duration");
        require(_minStartingPrice > 0, "AuctionFactory: zero min starting price");

        minAuctionDuration = _minDuration;
        maxAuctionDuration = _maxDuration;
        minStartingPrice = _minStartingPrice;

        emit AuctionParametersUpdated(_minDuration, _maxDuration, _minStartingPrice);
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
