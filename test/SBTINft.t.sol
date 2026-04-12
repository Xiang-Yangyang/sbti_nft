// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/SBTINft.sol";

contract SBTINftGasTest is Test {
    SBTINft public nft;
    address public user = address(0xBEEF);

    function setUp() public {
        nft = new SBTINft();
        vm.deal(user, 10 ether);
    }

    // ============ Gas 测试: mint ============
    function test_gas_mint() public {
        vm.prank(user);
        uint256 tokenId = nft.mint{value: 0.0001 ether}();
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), user);
        // cardSeed 应该被设置
        assertTrue(nft.cardSeed(0) != 0);
    }

    // ============ Gas 测试: tokenURI (blank card, 普通卡) ============
    function test_gas_tokenURI_blank_normal() public {
        // 反复 mint 直到拿到普通卡
        uint256 tokenId;
        bool found = false;
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(user);
            tokenId = nft.mint{value: 0.0001 ether}();
            if (!nft.isGoldCard(tokenId)) {
                found = true;
                break;
            }
        }
        require(found, "No normal card found in 50 mints");

        // 测 tokenURI gas
        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
    }

    // ============ Gas 测试: tokenURI (blank card, 金卡) ============
    function test_gas_tokenURI_blank_gold() public {
        // 反复 mint 直到拿到金卡
        uint256 tokenId;
        bool found = false;
        for (uint256 i = 0; i < 200; i++) {
            vm.prank(user);
            tokenId = nft.mint{value: 0.0001 ether}();
            if (nft.isGoldCard(tokenId)) {
                found = true;
                break;
            }
        }
        require(found, "No gold card found in 200 mints");

        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
    }

    // ============ Gas 测试: inscribe 铭刻 ============
    function test_gas_inscribe() public {
        vm.prank(user);
        uint256 tokenId = nft.mint{value: 0.0001 ether}();

        // 铭刻参数: personalityIndex=5(ENFJ), 15个维度, matchPercent=85
        uint8[15] memory dims = [
            uint8(3), 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1
        ];

        vm.prank(user);
        nft.inscribe(tokenId, 5, dims, 85);

        assertTrue(nft.isInscribed(tokenId));
    }

    // ============ Gas 测试: tokenURI (inscribed card, 铭刻后) ============
    function test_gas_tokenURI_inscribed() public {
        vm.prank(user);
        uint256 tokenId = nft.mint{value: 0.0001 ether}();

        uint8[15] memory dims = [
            uint8(3), 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1
        ];

        vm.prank(user);
        nft.inscribe(tokenId, 5, dims, 85);

        // 铭刻后的 tokenURI
        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
    }

    // ============ Gas 测试: 全流程 mint → inscribe → tokenURI ============
    function test_gas_full_flow() public {
        // Step 1: Mint
        vm.prank(user);
        uint256 tokenId = nft.mint{value: 0.0001 ether}();

        // Step 2: 查看空白卡 tokenURI
        string memory blankURI = nft.tokenURI(tokenId);
        assertTrue(bytes(blankURI).length > 0);

        // Step 3: 铭刻
        uint8[15] memory dims = [
            uint8(3), 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1, 3, 2, 1
        ];
        vm.prank(user);
        nft.inscribe(tokenId, 5, dims, 85);

        // Step 4: 查看铭刻后 tokenURI
        string memory inscribedURI = nft.tokenURI(tokenId);
        assertTrue(bytes(inscribedURI).length > 0);

        // 验证两个 URI 不同
        assertTrue(
            keccak256(bytes(blankURI)) != keccak256(bytes(inscribedURI)),
            "Blank and inscribed URIs should differ"
        );
    }

    // ============ Gas 测试: isGoldCard 查询 ============
    function test_gas_isGoldCard() public {
        vm.prank(user);
        uint256 tokenId = nft.mint{value: 0.0001 ether}();
        // 查询是否金卡（view 调用）
        nft.isGoldCard(tokenId);
    }

    // ============ Gas 测试: 连续 mint 5 个 ============
    function test_gas_mint_5x() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user);
            nft.mint{value: 0.0001 ether}();
        }
        assertEq(nft.totalSupply(), 5);
    }
}
