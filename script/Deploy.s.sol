// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/SBTINft.sol";

/**
 * @title DeploySBTI
 * @notice 部署 SBTI NFT 合约，支持多环境配置
 * @dev 通过环境变量 MINT_PRICE 和 AUTO_SET_PRICE 控制部署后行为
 *
 * 用法:
 *   测试网: source .env.testnet && forge script script/Deploy.s.sol:DeploySBTI --rpc-url $RPC_URL --broadcast -vvv
 *   正式网: source .env.mainnet && forge script script/Deploy.s.sol:DeploySBTI --rpc-url $RPC_URL --broadcast -vvv
 */
contract DeploySBTI is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 读取可选的价格配置（默认 0.015 ether = 合约构造函数默认值）
        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0.015 ether));
        bool autoSetPrice = vm.envOr("AUTO_SET_PRICE", false);

        console.log("=== SBTI NFT Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Mint Price (wei):", mintPrice);
        console.log("Auto Set Price:", autoSetPrice);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署合约
        SBTINft nft = new SBTINft();
        console.log("SBTINft deployed at:", address(nft));

        // 2. 如果配置了自动设置价格且价格与默认值不同，则调用 setMintPrice
        if (autoSetPrice && mintPrice != 0.015 ether) {
            nft.setMintPrice(mintPrice);
            console.log("Mint price updated to:", mintPrice);
        }

        vm.stopBroadcast();

        // 3. 输出摘要
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Contract:", address(nft));
        console.log("Final Mint Price (wei):", nft.mintPrice());
        console.log("Max Supply:", nft.MAX_SUPPLY());
        console.log("Owner:", nft.owner());
    }
}
