const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * MyNFT合约测试套件
 * 
 * 测试覆盖：
 * 1. 合约部署和初始化
 * 2. NFT铸造功能
 * 3. 批量铸造功能
 * 4. 元数据管理
 * 5. 权限控制
 * 6. 查询功能
 */
describe("MyNFT Contract", function () {
    let myNFT;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    // 测试用的IPFS链接（模拟数据）
    const sampleTokenURI = "ipfs://bafybeihxwrls2uzs2xnn77rwcqpetfe6ethnqkdkmcbk6xok3bxztvhmta/xcy1.json";
    const sampleTokenURI2 = "ipfs://bafybeihxwrls2uzs2xnn77rwcqpetfe6ethnqkdkmcbk6xok3bxztvhmta/xcy2.json";
    
    // 测试用的NFT元数据示例
    // const sampleMetadata = {
    //     name: "My First NFT",
    //     description: "This is my first NFT on blockchain",
    //     image: "ipfs://QmImageHashHere/image.png",
    //     attributes: [
    //         {
    //             trait_type: "Color",
    //             value: "Blue"
    //         },
    //         {
    //             trait_type: "Rarity",
    //             value: "Common"
    //         }
    //     ]
    // };

    beforeEach(async function () {
        // 获取测试账户
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        // 部署合约
        const MyNFT = await ethers.getContractFactory("MyNFT");
        myNFT = await MyNFT.deploy("MyAwesomeNFT", "MANFT");
        await myNFT.waitForDeployment();
    });

    describe("部署和初始化", function () {
        it("应该正确设置NFT名称和符号", async function () {
            expect(await myNFT.name()).to.equal("MyAwesomeNFT");
            expect(await myNFT.symbol()).to.equal("MANFT");
        });

        it("应该设置正确的所有者", async function () {
            expect(await myNFT.owner()).to.equal(owner.address);
        });

        it("初始总供应量应该为0", async function () {
            expect(await myNFT.totalSupply()).to.equal(0);
        });
    });

    describe("NFT铸造功能", function () {
        it("所有者应该能够成功铸造NFT", async function () {
            // 铸造NFT
            const tx = await myNFT.mintNFT(addr1.address, sampleTokenURI);
            const receipt = await tx.wait();

            // 检查事件
            const event = receipt.logs.find(log => {
                try {
                    return myNFT.interface.parseLog(log).name === 'NFTMinted';
                } catch {
                    return false;
                }
            });
            expect(event).to.not.be.undefined;

            // 检查NFT所有权
            expect(await myNFT.ownerOf(1)).to.equal(addr1.address);
            
            // 检查元数据URI
            expect(await myNFT.tokenURI(1)).to.equal(sampleTokenURI);
            
            // 检查总供应量
            expect(await myNFT.totalSupply()).to.equal(1);
            
            // 检查余额
            expect(await myNFT.balanceOf(addr1.address)).to.equal(1);
        });

        it("非所有者不应该能够铸造NFT", async function () {
            await expect(
                myNFT.connect(addr1).mintNFT(addr1.address, sampleTokenURI)
            ).to.be.revertedWithCustomError(myNFT, "OwnableUnauthorizedAccount");
        });

        it("不应该能够向零地址铸造NFT", async function () {
            await expect(
                myNFT.mintNFT(ethers.ZeroAddress, sampleTokenURI)
            ).to.be.revertedWith("MyNFT: recipient cannot be zero address");
        });

        it("不应该能够使用空的tokenURI铸造NFT", async function () {
            await expect(
                myNFT.mintNFT(addr1.address, "")
            ).to.be.revertedWith("MyNFT: tokenURI cannot be empty");
        });

        it("应该正确记录铸造信息", async function () {
            const tx = await myNFT.mintNFT(addr1.address, sampleTokenURI);
            const receipt = await tx.wait();
            const block = await ethers.provider.getBlock(receipt.blockNumber);

            // 获取NFT信息
            const [nftOwner, tokenURI, mintTime, minterAddress] = await myNFT.getNFTInfo(1);

            expect(nftOwner).to.equal(addr1.address);
            expect(tokenURI).to.equal(sampleTokenURI);
            expect(mintTime).to.equal(block.timestamp);
            expect(minterAddress).to.equal(owner.address);
        });
    });

    describe("批量铸造功能", function () {
        it("应该能够批量铸造多个NFT", async function () {
            const recipients = [addr1.address, addr2.address];
            const tokenURIs = [sampleTokenURI, sampleTokenURI2];

            const tx = await myNFT.batchMintNFT(recipients, tokenURIs);
            await tx.wait();

            // 检查所有权
            expect(await myNFT.ownerOf(1)).to.equal(addr1.address);
            expect(await myNFT.ownerOf(2)).to.equal(addr2.address);

            // 检查元数据
            expect(await myNFT.tokenURI(1)).to.equal(sampleTokenURI);
            expect(await myNFT.tokenURI(2)).to.equal(sampleTokenURI2);

            // 检查总供应量
            expect(await myNFT.totalSupply()).to.equal(2);
        });

        it("批量铸造时数组长度不匹配应该失败", async function () {
            const recipients = [addr1.address, addr2.address];
            const tokenURIs = [sampleTokenURI]; // 长度不匹配

            await expect(
                myNFT.batchMintNFT(recipients, tokenURIs)
            ).to.be.revertedWith("MyNFT: arrays length mismatch");
        });

        it("批量铸造空数组应该失败", async function () {
            await expect(
                myNFT.batchMintNFT([], [])
            ).to.be.revertedWith("MyNFT: empty arrays");
        });
    });

    describe("查询功能", function () {
        beforeEach(async function () {
            // 铸造一些测试NFT
            await myNFT.mintNFT(addr1.address, sampleTokenURI);
            await myNFT.mintNFT(addr2.address, sampleTokenURI2);
        });

        it("应该正确查询NFT信息", async function () {
            const [nftOwner, tokenURI, mintTime, minterAddress] = await myNFT.getNFTInfo(1);

            expect(nftOwner).to.equal(addr1.address);
            expect(tokenURI).to.equal(sampleTokenURI);
            expect(mintTime).to.be.gt(0);
            expect(minterAddress).to.equal(owner.address);
        });

        it("查询不存在的NFT应该失败", async function () {
            await expect(
                myNFT.getNFTInfo(999)
            ).to.be.revertedWith("MyNFT: token does not exist");
        });

        it("应该正确查询地址余额", async function () {
            expect(await myNFT.balanceOf(addr1.address)).to.equal(1);
            expect(await myNFT.balanceOf(addr2.address)).to.equal(1);
            expect(await myNFT.balanceOf(addrs[0].address)).to.equal(0);
        });

        it("查询零地址余额应该失败", async function () {
            await expect(
                myNFT.balanceOf(ethers.ZeroAddress)
            ).to.be.revertedWith("MyNFT: address zero is not a valid owner");
        });

        it("应该正确返回总供应量", async function () {
            expect(await myNFT.totalSupply()).to.equal(2);
        });
    });

    describe("ERC721标准兼容性", function () {
        beforeEach(async function () {
            await myNFT.mintNFT(addr1.address, sampleTokenURI);
        });

        it("应该支持ERC721接口", async function () {
            // ERC721接口ID: 0x80ac58cd
            expect(await myNFT.supportsInterface("0x80ac58cd")).to.be.true;
        });

        it("应该支持ERC721Metadata接口", async function () {
            // ERC721Metadata接口ID: 0x5b5e139f
            expect(await myNFT.supportsInterface("0x5b5e139f")).to.be.true;
        });

        it("应该能够转移NFT", async function () {
            // addr1转移NFT给addr2
            await myNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 1);
            
            expect(await myNFT.ownerOf(1)).to.equal(addr2.address);
            expect(await myNFT.balanceOf(addr1.address)).to.equal(0);
            expect(await myNFT.balanceOf(addr2.address)).to.equal(1);
        });

        it("应该能够批准和转移NFT", async function () {
            // addr1批准addr2操作NFT
            await myNFT.connect(addr1).approve(addr2.address, 1);
            expect(await myNFT.getApproved(1)).to.equal(addr2.address);

            // addr2代表addr1转移NFT
            await myNFT.connect(addr2).transferFrom(addr1.address, addr2.address, 1);
            expect(await myNFT.ownerOf(1)).to.equal(addr2.address);
        });
    });

    describe("Gas优化测试", function () {
        it("单次铸造的gas消耗应该在合理范围内", async function () {
            const tx = await myNFT.mintNFT(addr1.address, sampleTokenURI);
            const receipt = await tx.wait();
            
            console.log(`单次铸造Gas消耗: ${receipt.gasUsed.toString()}`);
            
            // Gas消耗应该小于200,000（这是一个合理的上限）
            expect(receipt.gasUsed).to.be.lt(200000);
        });

        it("批量铸造应该比单次铸造更高效", async function () {
            // 单次铸造两个NFT
            const tx1 = await myNFT.mintNFT(addr1.address, sampleTokenURI);
            const receipt1 = await tx1.wait();
            const tx2 = await myNFT.mintNFT(addr2.address, sampleTokenURI2);
            const receipt2 = await tx2.wait();
            const singleMintGas = receipt1.gasUsed + receipt2.gasUsed;

            // 重新部署合约进行批量铸造测试
            const MyNFT = await ethers.getContractFactory("MyNFT");
            const newNFT = await MyNFT.deploy("TestNFT", "TNFT");
            await newNFT.waitForDeployment();

            // 批量铸造两个NFT
            const batchTx = await newNFT.batchMintNFT(
                [addr1.address, addr2.address], 
                [sampleTokenURI, sampleTokenURI2]
            );
            const batchReceipt = await batchTx.wait();

            console.log(`单次铸造总Gas: ${singleMintGas.toString()}`);
            console.log(`批量铸造Gas: ${batchReceipt.gasUsed.toString()}`);

            // 批量铸造应该更高效（使用更少的gas）
            expect(batchReceipt.gasUsed).to.be.lt(singleMintGas);
        });
    });
});
