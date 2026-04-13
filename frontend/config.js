/**
 * SBTI NFT — 全局配置
 * 所有合约地址、网络参数集中管理，修改一处即可全局生效
 */
const SBTI_CONFIG = {
  // ============ 合约地址 ============
  CONTRACT_ADDRESS: '0xB6279d850B63cfBba46B08b3eD92D0175019ce55',
  RENDERER_ADDRESS: '0x515FA86dEcB6565905E880875Dd2D8455443b113',

  // ============ 网络配置 ============
  CHAIN_ID: 97,                    // BSC Testnet
  CHAIN_NAME: 'BSC Testnet',
  RPC_URL: 'https://data-seed-prebsc-1-s1.binance.org:8545',
  // 备用 RPC（按优先级排序，自动切换）
  RPC_URLS: [
    'https://data-seed-prebsc-1-s1.binance.org:8545',
    'https://bsc-testnet-rpc.publicnode.com',
    'https://data-seed-prebsc-2-s1.binance.org:8545',
    'https://data-seed-prebsc-1-s2.binance.org:8545',
  ],
  EXPLORER_URL: 'https://testnet.bscscan.com',
  CURRENCY_SYMBOL: 'tBNB',

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
