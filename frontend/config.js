/**
 * SBTI NFT — 全局配置
 * 所有合约地址、网络参数集中管理，修改一处即可全局生效
 */
const SBTI_CONFIG = {
  // ============ 合约地址 ============
  CONTRACT_ADDRESS: '0x4263f3996e5eaF7a98cA210Aa5749353d898Faf4',
  RENDERER_ADDRESS: '0x3536F55238fb9Dac3781Bf81631e3b927051099A',

  // ============ 网络配置 ============
  CHAIN_ID: 56,                    // BSC Mainnet
  CHAIN_NAME: 'BNB Smart Chain',
  RPC_URL: 'https://bsc-dataseed1.binance.org',
  // 备用 RPC（并发竞速，谁先返回用谁）
  RPC_URLS: [
    'https://bsc-dataseed1.binance.org',
    'https://bsc-dataseed2.binance.org',
    'https://bsc-dataseed3.binance.org',
    'https://bsc-dataseed4.binance.org',
    'https://bsc-dataseed1.defibit.io',
    'https://bsc-dataseed2.defibit.io',
    'https://bsc-dataseed1.ninicoin.io',
    'https://bsc-dataseed2.ninicoin.io',
    'https://bsc.drpc.org',
  ],
  EXPLORER_URL: 'https://bscscan.com',
  CURRENCY_SYMBOL: 'BNB',

  // ============ 合约 ABI ============
  CONTRACT_ABI: [
    'function mint() external payable returns (uint256)',
    'function inscribe(uint256 tokenId, uint8 personalityIndex, uint8[15] dimensions, uint8 matchPercent, string username) external',
    'function isInscribed(uint256) view returns (bool)',
    'function totalSupply() view returns (uint256)',
    'function MAX_SUPPLY() view returns (uint256)',
    'function mintPrice() view returns (uint256)',
    'function tokenURI(uint256) view returns (string)',
    'function balanceOf(address) view returns (uint256)',
    'function ownerOf(uint256) view returns (address)',
    'function getSoulStele(uint256) view returns (uint8 personalityIndex, uint8[15] dimensions, uint32 inscribeTime, uint8 matchPercent)',
    'function getUsername(uint256) view returns (string)',
    'function inscribedUsername(uint256) view returns (string)',
    'function personalityCodes(uint256) view returns (string)',
    'function personalityNames(uint256) view returns (string)',
    'function isGoldCard(uint256) view returns (bool)',
    'function cardSeed(uint256) view returns (uint256)',
    'event Minted(address indexed owner, uint256 indexed tokenId)',
    'event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)',
    'event Inscribed(uint256 indexed tokenId, uint8 personalityIndex, uint8 matchPercent)',
  ],

  // ============ 辅助方法 ============
  contractUrl() {
    return `${this.EXPLORER_URL}/address/${this.CONTRACT_ADDRESS}`;
  },
};
