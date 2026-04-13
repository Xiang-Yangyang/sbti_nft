// 生产环境配置（BSC 主网）
const SBTI_CONFIG = {
  // 合约地址（部署主网后替换）
  CONTRACT_ADDRESS: '0x你的主网合约地址',
  
  // 主网 Chain ID
  CHAIN_ID: 56,
  CHAIN_NAME: 'BNB Smart Chain Mainnet',
  
  // 区块浏览器
  EXPLORER_URL: 'https://bscscan.com',
  EXPLORER_TX_URL: 'https://bscscan.com/tx/',
  EXPLORER_ADDRESS_URL: 'https://bscscan.com/address/',
  
  // OpenSea (主网)
  OPENSEA_URL: 'https://opensea.io/assets/bsc',
  
  // 备用 RPC（根据实测速度优化，并发竞速）
  RPC_URLS: [
    // 第一梯队（< 1.5 秒，最优先）
    'https://bsc-mainnet.nodereal.io/v1/64a9df0874fb4a93b9d0a3849de012d3',
    'https://bsc-dataseed2.defibit.io',
    'https://bsc-mainnet.public.blastapi.io',
    
    // 第二梯队（< 2 秒，备用）
    'https://bsc.publicnode.com',
    'https://bsc-dataseed3.defibit.io',
    'https://bsc-dataseed4.defibit.io',
    
    // 第三梯队（Binance 官方，虽然经常超时但还是保留）
    'https://bsc-dataseed.binance.org',
    'https://bsc-dataseed1.binance.org',
    'https://bsc-dataseed2.binance.org',
  ],
  
  // 默认 RPC（最快的那个）
  RPC_URL: 'https://bsc-mainnet.nodereal.io/v1/64a9df0874fb4a93b9d0a3849de012d3',
  
  // 原生币信息
  NATIVE_CURRENCY: {
    name: 'BNB',
    symbol: 'BNB',
    decimals: 18,
  },
  
  // 网络参数（用于添加网络到钱包）
  NETWORK_PARAMS: {
    chainId: '0x38', // 56 的十六进制
    chainName: 'BNB Smart Chain Mainnet',
    nativeCurrency: {
      name: 'BNB',
      symbol: 'BNB',
      decimals: 18,
    },
    rpcUrls: ['https://bsc-mainnet.nodereal.io/v1/64a9df0874fb4a93b9d0a3849de012d3'],
    blockExplorerUrls: ['https://bscscan.com/'],
  },
  
  // DEBUG 开关（生产环境关闭）
  DEBUG: false,
};
