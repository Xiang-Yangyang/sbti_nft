// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/SBTIRenderer.sol";
import "../contracts/SBTINft.sol";

/**
 * @title DeploySBTI
 * @notice 部署 SBTI NFT（分体架构：Renderer + Core）
 * @dev 先部署 Renderer，再部署 Core（传入 Renderer 地址）
 *
 * 用法:
 *   测试网: source .env && forge script script/Deploy.s.sol:DeploySBTI --rpc-url $RPC_URL --broadcast -vvv
 *   正式网: source .env.mainnet && forge script script/Deploy.s.sol:DeploySBTI --rpc-url $RPC_URL --broadcast -vvv
 */
contract DeploySBTI is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0.018 ether));
        bool autoSetPrice = vm.envOr("AUTO_SET_PRICE", false);

        console.log("=== SBTI NFT Deployment (Split Architecture) ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Mint Price (wei):", mintPrice);
        console.log("Auto Set Price:", autoSetPrice);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署渲染合约
        SBTIRenderer rendererContract = new SBTIRenderer();
        console.log("SBTIRenderer deployed at:", address(rendererContract));

        // 2. 部署主合约（传入渲染器地址）
        SBTINft nft = new SBTINft(address(rendererContract));
        console.log("SBTINft deployed at:", address(nft));

        // 3. 如果配置了自动设置价格且价格与默认值不同
        if (autoSetPrice && mintPrice != 0.018 ether) {
            nft.setMintPrice(mintPrice);
            console.log("Mint price updated to:", mintPrice);
        }

        vm.stopBroadcast();

        // 4. 输出摘要
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Renderer:", address(rendererContract));
        console.log("Contract:", address(nft));
        console.log("Final Mint Price (wei):", nft.mintPrice());
        console.log("Max Supply:", nft.MAX_SUPPLY());
        console.log("Owner:", nft.owner());
        console.log("");
        console.log("NOTE: Update frontend/config.js with new contract address!");
    }
}
