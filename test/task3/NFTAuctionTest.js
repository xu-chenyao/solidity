const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * NFT 拍卖市场测试套件
 * 测试完整的拍卖流程，包括 NFT 铸造、拍卖创建、出价、结束拍卖等功能
 */
describe("NFT Auction Market", function () {
  let owner, seller, bidder1, bidder2, bidder3, feeRecipient;
  let auctionNFT, auctionFactory, priceOracle, testToken;
  let auctionContract;

  // 测试常量
  const ETH_PRICE = ethers.parseUnits("2000", 8); // $2000 per ETH
  const TOKEN_PRICE = ethers.parseUnits("1", 8); // $1 per token
  const STARTING_PRICE = ethers.parseUnits("100", 8); // $100
  const RESERVE_PRICE = ethers.parseUnits("200", 8); // $200
  const BID_INCREMENT = ethers.parseUnits("10", 8); // $10
  const AUCTION_DURATION = 3600; // 1 hour

  beforeEach(async function () {
    // 获取测试账户
    [owner, seller, bidder1, bidder2, bidder3, feeRecipient] = await ethers.getSigners();

    // 部署模拟价格预言机
    const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    priceOracle = await MockPriceOracle.deploy(ETH_PRICE);

    // 部署测试代币
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy(
      "Test Token",
      "TEST",
      18,
      1000000, // 1M tokens
      owner.address
    );

    // 在价格预言机中设置测试代币价格
    await priceOracle.setTokenPrice(testToken.target, TOKEN_PRICE);

    // 部署可升级的 NFT 合约
    const AuctionNFT = await ethers.getContractFactory("AuctionNFT");
    auctionNFT = await upgrades.deployProxy(
      AuctionNFT,
      ["Auction NFT", "ANFT", owner.address],
      { initializer: "initialize" }
    );

    // 部署可升级的拍卖工厂合约
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    auctionFactory = await upgrades.deployProxy(
      AuctionFactory,
      [priceOracle.target, feeRecipient.address, owner.address],
      { initializer: "initialize" }
    );

    // 授权拍卖工厂操作 NFT
    await auctionNFT.setAuctionAuthorization(auctionFactory.target, true);

    // 给测试用户分发代币
    await testToken.transfer(bidder1.address, ethers.parseUnits("10000", 18));
    await testToken.transfer(bidder2.address, ethers.parseUnits("10000", 18));
    await testToken.transfer(bidder3.address, ethers.parseUnits("10000", 18));
  });

  describe("NFT 合约测试", function () {
    it("应该正确初始化 NFT 合约", async function () {
      expect(await auctionNFT.name()).to.equal("Auction NFT");
      expect(await auctionNFT.symbol()).to.equal("ANFT");
      expect(await auctionNFT.owner()).to.equal(owner.address);
      expect(await auctionNFT.getNextTokenId()).to.equal(1);
    });

    it("应该能够铸造 NFT", async function () {
      const tokenURI = "https://example.com/token/1";
      
      await expect(auctionNFT.mint(seller.address, tokenURI))
        .to.emit(auctionNFT, "NFTMinted")
        .withArgs(seller.address, 1, tokenURI);

      expect(await auctionNFT.ownerOf(1)).to.equal(seller.address);
      expect(await auctionNFT.tokenURI(1)).to.equal(tokenURI);
      expect(await auctionNFT.totalSupply()).to.equal(1);
    });

    it("应该能够批量铸造 NFT", async function () {
      const tokenURIs = [
        "https://example.com/token/1",
        "https://example.com/token/2",
        "https://example.com/token/3"
      ];

      const tx = await auctionNFT.batchMint(seller.address, tokenURIs);
      const receipt = await tx.wait();

      // 检查事件
      expect(receipt.logs.length).to.equal(tokenURIs.length);
      
      // 检查所有权
      for (let i = 0; i < tokenURIs.length; i++) {
        expect(await auctionNFT.ownerOf(i + 1)).to.equal(seller.address);
        expect(await auctionNFT.tokenURI(i + 1)).to.equal(tokenURIs[i]);
      }

      expect(await auctionNFT.totalSupply()).to.equal(tokenURIs.length);
    });

    it("应该阻止拍卖中的 NFT 转移", async function () {
      await auctionNFT.mint(seller.address, "https://example.com/token/1");
      
      // 设置 NFT 为拍卖状态
      await auctionNFT.setTokenAuctionStatus(1, true);

      // 尝试转移应该失败
      await expect(
        auctionNFT.connect(seller).transferFrom(seller.address, bidder1.address, 1)
      ).to.be.revertedWith("AuctionNFT: token is in auction");
    });
  });

  describe("价格预言机测试", function () {
    it("应该正确返回 ETH 价格", async function () {
      const [price, decimals] = await priceOracle.getETHPrice();
      expect(price).to.equal(ETH_PRICE);
      expect(decimals).to.equal(8);
    });

    it("应该正确返回代币价格", async function () {
      const [price, decimals] = await priceOracle.getTokenPrice(testToken.target);
      expect(price).to.equal(TOKEN_PRICE);
      expect(decimals).to.equal(8);
    });

    it("应该正确转换 ETH 为美元", async function () {
      const ethAmount = ethers.parseEther("1"); // 1 ETH
      const usdValue = await priceOracle.convertETHToUSD(ethAmount);
      expect(usdValue).to.equal(ETH_PRICE); // $2000
    });

    it("应该正确转换代币为美元", async function () {
      const tokenAmount = ethers.parseUnits("100", 18); // 100 tokens
      const usdValue = await priceOracle.convertTokenToUSD(testToken.target, tokenAmount);
      expect(usdValue).to.equal(ethers.parseUnits("100", 8)); // $100
    });
  });

  describe("拍卖工厂测试", function () {
    beforeEach(async function () {
      // 铸造 NFT 给卖家
      await auctionNFT.mint(seller.address, "https://example.com/token/1");
      
      // 卖家授权拍卖工厂操作 NFT
      await auctionNFT.connect(seller).setApprovalForAll(auctionFactory.target, true);
    });

    it("应该能够创建拍卖", async function () {
      const tx = await auctionFactory.connect(seller).createAuction(
        auctionNFT.target,
        1,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      const receipt = await tx.wait();
      const auctionCreatedEvent = receipt.logs.find(log => {
        try {
          return auctionFactory.interface.parseLog(log).name === "AuctionCreated";
        } catch {
          return false;
        }
      });

      expect(auctionCreatedEvent).to.not.be.undefined;
      
      const auctionId = auctionCreatedEvent.args[0];
      expect(auctionId).to.equal(1);

      // 检查拍卖是否正确记录
      const auctionAddress = await auctionFactory.getAuction(auctionId);
      expect(auctionAddress).to.not.equal(ethers.ZeroAddress);

      // 检查 NFT 是否转移到拍卖合约
      expect(await auctionNFT.ownerOf(1)).to.equal(auctionAddress);
    });

    it("应该正确记录拍卖统计", async function () {
      // 创建拍卖
      await auctionFactory.connect(seller).createAuction(
        auctionNFT.target,
        1,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      const stats = await auctionFactory.getAuctionStats();
      expect(stats.totalAuctions).to.equal(1);
      expect(stats.activeAuctions).to.equal(1);
      expect(stats.endedAuctions).to.equal(0);
      expect(stats.cancelledAuctions).to.equal(0);
    });

    it("应该能够批量创建拍卖", async function () {
      // 批量铸造 NFT
      const tokenURIs = ["uri1", "uri2", "uri3"];
      await auctionNFT.batchMint(seller.address, tokenURIs);

      // 批量创建拍卖
      const tokenIds = [2, 3, 4]; // tokenId 1 already minted in beforeEach
      const tx = await auctionFactory.connect(seller).createBatchAuctions(
        auctionNFT.target,
        tokenIds,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      const receipt = await tx.wait();
      const auctionEvents = receipt.logs.filter(log => {
        try {
          return auctionFactory.interface.parseLog(log).name === "AuctionCreated";
        } catch {
          return false;
        }
      });

      expect(auctionEvents.length).to.equal(tokenIds.length);

      // 检查统计
      const stats = await auctionFactory.getAuctionStats();
      expect(stats.totalAuctions).to.equal(tokenIds.length);
    });
  });

  describe("拍卖流程测试", function () {
    let auctionId;

    beforeEach(async function () {
      // 铸造并创建拍卖
      await auctionNFT.mint(seller.address, "https://example.com/token/1");
      await auctionNFT.connect(seller).setApprovalForAll(auctionFactory.target, true);

      const tx = await auctionFactory.connect(seller).createAuction(
        auctionNFT.target,
        1,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      const receipt = await tx.wait();
      const auctionCreatedEvent = receipt.logs.find(log => {
        try {
          return auctionFactory.interface.parseLog(log).name === "AuctionCreated";
        } catch {
          return false;
        }
      });

      auctionId = auctionCreatedEvent.args[0];
      const auctionAddress = await auctionFactory.getAuction(auctionId);
      auctionContract = await ethers.getContractAt("NFTAuction", auctionAddress);
    });

    it("应该能够使用 ETH 出价", async function () {
      const bidAmount = ethers.parseEther("0.1"); // 0.1 ETH = $200
      
      await expect(auctionContract.connect(bidder1).bidWithETH({ value: bidAmount }))
        .to.emit(auctionContract, "BidPlaced");

      const [bidder, amount, usdValue, bidType] = await auctionContract.getHighestBid();
      expect(bidder).to.equal(bidder1.address);
      expect(amount).to.equal(bidAmount);
      expect(bidType).to.equal(0); // BidType.ETH
    });

    it("应该能够使用 ERC20 代币出价", async function () {
      const bidAmount = ethers.parseUnits("300", 18); // 300 tokens = $300
      
      // 授权拍卖合约使用代币
      await testToken.connect(bidder1).approve(auctionContract.target, bidAmount);

      await expect(
        auctionContract.connect(bidder1).bidWithERC20(testToken.target, bidAmount)
      ).to.emit(auctionContract, "BidPlaced");

      const [bidder, amount, usdValue, bidType, token] = await auctionContract.getHighestBid();
      expect(bidder).to.equal(bidder1.address);
      expect(amount).to.equal(bidAmount);
      expect(bidType).to.equal(1); // BidType.ERC20
      expect(token).to.equal(testToken.target);
    });

    it("应该正确处理多个出价", async function () {
      // 第一个出价：ETH
      const ethBidAmount = ethers.parseEther("0.1"); // 0.1 ETH = $200
      await auctionContract.connect(bidder1).bidWithETH({ value: ethBidAmount });

      // 第二个出价：ERC20 代币
      const tokenBidAmount = ethers.parseUnits("250", 18); // 250 tokens = $250
      await testToken.connect(bidder2).approve(auctionContract.target, tokenBidAmount);
      await auctionContract.connect(bidder2).bidWithERC20(testToken.target, tokenBidAmount);

      // 第三个出价：更多 ETH
      const higherEthBid = ethers.parseEther("0.15"); // 0.15 ETH = $300
      await auctionContract.connect(bidder3).bidWithETH({ value: higherEthBid });

      // 检查最高出价
      const [bidder, amount, usdValue, bidType] = await auctionContract.getHighestBid();
      expect(bidder).to.equal(bidder3.address);
      expect(amount).to.equal(higherEthBid);
      expect(bidType).to.equal(0); // BidType.ETH

      // 检查总出价数
      const auctionInfo = await auctionContract.getAuctionInfo();
      expect(auctionInfo.totalBids).to.equal(3);
    });

    it("应该正确结束拍卖并转移资产", async function () {
      // 出价
      const bidAmount = ethers.parseEther("0.15"); // 0.15 ETH = $300 (超过保留价)
      await auctionContract.connect(bidder1).bidWithETH({ value: bidAmount });

      // 等待拍卖结束
      await time.increase(AUCTION_DURATION + 1);

      // 记录初始余额
      const initialSellerBalance = await ethers.provider.getBalance(seller.address);
      const initialFeeRecipientBalance = await ethers.provider.getBalance(feeRecipient.address);

      // 结束拍卖
      await expect(auctionContract.endAuction())
        .to.emit(auctionContract, "AuctionEnded");

      // 检查 NFT 转移
      expect(await auctionNFT.ownerOf(1)).to.equal(bidder1.address);

      // 检查资金转移（考虑平台费用）
      const platformFee = bidAmount * BigInt(250) / BigInt(10000); // 2.5%
      const sellerAmount = bidAmount - platformFee;

      const finalSellerBalance = await ethers.provider.getBalance(seller.address);
      const finalFeeRecipientBalance = await ethers.provider.getBalance(feeRecipient.address);

      expect(finalSellerBalance - initialSellerBalance).to.equal(sellerAmount);
      expect(finalFeeRecipientBalance - initialFeeRecipientBalance).to.equal(platformFee);
    });

    it("应该在未达到保留价时退还所有出价", async function () {
      // 出价但不超过保留价
      const bidAmount = ethers.parseEther("0.05"); // 0.05 ETH = $100 (低于保留价 $200)
      await auctionContract.connect(bidder1).bidWithETH({ value: bidAmount });

      const initialBidderBalance = await ethers.provider.getBalance(bidder1.address);

      // 等待拍卖结束
      await time.increase(AUCTION_DURATION + 1);

      // 结束拍卖
      await auctionContract.endAuction();

      // NFT 应该仍然属于拍卖合约（因为没有达到保留价）
      expect(await auctionNFT.ownerOf(1)).to.equal(auctionContract.target);

      // 检查出价是否被退还
      const finalBidderBalance = await ethers.provider.getBalance(bidder1.address);
      expect(finalBidderBalance).to.be.gt(initialBidderBalance);
    });

    it("应该允许卖家在没有出价时取消拍卖", async function () {
      await expect(auctionContract.connect(seller).cancelAuction())
        .to.emit(auctionContract, "AuctionCancelled");

      const auctionInfo = await auctionContract.getAuctionInfo();
      expect(auctionInfo.status).to.equal(2); // AuctionStatus.Cancelled
    });

    it("应该阻止在有出价时取消拍卖", async function () {
      // 先出价
      const bidAmount = ethers.parseEther("0.1");
      await auctionContract.connect(bidder1).bidWithETH({ value: bidAmount });

      // 尝试取消应该失败
      await expect(
        auctionContract.connect(seller).cancelAuction()
      ).to.be.revertedWith("NFTAuction: bids exist");
    });

    it("应该在拍卖即将结束时延长时间", async function () {
      // 等到拍卖快结束时（最后 4 分钟）
      await time.increase(AUCTION_DURATION - 240);

      const auctionInfoBefore = await auctionContract.getAuctionInfo();
      const endTimeBefore = auctionInfoBefore.endTime;

      // 出价（应该触发时间延长）
      const bidAmount = ethers.parseEther("0.1");
      await auctionContract.connect(bidder1).bidWithETH({ value: bidAmount });

      const auctionInfoAfter = await auctionContract.getAuctionInfo();
      const endTimeAfter = auctionInfoAfter.endTime;

      // 结束时间应该被延长
      expect(endTimeAfter).to.be.gt(endTimeBefore);
    });
  });

  describe("合约升级测试", function () {
    it("应该能够升级 NFT 合约", async function () {
      // 部署新版本的实现合约
      const AuctionNFTV2 = await ethers.getContractFactory("AuctionNFT");
      
      // 升级合约
      const upgradedNFT = await upgrades.upgradeProxy(auctionNFT.target, AuctionNFTV2);
      
      // 验证升级后合约仍然正常工作
      expect(await upgradedNFT.name()).to.equal("Auction NFT");
      expect(await upgradedNFT.owner()).to.equal(owner.address);
    });

    it("应该能够升级拍卖工厂合约", async function () {
      // 部署新版本的实现合约
      const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactory");
      
      // 升级合约
      const upgradedFactory = await upgrades.upgradeProxy(auctionFactory.target, AuctionFactoryV2);
      
      // 验证升级后合约仍然正常工作
      expect(await upgradedFactory.feeRecipient()).to.equal(feeRecipient.address);
      expect(await upgradedFactory.owner()).to.equal(owner.address);
    });
  });

  describe("边界情况和错误处理", function () {
    beforeEach(async function () {
      await auctionNFT.mint(seller.address, "https://example.com/token/1");
      await auctionNFT.connect(seller).setApprovalForAll(auctionFactory.target, true);
    });

    it("应该拒绝零起拍价", async function () {
      await expect(
        auctionFactory.connect(seller).createAuction(
          auctionNFT.target,
          1,
          0, // 零起拍价
          RESERVE_PRICE,
          AUCTION_DURATION,
          BID_INCREMENT
        )
      ).to.be.revertedWith("AuctionFactory: starting price too low");
    });

    it("应该拒绝保留价低于起拍价", async function () {
      await expect(
        auctionFactory.connect(seller).createAuction(
          auctionNFT.target,
          1,
          STARTING_PRICE,
          ethers.parseUnits("50", 8), // 保留价低于起拍价
          AUCTION_DURATION,
          BID_INCREMENT
        )
      ).to.be.revertedWith("AuctionFactory: invalid reserve price");
    });

    it("应该拒绝过短的拍卖持续时间", async function () {
      await expect(
        auctionFactory.connect(seller).createAuction(
          auctionNFT.target,
          1,
          STARTING_PRICE,
          RESERVE_PRICE,
          1800, // 30分钟，低于最小值1小时
          BID_INCREMENT
        )
      ).to.be.revertedWith("AuctionFactory: duration too short");
    });

    it("应该拒绝非所有者创建拍卖", async function () {
      await expect(
        auctionFactory.connect(bidder1).createAuction(
          auctionNFT.target,
          1,
          STARTING_PRICE,
          RESERVE_PRICE,
          AUCTION_DURATION,
          BID_INCREMENT
        )
      ).to.be.revertedWith("AuctionFactory: not NFT owner");
    });

    it("应该拒绝重复拍卖同一个 NFT", async function () {
      // 第一次创建拍卖
      await auctionFactory.connect(seller).createAuction(
        auctionNFT.target,
        1,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      // 再次创建应该失败（NFT 已转移到拍卖合约）
      await expect(
        auctionFactory.connect(seller).createAuction(
          auctionNFT.target,
          1,
          STARTING_PRICE,
          RESERVE_PRICE,
          AUCTION_DURATION,
          BID_INCREMENT
        )
      ).to.be.revertedWith("ERC721: invalid token ID");
    });
  });

  describe("价格波动测试", function () {
    let auctionId;

    beforeEach(async function () {
      await auctionNFT.mint(seller.address, "https://example.com/token/1");
      await auctionNFT.connect(seller).setApprovalForAll(auctionFactory.target, true);

      const tx = await auctionFactory.connect(seller).createAuction(
        auctionNFT.target,
        1,
        STARTING_PRICE,
        RESERVE_PRICE,
        AUCTION_DURATION,
        BID_INCREMENT
      );

      const receipt = await tx.wait();
      const auctionCreatedEvent = receipt.logs.find(log => {
        try {
          return auctionFactory.interface.parseLog(log).name === "AuctionCreated";
        } catch {
          return false;
        }
      });

      auctionId = auctionCreatedEvent.args[0];
      const auctionAddress = await auctionFactory.getAuction(auctionId);
      auctionContract = await ethers.getContractAt("NFTAuction", auctionAddress);
    });

    it("应该正确处理价格波动对出价的影响", async function () {
      // 初始出价
      const ethBidAmount = ethers.parseEther("0.1"); // 0.1 ETH = $200 (当前价格)
      await auctionContract.connect(bidder1).bidWithETH({ value: ethBidAmount });

      // 模拟 ETH 价格上涨 50%
      const newETHPrice = ethers.parseUnits("3000", 8); // $3000 per ETH
      await priceOracle.setETHPrice(newETHPrice);

      // 现在同样的 ETH 数量值更多美元了
      const newUsdValue = await priceOracle.convertETHToUSD(ethBidAmount);
      expect(newUsdValue).to.equal(ethers.parseUnits("300", 8)); // $300

      // 但是拍卖中的出价记录仍然是出价时的价值
      const [, , usdValue] = await auctionContract.getHighestBid();
      expect(usdValue).to.equal(ethers.parseUnits("200", 8)); // 仍然是 $200
    });
  });
});
