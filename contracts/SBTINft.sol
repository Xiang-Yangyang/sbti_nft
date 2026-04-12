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
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.0001 ether;

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

        emit Minted(msg.sender, tokenId);
        return tokenId;
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

    // 空白卡片 URI（未做测试）
    function _blankCardURI(uint256 tokenId) internal pure returns (string memory) {
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 500" style="background:#1a1a2e">',
            '<defs><linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:#e94560"/><stop offset="100%" style="stop-color:#0f3460"/>',
            '</linearGradient></defs>',
            '<rect x="40" y="40" width="320" height="420" rx="20" fill="none" stroke="url(#g1)" stroke-width="3"/>',
            '<text x="200" y="200" text-anchor="middle" fill="#e94560" font-size="48" font-family="monospace">SBTI</text>',
            '<text x="200" y="250" text-anchor="middle" fill="#8888aa" font-size="16" font-family="sans-serif">Soul Card #',
            tokenId.toString(),
            '</text>',
            '<text x="200" y="310" text-anchor="middle" fill="#555577" font-size="14" font-family="sans-serif">',
            unicode'[ 等待灵魂铭刻 ]',
            '</text>',
            '<circle cx="200" cy="380" r="20" fill="none" stroke="#e94560" stroke-width="1" opacity="0.5">',
            '<animate attributeName="r" values="15;25;15" dur="2s" repeatCount="indefinite"/>',
            '<animate attributeName="opacity" values="0.3;0.8;0.3" dur="2s" repeatCount="indefinite"/>',
            '</circle>',
            '</svg>'
        ));

        string memory json = string(abi.encodePacked(
            '{"name":"SBTI Soul Card #', tokenId.toString(),
            '","description":"An blank SBTI soul card awaiting inscription.",',
            '"attributes":[{"trait_type":"Status","value":"Blank"}],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
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

        string memory json = string(abi.encodePacked(
            '{"name":"SBTI #', tokenId.toString(), ' | ', pCode,
            '","description":"', pName, ' - SBTI Soul Stele, permanently inscribed on-chain.",',
            '"attributes":[',
                '{"trait_type":"Personality","value":"', pCode, '"},',
                '{"trait_type":"Name","value":"', pName, '"},',
                '{"trait_type":"Match","value":"', uint256(matchPct).toString(), '%"},',
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
        // 维度柱状图
        string memory bars = _buildDimensionBars(dims, color1);

        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 560" style="background:#0a0a0f">',
            '<defs><linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:', color1, '"/><stop offset="100%" style="stop-color:', color2, '"/>',
            '</linearGradient></defs>',
            // 灵魂碑外框
            '<path d="M60,160 L60,500 L340,500 L340,160 Q340,60 200,60 Q60,60 60,160Z" fill="none" stroke="url(#g1)" stroke-width="2.5"/>',
            // SOUL INSCRIBED
            '<text x="200" y="120" text-anchor="middle" fill="', color1, '" font-size="20" font-family="serif" letter-spacing="4">SOUL STELE</text>',
            // 人格代码（大字）
            '<text x="200" y="195" text-anchor="middle" fill="url(#g1)" font-size="52" font-family="monospace" font-weight="bold">', pCode, '</text>',
            // 人格名称
            '<text x="200" y="230" text-anchor="middle" fill="#8888aa" font-size="18" font-family="sans-serif">', pName, '</text>',
            // 匹配度
            '<text x="200" y="262" text-anchor="middle" fill="#555566" font-size="13" font-family="monospace">Match: ', uint256(matchPct).toString(), '%</text>',
            // 分隔线
            '<line x1="90" y1="278" x2="310" y2="278" stroke="#333344" stroke-width="0.5"/>',
            // 维度柱状图
            bars,
            // Token ID
            '<text x="200" y="490" text-anchor="middle" fill="#333344" font-size="11" font-family="monospace">#', tokenId.toString(), '</text>',
            '</svg>'
        ));
    }

    function _buildDimensionBars(uint8[15] memory dims, string memory color) internal pure returns (string memory) {
        string[15] memory labels = [
            "S1","S2","S3","E1","E2","E3","A1","A2","A3","Ac1","Ac2","Ac3","So1","So2","So3"
        ];
        
        bytes memory result = "";
        for (uint8 i = 0; i < 15; i++) {
            uint256 barWidth = uint256(dims[i]) * 26; // L=26, M=52, H=78
            uint256 yPos = 295 + uint256(i) * 12;
            
            // 维度标签
            result = abi.encodePacked(result,
                '<text x="88" y="', (yPos + 9).toString(), '" text-anchor="end" fill="#555566" font-size="9" font-family="monospace">', labels[i], '</text>'
            );
            // 背景条
            result = abi.encodePacked(result,
                '<rect x="94" y="', yPos.toString(), '" width="78" height="8" rx="2" fill="#1a1a2e"/>'
            );
            // 数值条
            result = abi.encodePacked(result,
                '<rect x="94" y="', yPos.toString(), '" width="', barWidth.toString(), '" height="8" rx="2" fill="', color, '" opacity="0.7"/>'
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
