require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "london",
          metadata: {
            bytecodeHash: "ipfs"
          },
        },
      },
    ]
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      chainId: 11155111,
    },
    // mainnet: {
    //   url: process.env.MAINNET_RPC_URL,
    //   accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
    //   chainId: 1,
    // }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  sourcify: {
    enabled: true
  },
  gasReporter: {
    enabled: true,             // 开启
    showMethodSig: true,       // 方法显示为函数签名
    // currency: "USD",           // 可显示费用（需要价格源）
    // coinmarketcap: process.env.CMC_API_KEY || undefined, // 可选
    // outputFile: "gas-report.txt",
    noColors: true,
    onlyCalledMethods: true,   // 只展示测试里实际被调用的方法
  },
};