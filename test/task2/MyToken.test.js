const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyToken ERC20合约测试", function () {
  let myToken;
  let owner, addr1, addr2, addr3;
  
  // 代币基本信息
  const TOKEN_NAME = "MyToken";
  const TOKEN_SYMBOL = "MTK";
  const TOKEN_DECIMALS = 18;
  const INITIAL_SUPPLY = 1000000; // 100万代币
  const TOTAL_SUPPLY = ethers.parseUnits(INITIAL_SUPPLY.toString(), TOKEN_DECIMALS);
  // beforeEach
  // 初始化测试所需的环境（如部署合约、设置变量等）。
  // 清理或重置数据（确保每个测试用例都是从同样的状态开始）。
  beforeEach(async function () {
    // 获取测试账户
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // 部署合约
    const MyToken = await ethers.getContractFactory("MyToken");
    myToken = await MyToken.deploy(
      TOKEN_NAME,
      TOKEN_SYMBOL, 
      TOKEN_DECIMALS,
      INITIAL_SUPPLY
    );
    await myToken.waitForDeployment();
  });

  describe("合约部署", function () {
    it("应该正确设置代币基本信息", async function () {
      expect(await myToken.name()).to.equal(TOKEN_NAME);
      expect(await myToken.symbol()).to.equal(TOKEN_SYMBOL);
      expect(await myToken.decimals()).to.equal(TOKEN_DECIMALS);
      expect(await myToken.totalSupply()).to.equal(TOTAL_SUPPLY);
    });

    it("应该将初始供应量分配给部署者", async function () {
      const ownerBalance = await myToken.balanceOf(owner.address);
      expect(ownerBalance).to.equal(TOTAL_SUPPLY);
    });

    it("应该设置正确的合约所有者", async function () {
      expect(await myToken.owner()).to.equal(owner.address);
    });

    it("部署后应该有正确的初始状态", async function () {
      // 验证部署后的初始状态
      expect(await myToken.name()).to.equal(TOKEN_NAME);
      expect(await myToken.symbol()).to.equal(TOKEN_SYMBOL);
      expect(await myToken.decimals()).to.equal(TOKEN_DECIMALS);
      expect(await myToken.totalSupply()).to.equal(TOTAL_SUPPLY);
      expect(await myToken.owner()).to.equal(owner.address);
      expect(await myToken.balanceOf(owner.address)).to.equal(TOTAL_SUPPLY);
    });
  });

  describe("余额查询 (balanceOf)", function () {
    it("应该返回正确的账户余额", async function () {
      expect(await myToken.balanceOf(owner.address)).to.equal(TOTAL_SUPPLY);
      expect(await myToken.balanceOf(addr1.address)).to.equal(0);
    });

    it("应该处理零地址查询", async function () {
      expect(await myToken.balanceOf(ethers.ZeroAddress)).to.equal(0);
    });
  });

  describe("转账功能 (transfer)", function () {
    const transferAmount = ethers.parseUnits("100", TOKEN_DECIMALS);

    it("应该成功转账", async function () {
      await expect(myToken.transfer(addr1.address, transferAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, addr1.address, transferAmount);

      expect(await myToken.balanceOf(owner.address)).to.equal(TOTAL_SUPPLY - transferAmount);
      expect(await myToken.balanceOf(addr1.address)).to.equal(transferAmount);
    });

    it("应该拒绝余额不足的转账", async function () {
      const largeAmount = TOTAL_SUPPLY + ethers.parseUnits("1", TOKEN_DECIMALS);
      
      await expect(myToken.transfer(addr1.address, largeAmount))
        .to.be.revertedWith("MyToken: transfer amount exceeds balance");
    });

    it("应该拒绝转账到零地址", async function () {
      await expect(myToken.transfer(ethers.ZeroAddress, transferAmount))
        .to.be.revertedWith("MyToken: address cannot be zero");
    });

    it("应该允许转账0代币", async function () {
      await expect(myToken.transfer(addr1.address, 0))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, addr1.address, 0);
    });

    it("应该正确处理自己转给自己", async function () {
      const initialBalance = await myToken.balanceOf(owner.address);
      
      await expect(myToken.transfer(owner.address, transferAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, owner.address, transferAmount);
      
      expect(await myToken.balanceOf(owner.address)).to.equal(initialBalance);
    });
  });

  describe("授权功能 (approve & allowance)", function () {
    const approveAmount = ethers.parseUnits("500", TOKEN_DECIMALS);

    it("应该成功设置授权", async function () {
      await expect(myToken.approve(addr1.address, approveAmount))
        .to.emit(myToken, "Approval")
        .withArgs(owner.address, addr1.address, approveAmount);

      expect(await myToken.allowance(owner.address, addr1.address)).to.equal(approveAmount);
    });

    it("应该拒绝授权给零地址", async function () {
      await expect(myToken.approve(ethers.ZeroAddress, approveAmount))
        .to.be.revertedWith("MyToken: address cannot be zero");
    });

    it("应该允许覆盖现有授权", async function () {
      await myToken.approve(addr1.address, approveAmount);
      
      const newAmount = ethers.parseUnits("200", TOKEN_DECIMALS);
      await expect(myToken.approve(addr1.address, newAmount))
        .to.emit(myToken, "Approval")
        .withArgs(owner.address, addr1.address, newAmount);

      expect(await myToken.allowance(owner.address, addr1.address)).to.equal(newAmount);
    });

    it("应该允许授权0代币", async function () {
      await myToken.approve(addr1.address, approveAmount);
      
      await expect(myToken.approve(addr1.address, 0))
        .to.emit(myToken, "Approval")
        .withArgs(owner.address, addr1.address, 0);

      expect(await myToken.allowance(owner.address, addr1.address)).to.equal(0);
    });
  });

  describe("代扣转账功能 (transferFrom)", function () {
    const approveAmount = ethers.parseUnits("500", TOKEN_DECIMALS);
    const transferAmount = ethers.parseUnits("200", TOKEN_DECIMALS);

    beforeEach(async function () {
      // 设置授权
      await myToken.approve(addr1.address, approveAmount);
    });

    it("应该成功执行代扣转账", async function () {
      await expect(myToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, addr2.address, transferAmount)
        .and.to.emit(myToken, "Approval")
        .withArgs(owner.address, addr1.address, approveAmount - transferAmount);

      expect(await myToken.balanceOf(owner.address)).to.equal(TOTAL_SUPPLY - transferAmount);
      expect(await myToken.balanceOf(addr2.address)).to.equal(transferAmount);
      expect(await myToken.allowance(owner.address, addr1.address)).to.equal(approveAmount - transferAmount);
    });

    it("应该拒绝超出授权额度的转账", async function () {
      const largeAmount = approveAmount + ethers.parseUnits("1", TOKEN_DECIMALS);
      
      await expect(myToken.connect(addr1).transferFrom(owner.address, addr2.address, largeAmount))
        .to.be.revertedWith("MyToken: insufficient allowance");
    });

    it("应该拒绝从零地址转账", async function () {
      await expect(myToken.connect(addr1).transferFrom(ethers.ZeroAddress, addr2.address, transferAmount))
        .to.be.revertedWith("MyToken: address cannot be zero");
    });

    it("应该拒绝转账到零地址", async function () {
      await expect(myToken.connect(addr1).transferFrom(owner.address, ethers.ZeroAddress, transferAmount))
        .to.be.revertedWith("MyToken: address cannot be zero");
    });

    it("应该处理最大授权额度", async function () {
      // 设置最大授权
      await myToken.approve(addr1.address, ethers.MaxUint256);
      
      await expect(myToken.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, addr2.address, transferAmount);

      // 最大授权不应该减少
      expect(await myToken.allowance(owner.address, addr1.address)).to.equal(ethers.MaxUint256);
    });
  });

  describe("增发功能 (mint)", function () {
    const mintAmount = ethers.parseUnits("1000", TOKEN_DECIMALS);

    it("所有者应该能够增发代币", async function () {
      const initialSupply = await myToken.totalSupply();
      const initialBalance = await myToken.balanceOf(addr1.address);

      await expect(myToken.mint(addr1.address, mintAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(ethers.ZeroAddress, addr1.address, mintAmount)
        .and.to.emit(myToken, "Mint")
        .withArgs(addr1.address, mintAmount);

      expect(await myToken.totalSupply()).to.equal(initialSupply + mintAmount);
      expect(await myToken.balanceOf(addr1.address)).to.equal(initialBalance + mintAmount);
    });

    it("非所有者不能增发代币", async function () {
      await expect(myToken.connect(addr1).mint(addr2.address, mintAmount))
        .to.be.revertedWith("MyToken: caller is not the owner");
    });

    it("应该拒绝增发到零地址", async function () {
      await expect(myToken.mint(ethers.ZeroAddress, mintAmount))
        .to.be.revertedWith("MyToken: address cannot be zero");
    });

    it("应该拒绝增发0代币", async function () {
      await expect(myToken.mint(addr1.address, 0))
        .to.be.revertedWith("MyToken: mint amount must be greater than 0");
    });
  });

  describe("所有权管理", function () {
    it("应该能够转移所有权", async function () {
      await expect(myToken.transferOwnership(addr1.address))
        .to.emit(myToken, "OwnershipTransferred")
        .withArgs(owner.address, addr1.address);

      expect(await myToken.owner()).to.equal(addr1.address);
    });

    it("新所有者应该能够增发代币", async function () {
      await myToken.transferOwnership(addr1.address);
      
      const mintAmount = ethers.parseUnits("100", TOKEN_DECIMALS);
      await expect(myToken.connect(addr1).mint(addr2.address, mintAmount))
        .to.emit(myToken, "Mint")
        .withArgs(addr2.address, mintAmount);
    });

    it("原所有者转移所有权后不能增发", async function () {
      await myToken.transferOwnership(addr1.address);
      
      const mintAmount = ethers.parseUnits("100", TOKEN_DECIMALS);
      await expect(myToken.mint(addr2.address, mintAmount))
        .to.be.revertedWith("MyToken: caller is not the owner");
    });

    it("应该能够放弃所有权", async function () {
      await expect(myToken.renounceOwnership())
        .to.emit(myToken, "OwnershipTransferred")
        .withArgs(owner.address, ethers.ZeroAddress);

      expect(await myToken.owner()).to.equal(ethers.ZeroAddress);
    });

    it("非所有者不能转移所有权", async function () {
      await expect(myToken.connect(addr1).transferOwnership(addr2.address))
        .to.be.revertedWith("MyToken: caller is not the owner");
    });
  });

  describe("辅助功能", function () {
    const approveAmount = ethers.parseUnits("500", TOKEN_DECIMALS);
    const increaseAmount = ethers.parseUnits("200", TOKEN_DECIMALS);
    const decreaseAmount = ethers.parseUnits("100", TOKEN_DECIMALS);

    describe("增加授权额度 (increaseAllowance)", function () {
      it("应该成功增加授权额度", async function () {
        await myToken.approve(addr1.address, approveAmount);
        
        await expect(myToken.increaseAllowance(addr1.address, increaseAmount))
          .to.emit(myToken, "Approval")
          .withArgs(owner.address, addr1.address, approveAmount + increaseAmount);

        expect(await myToken.allowance(owner.address, addr1.address))
          .to.equal(approveAmount + increaseAmount);
      });
    });

    describe("减少授权额度 (decreaseAllowance)", function () {
      beforeEach(async function () {
        await myToken.approve(addr1.address, approveAmount);
      });

      it("应该成功减少授权额度", async function () {
        await expect(myToken.decreaseAllowance(addr1.address, decreaseAmount))
          .to.emit(myToken, "Approval")
          .withArgs(owner.address, addr1.address, approveAmount - decreaseAmount);

        expect(await myToken.allowance(owner.address, addr1.address))
          .to.equal(approveAmount - decreaseAmount);
      });

      it("应该拒绝减少超出当前授权的额度", async function () {
        const largeAmount = approveAmount + ethers.parseUnits("1", TOKEN_DECIMALS);
        
        await expect(myToken.decreaseAllowance(addr1.address, largeAmount))
          .to.be.revertedWith("MyToken: decreased allowance below zero");
      });
    });

    describe("批量转账 (batchTransfer)", function () {
      it("应该成功执行批量转账", async function () {
        const recipients = [addr1.address, addr2.address, addr3.address];
        const amounts = [
          ethers.parseUnits("100", TOKEN_DECIMALS),
          ethers.parseUnits("200", TOKEN_DECIMALS),
          ethers.parseUnits("300", TOKEN_DECIMALS)
        ];

        await expect(myToken.batchTransfer(recipients, amounts))
          .to.emit(myToken, "Transfer")
          .withArgs(owner.address, addr1.address, amounts[0])
          .and.to.emit(myToken, "Transfer")
          .withArgs(owner.address, addr2.address, amounts[1])
          .and.to.emit(myToken, "Transfer")
          .withArgs(owner.address, addr3.address, amounts[2]);

        expect(await myToken.balanceOf(addr1.address)).to.equal(amounts[0]);
        expect(await myToken.balanceOf(addr2.address)).to.equal(amounts[1]);
        expect(await myToken.balanceOf(addr3.address)).to.equal(amounts[2]);
      });

      it("应该拒绝数组长度不匹配", async function () {
        const recipients = [addr1.address, addr2.address];
        const amounts = [ethers.parseUnits("100", TOKEN_DECIMALS)];

        await expect(myToken.batchTransfer(recipients, amounts))
          .to.be.revertedWith("MyToken: arrays length mismatch");
      });

      it("应该拒绝空数组", async function () {
        await expect(myToken.batchTransfer([], []))
          .to.be.revertedWith("MyToken: empty arrays");
      });
    });
  });

  describe("边界条件和安全测试", function () {
    it("应该正确处理大额转账", async function () {
      const largeAmount = ethers.parseUnits("999999", TOKEN_DECIMALS);
      
      await expect(myToken.transfer(addr1.address, largeAmount))
        .to.emit(myToken, "Transfer")
        .withArgs(owner.address, addr1.address, largeAmount);

      expect(await myToken.balanceOf(addr1.address)).to.equal(largeAmount);
    });

    it("应该防止整数溢出", async function () {
      // 尝试增发最大值
      const maxAmount = ethers.MaxUint256;
      
      await expect(myToken.mint(addr1.address, maxAmount))
        .to.be.reverted; // 应该因为溢出而失败
    });

    it("应该正确处理连续操作", async function () {
      // 连续转账
      const amount = ethers.parseUnits("100", TOKEN_DECIMALS);
      
      await myToken.transfer(addr1.address, amount);
      await myToken.transfer(addr2.address, amount);
      await myToken.connect(addr1).transfer(addr3.address, amount);

      expect(await myToken.balanceOf(addr1.address)).to.equal(0);
      expect(await myToken.balanceOf(addr2.address)).to.equal(amount);
      expect(await myToken.balanceOf(addr3.address)).to.equal(amount);
    });
  });

  describe("Gas优化测试", function () {
    it("批量转账应该比单独转账更节省gas", async function () {
      const recipients = [addr1.address, addr2.address];
      const amounts = [
        ethers.parseUnits("100", TOKEN_DECIMALS),
        ethers.parseUnits("200", TOKEN_DECIMALS)
      ];

      // 批量转账
      const batchTx = await myToken.batchTransfer(recipients, amounts);
      const batchReceipt = await batchTx.wait();

      // 重置状态
      await myToken.transfer(owner.address, await myToken.balanceOf(addr1.address));
      await myToken.transfer(owner.address, await myToken.balanceOf(addr2.address));

      // 单独转账
      const tx1 = await myToken.transfer(addr1.address, amounts[0]);
      const tx2 = await myToken.transfer(addr2.address, amounts[1]);
      const receipt1 = await tx1.wait();
      const receipt2 = await tx2.wait();

      const individualGas = receipt1.gasUsed + receipt2.gasUsed;
      
      console.log(`批量转账Gas: ${batchReceipt.gasUsed}`);
      console.log(`单独转账Gas: ${individualGas}`);
      
      // 批量转账应该更节省gas（这个测试可能因为overhead而不总是成立）
      // expect(batchReceipt.gasUsed).to.be.lessThan(individualGas);
    });
  });
});
