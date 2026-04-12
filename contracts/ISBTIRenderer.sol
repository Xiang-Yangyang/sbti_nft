// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ISBTIRenderer
 * @notice SBTI 渲染器接口 — 主合约通过此接口调用渲染合约生成 SVG + metadata
 */
interface ISBTIRenderer {
    /// @notice 生成空白卡片的完整 tokenURI（data:application/json;base64,...）
    function blankCardURI(
        uint256 tokenId,
        uint256 seed
    ) external pure returns (string memory);

    /// @notice 生成已铭刻灵魂碑的完整 tokenURI
    function steleURI(
        uint256 tokenId,
        uint256 seed,
        uint256 packedSteleData,
        string memory username,
        string memory personalityCode,
        string memory personalityName
    ) external pure returns (string memory);
}
