// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IPriceOracle.sol";
import "./AuctionNFT.sol";

/**
 * @title NFTAuction
 * @dev NFT 拍卖合约，支持 ETH 和 ERC20 代币出价
 * 集成价格预言机，将所有出价转换为美元进行比较
 */
contract NFTAuction is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev 拍卖状态枚举
    enum AuctionStatus {
        Active,     // 进行中
        Ended,      // 已结束
        Cancelled   // 已取消
    }

    /// @dev 出价类型枚举
    enum BidType {
        ETH,    // ETH 出价
        ERC20   // ERC20 代币出价
    }

    /// @dev 出价信息结构体
    struct Bid {
        address bidder;         // 出价者地址
        uint256 amount;         // 出价金额（原始代币数量）
        uint256 usdValue;       // 美元价值（8位小数）
        BidType bidType;        // 出价类型
        address token;          // ERC20 代币地址（如果是 ETH 出价则为 0）
        uint256 timestamp;      // 出价时间戳
    }

    /// @dev 拍卖信息结构体
    struct AuctionInfo {
        address seller;         // 卖家地址
        address nftContract;    // NFT 合约地址
        uint256 tokenId;        // NFT ID
        uint256 startingPrice;  // 起拍价（美元，8位小数）
        uint256 reservePrice;   // 保留价（美元，8位小数）
        uint256 startTime;      // 开始时间
        uint256 endTime;        // 结束时间
        uint256 bidIncrement;   // 最小加价幅度（美元，8位小数）
        AuctionStatus status;   // 拍卖状态
        uint256 highestBidIndex; // 最高出价索引
        uint256 totalBids;      // 总出价数量
    }

    /// @dev 拍卖 ID
    uint256 public auctionId;

    /// @dev 拍卖信息
    AuctionInfo public auction;

    /// @dev 所有出价记录
    Bid[] public bids;

    /// @dev 价格预言机合约
    IPriceOracle public priceOracle;

    /// @dev 工厂合约地址
    address public factory;

    /// @dev 平台费率（基点，10000 = 100%）
    uint256 public constant PLATFORM_FEE_RATE = 250; // 2.5%

    /// @dev 平台费用接收地址
    address public feeRecipient;

    // 事件定义
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 usdValue,
        BidType bidType,
        address token
    );
    
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        uint256 usdValue
    );
    
    event AuctionCancelled(uint256 indexed auctionId);
    
    event BidRefunded(
        address indexed bidder,
        uint256 amount,
        BidType bidType,
        address token
    );

    /**
     * @dev 构造函数
     * @param _auctionId 拍卖 ID
     * @param _seller 卖家地址
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT ID
     * @param _startingPrice 起拍价（美元，8位小数）
     * @param _reservePrice 保留价（美元，8位小数）
     * @param _duration 拍卖持续时间（秒）
     * @param _bidIncrement 最小加价幅度（美元，8位小数）
     * @param _priceOracle 价格预言机地址
     * @param _feeRecipient 平台费用接收地址
     */
    constructor(
        uint256 _auctionId,
        address _seller,
        address _nftContract,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _bidIncrement,
        address _priceOracle,
        address _feeRecipient
    ) {
        require(_seller != address(0), "NFTAuction: zero seller address");
        require(_nftContract != address(0), "NFTAuction: zero NFT contract");
        require(_startingPrice > 0, "NFTAuction: zero starting price");
        require(_reservePrice >= _startingPrice, "NFTAuction: invalid reserve price");
        require(_duration > 0, "NFTAuction: zero duration");
        require(_bidIncrement > 0, "NFTAuction: zero bid increment");
        require(_priceOracle != address(0), "NFTAuction: zero oracle address");
        require(_feeRecipient != address(0), "NFTAuction: zero fee recipient");

        // 验证 NFT 所有权
        require(IERC721(_nftContract).ownerOf(_tokenId) == _seller, "NFTAuction: seller not owner");
        
        factory = msg.sender;
        auctionId = _auctionId;
        priceOracle = IPriceOracle(_priceOracle);
        feeRecipient = _feeRecipient;

        auction = AuctionInfo({
            seller: _seller,
            nftContract: _nftContract,
            tokenId: _tokenId,
            startingPrice: _startingPrice,
            reservePrice: _reservePrice,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            bidIncrement: _bidIncrement,
            status: AuctionStatus.Active,
            highestBidIndex: 0,
            totalBids: 0
        });

        // 设置 NFT 为拍卖状态
        AuctionNFT(_nftContract).setTokenAuctionStatus(_tokenId, true);

        emit AuctionCreated(
            _auctionId,
            _seller,
            _nftContract,
            _tokenId,
            _startingPrice,
            _reservePrice,
            block.timestamp,
            block.timestamp + _duration
        );
    }

    /**
     * @dev 使用 ETH 出价
     */
    function bidWithETH() external payable nonReentrant {
        require(msg.value > 0, "NFTAuction: zero ETH amount");
        require(auction.status == AuctionStatus.Active, "NFTAuction: auction not active");
        require(block.timestamp <= auction.endTime, "NFTAuction: auction ended");
        require(msg.sender != auction.seller, "NFTAuction: seller cannot bid");

        // 将 ETH 转换为美元价值
        uint256 usdValue = priceOracle.convertETHToUSD(msg.value);
        require(usdValue >= auction.startingPrice, "NFTAuction: bid below starting price");

        // 检查是否超过当前最高出价
        if (auction.totalBids > 0) {
            uint256 currentHighestUSD = bids[auction.highestBidIndex].usdValue;
            require(usdValue >= currentHighestUSD + auction.bidIncrement, "NFTAuction: bid increment too low");
        }

        // 记录出价
        bids.push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            usdValue: usdValue,
            bidType: BidType.ETH,
            token: address(0),
            timestamp: block.timestamp
        }));

        auction.highestBidIndex = auction.totalBids;
        auction.totalBids++;

        // 如果拍卖即将结束，延长时间（防止狙击）
        if (auction.endTime - block.timestamp < 300) { // 5分钟
            auction.endTime = block.timestamp + 300;
        }

        emit BidPlaced(auctionId, msg.sender, msg.value, usdValue, BidType.ETH, address(0));
    }

    /**
     * @dev 使用 ERC20 代币出价
     * @param _token ERC20 代币地址
     * @param _amount 代币数量
     */
    function bidWithERC20(address _token, uint256 _amount) external nonReentrant {
        require(_token != address(0), "NFTAuction: zero token address");
        require(_amount > 0, "NFTAuction: zero token amount");
        require(auction.status == AuctionStatus.Active, "NFTAuction: auction not active");
        require(block.timestamp <= auction.endTime, "NFTAuction: auction ended");
        require(msg.sender != auction.seller, "NFTAuction: seller cannot bid");

        // 检查价格预言机是否支持该代币
        require(priceOracle.isTokenSupported(_token), "NFTAuction: token not supported");

        // 将代币转换为美元价值
        uint256 usdValue = priceOracle.convertTokenToUSD(_token, _amount);
        require(usdValue >= auction.startingPrice, "NFTAuction: bid below starting price");

        // 检查是否超过当前最高出价
        if (auction.totalBids > 0) {
            uint256 currentHighestUSD = bids[auction.highestBidIndex].usdValue;
            require(usdValue >= currentHighestUSD + auction.bidIncrement, "NFTAuction: bid increment too low");
        }

        // 转移代币到合约
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // 记录出价
        bids.push(Bid({
            bidder: msg.sender,
            amount: _amount,
            usdValue: usdValue,
            bidType: BidType.ERC20,
            token: _token,
            timestamp: block.timestamp
        }));

        auction.highestBidIndex = auction.totalBids;
        auction.totalBids++;

        // 如果拍卖即将结束，延长时间（防止狙击）
        if (auction.endTime - block.timestamp < 300) { // 5分钟
            auction.endTime = block.timestamp + 300;
        }

        emit BidPlaced(auctionId, msg.sender, _amount, usdValue, BidType.ERC20, _token);
    }

    /**
     * @dev 结束拍卖
     */
    function endAuction() external nonReentrant {
        require(auction.status == AuctionStatus.Active, "NFTAuction: auction not active");
        require(
            block.timestamp > auction.endTime || msg.sender == auction.seller,
            "NFTAuction: auction not ended"
        );

        auction.status = AuctionStatus.Ended;

        // 清除 NFT 拍卖状态
        AuctionNFT(auction.nftContract).setTokenAuctionStatus(auction.tokenId, false);

        if (auction.totalBids == 0) {
            // 没有出价，拍卖结束
            emit AuctionEnded(auctionId, address(0), 0, 0);
            return;
        }

        Bid memory winningBid = bids[auction.highestBidIndex];

        // 检查是否达到保留价
        if (winningBid.usdValue < auction.reservePrice) {
            // 未达到保留价，退还所有出价
            _refundAllBids();
            emit AuctionEnded(auctionId, address(0), 0, 0);
            return;
        }

        // 转移 NFT 给获胜者
        IERC721(auction.nftContract).safeTransferFrom(
            auction.seller,
            winningBid.bidder,
            auction.tokenId
        );

        // 计算平台费用
        uint256 platformFee;
        uint256 sellerAmount;

        if (winningBid.bidType == BidType.ETH) {
            platformFee = (winningBid.amount * PLATFORM_FEE_RATE) / 10000;
            sellerAmount = winningBid.amount - platformFee;

            // 转移资金
            payable(feeRecipient).transfer(platformFee);
            payable(auction.seller).transfer(sellerAmount);
        } else {
            platformFee = (winningBid.amount * PLATFORM_FEE_RATE) / 10000;
            sellerAmount = winningBid.amount - platformFee;

            // 转移代币
            IERC20(winningBid.token).safeTransfer(feeRecipient, platformFee);
            IERC20(winningBid.token).safeTransfer(auction.seller, sellerAmount);
        }

        // 退还其他出价
        _refundOtherBids(auction.highestBidIndex);

        emit AuctionEnded(auctionId, winningBid.bidder, winningBid.amount, winningBid.usdValue);
    }

    /**
     * @dev 取消拍卖（仅卖家在没有出价时可调用）
     */
    function cancelAuction() external {
        require(msg.sender == auction.seller, "NFTAuction: only seller can cancel");
        require(auction.status == AuctionStatus.Active, "NFTAuction: auction not active");
        require(auction.totalBids == 0, "NFTAuction: bids exist");

        auction.status = AuctionStatus.Cancelled;

        // 清除 NFT 拍卖状态
        AuctionNFT(auction.nftContract).setTokenAuctionStatus(auction.tokenId, false);

        emit AuctionCancelled(auctionId);
    }

    /**
     * @dev 获取当前最高出价信息
     * @return bidder 出价者地址
     * @return amount 出价金额
     * @return usdValue 美元价值
     * @return bidType 出价类型
     * @return token 代币地址
     */
    function getHighestBid() external view returns (
        address bidder,
        uint256 amount,
        uint256 usdValue,
        BidType bidType,
        address token
    ) {
        if (auction.totalBids == 0) {
            return (address(0), 0, 0, BidType.ETH, address(0));
        }

        Bid memory highestBid = bids[auction.highestBidIndex];
        return (
            highestBid.bidder,
            highestBid.amount,
            highestBid.usdValue,
            highestBid.bidType,
            highestBid.token
        );
    }

    /**
     * @dev 获取拍卖基本信息
     * @return 拍卖信息结构体
     */
    function getAuctionInfo() external view returns (AuctionInfo memory) {
        return auction;
    }

    /**
     * @dev 获取指定出价信息
     * @param _bidIndex 出价索引
     * @return 出价信息结构体
     */
    function getBid(uint256 _bidIndex) external view returns (Bid memory) {
        require(_bidIndex < auction.totalBids, "NFTAuction: invalid bid index");
        return bids[_bidIndex];
    }

    /**
     * @dev 获取所有出价信息
     * @return 出价信息数组
     */
    function getAllBids() external view returns (Bid[] memory) {
        return bids;
    }

    /**
     * @dev 内部函数：退还所有出价
     */
    function _refundAllBids() internal {
        for (uint256 i = 0; i < auction.totalBids; i++) {
            _refundBid(i);
        }
    }

    /**
     * @dev 内部函数：退还除获胜出价外的所有出价
     * @param _winningBidIndex 获胜出价索引
     */
    function _refundOtherBids(uint256 _winningBidIndex) internal {
        for (uint256 i = 0; i < auction.totalBids; i++) {
            if (i != _winningBidIndex) {
                _refundBid(i);
            }
        }
    }

    /**
     * @dev 内部函数：退还指定出价
     * @param _bidIndex 出价索引
     */
    function _refundBid(uint256 _bidIndex) internal {
        Bid memory bid = bids[_bidIndex];
        
        if (bid.bidType == BidType.ETH) {
            payable(bid.bidder).transfer(bid.amount);
        } else {
            IERC20(bid.token).safeTransfer(bid.bidder, bid.amount);
        }

        emit BidRefunded(bid.bidder, bid.amount, bid.bidType, bid.token);
    }

    /**
     * @dev 紧急情况下提取资金（仅工厂合约可调用）
     */
    function emergencyWithdraw() external {
        require(msg.sender == factory, "NFTAuction: only factory can withdraw");
        require(auction.status == AuctionStatus.Cancelled, "NFTAuction: auction not cancelled");

        // 退还所有出价
        _refundAllBids();
    }

}
