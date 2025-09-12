# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
REPORT_GAS=true npx hardhat test

npx hardhat help
#运行测试
npx hardhat test 
#启动本地测试网络
npx hardhat node 

npx hardhat run scripts/demo.js
# 本地部署
npx hardhat ignition deploy ./ignition/modules/Lock.js 
npx hardhat ignition deploy ./ignition/modules/Lock.js --network localhost
# 测试网部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia 
# 测试网强制重新部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network sepolia --reset
# 主网部署
npx hardhat ignition deploy ./ignition/modules/Lock.js --network mainnet 



# 重新编译和部署
npx hardhat clean && npx hardhat compile && npm run deploy:task2:sepolia
#将 MyToken.sol 合约及其所有依赖的 import 文件合并到一个文件中
npx hardhat flatten contracts/task2/MyToken.sol > MyToken_flattened.sol
#合约验证/手动验证
npx hardhat verify --network sepolia 0x0A81015f205D4cBA59BA7996a9ce4362c2bfD5f0 "MyToken" "MTK" 18 1000000

```
