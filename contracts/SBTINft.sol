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
     */
    function inscribe(
        uint256 tokenId,
        uint8 personalityIndex,
        uint8[15] calldata dimensions,
        uint8 matchPercent
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not your NFT");
        require(!isInscribed[tokenId], "Already inscribed");
        require(personalityIndex <= 26, "Invalid personality");
        require(matchPercent <= 100, "Invalid match percent");

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

        string memory svg = _buildBlankSVG(tokenId, gold, colorOffset, gx1, gy1, gx2, gy2);

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

    function _buildBlankSVG(
        uint256 tokenId,
        bool gold,
        uint256 colorOffset,
        string memory gx1, string memory gy1, string memory gx2, string memory gy2
    ) internal pure returns (string memory) {
        string memory svg = _blankPart1(gold);
        svg = string(abi.encodePacked(svg, _blankPart2(gold, colorOffset, gx1, gy1, gx2, gy2)));
        svg = string(abi.encodePacked(svg, _blankPart3(gold)));
        svg = string(abi.encodePacked(svg, _blankPart4(tokenId, gold)));
        return svg;
    }

    // Part1: SVG头 + defs（渐变定义）
    function _blankPart1(
        bool gold
    ) internal pure returns (string memory) {
        // g1: SBTI标题渐变（金卡→金色系，普通→青蓝紫）
        string memory g1c0 = gold ? "#ffd700" : "#72efdd";
        string memory g1c1 = gold ? "#ffb800" : "#4cc9f0";
        string memory g1c2 = gold ? "#ff8c00" : "#7209b7";
        // glow: 背景光晕（金卡→暖金，普通→青蓝）
        string memory glowColor = gold ? "#ffd700" : "#4cc9f0";
        string memory glowOpacity = gold ? "0.15" : "0.15";

        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<defs>',
            // g1: 标题/五角星渐变
            '<linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">'
            '<stop offset="0%" style="stop-color:', g1c0, '"/>'
            '<stop offset="50%" style="stop-color:', g1c1, '"/>'
            '<stop offset="100%" style="stop-color:', g1c2, '"/>'
            '</linearGradient>',
            // glow: 背景径向光晕
            '<radialGradient id="glow" cx="50%" cy="50%" r="50%">'
            '<stop offset="0%" style="stop-color:', glowColor, ';stop-opacity:', glowOpacity, '"/>'
            '<stop offset="100%" style="stop-color:#0e0e1a;stop-opacity:0"/>'
            '</radialGradient>'
        ));
    }

    // Part2: 更多 defs + 背景 + 光晕 + 边框
    function _blankPart2(
        bool gold, uint256 colorOffset,
        string memory gx1, string memory gy1, string memory gx2, string memory gy2
    ) internal pure returns (string memory) {
        // gold渐变（tokenId 编号用）
        // divider 分隔线渐变
        string memory dc0 = gold ? "#ffd700" : "#4cc9f0";
        string memory dc1 = gold ? "#ffb800" : "#72efdd";
        string memory dc2 = gold ? "#ffe066" : "#4cc9f0";

        // 8色边框/光晕 stop
        string memory borderStops = _buildGradientStops(colorOffset, gold);

        return string(abi.encodePacked(
            // gold 渐变（编号用）
            '<linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="0%">'
            '<stop offset="0%" style="stop-color:#f6d365"/><stop offset="50%" style="stop-color:#d4a843"/><stop offset="100%" style="stop-color:#fda085"/>'
            '</linearGradient>',
            // divider 分隔线渐变
            '<linearGradient id="divider" x1="0%" y1="0%" x2="100%" y2="0%">'
            '<stop offset="0%" style="stop-color:', dc0, ';stop-opacity:0"/>'
            '<stop offset="25%" style="stop-color:', dc1, ';stop-opacity:0.6"/>'
            '<stop offset="50%" style="stop-color:', dc2, ';stop-opacity:1"/>'
            '<stop offset="75%" style="stop-color:', dc1, ';stop-opacity:0.6"/>'
            '<stop offset="100%" style="stop-color:', dc0, ';stop-opacity:0"/>'
            '</linearGradient>',
            // cardbg 卡片背景
            '<linearGradient id="cardbg" x1="30%" y1="0%" x2="70%" y2="100%">'
            '<stop offset="0%" style="stop-color:#0e0e1a"/>'
            '<stop offset="40%" style="stop-color:#161625"/>'
            '<stop offset="100%" style="stop-color:#1a1a30"/>'
            '</linearGradient>',
            // border1: 多彩/金色边框渐变（随机角度 + 随机偏移色环）
            '<linearGradient id="border1" x1="', gx1, '" y1="', gy1, '" x2="', gx2, '" y2="', gy2, '">',
            borderStops,
            '</linearGradient>'
        ));
    }

    // 构建 8 色渐变 stops（边框和外围光晕共用）
    function _buildGradientStops(uint256 colorOffset, bool gold) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<stop offset="0%" style="stop-color:', _getRingColor(colorOffset, 0, gold), '"/>'
            '<stop offset="15%" style="stop-color:', _getRingColor(colorOffset, 1, gold), '"/>'
            '<stop offset="30%" style="stop-color:', _getRingColor(colorOffset, 2, gold), '"/>'
            '<stop offset="50%" style="stop-color:', _getRingColor(colorOffset, 3, gold), '"/>',
            '<stop offset="65%" style="stop-color:', _getRingColor(colorOffset, 4, gold), '"/>'
            '<stop offset="80%" style="stop-color:', _getRingColor(colorOffset, 5, gold), '"/>'
            '<stop offset="90%" style="stop-color:', _getRingColor(colorOffset, 6, gold), '"/>'
            '<stop offset="100%" style="stop-color:', _getRingColor(colorOffset, 0, gold), '"/>'
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
            // 外围光晕滤镜 + 渐变（复用 border1 色彩）
            '<filter id="glowBlur" x="-30%" y="-30%" width="160%" height="160%">'
            '<feGaussianBlur stdDeviation="12" result="blur"/>'
            '</filter>'
            '</defs>',
            // 外部底色
            '<rect width="400" height="400" fill="#0a0a0f"/>',
            // 外围光晕（用 border1 渐变 + blur）
            '<rect x="26" y="26" width="348" height="348" rx="20" fill="none" stroke="url(#border1)" stroke-width="10" filter="url(#glowBlur)" opacity="0.9"/>',
            // 卡片背景
            '<rect x="30" y="30" width="340" height="340" rx="18" fill="url(#cardbg)"/>',
            // 背景光晕
            '<circle cx="200" cy="185" r="125" fill="url(#glow)"/>',
            // 边框
            '<rect x="30" y="30" width="340" height="340" rx="18" fill="none" stroke="url(#border1)" stroke-width="', borderWidth, '" opacity="0.7"/>',
            // 五角星
            '<polygon points="200,65 214,105 258,105 222,130 234,170 200,148 166,170 178,130 142,105 186,105" fill="none" stroke="url(#g1)" stroke-width="2.5"/>'
            '<circle cx="200" cy="125" r="23" fill="none" stroke="url(#g1)" stroke-width="1" opacity="0.6"/>'
            '<circle cx="200" cy="125" r="6" fill="', centerDotColor, '" opacity="0.9"/>',
            // 粒子光点
            '<circle cx="85" cy="120" r="1.2" fill="', p1, '" opacity="0.5"/>'
            '<circle cx="310" cy="135" r="1" fill="', p2, '" opacity="0.4"/>'
            '<circle cx="120" cy="280" r="1.3" fill="', p3, '" opacity="0.5"/>'
            '<circle cx="300" cy="290" r="1" fill="', p1, '" opacity="0.3"/>'
            '<circle cx="150" cy="100" r="0.8" fill="', p2, '" opacity="0.6"/>'
            '<circle cx="270" cy="310" r="1.1" fill="', p3, '" opacity="0.4"/>'
        ));
    }

    // Part4: 文字内容 + 底部标签
    function _blankPart4(uint256 tokenId, bool gold) internal pure returns (string memory) {
        string memory pulseColor = gold ? "#ffd700" : "#72efdd";

        return string(abi.encodePacked(
            // SBTI 大标题
            '<text x="200" y="220" text-anchor="middle" fill="url(#g1)" font-size="48" font-family="\'Courier New\',monospace" font-weight="800" letter-spacing="10">SBTI</text>',
            // Soul Card 副标题
            '<text x="200" y="246" text-anchor="middle" fill="rgba(255,255,255,0.35)" font-size="14" font-family="sans-serif" font-weight="300" letter-spacing="4">Soul Card</text>',
            // 分隔线
            '<rect x="140" y="261" width="120" height="1.5" rx="1" fill="url(#divider)"/>',
            // 脉冲圆点 + 状态文字
            '<circle cx="155" cy="284" r="3" fill="', pulseColor, '" opacity="0.6">'
            '<animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>'
            '</circle>'
            '<text x="210" y="288" text-anchor="middle" fill="rgba(255,255,255,0.4)" font-size="12" font-family="sans-serif" letter-spacing="2">',
            unicode'等待灵魂铭刻',
            '</text>',
            // 底部标签
            '<rect x="155" y="306" width="90" height="22" rx="11" fill="none" stroke="rgba(85,85,102,0.5)" stroke-width="1"/>'
            '<text x="200" y="321" text-anchor="middle" fill="rgba(114,239,221,0.5)" font-size="10" font-family="monospace" font-weight="600" letter-spacing="2">SBTI NFT</text>'
            '<text x="200" y="344" text-anchor="middle" fill="url(#gold)" font-size="11" font-family="monospace" font-weight="bold">#', tokenId.toString(), '</text>'
            '</svg>'
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
        
        // 根据人格类型选择配色
        string memory color1;
        string memory color2;
        (color1, color2) = _getPersonalityColors(pIndex);

        string memory svg = _buildSteleSVG(tokenId, pCode, pName, color1, color2, dims, matchPct);

        bool gold = isGoldCard(tokenId);
        string memory inscribedName = gold
            ? string(abi.encodePacked("SBTI Golden #", tokenId.toString(), " | ", pCode))
            : string(abi.encodePacked("SBTI #", tokenId.toString(), " | ", pCode));
        string memory rarity = gold ? "Gold" : "Normal";
        string memory json = string(abi.encodePacked(
            '{"name":"', inscribedName,
            '","description":"', pName, ' - SBTI Soul Stele, permanently inscribed on-chain.",',
            '"attributes":[',
                '{"trait_type":"Personality","value":"', pCode, '"},',
                '{"trait_type":"Name","value":"', pName, '"},',
                '{"trait_type":"Match","value":"', uint256(matchPct).toString(), '%"},',
                '{"trait_type":"Rarity","value":"', rarity, '"},',
                '{"trait_type":"Status","value":"Inscribed"}',
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _buildSteleSVG(
        uint256 tokenId,
        string memory pCode,
        string memory pName,
        string memory color1,
        string memory color2,
        uint8[15] memory dims,
        uint8 matchPct
    ) internal pure returns (string memory) {
        // 维度柱状图（紧凑版，适配 400×400）
        string memory bars = _buildDimensionBars(dims, color1);

        // Part 1: SVG 头部 + 装饰
        string memory part1 = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="background:#0a0a0f">',
            '<defs>'
            '<linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">'
            '<stop offset="0%" style="stop-color:', color1, '"/><stop offset="100%" style="stop-color:', color2, '"/>'
            '</linearGradient>'
            '<radialGradient id="glow" cx="50%" cy="35%" r="45%">'
            '<stop offset="0%" style="stop-color:', color1, ';stop-opacity:0.12"/><stop offset="100%" style="stop-color:#0a0a0f;stop-opacity:0"/>'
            '</radialGradient>'
            '</defs>',
            // 背景光晕
            '<circle cx="200" cy="140" r="130" fill="url(#glow)"/>',
            // 拱门形灵魂碑外框（缩放适配 400×400）
            '<path d="M55,130 L55,360 L345,360 L345,130 Q345,40 200,40 Q55,40 55,130Z" fill="none" stroke="url(#g1)" stroke-width="2"/>'
        ));

        // Part 2: 文字内容
        string memory part2 = string(abi.encodePacked(
            // SOUL STELE 标题
            '<text x="200" y="82" text-anchor="middle" fill="', color1, '" font-size="16" font-family="serif" letter-spacing="4">SOUL STELE</text>',
            // 人格代码（大字）
            '<text x="200" y="145" text-anchor="middle" fill="url(#g1)" font-size="44" font-family="monospace" font-weight="bold">', pCode, '</text>',
            // 人格名称
            '<text x="200" y="172" text-anchor="middle" fill="#8888aa" font-size="15" font-family="sans-serif">', pName, '</text>',
            // 匹配度
            '<text x="200" y="196" text-anchor="middle" fill="#555566" font-size="11" font-family="monospace">Match: ', uint256(matchPct).toString(), '%</text>',
            // 分隔线
            '<line x1="85" y1="208" x2="315" y2="208" stroke="#333344" stroke-width="0.5"/>'
        ));

        // Part 3: 维度条 + Token ID
        string memory part3 = string(abi.encodePacked(
            bars,
            // Token ID
            '<text x="200" y="380" text-anchor="middle" fill="#333344" font-size="10" font-family="monospace">#', tokenId.toString(), '</text>',
            '</svg>'
        ));

        return string(abi.encodePacked(part1, part2, part3));
    }

    function _buildDimensionBars(uint8[15] memory dims, string memory color) internal pure returns (string memory) {
        string[15] memory labels = [
            "S1","S2","S3","E1","E2","E3","A1","A2","A3","Ac1","Ac2","Ac3","So1","So2","So3"
        ];
        
        bytes memory result = "";
        for (uint8 i = 0; i < 15; i++) {
            uint256 barWidth = uint256(dims[i]) * 26; // L=26, M=52, H=78
            uint256 yPos = 220 + uint256(i) * 10;     // 起始 y=220，间隔 10px（更紧凑）
            
            // 维度标签
            result = abi.encodePacked(result,
                '<text x="83" y="', (yPos + 7).toString(), '" text-anchor="end" fill="#555566" font-size="8" font-family="monospace">', labels[i], '</text>'
            );
            // 背景条
            result = abi.encodePacked(result,
                '<rect x="88" y="', yPos.toString(), '" width="78" height="7" rx="2" fill="#1a1a2e"/>'
            );
            // 数值条
            result = abi.encodePacked(result,
                '<rect x="88" y="', yPos.toString(), '" width="', barWidth.toString(), '" height="7" rx="2" fill="', color, '" opacity="0.7"/>'
            );
        }
        return string(result);
    }

    function _getPersonalityColors(uint8 pIndex) internal pure returns (string memory, string memory) {
        // 按人格类型分配不同的渐变色
        if (pIndex == 0)  return ("#e94560", "#0f3460"); // CTRL 拿捏者 - 红蓝
        if (pIndex == 1)  return ("#ffd700", "#ff6b35"); // ATM-er 送钱者 - 金橙
        if (pIndex == 2)  return ("#888888", "#444444"); // Dior-s 屌丝 - 灰
        if (pIndex == 3)  return ("#ffd700", "#b8860b"); // BOSS 领导者 - 金
        if (pIndex == 4)  return ("#ff69b4", "#ff1493"); // THAN-K 感恩者 - 粉
        if (pIndex == 5)  return ("#ff4444", "#cc0000"); // OH-NO 哦不人 - 红
        if (pIndex == 6)  return ("#00ff88", "#009955"); // GOGO 行者 - 绿
        if (pIndex == 7)  return ("#ff69b4", "#8b008b"); // SEXY 尤物 - 粉紫
        if (pIndex == 8)  return ("#ff6b9d", "#c44569"); // LOVE-R 多情者 - 玫红
        if (pIndex == 9)  return ("#ffb6c1", "#ff69b4"); // MUM 妈妈 - 浅粉
        if (pIndex == 10) return ("#9b59b6", "#6c3483"); // FAKE 伪人 - 紫
        if (pIndex == 11) return ("#95a5a6", "#7f8c8d"); // OJBK 无所谓人 - 灰蓝
        if (pIndex == 12) return ("#8B4513", "#D2691E"); // MALO 吗喽 - 棕
        if (pIndex == 13) return ("#ffff00", "#ff6600"); // JOKE-R 小丑 - 黄橙
        if (pIndex == 14) return ("#00ffff", "#0099cc"); // WOC! 握草人 - 青
        if (pIndex == 15) return ("#4169e1", "#1e3a8a"); // THIN-K 思考者 - 蓝
        if (pIndex == 16) return ("#dc143c", "#8b0000"); // SHIT 愤世者 - 深红
        if (pIndex == 17) return ("#708090", "#2f4f4f"); // ZZZZ 装死者 - 石灰
        if (pIndex == 18) return ("#cd853f", "#8b7355"); // POOR 贫困者 - 土黄
        if (pIndex == 19) return ("#daa520", "#b8860b"); // MONK 僧人 - 金棕
        if (pIndex == 20) return ("#98fb98", "#66cdaa"); // IMSB 傻者 - 浅绿
        if (pIndex == 21) return ("#4682b4", "#2c3e50"); // SOLO 孤儿 - 钢蓝
        if (pIndex == 22) return ("#ff4500", "#cc3700"); // FUCK 草者 - 橙红
        if (pIndex == 23) return ("#2c2c2c", "#111111"); // DEAD 死者 - 黑
        if (pIndex == 24) return ("#696969", "#363636"); // IMFW 废物 - 深灰
        if (pIndex == 25) return ("#ff00ff", "#ff69b4"); // HHHH 傻乐者 - 品红
        return ("#00ff00", "#006600");                    // DRUNK 酒鬼 - 绿
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
