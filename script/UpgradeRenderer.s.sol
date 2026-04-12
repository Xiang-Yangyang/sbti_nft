// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/SBTIRenderer.sol";
import "../contracts/SBTINft.sol";

/**
 * @title UpgradeRenderer
 * @notice 仅升级 Renderer 合约（不动主合约）
 * @dev 部署新 Renderer → 调用 SBTINft.setRenderer(新地址)
 *
 * 用法:
 *   source .env && forge script script/UpgradeRenderer.s.sol:UpgradeRenderer \
 *     --rpc-url $BSC_TESTNET_RPC_URL --broadcast -vvv
 */
contract UpgradeRenderer is Script {
    // 主合约地址（不变）
    address constant SBTI_NFT = 0xB6279d850B63cfBba46B08b3eD92D0175019ce55;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Upgrade SBTIRenderer ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("SBTINft (unchanged):", SBTI_NFT);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署新的渲染合约
        SBTIRenderer newRenderer = new SBTIRenderer();
        console.log("New SBTIRenderer deployed at:", address(newRenderer));

        // 2. 调用主合约 setRenderer 指向新渲染器
        SBTINft nft = SBTINft(SBTI_NFT);
        nft.setRenderer(address(newRenderer));
        console.log("setRenderer() called successfully");

        vm.stopBroadcast();

        // 3. 输出摘要
        console.log("");
        console.log("=== Upgrade Summary ===");
        console.log("Old Renderer: 0xf556d5900c67D1c667C654fca8DEdadA01014356");
        console.log("New Renderer:", address(newRenderer));
        console.log("SBTINft:", SBTI_NFT);
        console.log("");
        console.log("NOTE: Update frontend/config.js RENDERER_ADDRESS with new address!");
    }
}
