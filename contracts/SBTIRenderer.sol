// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./ISBTIRenderer.sol";

/**
 * @title SBTIRenderer
 * @notice SBTI 灵魂碑 SVG 渲染器 — 负责所有链上图片生成
 * @dev 纯计算合约，无状态存储。主合约通过接口调用。可独立升级。
 */
contract SBTIRenderer is ISBTIRenderer {
    using Strings for uint256;

    uint256 private constant GOLD_CHANCE = 10;

    // ============ 接口实现 ============

    function blankCardURI(
        uint256 tokenId,
        uint256 seed
    ) external pure override returns (string memory) {
        bool gold = (seed % 100) < GOLD_CHANCE;
        uint256 colorOffset = (seed >> 16) % 7;

        (string memory gx1, string memory gy1, string memory gx2, string memory gy2) = _gradientCoords(seed);

        string memory svg = _blankPart1(gold);
        svg = string(abi.encodePacked(svg, _blankPart2(gold, colorOffset, gx1, gy1, gx2, gy2)));
        svg = string(abi.encodePacked(svg, _blankPart3(gold)));
        svg = string(abi.encodePacked(svg, _blankPart4(tokenId, gold)));

        string memory rarity = gold ? "Gold" : "Normal";
        string memory cardName = gold
            ? string(abi.encodePacked("SBTI Soul Golden Card #", tokenId.toString()))
            : string(abi.encodePacked("SBTI Soul Card #", tokenId.toString()));
        string memory desc = gold
            ? "A rare golden SBTI soul card awaiting inscription."
            : "A blank SBTI soul card awaiting inscription.";
        string memory json = string(abi.encodePacked(
            '{"name":"', cardName,
            '","description":"', desc, '",',
            '"attributes":[{"trait_type":"Status","value":"Blank"},{"trait_type":"Rarity","value":"', rarity, '"}],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function steleURI(
        uint256 tokenId,
        uint256 seed,
        uint256 packedSteleData,
        string memory username,
        string memory pCode,
        string memory pName
    ) external pure override returns (string memory) {
        // 解包 steleData
        uint8 pIndex = uint8(packedSteleData & 0x1F);
        uint8[15] memory dims;
        for (uint8 i = 0; i < 15; i++) {
            dims[i] = uint8((packedSteleData >> (5 + i * 2)) & 0x3);
        }
        uint32 inscribeTime = uint32((packedSteleData >> 35) & 0xFFFFFFFF);
        uint8 matchPct = uint8((packedSteleData >> 67) & 0x7F);

        (string memory c1, string memory c2) = _getPersonalityColors(pIndex);
        string memory timeStr = _formatTimestamp(inscribeTime);

        bool gold = (seed % 100) < GOLD_CHANCE;
        uint256 colorOffset = (seed >> 16) % 7;
        (string memory gx1, string memory gy1, string memory gx2, string memory gy2) = _gradientCoords(seed);

        string memory svg = _steleDefs(c1, c2, gold, colorOffset, gx1, gy1, gx2, gy2);
        svg = string(abi.encodePacked(svg, _steleBody(pCode, pName, c1, username, matchPct)));
        svg = string(abi.encodePacked(svg, _steleBars(dims, c1, timeStr, tokenId)));

        string memory inscribedName = gold
            ? string(abi.encodePacked("SBTI Golden Stele #", tokenId.toString(), " | ", pCode))
            : string(abi.encodePacked("SBTI Stele #", tokenId.toString(), " | ", pCode));
        string memory rarity = gold ? "Gold" : "Normal";
        string memory desc = string(abi.encodePacked(
            username, ' is ', pName, ' (SBTI) - SBTI Soul Stele, permanently inscribed on-chain on ', timeStr, '.'
        ));
        string memory json = string(abi.encodePacked(
            '{"name":"', inscribedName,
            '","description":"', desc, '",',
            '"attributes":[',
                '{"trait_type":"Personality","value":"', pCode, '"},',
                '{"trait_type":"Name","value":"', pName, '"},',
                '{"trait_type":"Match","value":"', uint256(matchPct).toString(), '%"},',
                '{"trait_type":"Rarity","value":"', rarity, '"},',
                '{"trait_type":"Username","value":"', username, '"},',
                '{"trait_type":"Status","value":"Inscribed"}',
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // ============ 颜色环 ============

    function _normalRing(uint256 idx) internal pure returns (string memory) {
        if (idx == 0) return "#72efdd";
        if (idx == 1) return "#4cc9f0";
        if (idx == 2) return "#4361ee";
        if (idx == 3) return "#7209b7";
        if (idx == 4) return "#b5179e";
        if (idx == 5) return "#f72585";
        if (idx == 6) return "#ff6fff";
        return "#72efdd";
    }

    function _goldRing(uint256 idx) internal pure returns (string memory) {
        if (idx == 0) return "#ffd700";
        if (idx == 1) return "#ffb800";
        if (idx == 2) return "#ff8c00";
        if (idx == 3) return "#ffa500";
        if (idx == 4) return "#ffe066";
        if (idx == 5) return "#ffd700";
        if (idx == 6) return "#ff9500";
        return "#ffb800";
    }

    function _getRingColor(uint256 offset, uint256 idx, bool gold) internal pure returns (string memory) {
        uint256 mapped = (idx + offset) % 7;
        return gold ? _goldRing(mapped) : _normalRing(mapped);
    }

    // ============ 渐变坐标 ============

    function _gradientCoords(uint256 seed) internal pure returns (
        string memory x1, string memory y1, string memory x2, string memory y2
    ) {
        uint256 angle = (seed >> 8) % 360;
        uint256 sector = angle / 30;
        uint256 cx; uint256 cy;
        if (sector == 0)       { cx = 50; cy = 0;  }
        else if (sector == 1)  { cx = 43; cy = 25; }
        else if (sector == 2)  { cx = 25; cy = 43; }
        else if (sector == 3)  { cx = 0;  cy = 50; }
        else if (sector == 4)  { cx = 25; cy = 43; }
        else if (sector == 5)  { cx = 43; cy = 25; }
        else if (sector == 6)  { cx = 50; cy = 0;  }
        else if (sector == 7)  { cx = 43; cy = 25; }
        else if (sector == 8)  { cx = 25; cy = 43; }
        else if (sector == 9)  { cx = 0;  cy = 50; }
        else if (sector == 10) { cx = 25; cy = 43; }
        else                   { cx = 43; cy = 25; }

        uint256 x1v; uint256 y1v; uint256 x2v; uint256 y2v;
        if (angle < 90) {
            x1v = 50 - cx; y1v = 50 - cy; x2v = 50 + cx; y2v = 50 + cy;
        } else if (angle < 180) {
            x1v = 50 + cy; y1v = 50 - cx; x2v = 50 > cy ? 50 - cy : 0; y2v = 50 + cx;
        } else if (angle < 270) {
            x1v = 50 + cx; y1v = 50 + cy; x2v = 50 > cx ? 50 - cx : 0; y2v = 50 > cy ? 50 - cy : 0;
        } else {
            x1v = 50 > cy ? 50 - cy : 0; y1v = 50 + cx; x2v = 50 + cy; y2v = 50 > cx ? 50 - cx : 0;
        }

        x1 = string(abi.encodePacked(x1v.toString(), "%"));
        y1 = string(abi.encodePacked(y1v.toString(), "%"));
        x2 = string(abi.encodePacked(x2v.toString(), "%"));
        y2 = string(abi.encodePacked(y2v.toString(), "%"));
    }

    // ============ 空白卡片 SVG ============

    function _blankPart1(bool gold) internal pure returns (string memory) {
        string memory g1c0 = gold ? "#ffd700" : "#72efdd";
        string memory g1c1 = gold ? "#ffb800" : "#4cc9f0";
        string memory g1c2 = gold ? "#ff8c00" : "#7209b7";
        string memory gc = gold ? "#ffd700" : "#4cc9f0";
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400"><defs>'
            '<linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">'
            '<stop offset="0%" stop-color="', g1c0, '"/><stop offset="50%" stop-color="', g1c1, '"/><stop offset="100%" stop-color="', g1c2, '"/></linearGradient>'
            '<radialGradient id="glow" cx="50%" cy="50%" r="50%">'
            '<stop offset="0%" stop-color="', gc, '" stop-opacity=".15"/><stop offset="100%" stop-color="#0e0e1a" stop-opacity="0"/></radialGradient>'
        ));
    }

    function _blankPart2(
        bool gold, uint256 colorOffset,
        string memory gx1, string memory gy1, string memory gx2, string memory gy2
    ) internal pure returns (string memory) {
        string memory dc0 = gold ? "#ffd700" : "#4cc9f0";
        string memory dc1 = gold ? "#ffb800" : "#72efdd";
        string memory dc2 = gold ? "#ffe066" : "#4cc9f0";
        string memory bs = _buildGradientStops(colorOffset, gold);
        return string(abi.encodePacked(
            '<linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="0%">'
            '<stop offset="0%" stop-color="#f6d365"/><stop offset="50%" stop-color="#d4a843"/><stop offset="100%" stop-color="#fda085"/></linearGradient>'
            '<linearGradient id="dv" x1="0%" y1="0%" x2="100%" y2="0%">'
            '<stop offset="0%" stop-color="', dc0, '" stop-opacity="0"/>'
            '<stop offset="25%" stop-color="', dc1, '" stop-opacity=".6"/>'
            '<stop offset="50%" stop-color="', dc2, '" stop-opacity="1"/>'
            '<stop offset="75%" stop-color="', dc1, '" stop-opacity=".6"/>'
            '<stop offset="100%" stop-color="', dc0, '" stop-opacity="0"/></linearGradient>',
            '<linearGradient id="cb" x1="30%" y1="0%" x2="70%" y2="100%">'
            '<stop offset="0%" stop-color="#0e0e1a"/><stop offset="40%" stop-color="#161625"/><stop offset="100%" stop-color="#1a1a30"/></linearGradient>'
            '<linearGradient id="b1" x1="', gx1, '" y1="', gy1, '" x2="', gx2, '" y2="', gy2, '">', bs, '</linearGradient>'
        ));
    }

    function _buildGradientStops(uint256 colorOffset, bool gold) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<stop offset="0%" stop-color="', _getRingColor(colorOffset, 0, gold), '"/>'
            '<stop offset="15%" stop-color="', _getRingColor(colorOffset, 1, gold), '"/>'
            '<stop offset="30%" stop-color="', _getRingColor(colorOffset, 2, gold), '"/>'
            '<stop offset="50%" stop-color="', _getRingColor(colorOffset, 3, gold), '"/>',
            '<stop offset="65%" stop-color="', _getRingColor(colorOffset, 4, gold), '"/>'
            '<stop offset="80%" stop-color="', _getRingColor(colorOffset, 5, gold), '"/>'
            '<stop offset="90%" stop-color="', _getRingColor(colorOffset, 6, gold), '"/>'
            '<stop offset="100%" stop-color="', _getRingColor(colorOffset, 0, gold), '"/>'
        ));
    }

    function _blankPart3(bool gold) internal pure returns (string memory) {
        string memory centerDotColor = gold ? "#ffd700" : "#72efdd";
        string memory p1 = gold ? "#ffd700" : "#72efdd";
        string memory p2 = gold ? "#ffb800" : "#4cc9f0";
        string memory p3 = gold ? "#ff9500" : "#7209b7";
        string memory borderWidth = gold ? "2.5" : "2";

        return string(abi.encodePacked(
            '<filter id="gB"><feGaussianBlur stdDeviation="12"/></filter></defs>',
            '<rect width="400" height="400" fill="#0a0a0f"/>'
            '<rect x="26" y="26" width="348" height="348" rx="20" fill="none" stroke="url(#b1)" stroke-width="10" filter="url(#gB)" opacity=".9"/>'
            '<rect x="30" y="30" width="340" height="340" rx="18" fill="url(#cb)"/>'
            '<circle cx="200" cy="185" r="125" fill="url(#glow)"/>'
            '<rect x="30" y="30" width="340" height="340" rx="18" fill="none" stroke="url(#b1)" stroke-width="', borderWidth, '" opacity=".7"/>'
            '<polygon points="200,65 214,105 258,105 222,130 234,170 200,148 166,170 178,130 142,105 186,105" fill="none" stroke="url(#g1)" stroke-width="2.5"/>'
            '<circle cx="200" cy="125" r="23" fill="none" stroke="url(#g1)" stroke-width="1" opacity=".6"/>'
            '<circle cx="200" cy="125" r="6" fill="', centerDotColor, '" opacity=".9"/>',
            '<circle cx="85" cy="120" r="1.2" fill="', p1, '" opacity=".5"/>'
            '<circle cx="310" cy="135" r="1" fill="', p2, '" opacity=".4"/>'
            '<circle cx="120" cy="280" r="1.3" fill="', p3, '" opacity=".5"/>'
            '<circle cx="300" cy="290" r="1" fill="', p1, '" opacity=".3"/>'
            '<circle cx="150" cy="100" r=".8" fill="', p2, '" opacity=".6"/>'
            '<circle cx="270" cy="310" r="1.1" fill="', p3, '" opacity=".4"/>'
        ));
    }

    function _blankPart4(uint256 tokenId, bool gold) internal pure returns (string memory) {
        string memory pulseColor = gold ? "#ffd700" : "#72efdd";

        return string(abi.encodePacked(
            '<text x="200" y="220" text-anchor="middle" fill="url(#g1)" font-size="48" font-family="monospace" font-weight="800" letter-spacing="10">SBTI</text>'
            '<text x="200" y="246" text-anchor="middle" fill="rgba(255,255,255,.35)" font-size="14" font-family="sans-serif" font-weight="300" letter-spacing="4">Soul Card</text>'
            '<rect x="140" y="261" width="120" height="1.5" rx="1" fill="url(#dv)"/>',
            '<circle cx="155" cy="284" r="3" fill="', pulseColor, '" opacity=".6">'
            '<animate attributeName="opacity" values=".4;1;.4" dur="2s" repeatCount="indefinite"/>'
            '</circle>'
            '<text x="210" y="288" text-anchor="middle" fill="rgba(255,255,255,.4)" font-size="12" font-family="sans-serif" letter-spacing="2">',
            unicode'等待灵魂铭刻',
            '</text>',
            '<rect x="155" y="306" width="90" height="22" rx="11" fill="none" stroke="rgba(85,85,102,.5)" stroke-width="1"/>'
            '<text x="200" y="321" text-anchor="middle" fill="rgba(114,239,221,.5)" font-size="10" font-family="monospace" font-weight="600" letter-spacing="2">SBTI NFT</text>'
            '<text x="200" y="344" text-anchor="middle" fill="url(#gold)" font-size="11" font-family="monospace" font-weight="bold">#', tokenId.toString(), '</text></svg>'
        ));
    }

    // ============ 灵魂碑 SVG ============

    function _steleDefs(
        string memory c1, string memory c2,
        bool gold, uint256 colorOffset,
        string memory gx1, string memory gy1, string memory gx2, string memory gy2
    ) internal pure returns (string memory) {
        string memory bs = _buildGradientStops(colorOffset, gold);
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="background:#0a0a0f"><defs>'
            '<linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">'
            '<stop offset="0%" stop-color="', c1, '"/><stop offset="100%" stop-color="', c2, '"/></linearGradient>'
            '<radialGradient id="gw" cx="50%" cy="30%" r="45%">'
            '<stop offset="0%" stop-color="', c1, '" stop-opacity=".15"/><stop offset="100%" stop-color="#0a0a0f" stop-opacity="0"/></radialGradient>'
            '<linearGradient id="dv" x1="0%" y1="0%" x2="100%" y2="0%">'
            '<stop offset="0%" stop-color="', c1, '" stop-opacity="0"/><stop offset="50%" stop-color="', c1, '" stop-opacity=".5"/><stop offset="100%" stop-color="', c1, '" stop-opacity="0"/></linearGradient>'
            '<linearGradient id="cb" x1="30%" y1="0%" x2="70%" y2="100%">'
            '<stop offset="0%" stop-color="#0e0e1a"/><stop offset="40%" stop-color="#161625"/><stop offset="100%" stop-color="#1a1a30"/></linearGradient>',
            '<linearGradient id="bdr" x1="', gx1, '" y1="', gy1, '" x2="', gx2, '" y2="', gy2, '">', bs, '</linearGradient>'
            '<filter id="gB"><feGaussianBlur stdDeviation="12"/></filter></defs>',
            '<path d="M26,85 L26,354 Q26,374 48,374 L352,374 Q374,374 374,354 L374,85 Q374,11 200,11 Q26,11 26,85Z" fill="none" stroke="url(#bdr)" stroke-width="10" filter="url(#gB)" opacity=".9"/>'
            '<circle cx="200" cy="120" r="130" fill="url(#gw)"/>'
            '<path d="M30,85 L30,352 Q30,370 48,370 L352,370 Q370,370 370,352 L370,85 Q370,15 200,15 Q30,15 30,85Z" fill="url(#cb)" stroke="url(#bdr)" stroke-width="2" opacity=".7"/>'
            '<circle cx="90" cy="82" r="1" fill="', c1, '" opacity=".4"/>'
            '<circle cx="310" cy="75" r=".8" fill="', c1, '" opacity=".5"/>'
            '<circle cx="120" cy="52" r="1.2" fill="', c1, '" opacity=".3"/>'
            '<circle cx="280" cy="60" r=".7" fill="', c1, '" opacity=".4"/>'
        ));
    }

    function _steleBody(
        string memory pCode, string memory pName, string memory c1,
        string memory username, uint8 matchPct
    ) internal pure returns (string memory) {
        uint256 barW = uint256(matchPct) * 80 / 100;
        return string(abi.encodePacked(
            '<text x="200" y="60" text-anchor="middle" fill="', c1, '" font-size="11" font-family="monospace" letter-spacing="5" opacity=".9">SBTI STELE</text>'
            '<text x="200" y="78" text-anchor="middle" fill="#6a6a88" font-size="9" font-family="monospace" letter-spacing="2">', username, '</text>'
            '<text x="200" y="118" text-anchor="middle" fill="url(#g1)" font-size="44" font-family="monospace" font-weight="800" letter-spacing="8">', pCode, '</text>'
            '<text x="200" y="138" text-anchor="middle" fill="#8888aa" font-size="14" font-family="sans-serif" font-weight="300" letter-spacing="4">', pName, '</text>',
            '<text x="155" y="155" text-anchor="end" fill="', c1, '" font-size="9" font-family="monospace" font-weight="bold">', uint256(matchPct).toString(), '%</text>'
            '<rect x="160" y="149" width="80" height="5" rx="2.5" fill="#1a1a2e"/>'
            '<rect x="160" y="149" width="', barW.toString(), '" height="5" rx="2.5" fill="', c1, '" opacity=".8"/>'
            '<rect x="60" y="166" width="280" height="1" rx=".5" fill="url(#dv)"/>'
        ));
    }

    function _steleBars(
        uint8[15] memory dims, string memory c,
        string memory timeStr, uint256 tokenId
    ) internal pure returns (string memory) {
        bytes memory r = _dimBlocks(dims, c);
        return string(abi.encodePacked(r,
            '<rect x="60" y="332" width="280" height="1" rx=".5" fill="url(#dv)"/>'
            '<text x="200" y="345" text-anchor="middle" fill="#445" font-size="9" font-family="monospace" letter-spacing="1">', timeStr, '</text>'
            '<text x="200" y="358" text-anchor="middle" fill="#556" font-size="10" font-family="monospace" font-weight="bold">#', tokenId.toString(), '</text></svg>'
        ));
    }

    /// @dev 5 大类分组 + 方块矩阵，与 about.html 对齐
    function _dimBlocks(uint8[15] memory dims, string memory c) internal pure returns (bytes memory) {
        bytes memory r = "";
        // SELF: dims[0..2] = S1,S2,S3
        r = abi.encodePacked(r, _groupTitle("SELF", "192", "#666677"));
        r = abi.encodePacked(r, _blockRow("S1", dims[0], "199", "120", "124", c));
        r = abi.encodePacked(r, _blockRow("S2", dims[1], "199", "177", "181", c));
        r = abi.encodePacked(r, _blockRow("S3", dims[2], "199", "234", "238", c));
        // EMOTION: dims[3..5] = E1,E2,E3
        r = abi.encodePacked(r, _groupTitle("EMOTION", "220", "#666677"));
        r = abi.encodePacked(r, _blockRow("E1", dims[3], "227", "120", "124", c));
        r = abi.encodePacked(r, _blockRow("E2", dims[4], "227", "177", "181", c));
        r = abi.encodePacked(r, _blockRow("E3", dims[5], "227", "234", "238", c));
        // ATTITUDE: dims[6..8] = A1,A2,A3
        r = abi.encodePacked(r, _groupTitle("ATTITUDE", "248", "#666677"));
        r = abi.encodePacked(r, _blockRow("A1", dims[6], "255", "120", "124", c));
        r = abi.encodePacked(r, _blockRow("A2", dims[7], "255", "177", "181", c));
        r = abi.encodePacked(r, _blockRow("A3", dims[8], "255", "234", "238", c));
        // ACTION: dims[9..11] = Ac1,Ac2,Ac3
        r = abi.encodePacked(r, _groupTitle("ACTION", "276", "#666677"));
        r = abi.encodePacked(r, _blockRow("Ac1", dims[9], "283", "120", "124", c));
        r = abi.encodePacked(r, _blockRow("Ac2", dims[10], "283", "177", "181", c));
        r = abi.encodePacked(r, _blockRow("Ac3", dims[11], "283", "234", "238", c));
        // SOCIAL: dims[12..14] = So1,So2,So3
        r = abi.encodePacked(r, _groupTitle("SOCIAL", "304", "#666677"));
        r = abi.encodePacked(r, _blockRow("So1", dims[12], "311", "120", "124", c));
        r = abi.encodePacked(r, _blockRow("So2", dims[13], "311", "177", "181", c));
        r = abi.encodePacked(r, _blockRow("So3", dims[14], "311", "234", "238", c));
        return r;
    }

    function _groupTitle(string memory name, string memory y, string memory fill) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<text x="200" y="', y, '" text-anchor="middle" fill="', fill, '" font-size="10" font-family="monospace" letter-spacing="3">', name, '</text>'
        );
    }

    /// @dev 渲染一个维度的标签 + 5 个方块（亮色=有值，暗色=空）
    function _blockRow(
        string memory label, uint8 val, string memory y,
        string memory labelX, string memory startX, string memory c
    ) internal pure returns (bytes memory) {
        uint256 sx = _parseUint(startX);
        uint256 ly = _parseUint(y) + 5; // label y = blockY + 5
        bytes memory r = abi.encodePacked(
            '<text x="', labelX, '" y="', ly.toString(), '" text-anchor="end" fill="#555566" font-size="9" font-family="monospace">', label, '</text>'
        );
        for (uint8 j = 0; j < 5; j++) {
            uint256 bx = sx + uint256(j) * 7;
            if (j < val) {
                r = abi.encodePacked(r, '<rect x="', bx.toString(), '" y="', y, '" width="5" height="5" rx="1" fill="', c, '" opacity=".85"/>');
            } else {
                r = abi.encodePacked(r, '<rect x="', bx.toString(), '" y="', y, '" width="5" height="5" rx="1" fill="#1a1a2e"/>');
            }
        }
        return r;
    }

    function _parseUint(string memory s) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            result = result * 10 + (uint8(b[i]) - 48);
        }
    }

    // ============ 时间戳格式化 ============

    function _formatTimestamp(uint32 ts) internal pure returns (string memory) {
        uint256 z = uint256(ts) / 86400 + 719468;
        uint256 era = z / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        uint256 y = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        uint256 d = doy - (153 * mp + 2) / 5 + 1;
        uint256 m = mp < 10 ? mp + 3 : mp - 9;
        if (m <= 2) y += 1;

        return string(abi.encodePacked(
            y.toString(), "-",
            m < 10 ? "0" : "", m.toString(), "-",
            d < 10 ? "0" : "", d.toString()
        ));
    }

    // ============ 人格颜色查表 ============

    function _getPersonalityColors(uint8 pIndex) internal pure returns (string memory, string memory) {
        bytes memory tbl = hex"e945600f3460" hex"ffd700ff6b35" hex"888888444444" hex"ffd700b8860b"
            hex"ff69b4ff1493" hex"ff4444cc0000" hex"00ff88009955" hex"ff69b48b008b"
            hex"ff6b9dc44569" hex"ffb6c1ff69b4" hex"9b59b66c3483" hex"95a5a67f8c8d"
            hex"8b4513d2691e" hex"ffff00ff6600" hex"00ffff0099cc" hex"4169e11e3a8a"
            hex"dc143c8b0000" hex"7080902f4f4f" hex"cd853f8b7355" hex"daa520b8860b"
            hex"98fb9866cdaa" hex"4682b42c3e50" hex"ff4500cc3700" hex"2c2c2c111111"
            hex"696969363636" hex"ff00ffff69b4" hex"00ff00006600";
        uint256 off = uint256(pIndex) * 6;
        return (_hexColor(tbl, off), _hexColor(tbl, off + 3));
    }

    function _hexColor(bytes memory tbl, uint256 off) internal pure returns (string memory) {
        bytes memory o = new bytes(7);
        o[0] = "#";
        bytes16 hex16 = "0123456789abcdef";
        for (uint256 i = 0; i < 3; i++) {
            uint8 b = uint8(tbl[off + i]);
            o[1 + i * 2] = hex16[b >> 4];
            o[2 + i * 2] = hex16[b & 0x0f];
        }
        return string(o);
    }
}
