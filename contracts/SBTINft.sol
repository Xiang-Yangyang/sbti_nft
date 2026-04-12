// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title SBTINft
 * @notice SBTI 灵魂碑 NFT — 购买空白卡片，做人格测试，结果永久刻在链上灵魂碑
 * @dev ERC-721 + 链上 SVG 动态生成 + EIP-4906 Metadata 刷新
 */
contract SBTINft is ERC721, Ownable {
    using Strings for uint256;
    using Strings for uint16;

    // ============ EIP-4906: Metadata Update ============
    event MetadataUpdate(uint256 _tokenId);

    // ============ 常量 ============
    uint256 public constant MAX_SUPPLY = 16384; // 2^14
    uint256 public mintPrice = 0.015 ether;

    // ============ 状态 ============
    uint256 private _nextTokenId;
    
    // 灵魂碑数据结构 —— 打包进一个 uint256
    // personalityCode: 人格编号 (0-26, 5 bits)
    // dimensions: 15个维度值 (每个2bits: 0=未测, 1=L, 2=M, 3=H, 共30 bits)
    // timestamp: 铭刻时间 (32 bits)
    // totalScore: 匹配度 (7 bits, 0-100)
    // 总计: 5 + 30 + 32 + 7 = 74 bits < 256 bits
    mapping(uint256 => uint256) public steleData;
    
    // NFT 是否已铭刻（做完测试）
    mapping(uint256 => bool) public isInscribed;

    // 铭刻者用户名（链上存储）
    mapping(uint256 => string) public inscribedUsername;

    // ============ 视觉随机种子 ============
    // mint 时生成，决定渐变角度、颜色偏移、是否金卡
    mapping(uint256 => uint256) public cardSeed;
    uint256 public constant GOLD_CHANCE = 10; // 10% 金卡概率

    // 人格名称映射
    string[27] public personalityNames;
    string[27] public personalityCodes;

    // ============ 事件 ============
    event Minted(address indexed owner, uint256 indexed tokenId);
    event Inscribed(uint256 indexed tokenId, uint8 personalityIndex, uint8 matchPercent);

    // ============ 构造函数 ============
    constructor() ERC721("SBTI Soul Stele", "SBTI") Ownable(msg.sender) {
        // 25 种标准人格
        personalityCodes[0] = "CTRL";    personalityNames[0] = unicode"拿捏者";
        personalityCodes[1] = "ATM-er";  personalityNames[1] = unicode"送钱者";
        personalityCodes[2] = "Dior-s";  personalityNames[2] = unicode"屌丝";
        personalityCodes[3] = "BOSS";    personalityNames[3] = unicode"领导者";
        personalityCodes[4] = "THAN-K";  personalityNames[4] = unicode"感恩者";
        personalityCodes[5] = "OH-NO";   personalityNames[5] = unicode"哦不人";
        personalityCodes[6] = "GOGO";    personalityNames[6] = unicode"行者";
        personalityCodes[7] = "SEXY";    personalityNames[7] = unicode"尤物";
        personalityCodes[8] = "LOVE-R";  personalityNames[8] = unicode"多情者";
        personalityCodes[9] = "MUM";     personalityNames[9] = unicode"妈妈";
        personalityCodes[10] = "FAKE";   personalityNames[10] = unicode"伪人";
        personalityCodes[11] = "OJBK";   personalityNames[11] = unicode"无所谓人";
        personalityCodes[12] = "MALO";   personalityNames[12] = unicode"吗喽";
        personalityCodes[13] = "JOKE-R"; personalityNames[13] = unicode"小丑";
        personalityCodes[14] = "WOC!";   personalityNames[14] = unicode"握草人";
        personalityCodes[15] = "THIN-K"; personalityNames[15] = unicode"思考者";
        personalityCodes[16] = "SHIT";   personalityNames[16] = unicode"愤世者";
        personalityCodes[17] = "ZZZZ";   personalityNames[17] = unicode"装死者";
        personalityCodes[18] = "POOR";   personalityNames[18] = unicode"贫困者";
        personalityCodes[19] = "MONK";   personalityNames[19] = unicode"僧人";
        personalityCodes[20] = "IMSB";   personalityNames[20] = unicode"傻者";
        personalityCodes[21] = "SOLO";   personalityNames[21] = unicode"孤儿";
        personalityCodes[22] = "FUCK";   personalityNames[22] = unicode"草者";
        personalityCodes[23] = "DEAD";   personalityNames[23] = unicode"死者";
        personalityCodes[24] = "IMFW";   personalityNames[24] = unicode"废物";
        // 2 种隐藏人格
        personalityCodes[25] = "HHHH";   personalityNames[25] = unicode"傻乐者";
        personalityCodes[26] = "DRUNK";  personalityNames[26] = unicode"酒鬼";
    }

    // ============ Mint ============
    function mint() external payable returns (uint256) {
        require(_nextTokenId < MAX_SUPPLY, "Sold out");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        // 链上随机种子：决定渐变角度、颜色偏移、是否金卡
        cardSeed[tokenId] = uint256(keccak256(abi.encodePacked(
            block.timestamp, block.prevrandao, tokenId, msg.sender
        )));

        emit Minted(msg.sender, tokenId);
        return tokenId;
    }

    // ============ 种子查询 ============
    function isGoldCard(uint256 tokenId) public view returns (bool) {
        return (cardSeed[tokenId] % 100) < GOLD_CHANCE;
    }

    // ============ 铭刻灵魂碑（写入测试结果） ============
    /**
     * @notice 将 SBTI 测试结果铭刻到 NFT 上，不可逆
     * @param tokenId NFT ID
     * @param personalityIndex 人格编号 (0-26)
     * @param dimensions 15个维度值，每个 1=L, 2=M, 3=H
     * @param matchPercent 匹配度百分比 (0-100)
     * @param username 铭刻者用户名（最长 20 字节）
     */
    function inscribe(
        uint256 tokenId,
        uint8 personalityIndex,
        uint8[15] calldata dimensions,
        uint8 matchPercent,
        string calldata username
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not your NFT");
        require(!isInscribed[tokenId], "Already inscribed");
        require(personalityIndex <= 26, "Invalid personality");
        require(matchPercent <= 100, "Invalid match percent");
        require(bytes(username).length > 0 && bytes(username).length <= 20, "Username 1-20 bytes");

        // 打包数据到 uint256
        uint256 packed = 0;
        
        // 人格编号 (5 bits)
        packed |= uint256(personalityIndex);
        
        // 15个维度值 (每个2 bits, 共30 bits)
        for (uint8 i = 0; i < 15; i++) {
            require(dimensions[i] >= 1 && dimensions[i] <= 3, "Invalid dimension");
            packed |= uint256(dimensions[i]) << (5 + i * 2);
        }
        
        // 铭刻时间戳 (32 bits)
        packed |= uint256(uint32(block.timestamp)) << 35;
        
        // 匹配度 (7 bits)
        packed |= uint256(matchPercent) << 67;

        steleData[tokenId] = packed;
        inscribedUsername[tokenId] = username;
        isInscribed[tokenId] = true;

        emit Inscribed(tokenId, personalityIndex, matchPercent);
        // EIP-4906: 通知 MetaMask / OpenSea 等平台刷新该 token 的 metadata
        emit MetadataUpdate(tokenId);
    }

    // ============ 解包灵魂碑数据 ============
    function getSoulStele(uint256 tokenId) public view returns (
        uint8 personalityIndex,
        uint8[15] memory dimensions,
        uint32 inscribeTime,
        uint8 matchPercent
    ) {
        require(isInscribed[tokenId], "Not inscribed yet");
        uint256 packed = steleData[tokenId];

        personalityIndex = uint8(packed & 0x1F);
        
        for (uint8 i = 0; i < 15; i++) {
            dimensions[i] = uint8((packed >> (5 + i * 2)) & 0x3);
        }
        
        inscribeTime = uint32((packed >> 35) & 0xFFFFFFFF);
        matchPercent = uint8((packed >> 67) & 0x7F);
    }

    function getUsername(uint256 tokenId) public view returns (string memory) {
        require(isInscribed[tokenId], "Not inscribed yet");
        return inscribedUsername[tokenId];
    }

    // ============ 动态 tokenURI（链上 SVG） ============
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        if (!isInscribed[tokenId]) {
            return _blankCardURI(tokenId);
        } else {
            return _steleURI(tokenId);
        }
    }

    // ============ 颜色环（与 preview_nft_svg.html 完全一致） ============
    // 普通卡 8色环（闭环，最后一个 = 第一个）
    function _normalRing(uint256 idx) internal pure returns (string memory) {
        if (idx == 0) return "#72efdd";
        if (idx == 1) return "#4cc9f0";
        if (idx == 2) return "#4361ee";
        if (idx == 3) return "#7209b7";
        if (idx == 4) return "#b5179e";
        if (idx == 5) return "#f72585";
        if (idx == 6) return "#ff6fff";
        return "#72efdd"; // idx == 7, 闭环
    }
    // 金卡 8色环（闭环）
    function _goldRing(uint256 idx) internal pure returns (string memory) {
        if (idx == 0) return "#ffd700";
        if (idx == 1) return "#ffb800";
        if (idx == 2) return "#ff8c00";
        if (idx == 3) return "#ffa500";
        if (idx == 4) return "#ffe066";
        if (idx == 5) return "#ffd700";
        if (idx == 6) return "#ff9500";
        return "#ffb800"; // idx == 7, 闭环
    }

    // 从种子获取渐变角度坐标 (模拟 JS randomAngle)
    // 返回 x1,y1,x2,y2 百分比字符串
    function _gradientCoords(uint256 seed) internal pure returns (
        string memory x1, string memory y1, string memory x2, string memory y2
    ) {
        // 用 seed 的一部分取 0-359 度角
        uint256 angle = (seed >> 8) % 360;
        // 简化三角函数：用查表法（每30度一档，12档）
        // cos/sin 查表 × 50，结果 = 50 ± lookup
        uint256 sector = angle / 30; // 0-11
        uint256 cx; uint256 cy;
        // cos*50 和 sin*50 的近似值（12个扇区）
        if (sector == 0)  { cx = 50; cy = 0;  }
        else if (sector == 1)  { cx = 43; cy = 25; }
        else if (sector == 2)  { cx = 25; cy = 43; }
        else if (sector == 3)  { cx = 0;  cy = 50; }
        else if (sector == 4)  { cx = 25; cy = 43; } // cos负 → 50-25=25
        else if (sector == 5)  { cx = 43; cy = 25; }
        else if (sector == 6)  { cx = 50; cy = 0;  }
        else if (sector == 7)  { cx = 43; cy = 25; }
        else if (sector == 8)  { cx = 25; cy = 43; }
        else if (sector == 9)  { cx = 0;  cy = 50; }
        else if (sector == 10) { cx = 25; cy = 43; }
        else                   { cx = 43; cy = 25; }

        // 根据象限决定加减
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

    // 根据种子和 offset 获取旋转后色环中的颜色
    function _getRingColor(uint256 offset, uint256 idx, bool gold) internal pure returns (string memory) {
        uint256 mapped = (idx + offset) % 7; // 7色（去掉闭环尾）
        return gold ? _goldRing(mapped) : _normalRing(mapped);
    }

    // 空白卡片 URI（1:1 复刻 preview_nft_svg.html，含随机 + 金卡）
    function _blankCardURI(uint256 tokenId) internal view returns (string memory) {
        uint256 seed = cardSeed[tokenId];
        bool gold = (seed % 100) < GOLD_CHANCE;
        uint256 colorOffset = (seed >> 16) % 7;

        // 渐变坐标
        (string memory gx1, string memory gy1, string memory gx2, string memory gy2) = _gradientCoords(seed);

        string memory svg = _blankPart1(gold);
        svg = string(abi.encodePacked(svg, _blankPart2(gold, colorOffset, gx1, gy1, gx2, gy2)));
        svg = string(abi.encodePacked(svg, _blankPart3(gold)));
        svg = string(abi.encodePacked(svg, _blankPart4(tokenId, gold)));

        // metadata
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

    // Part1: SVG头 + defs（渐变定义）
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

    // Part2: 更多 defs + 背景 + 光晕 + 边框
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

    // 构建 8 色渐变 stops（边框和外围光晕共用）
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

    // Part3: 外围光晕 + 卡片背景 + 背景光晕 + 边框 + 五角星 + 粒子
    function _blankPart3(bool gold) internal pure returns (string memory) {
        // 五角星中心点颜色
        string memory centerDotColor = gold ? "#ffd700" : "#72efdd";
        // 粒子颜色
        string memory p1 = gold ? "#ffd700" : "#72efdd";
        string memory p2 = gold ? "#ffb800" : "#4cc9f0";
        string memory p3 = gold ? "#ff9500" : "#7209b7";
        // 边框宽度
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

    // Part4: 文字内容 + 底部标签
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

    // 灵魂碑 URI（已完成测试）
    function _steleURI(uint256 tokenId) internal view returns (string memory) {
        (
            uint8 pIndex,
            uint8[15] memory dims,
            uint32 inscribeTime,
            uint8 matchPct
        ) = getSoulStele(tokenId);

        string memory pCode = personalityCodes[pIndex];
        string memory pName = personalityNames[pIndex];
        string memory username = inscribedUsername[tokenId];
        
        // 根据人格类型选择配色
        string memory color1;
        string memory color2;
        (color1, color2) = _getPersonalityColors(pIndex);

        // 格式化铭刻时间为 YYYY-MM-DD
        string memory timeStr = _formatTimestamp(inscribeTime);

        // 继承 Card 的渐变参数（种子 → 角度 + 色环偏移）
        bool gold = isGoldCard(tokenId);
        uint256 seed = cardSeed[tokenId];
        uint256 colorOffset = (seed >> 16) % 7;
        (string memory gx1, string memory gy1, string memory gx2, string memory gy2) = _gradientCoords(seed);

        string memory svg = _steleDefs(color1, color2, gold, colorOffset, gx1, gy1, gx2, gy2);
        svg = string(abi.encodePacked(svg, _steleBody(pCode, pName, color1, username, matchPct)));
        svg = string(abi.encodePacked(svg, _steleBars(dims, color1, timeStr, tokenId)));

        // 金碑: SBTI Golden Stele #xx | CODE, 普通碑: SBTI Stele #xx | CODE
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

    // Stele defs: SVG头 + 所有渐变/滤镜 + 碑体结构 + 星尘粒子（合并原Part1+Part2）
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
            // bdr: 边框+外发光共用一个渐变
            '<linearGradient id="bdr" x1="', gx1, '" y1="', gy1, '" x2="', gx2, '" y2="', gy2, '">', bs, '</linearGradient>'
            '<filter id="gB"><feGaussianBlur stdDeviation="12"/></filter></defs>',
            // 外发光 + 光晕 + 碑体 + 星尘粒子
            '<path d="M26,85 L26,354 Q26,374 48,374 L352,374 Q374,374 374,354 L374,85 Q374,11 200,11 Q26,11 26,85Z" fill="none" stroke="url(#bdr)" stroke-width="10" filter="url(#gB)" opacity=".9"/>'
            '<circle cx="200" cy="120" r="130" fill="url(#gw)"/>'
            '<path d="M30,85 L30,352 Q30,370 48,370 L352,370 Q370,370 370,352 L370,85 Q370,15 200,15 Q30,15 30,85Z" fill="url(#cb)" stroke="url(#bdr)" stroke-width="2" opacity=".7"/>'
            '<circle cx="90" cy="82" r="1" fill="', c1, '" opacity=".4"/>'
            '<circle cx="310" cy="75" r=".8" fill="', c1, '" opacity=".5"/>'
            '<circle cx="120" cy="52" r="1.2" fill="', c1, '" opacity=".3"/>'
            '<circle cx="280" cy="60" r=".7" fill="', c1, '" opacity=".4"/>'
        ));
    }

    // Stele body: 文字内容（标题+用户名+人格代号+名称+匹配度进度条+分隔线）
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

    // Stele bars: 维度柱状图 + 底部分隔 + 时间 + Token ID
    function _steleBars(
        uint8[15] memory dims, string memory c,
        string memory timeStr, uint256 tokenId
    ) internal pure returns (string memory) {
        bytes memory r = _dimBars(dims, c);
        return string(abi.encodePacked(r,
            '<rect x="60" y="332" width="280" height="1" rx=".5" fill="url(#dv)"/>'
            '<text x="200" y="345" text-anchor="middle" fill="#445" font-size="9" font-family="monospace" letter-spacing="1">', timeStr, '</text>'
            '<text x="200" y="358" text-anchor="middle" fill="#556" font-size="10" font-family="monospace" font-weight="bold">#', tokenId.toString(), '</text></svg>'
        ));
    }

    function _dimBars(uint8[15] memory dims, string memory c) internal pure returns (bytes memory) {
        string[15] memory lb = ["S1","S2","S3","E1","E2","E3","A1","A2","A3","Ac1","Ac2","Ac3","So1","So2","So3"];
        bytes memory r = "";
        for (uint8 i = 0; i < 15; i++) {
            uint256 yp = 178 + uint256(i) * 10;
            r = abi.encodePacked(r,
                '<text x="83" y="', (yp + 7).toString(), '" text-anchor="end" fill="#556" font-size="8" font-family="monospace">', lb[i], '</text>'
                '<rect x="88" y="', yp.toString(), '" width="78" height="7" rx="2" fill="#1a1a2e"/>'
                '<rect x="88" y="', yp.toString(), '" width="', (uint256(dims[i]) * 26).toString(), '" height="7" rx="2" fill="', c, '" opacity=".7"/>'
            );
        }
        return r;
    }

    // ============ 时间戳格式化 ============
    function _formatTimestamp(uint32 ts) internal pure returns (string memory) {
        // 简化的 Unix 时间戳 → "YYYY-MM-DD" 转换
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

    function _getPersonalityColors(uint8 pIndex) internal pure returns (string memory, string memory) {
        // 紧凑查表：27对颜色 × 2 × 3字节(RGB) = 162字节
        // 每行6字节: color1_RGB + color2_RGB
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

    // ============ 管理函数 ============
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }
}
