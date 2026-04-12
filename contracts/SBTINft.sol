// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ISBTIRenderer.sol";

/**
 * @title SBTINft
 * @notice SBTI 灵魂碑 NFT — 购买空白卡片，做人格测试，结果永久刻在链上灵魂碑
 * @dev ERC-721 + 链上 SVG（委托 Renderer 渲染）+ EIP-4906 Metadata 刷新
 *      数据合约 / 渲染合约分离架构，渲染器可独立升级
 */
contract SBTINft is ERC721, Ownable {
    using Strings for uint256;

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
    mapping(uint256 => uint256) public steleData;

    // NFT 是否已铭刻
    mapping(uint256 => bool) public isInscribed;

    // 铭刻者用户名
    mapping(uint256 => string) public inscribedUsername;

    // ============ 视觉随机种子 ============
    mapping(uint256 => uint256) public cardSeed;
    uint256 public constant GOLD_CHANCE = 10;

    // 人格名称映射
    string[27] public personalityNames;
    string[27] public personalityCodes;

    // ============ 渲染器（可升级） ============
    ISBTIRenderer public renderer;

    // ============ 事件 ============
    event Minted(address indexed owner, uint256 indexed tokenId);
    event Inscribed(uint256 indexed tokenId, uint8 personalityIndex, uint8 matchPercent);
    event RendererUpdated(address indexed oldRenderer, address indexed newRenderer);

    // ============ 构造函数 ============
    constructor(address _renderer) ERC721("SBTI Soul Stele", "SBTI") Ownable(msg.sender) {
        renderer = ISBTIRenderer(_renderer);

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

    // ============ 渲染器管理 ============
    function setRenderer(address _renderer) external onlyOwner {
        address old = address(renderer);
        renderer = ISBTIRenderer(_renderer);
        emit RendererUpdated(old, _renderer);
    }

    // ============ Mint ============
    function mint() external payable returns (uint256) {
        require(_nextTokenId < MAX_SUPPLY, "Sold out");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

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

    // ============ 铭刻灵魂碑 ============
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

        uint256 packed = 0;
        packed |= uint256(personalityIndex);
        for (uint8 i = 0; i < 15; i++) {
            require(dimensions[i] >= 1 && dimensions[i] <= 3, "Invalid dimension");
            packed |= uint256(dimensions[i]) << (5 + i * 2);
        }
        packed |= uint256(uint32(block.timestamp)) << 35;
        packed |= uint256(matchPercent) << 67;

        steleData[tokenId] = packed;
        inscribedUsername[tokenId] = username;
        isInscribed[tokenId] = true;

        emit Inscribed(tokenId, personalityIndex, matchPercent);
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

    // ============ tokenURI — 委托渲染器 ============
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        if (!isInscribed[tokenId]) {
            return renderer.blankCardURI(tokenId, cardSeed[tokenId]);
        } else {
            uint8 pIndex = uint8(steleData[tokenId] & 0x1F);
            return renderer.steleURI(
                tokenId,
                cardSeed[tokenId],
                steleData[tokenId],
                inscribedUsername[tokenId],
                personalityCodes[pIndex],
                personalityNames[pIndex]
            );
        }
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
