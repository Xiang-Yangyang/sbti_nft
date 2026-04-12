// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/SBTINft.sol";

contract DeploySBTI is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SBTINft nft = new SBTINft();
        console.log("SBTINft deployed at:", address(nft));

        vm.stopBroadcast();
    }
}
