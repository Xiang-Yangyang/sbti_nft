/**
 * SBTI × NFT — 前端交互逻辑
 * 连接钱包 → Mint → 做测试 → 铭刻上链
 */

// ============ 调试日志 ============
const _debugLogs = [];
function debugLog(...args) {
  const timestamp = new Date().toLocaleTimeString();
  const msg = `[${timestamp}] ${args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ')}`;
  _debugLogs.push(msg);
  console.log('[SBTI]', ...args);
}
// 导出日志（控制台输入 exportLogs() 即可）
window.exportLogs = function() {
  const text = _debugLogs.join('\n');
  const blob = new Blob([text], { type: 'text/plain' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'debug.log';
  a.click();
  console.log(`已导出 ${_debugLogs.length} 条日志`);
};
// 控制台输入 showLogs() 查看全部日志
window.showLogs = function() {
  console.log(_debugLogs.join('\n'));
};

// ============ 全局状态 ============
let provider = null;
let signer = null;
let contract = null;
let userAddress = '';
let currentTokenId = null;

// 测试状态
let currentQuestion = 0;
let answers = [];
let isDrunkTriggered = false;
let showDrinkFollowup = false;

// 合约地址（部署后填入）
const CONTRACT_ADDRESS = '0xC665d48FAE84ac0aa7705151D67E8F92ddb7F406'; // BSC Testnet
const CONTRACT_ABI = [
  'function mint() external payable returns (uint256)',
  'function inscribe(uint256 tokenId, uint8 personalityIndex, uint8[15] dimensions, uint8 matchPercent) external',
  'function isInscribed(uint256) view returns (bool)',
  'function totalSupply() view returns (uint256)',
  'function mintPrice() view returns (uint256)',
  'function tokenURI(uint256) view returns (string)',
  'function balanceOf(address) view returns (uint256)',
  'function ownerOf(uint256) view returns (address)',
  'function getSoulStele(uint256) view returns (uint8 personalityIndex, uint8[15] dimensions, uint32 inscribeTime, uint8 matchPercent)',
  'function personalityCodes(uint256) view returns (string)',
  'function personalityNames(uint256) view returns (string)',
  'function isGoldCard(uint256) view returns (bool)',
  'function cardSeed(uint256) view returns (uint256)',
  'event Minted(address indexed owner, uint256 indexed tokenId)',
  'event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)',
  'event Inscribed(uint256 indexed tokenId, uint8 personalityIndex, uint8 matchPercent)',
];

// 用户持有的空白 NFT 列表
let userBlankNFTs = [];
// 用户持有的已铭刻 NFT 列表 (包含完整数据)
// 每项: { tokenId, personalityIndex, code, name, matchPercent, dimensions, inscribeTime }
let userInscribedNFTs = [];

// ============ BSC Testnet 配置 ============
const BSC_TESTNET_CHAIN_ID = '0x61'; // 97
const BSC_TESTNET_CONFIG = {
  chainId: BSC_TESTNET_CHAIN_ID,
  chainName: 'BSC Testnet',
  nativeCurrency: { name: 'tBNB', symbol: 'tBNB', decimals: 18 },
  rpcUrls: ['https://bsc-testnet-rpc.publicnode.com'],
  blockExplorerUrls: ['https://testnet.bscscan.com'],
};

// ============ 连接状态 ============
let isConnected = false; // 前端维护的连接状态
let currentWalletType = null; // 当前连接的钱包类型

// ============ 钱包 Provider 检测 ============
const WALLET_CONFIG = {
  metamask: {
    name: 'MetaMask',
    icon: 'https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg',
    getProvider: () => {
      // MetaMask 注入 window.ethereum 并设置 isMetaMask
      if (window.ethereum?.providers) {
        return window.ethereum.providers.find(p => p.isMetaMask && !p.isBraveWallet);
      }
      if (window.ethereum?.isMetaMask) return window.ethereum;
      return null;
    },
  },
  okx: {
    name: 'OKX Wallet',
    icon: 'images/okx.png',
    getProvider: () => {
      return window.okxwallet || null;
    },
  },
  binance: {
    name: 'Binance Wallet',
    icon: 'https://public.bnbstatic.com/static/images/common/favicon.ico',
    getProvider: () => {
      // 方法1: EIP-6963 发现的 provider（最新方式）
      if (window._eip6963Providers) {
        const binanceProvider = window._eip6963Providers.find(p =>
          p.info?.name?.toLowerCase().includes('binance')
        );
        if (binanceProvider) return binanceProvider.provider;
      }
      // 方法2: window.ethereum.providers 数组中查找
      if (window.ethereum?.providers) {
        const found = window.ethereum.providers.find(p =>
          p.isBinance || p.isBinanceChain || p.isBinanceW3W
        );
        if (found) return found;
      }
      // 方法3: 直接标记在 window.ethereum 上
      if (window.ethereum?.isBinance || window.ethereum?.isBinanceW3W) return window.ethereum;
      // 方法4: 旧版 Binance Chain Wallet
      if (window.BinanceChain) return window.BinanceChain;
      return null;
    },
  },
  bitget: {
    name: 'Bitget Wallet',
    icon: 'images/bitget.png',
    getProvider: () => {
      // 方法1: EIP-6963 发现的 provider
      if (window._eip6963Providers) {
        const bgProvider = window._eip6963Providers.find(p =>
          p.info?.name?.toLowerCase().includes('bitget') ||
          p.info?.rdns?.includes('bitget') ||
          p.info?.rdns?.includes('bitkeep')
        );
        if (bgProvider) return bgProvider.provider;
      }
      // 方法2: 官方推荐 window.bitkeep.ethereum
      if (window.bitkeep?.ethereum) return window.bitkeep.ethereum;
      // 方法3: 多钱包环境从 providers 数组中查找
      if (window.ethereum?.providers) {
        const found = window.ethereum.providers.find(p => p.isBitKeep || p.isBitget);
        if (found) return found;
      }
      // 方法4: 直接标记在 window.ethereum 上
      if (window.ethereum?.isBitKeep || window.ethereum?.isBitget) return window.ethereum;
      return null;
    },
  },
};

// ============ 钱包选择弹窗 ============
function showWalletModal() {
  document.getElementById('walletModal').style.display = 'flex';
}

function closeWalletModal(e) {
  // 点击背景关闭，或直接调用关闭
  if (!e || e.target === e.currentTarget) {
    document.getElementById('walletModal').style.display = 'none';
  }
}

// ============ 连接指定钱包 ============
async function connectWithWallet(walletType) {
  const config = WALLET_CONFIG[walletType];
  if (!config) return;

  let walletProvider = config.getProvider();

  // Binance / Bitget Wallet 可能注入延迟，等待最多 2 秒
  if (!walletProvider && (walletType === 'binance' || walletType === 'bitget')) {
    for (let i = 0; i < 4; i++) {
      await new Promise(r => setTimeout(r, 500));
      // 重新触发 EIP-6963 请求
      window.dispatchEvent(new Event('eip6963:requestProvider'));
      await new Promise(r => setTimeout(r, 100));
      walletProvider = config.getProvider();
      if (walletProvider) break;
      debugLog(`等待 ${config.name} 注入... 重试 ${i + 1}/4`);
    }
  }

  if (!walletProvider) {
    if (walletType === 'bitget') {
      showToast(`❌ 未检测到 Bitget Wallet，请安装插件后刷新页面`);
      // 延迟打开下载页面
      setTimeout(() => {
        window.open('https://web3.bitget.com/wallet-download?type=2', '_blank');
      }, 1500);
    } else {
      showToast(`❌ 未检测到 ${config.name}，请确保已安装插件`);
    }
    return;
  }

  // 关闭弹窗
  closeWalletModal();

  try {
    // 请求账户授权
    const accounts = await walletProvider.request({ method: 'eth_requestAccounts' });

    if (!accounts || accounts.length === 0) {
      showToast(`未获取到账户，请在 ${config.name} 中解锁并授权`);
      return;
    }

    userAddress = accounts[0];

    // 检查并切换网络到 BSC Testnet
    const chainId = await walletProvider.request({ method: 'eth_chainId' });
    if (chainId !== BSC_TESTNET_CHAIN_ID) {
      try {
        await walletProvider.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: BSC_TESTNET_CHAIN_ID }],
        });
      } catch (switchErr) {
        if (switchErr.code === 4902 || switchErr.code === -32603) {
          await walletProvider.request({
            method: 'wallet_addEthereumChain',
            params: [BSC_TESTNET_CONFIG],
          });
        } else {
          throw switchErr;
        }
      }
    }

    // 创建合约实例
    if (typeof ethers === 'undefined') {
      showToast('ethers.js 加载失败，请刷新页面重试');
      return;
    }
    provider = new ethers.BrowserProvider(walletProvider);
    signer = await provider.getSigner();
    contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

    // 标记为已连接
    isConnected = true;
    currentWalletType = walletType;

    // 更新 UI
    document.getElementById('connectBtn').innerHTML = '🔌 断开连接';
    document.getElementById('connectBtn').onclick = disconnectWallet;
    document.getElementById('walletAddress').style.display = 'inline';
    document.getElementById('walletAddress').textContent = userAddress.slice(0, 6) + '...' + userAddress.slice(-4);
    document.getElementById('walletNetwork').style.display = 'inline';
    document.getElementById('walletNetwork').textContent = 'BSC Testnet';

    showToast(`${config.name} 已连接 ✅`);

    // 监听账户变化
    if (walletProvider.on) {
      walletProvider.removeAllListeners?.('accountsChanged');
      walletProvider.removeAllListeners?.('chainChanged');

      walletProvider.on('accountsChanged', async (accs) => {
        if (accs.length === 0) {
          if (isConnected) {
            disconnectWallet();
            showToast(`${config.name} 已锁定，已自动断开`);
          }
        } else if (isConnected) {
          userAddress = accs[0];
          document.getElementById('walletAddress').textContent = userAddress.slice(0, 6) + '...' + userAddress.slice(-4);
          showToast('账户已切换');
          await scanUserNFTs();
        }
      });

      walletProvider.on('chainChanged', () => {
        if (isConnected) {
          location.reload();
        }
      });
    }

    // 扫描用户 NFT
    await scanUserNFTs();
  } catch (err) {
    debugLog(`${config.name} 连接失败:`, err);
    if (err.code === 4001) {
      showToast('你拒绝了连接请求');
    } else {
      showToast(`连接 ${config.name} 失败: ` + err.message);
    }
  }
}

// 兼容旧的 connectWallet（自动检测弹窗）
async function connectWallet() {
  showWalletModal();
}

// ============ 扫描用户持有的 NFT ============
async function scanUserNFTs() {
  if (!contract || !userAddress) return;

  try {
    showToast('🔍 正在扫描你的 NFT...');

    // 先查用户余额
    const balance = await contract.balanceOf(userAddress);
    const balanceNum = Number(balance);
    debugLog(`用户余额: ${balanceNum} 张 NFT`);

    if (balanceNum === 0) {
      userBlankNFTs = [];
      userInscribedNFTs = [];
      renderMintPanel();
      return;
    }

    // 获取 totalSupply，遍历所有 tokenId 检查 ownerOf
    const totalSupply = await contract.totalSupply();
    const total = Number(totalSupply);
    debugLog(`总铸造量: ${total}`);

    userBlankNFTs = [];
    userInscribedNFTs = [];

    // 并发检查所有 token（分批，避免 RPC 限速）
    const BATCH_SIZE = 10;
    for (let start = 0; start < total; start += BATCH_SIZE) {
      const end = Math.min(start + BATCH_SIZE, total);
      const batch = [];

      for (let tokenId = start; tokenId < end; tokenId++) {
        batch.push(
          (async (id) => {
            try {
              const owner = await contract.ownerOf(id);
              debugLog(`Token #${id}: owner=${owner}, me=${userAddress}, match=${owner.toLowerCase() === userAddress.toLowerCase()}`);
              if (owner.toLowerCase() === userAddress.toLowerCase()) {
                const inscribed = await contract.isInscribed(id);
                debugLog(`Token #${id}: isInscribed=${inscribed}`);
                if (inscribed) {
                  // 读取链上灵魂碑数据
                  try {
                    const tomb = await contract.getSoulStele(id);
                    const pIndex = Number(tomb.personalityIndex);
                    const pCode = await contract.personalityCodes(pIndex);
                    const pName = await contract.personalityNames(pIndex);
                    userInscribedNFTs.push({
                      tokenId: id,
                      personalityIndex: pIndex,
                      code: pCode,
                      name: pName,
                      matchPercent: Number(tomb.matchPercent),
                      dimensions: tomb.dimensions.map(Number),
                      inscribeTime: Number(tomb.inscribeTime),
                    });
                  } catch (tombErr) {
                    debugLog(`Token #${id}: 读取灵魂碑数据失败`, tombErr.message);
                    userInscribedNFTs.push({ tokenId: id, code: '???', name: '读取失败', matchPercent: 0 });
                  }
                } else {
                  userBlankNFTs.push(id);
                }
              }
            } catch (e) {
              debugLog(`Token #${id}: 查询失败`, e.message);
            }
          })(tokenId)
        );
      }

      await Promise.all(batch);
    }

    // 排序
    userBlankNFTs.sort((a, b) => a - b);
    userInscribedNFTs.sort((a, b) => a.tokenId - b.tokenId);

    debugLog(`扫描完成: ${userBlankNFTs.length} 张空白, ${userInscribedNFTs.length} 张已铭刻`);

    if (userBlankNFTs.length > 0) {
      showToast(`🃏 发现 ${userBlankNFTs.length} 张空白卡片！`);
    }

    // 根据结果渲染 UI
    renderMintPanel();

  } catch (err) {
    debugLog('扫描 NFT 失败:', err);
    showToast('扫描 NFT 失败，请检查网络');
    renderMintPanel(); // 出错也要恢复 UI
  }
}

// ============ 根据 NFT 状态渲染 Mint 面板 ============
function renderMintPanel() {
  const nftListEl = document.getElementById('nftListSection');
  const dividerEl = document.getElementById('nftListDivider');
  const previewEl = document.getElementById('blankPreview');
  const priceEl = document.querySelector('.price');
  const supplyEl = document.getElementById('supplyInfo');
  const mintBtn = document.getElementById('mintBtn');
  const subtextEl = document.getElementById('mintSubtext');
  const inscribedListEl = document.getElementById('inscribedListSection');
  
  // ===== 已铭刻 NFT 区域 =====
  if (inscribedListEl) {
    if (userInscribedNFTs.length > 0) {
      inscribedListEl.style.display = 'block';
      const inscribedContainer = document.getElementById('inscribedListCards');
      inscribedContainer.innerHTML = '';

      userInscribedNFTs.forEach((nft) => {
        const color = getPersonalityColor(nft.personalityIndex || 0);
        const card = document.createElement('div');
        card.className = 'nft-select-card inscribed-card';
        card.style.cursor = 'pointer';
        card.innerHTML = `
          <div class="nft-inscribed-mini-stele" style="border-color: ${color};">
            <span class="mini-label">✦</span>
            <span class="mini-code" style="color: ${color};">${nft.code}</span>
          </div>
          <div class="nft-select-info">
            <span class="nft-select-title" style="color: ${color};">Soul Stele #${nft.tokenId}</span>
            <span class="nft-select-status inscribed-status">${nft.code} · ${nft.name} · ${nft.matchPercent}%</span>
          </div>
          <span class="inscribed-badge-small">✦ 已铭刻</span>
        `;
        card.addEventListener('click', () => showSteleModal(nft));
        inscribedContainer.appendChild(card);
      });
    } else {
      inscribedListEl.style.display = 'none';
    }
  }

  // ===== 空白 NFT 区域 =====
  if (userBlankNFTs.length === 0) {
    // 没有空白 NFT，只显示 Mint 按钮（完整展示）
    if (nftListEl) nftListEl.style.display = 'none';
    if (previewEl) previewEl.style.display = '';
    if (priceEl) priceEl.style.display = '';
    if (supplyEl) supplyEl.style.display = '';
    mintBtn.style.display = '';
    mintBtn.className = 'btn btn-gold mint-btn-fixed';
    mintBtn.textContent = 'Mint 灵魂卡片';
    subtextEl.textContent = '';
    return;
  }

  // 有空白 NFT！显示选择列表
  if (nftListEl) {
    nftListEl.style.display = 'block';
    
    const listContainer = document.getElementById('nftListCards');
    listContainer.innerHTML = '';

    userBlankNFTs.forEach((tokenId) => {
      const card = document.createElement('div');
      card.className = 'nft-select-card';
      card.innerHTML = `
        <div class="nft-select-icon">🃏</div>
        <div class="nft-select-info">
          <span class="nft-select-title">Soul Card #${tokenId}</span>
          <span class="nft-select-status">空白 · 未铭刻</span>
        </div>
        <div class="nft-select-actions">
          <button class="btn btn-sm btn-ghost" onclick="showBlankCardModal(${tokenId})">查看</button>
          <button class="btn btn-sm btn-primary" onclick="selectBlankNFT(${tokenId})">选择铭刻</button>
        </div>
      `;
      listContainer.appendChild(card);
    });
  }

  // 始终显示"或者"和 Mint 新卡片入口
  if (dividerEl) dividerEl.style.display = '';
  if (previewEl) previewEl.style.display = ''; // 保留主视觉卡片预览图
  if (priceEl) priceEl.style.display = '';
  if (supplyEl) supplyEl.style.display = '';
  mintBtn.style.display = '';
  mintBtn.className = 'btn btn-gold mint-btn-fixed';
  mintBtn.textContent = 'Mint 新卡片';
  subtextEl.textContent = `你已有 ${userBlankNFTs.length} 张空白卡片，可直接选择开始测试`;
}

// ============ 选择一张空白 NFT 开始答题 ============
function selectBlankNFT(tokenId) {
  currentTokenId = tokenId;
  showToast(`✅ 选择 Soul Card #${tokenId}，开始灵魂测试！`);
  startTest();
}

// ============ 断开连接 ============
async function disconnectWallet() {
  // 尝试撤销权限（部分钱包支持）
  if (currentWalletType) {
    const config = WALLET_CONFIG[currentWalletType];
    const walletProvider = config?.getProvider();
    if (walletProvider) {
      try {
        await walletProvider.request({
          method: 'wallet_revokePermissions',
          params: [{ eth_accounts: {} }],
        });
      } catch (e) {
        debugLog('wallet_revokePermissions 不被支持，使用前端断开模式');
      }
      // 移除事件监听
      walletProvider.removeAllListeners?.('accountsChanged');
      walletProvider.removeAllListeners?.('chainChanged');
    }
  }

  // 清空前端状态
  userAddress = null;
  provider = null;
  signer = null;
  contract = null;
  isConnected = false;
  currentWalletType = null;
  userBlankNFTs = [];
  userInscribedNFTs = [];

  // 隐藏 NFT 列表
  const nftListEl = document.getElementById('nftListSection');
  if (nftListEl) nftListEl.style.display = 'none';
  const inscribedListEl = document.getElementById('inscribedListSection');
  if (inscribedListEl) inscribedListEl.style.display = 'none';
  document.getElementById('mintBtn').textContent = 'Mint 灵魂卡片';
  document.getElementById('mintBtn').className = 'btn btn-gold mint-btn-fixed';
  const subtext = document.getElementById('mintSubtext');
  if (subtext) subtext.textContent = '';

  document.getElementById('connectBtn').innerHTML = '🔗 连接钱包';
  document.getElementById('connectBtn').onclick = showWalletModal;
  document.getElementById('walletAddress').style.display = 'none';
  document.getElementById('walletNetwork').style.display = 'none';

  showToast('已断开连接 ✅');
}

function getNetworkName(chainId) {
  const networks = {
    '0x1': 'Ethereum',
    '0x5': 'Goerli',
    '0xaa36a7': 'Sepolia',
    '0x2105': 'Base',
    '0xa4b1': 'Arbitrum',
    '0x89': 'Polygon',
    '0x61': 'BSC Testnet',
    '0x38': 'BSC',
    '0x539': 'Localhost',
    '0x7a69': 'Hardhat',
  };
  return networks[chainId] || `Chain ${parseInt(chainId, 16)}`;
}

// ============ Mint NFT ============
async function mintNFT() {
  // 点击 Mint 后自动滚动到页面最底部
  setTimeout(() => {
    document.documentElement.scrollTop = document.documentElement.scrollHeight;
    document.body.scrollTop = document.body.scrollHeight; // Safari 兼容
    window.scrollTo(0, Math.max(document.body.scrollHeight, document.documentElement.scrollHeight));
  }, 50);

  // 演示模式（无合约时）
  if (CONTRACT_ADDRESS === '0x0000000000000000000000000000000000000000') {
    currentTokenId = Math.floor(Math.random() * 10000);
    showToast(`🎉 Demo模式 — 获得 Soul Card #${currentTokenId}`);
    startTest();
    return;
  }

  if (!contract || !isConnected) {
    // 按钮抖动效果
    const mintBtn = document.getElementById('mintBtn');
    mintBtn.classList.add('shake');
    setTimeout(() => mintBtn.classList.remove('shake'), 600);

    showToast('⚠️ 请先连接钱包！');

    // 弹出钱包选择弹窗
    showWalletModal();

    // 高亮连接按钮提示用户
    const connectBtn = document.getElementById('connectBtn');
    connectBtn.classList.add('highlight-pulse');
    setTimeout(() => connectBtn.classList.remove('highlight-pulse'), 2000);
    return;
  }

  try {
    showLoading('Minting 灵魂卡片...');

    const mintPrice = await contract.mintPrice();
    // 用底层 sendTransaction 发送，确保 gasLimit 不会被钱包覆盖
    const mintData = contract.interface.encodeFunctionData('mint', []);
    const tx = await signer.sendTransaction({
      to: CONTRACT_ADDRESS,
      data: mintData,
      value: mintPrice,
      gasLimit: 150000n,
    });
    
    showLoading('等待链上确认（约3-5秒）...');
    const receipt = await tx.wait();

    // 从事件中获取 tokenId
    try {
      const event = receipt.logs.find(log => {
        try {
          const parsed = contract.interface.parseLog(log);
          return parsed.name === 'Minted';
        } catch { return false; }
      });

      if (event) {
        const parsed = contract.interface.parseLog(event);
        currentTokenId = Number(parsed.args.tokenId);
      }
    } catch (parseErr) {
      debugLog('事件解析失败，尝试从 balanceOf 推算 tokenId:', parseErr);
    }

    // 如果没从事件拿到 tokenId，用 totalSupply 推算
    if (!currentTokenId && currentTokenId !== 0) {
      try {
        const supply = await contract.totalSupply();
        currentTokenId = Number(supply) - 1;
      } catch (e) {
        currentTokenId = 0;
      }
    }

    // 更新 supply 显示
    try {
      const supply = await contract.totalSupply();
      document.getElementById('supplyInfo').textContent = `已铸造 ${supply} / ∞`;
    } catch (e) {}

    hideLoading();
    showToast(`🎉 Mint 成功！Soul Card #${currentTokenId}`);
    startTest();
  } catch (err) {
    hideLoading();
    debugLog('Mint 失败:', err);
    showToast('Mint 失败: ' + (err.reason || err.message));
  }
}

// ============ 测试流程 ============
function startTest() {
  currentQuestion = 0;
  answers = [];
  isDrunkTriggered = false;
  showDrinkFollowup = false;

  switchPanel('testPanel');
  renderQuestion();
}

function renderQuestion() {
  const totalQuestions = QUESTIONS.length;
  
  // 更新"上一题"按钮状态
  const prevBtn = document.getElementById('prevQuestionBtn');
  if (prevBtn) {
    prevBtn.disabled = (currentQuestion === 0 && !showDrinkFollowup);
  }

  // 检查是否显示饮酒追加题
  if (showDrinkFollowup) {
    renderDrinkFollowup();
    return;
  }

  if (currentQuestion >= totalQuestions) {
    finishTest();
    return;
  }

  const q = QUESTIONS[currentQuestion];
  const progress = ((currentQuestion) / totalQuestions * 100).toFixed(0);

  document.getElementById('progressFill').style.width = progress + '%';
  document.getElementById('questionNumber').textContent = `Q${currentQuestion + 1} / ${totalQuestions}`;
  document.getElementById('questionText').textContent = q.text;

  const container = document.getElementById('optionsContainer');
  container.innerHTML = '';

  q.options.forEach((opt, idx) => {
    const btn = document.createElement('button');
    btn.className = 'option-btn';
    btn.textContent = opt.label;
    btn.onclick = () => selectOption(idx);
    container.appendChild(btn);
  });
}

function selectOption(optionIndex) {
  const q = QUESTIONS[currentQuestion];
  const selected = q.options[optionIndex];

  // 第31题：兴趣爱好题
  if (q.id === 31) {
    if (selected.value === -1) {
      // 选了饮酒，触发追加题
      showDrinkFollowup = true;
      answers.push(0); // 这题不计入维度
      renderQuestion();
      return;
    } else {
      answers.push(0); // 不计入维度
    }
  } else {
    answers.push(selected.value);
  }

  currentQuestion++;
  renderQuestion();
}

function renderDrinkFollowup() {
  document.getElementById('progressFill').style.width = '98%';
  document.getElementById('questionNumber').textContent = '🍺 隐藏题';
  document.getElementById('questionText').textContent = DRINK_FOLLOWUP.text;

  const container = document.getElementById('optionsContainer');
  container.innerHTML = '';

  DRINK_FOLLOWUP.options.forEach((opt, idx) => {
    const btn = document.createElement('button');
    btn.className = 'option-btn';
    btn.textContent = opt.label;
    btn.onclick = () => {
      if (opt.value === -2) {
        isDrunkTriggered = true;
      }
      showDrinkFollowup = false;
      currentQuestion++;
      renderQuestion();
    };
    container.appendChild(btn);
  });
}

function finishTest() {
  // 只取前30道基础题的答案
  const baseAnswers = answers.slice(0, 30);
  
  // 运行 SBTI 算法
  const result = runSBTI(baseAnswers, isDrunkTriggered);
  
  // 保存结果到全局
  window.sbtiResult = result;

  // 渲染结果
  renderResult(result);
  switchPanel('resultPanel');
}

// ============ 渲染结果 ============
function renderResult(result) {
  document.getElementById('resultCode').textContent = result.code;
  document.getElementById('resultCode').style.color = getPersonalityColor(result.index);
  document.getElementById('resultName').textContent = result.name;
  document.getElementById('resultMatch').textContent = `匹配度: ${result.similarity}%`;

  // 渲染维度网格
  const grid = document.getElementById('dimensionsGrid');
  grid.innerHTML = '';
  
  DIMENSIONS.forEach((dim, i) => {
    const level = result.dimLabels[i];
    const item = document.createElement('div');
    item.className = 'dim-item';
    item.innerHTML = `
      <span class="dim-code">${dim.code}</span>
      <span>${dim.name}</span>
      <span class="dim-level ${level}">${level}</span>
    `;
    grid.appendChild(item);
  });

  // 渲染灵魂碑预览 SVG
  renderStelePreview(result);
}

function renderStelePreview(result) {
  const color = getPersonalityColor(result.index);
  const color2 = getPersonalityColor2(result.index);
  
  // 维度柱状图（紧凑版，适配 400×400）
  let bars = '';
  const dimLabels = ['S1','S2','S3','E1','E2','E3','A1','A2','A3','Ac1','Ac2','Ac3','So1','So2','So3'];
  result.dimensions.forEach((val, i) => {
    const barWidth = val * 26;
    const y = 220 + i * 10;
    bars += `<text x="83" y="${y+7}" text-anchor="end" fill="#555566" font-size="8" font-family="monospace">${dimLabels[i]}</text>`;
    bars += `<rect x="88" y="${y}" width="78" height="7" rx="2" fill="#1a1a2e"/>`;
    bars += `<rect x="88" y="${y}" width="${barWidth}" height="7" rx="2" fill="${color}" opacity="0.7"/>`;
  });

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="background:#0a0a0f">
      <defs>
        <linearGradient id="tg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:${color}"/><stop offset="100%" style="stop-color:${color2}"/>
        </linearGradient>
        <radialGradient id="tglow" cx="50%" cy="35%" r="45%">
          <stop offset="0%" style="stop-color:${color};stop-opacity:0.12"/><stop offset="100%" style="stop-color:#0a0a0f;stop-opacity:0"/>
        </radialGradient>
      </defs>
      <circle cx="200" cy="140" r="130" fill="url(#tglow)"/>
      <path d="M55,130 L55,360 L345,360 L345,130 Q345,40 200,40 Q55,40 55,130Z" fill="none" stroke="url(#tg)" stroke-width="2"/>
      <text x="200" y="82" text-anchor="middle" fill="${color}" font-size="16" font-family="serif" letter-spacing="4">SOUL STELE</text>
      <text x="200" y="145" text-anchor="middle" fill="url(#tg)" font-size="44" font-family="monospace" font-weight="bold">${result.code}</text>
      <text x="200" y="172" text-anchor="middle" fill="#8888aa" font-size="15" font-family="sans-serif">${result.name}</text>
      <text x="200" y="196" text-anchor="middle" fill="#555566" font-size="11" font-family="monospace">Match: ${result.similarity}%</text>
      <line x1="85" y1="208" x2="315" y2="208" stroke="#333344" stroke-width="0.5"/>
      ${bars}
      <text x="200" y="380" text-anchor="middle" fill="#333344" font-size="10" font-family="monospace">#${currentTokenId || '???'}</text>
    </svg>
  `;

  document.getElementById('stelePreview').innerHTML = svg;
}

// ============ 灵魂碑查看弹窗 ============
function showSteleModal(nft) {
  const color = getPersonalityColor(nft.personalityIndex || 0);
  const color2 = getPersonalityColor2(nft.personalityIndex || 0);

  // 维度柱状图（紧凑版，适配 400×400）
  let bars = '';
  const dimLabels = ['S1','S2','S3','E1','E2','E3','A1','A2','A3','Ac1','Ac2','Ac3','So1','So2','So3'];
  if (nft.dimensions && nft.dimensions.length === 15) {
    nft.dimensions.forEach((val, i) => {
      const barWidth = val * 26;
      const y = 220 + i * 10;
      bars += `<text x="83" y="${y+7}" text-anchor="end" fill="#555566" font-size="8" font-family="monospace">${dimLabels[i]}</text>`;
      bars += `<rect x="88" y="${y}" width="78" height="7" rx="2" fill="#1a1a2e"/>`;
      bars += `<rect x="88" y="${y}" width="${barWidth}" height="7" rx="2" fill="${color}" opacity="0.7"/>`;
    });
  }

  const inscribeDate = nft.inscribeTime
    ? new Date(nft.inscribeTime * 1000).toLocaleDateString('zh-CN')
    : '未知';

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="background:#0a0a0f">
      <defs>
        <linearGradient id="mtg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:${color}"/><stop offset="100%" style="stop-color:${color2}"/>
        </linearGradient>
        <radialGradient id="mglow" cx="50%" cy="35%" r="45%">
          <stop offset="0%" style="stop-color:${color};stop-opacity:0.12"/><stop offset="100%" style="stop-color:#0a0a0f;stop-opacity:0"/>
        </radialGradient>
      </defs>
      <circle cx="200" cy="140" r="130" fill="url(#mglow)"/>
      <path d="M55,130 L55,360 L345,360 L345,130 Q345,40 200,40 Q55,40 55,130Z" fill="none" stroke="url(#mtg)" stroke-width="2"/>
      <text x="200" y="82" text-anchor="middle" fill="${color}" font-size="16" font-family="serif" letter-spacing="4">SOUL STELE</text>
      <text x="200" y="145" text-anchor="middle" fill="url(#mtg)" font-size="44" font-family="monospace" font-weight="bold">${nft.code}</text>
      <text x="200" y="172" text-anchor="middle" fill="#8888aa" font-size="15" font-family="sans-serif">${nft.name}</text>
      <text x="200" y="196" text-anchor="middle" fill="#555566" font-size="11" font-family="monospace">Match: ${nft.matchPercent}%</text>
      <line x1="85" y1="208" x2="315" y2="208" stroke="#333344" stroke-width="0.5"/>
      ${bars}
      <text x="200" y="380" text-anchor="middle" fill="#333344" font-size="10" font-family="monospace">#${nft.tokenId}</text>
    </svg>
  `;

  document.getElementById('steleModalBody').innerHTML = svg;
  document.getElementById('steleModalInfo').innerHTML = `
    <div class="stele-modal-meta">
      <span style="color: ${color};">Soul Stele #${nft.tokenId}</span>
      <span>铭刻日期: ${inscribeDate}</span>
    </div>
  `;

  const modal = document.getElementById('steleModal');
  modal.classList.add('show');
  document.body.style.overflow = 'hidden';
}

function closeSteleModal(event) {
  if (event && event.target !== event.currentTarget) return;
  const modal = document.getElementById('steleModal');
  modal.classList.remove('show');
  document.body.style.overflow = '';
}

// ============ 查看空白卡片 SVG（从链上 tokenURI 读取） ============
async function showBlankCardModal(tokenId) {
  const modalBody = document.getElementById('steleModalBody');
  const modalInfo = document.getElementById('steleModalInfo');
  const modal = document.getElementById('steleModal');

  // 先显示 loading 状态
  modalBody.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:center;height:380px;background:#0a0a14;border-radius:16px;">
      <div style="text-align:center;">
        <div class="spinner" style="margin:0 auto 16px;"></div>
        <p style="color:rgba(255,255,255,0.4);font-size:0.85rem;">正在从链上读取 Soul Card #${tokenId}...</p>
      </div>
    </div>
  `;
  modalInfo.innerHTML = `
    <div class="stele-modal-meta">
      <span style="color: #72efdd;">Soul Card #${tokenId}</span>
      <span style="color: var(--text-dim);">空白 · 未铭刻</span>
    </div>
  `;
  modal.classList.add('show');
  document.body.style.overflow = 'hidden';

  try {
    // 用独立 RPC 读取，避免依赖钱包连接状态
    const rpc = new ethers.JsonRpcProvider('https://bsc-testnet-rpc.publicnode.com');
    const readContract = new ethers.Contract(CONTRACT_ADDRESS, [
      'function tokenURI(uint256) view returns (string)',
      'function isGoldCard(uint256) view returns (bool)',
    ], rpc);

    const [uri, isGold] = await Promise.all([
      readContract.tokenURI(tokenId),
      readContract.isGoldCard(tokenId),
    ]);

    // tokenURI 是 data:application/json;base64,... 格式
    // 解析出 JSON → 取 image 字段（data:image/svg+xml;base64,...）
    let svgContent = '';
    if (uri.startsWith('data:application/json;base64,')) {
      const jsonStr = atob(uri.replace('data:application/json;base64,', ''));
      const metadata = JSON.parse(jsonStr);
      if (metadata.image && metadata.image.startsWith('data:image/svg+xml;base64,')) {
        svgContent = atob(metadata.image.replace('data:image/svg+xml;base64,', ''));
      }
    }

    if (svgContent) {
      modalBody.innerHTML = svgContent;
    } else {
      modalBody.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:center;height:380px;background:#0a0a14;border-radius:16px;">
          <p style="color:rgba(255,255,255,0.4);font-size:0.85rem;">无法解析卡片图片</p>
        </div>
      `;
    }

    // 更新底部信息
    const rarityColor = isGold ? '#ffd700' : '#72efdd';
    const rarityLabel = isGold ? '✦ 金卡' : '普通';
    modalInfo.innerHTML = `
      <div class="stele-modal-meta">
        <span style="color: ${rarityColor};">Soul Card #${tokenId}</span>
        <span style="color: ${rarityColor};">${rarityLabel}</span>
      </div>
    `;

  } catch (err) {
    console.error('读取 tokenURI 失败:', err);
    modalBody.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:center;height:380px;background:#0a0a14;border-radius:16px;">
        <p style="color:rgba(255,100,100,0.6);font-size:0.85rem;">读取失败：${err.message || '网络错误'}</p>
      </div>
    `;
  }
}

// ============ 铭刻上链 ============
async function inscribeNFT() {
  const result = window.sbtiResult;
  if (!result) return;

  // 演示模式
  if (CONTRACT_ADDRESS === '0x0000000000000000000000000000000000000000') {
    showToast('✦ 铭刻成功！(Demo模式)');
    showDonePanel(result);
    return;
  }

  try {
    showLoading('铭刻灵魂到区块链...');

    const tx = await (async () => {
      // 用底层 sendTransaction 发送，确保 gasLimit 不会被钱包覆盖
      const inscribeData = contract.interface.encodeFunctionData('inscribe', [
        currentTokenId,
        result.index,
        result.dimensions,
        result.similarity,
      ]);
      return signer.sendTransaction({
        to: CONTRACT_ADDRESS,
        data: inscribeData,
        gasLimit: 150000n,
      });
    })();

    showLoading('等待链上确认...');
    await tx.wait();

    hideLoading();
    showToast('✦ 铭刻成功！灵魂已永久上链');

    // 从空白列表移除，加入已铭刻列表
    userBlankNFTs = userBlankNFTs.filter(id => id !== currentTokenId);
    userInscribedNFTs.push({
      tokenId: currentTokenId,
      personalityIndex: result.index,
      code: result.code,
      name: result.name,
      matchPercent: result.similarity,
      dimensions: result.dimensions,
      inscribeTime: Math.floor(Date.now() / 1000),
    });

    // 尝试通知钱包刷新 NFT 元数据
    try {
      await forceRefreshNFTMetadata(currentTokenId);
    } catch (e) {
      debugLog('钱包刷新通知失败(非致命):', e.message);
    }

    showDonePanel(result);
  } catch (err) {
    hideLoading();
    debugLog('铭刻失败:', err);
    showToast('铭刻失败: ' + (err.reason || err.message));
  }
}

/**
 * 强制通知钱包刷新 NFT 元数据
 * 多种策略并行尝试，尽最大可能让钱包更新图片
 */
async function forceRefreshNFTMetadata(tokenId) {
  const walletProvider = provider?.provider || window.ethereum;
  if (!walletProvider) return;

  // 策略1: wallet_watchAsset — 让钱包重新关注这个 NFT，会重新拉取 tokenURI
  try {
    await walletProvider.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC721',
        options: {
          address: CONTRACT_ADDRESS,
          tokenId: String(tokenId),
        },
      },
    });
    debugLog('wallet_watchAsset 成功，钱包应会刷新 NFT #' + tokenId);
  } catch (e) {
    debugLog('wallet_watchAsset 不支持或被拒绝:', e.message);
  }

  // 策略2: 重新读一次 tokenURI 触发缓存更新（某些钱包会监听 eth_call）
  try {
    const rpc = new ethers.JsonRpcProvider('https://bsc-testnet-rpc.publicnode.com');
    const readContract = new ethers.Contract(CONTRACT_ADDRESS, [
      'function tokenURI(uint256) view returns (string)',
    ], rpc);
    const uri = await readContract.tokenURI(tokenId);
    debugLog('铭刻后 tokenURI 已更新，长度:', uri.length);
  } catch (e) {
    debugLog('tokenURI 读取失败:', e.message);
  }
}

function showDonePanel(result) {
  // 复制灵魂碑到最终面板
  document.getElementById('finalStele').innerHTML = document.getElementById('stelePreview').innerHTML;
  document.getElementById('finalCode').textContent = result.code;
  document.getElementById('finalCode').style.color = getPersonalityColor(result.index);
  document.getElementById('finalName').textContent = result.name;

  switchPanel('donePanel');
}

// ============ 测试导航：上一题 / 返回首页 ============
function goToPrevQuestion() {
  // 如果正在显示饮酒追加题，回到第31题
  if (showDrinkFollowup) {
    showDrinkFollowup = false;
    // 移除第31题的答案（之前选饮酒时 push 了一个 0）
    answers.pop();
    renderQuestion();
    return;
  }

  if (currentQuestion <= 0) return;

  currentQuestion--;
  answers.pop(); // 移除上一题的答案
  renderQuestion();
}

async function confirmGoHome() {
  if (currentQuestion > 0) {
    // 已经答了题，需要确认
    if (!confirm('确定返回首页吗？当前答题进度将丢失。')) {
      return;
    }
  }
  // 重置测试状态
  currentQuestion = 0;
  answers = [];
  isDrunkTriggered = false;
  showDrinkFollowup = false;
  currentTokenId = null;
  window.sbtiResult = null;

  switchPanel('mintPanel');

  // 重新扫描 NFT，刷新首页列表
  if (isConnected && contract) {
    await scanUserNFTs();
  }
}

// ============ 返回主页继续铭刻 ============
async function goBackToMint() {
  currentTokenId = null;
  window.sbtiResult = null;

  // 切回 Mint 面板
  switchPanel('mintPanel');

  // 重新扫描 NFT（铭刻后列表已更新）
  if (isConnected && contract) {
    await scanUserNFTs();
  }
}

// ============ 分享 ============
function shareResult() {
  const result = window.sbtiResult;
  if (!result) return;

  const text = `✦ 我在 SBTI × NFT 的灵魂碑上被刻上了「${result.code} · ${result.name}」\n匹配度 ${result.similarity}%\n我的灵魂已永久刻在区块链上！\n\n来测测你的灵魂人格 →`;
  
  if (navigator.share) {
    navigator.share({ title: 'SBTI × NFT', text });
  } else {
    navigator.clipboard.writeText(text).then(() => {
      showToast('已复制到剪贴板 📋');
    });
  }
}

// ============ UI 工具 ============
function switchPanel(panelId) {
  document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
  document.getElementById(panelId).classList.add('active');
}

function showLoading(text) {
  document.getElementById('loadingText').textContent = text;
  document.getElementById('loadingPanel').style.display = 'block';
  document.querySelectorAll('.panel').forEach(p => {
    if (p.id !== 'loadingPanel') p.style.opacity = '0.3';
  });
}

function hideLoading() {
  document.getElementById('loadingPanel').style.display = 'none';
  document.querySelectorAll('.panel').forEach(p => p.style.opacity = '1');
}

function showToast(message) {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3000);
}

// 人格配色
function getPersonalityColor(index) {
  const colors = [
    '#e94560','#ffd700','#888888','#ffd700','#ff69b4',
    '#ff4444','#00ff88','#ff69b4','#ff6b9d','#ffb6c1',
    '#9b59b6','#95a5a6','#8B4513','#ffff00','#00ffff',
    '#4169e1','#dc143c','#708090','#cd853f','#daa520',
    '#98fb98','#4682b4','#ff4500','#2c2c2c','#696969',
    '#ff00ff','#00ff00',
  ];
  return colors[index] || '#e94560';
}

function getPersonalityColor2(index) {
  const colors = [
    '#0f3460','#ff6b35','#444444','#b8860b','#ff1493',
    '#cc0000','#009955','#8b008b','#c44569','#ff69b4',
    '#6c3483','#7f8c8d','#D2691E','#ff6600','#0099cc',
    '#1e3a8a','#8b0000','#2f4f4f','#8b7355','#b8860b',
    '#66cdaa','#2c3e50','#cc3700','#111111','#363636',
    '#ff69b4','#006600',
  ];
  return colors[index] || '#0f3460';
}

// ============ 合约地址显示 & 复制 ============
function initContractAddressDisplay() {
  const addrText = document.getElementById('contractAddrText');
  const link = document.getElementById('contractLink');
  if (addrText && link) {
    // 显示完整地址
    addrText.textContent = CONTRACT_ADDRESS;
    link.href = `https://testnet.bscscan.com/address/${CONTRACT_ADDRESS}`;
  }
}

function copyContractAddress() {
  navigator.clipboard.writeText(CONTRACT_ADDRESS).then(() => {
    showToast('合约地址已复制 📋');
  }).catch(() => {
    // fallback
    const ta = document.createElement('textarea');
    ta.value = CONTRACT_ADDRESS;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
    showToast('合约地址已复制 📋');
  });
}

// ============ EIP-6963 多钱包发现 ============
window._eip6963Providers = [];

function initEIP6963() {
  window.addEventListener('eip6963:announceProvider', (event) => {
    const { info, provider } = event.detail;
    // 去重
    if (!window._eip6963Providers.find(p => p.info?.uuid === info?.uuid)) {
      window._eip6963Providers.push({ info, provider });
      debugLog(`EIP-6963 发现钱包: ${info?.name} (${info?.rdns})`);
    }
  });
  // 主动请求所有已注入的钱包广播
  window.dispatchEvent(new Event('eip6963:requestProvider'));
}

// ============ 初始化 ============
window.addEventListener('load', async () => {
  // 初始化 EIP-6963 多钱包发现
  initEIP6963();

  // 显示合约地址
  initContractAddressDisplay();

  // 读取 supply（不需要钱包，用公共 RPC）
  try {
    const rpc = new ethers.JsonRpcProvider('https://bsc-testnet-rpc.publicnode.com');
    const readContract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, rpc);
    const supply = await readContract.totalSupply();
    document.getElementById('supplyInfo').textContent = `已铸造 ${supply} / ∞`;
  } catch (e) {
    document.getElementById('supplyInfo').textContent = '已铸造 0 / ∞';
  }

  // 默认按钮
  document.getElementById('connectBtn').innerHTML = '🔗 连接钱包';
  document.getElementById('connectBtn').onclick = showWalletModal;

  // 自动检测：遍历所有钱包，找一个之前已授权过的静默连接
  for (const [type, config] of Object.entries(WALLET_CONFIG)) {
    try {
      const wp = config.getProvider();
      if (!wp) continue;
      const existingAccounts = await wp.request({ method: 'eth_accounts' });
      if (existingAccounts && existingAccounts.length > 0) {
        debugLog(`检测到 ${config.name} 之前已授权，自动连接`);
        await connectWithWallet(type);
        break; // 只连第一个检测到的
      }
    } catch (e) {
      debugLog(`自动检测 ${config.name} 失败:`, e);
    }
  }
});

// ============ 卡片 3D 拖拽旋转 ============
(function initCard3DDrag() {
  let card = null;
  let isDragging = false;
  let startX = 0, startY = 0;
  let currentRotX = 0, currentRotY = 0;
  let breatheResumeTimer = null;

  function getCard() {
    if (!card) card = document.querySelector('.soul-card');
    return card;
  }

  function onPointerDown(e) {
    const c = getCard();
    if (!c) return;
    if (!c.contains(e.target)) return;

    isDragging = true;
    c.classList.add('dragging');

    // 关闭 transition，让拖动即时跟手
    c.style.transition = 'none';

    const point = e.touches ? e.touches[0] : e;
    startX = point.clientX;
    startY = point.clientY;

    // 清掉未完成的恢复定时器
    if (breatheResumeTimer) {
      clearTimeout(breatheResumeTimer);
      breatheResumeTimer = null;
    }

    e.preventDefault();
  }

  function onPointerMove(e) {
    if (!isDragging) return;

    const point = e.touches ? e.touches[0] : e;
    const dx = point.clientX - startX;
    const dy = point.clientY - startY;

    // dx → rotateY, dy → rotateX (反向)
    currentRotX = -dy * 0.4;
    currentRotY = dx * 0.4;

    const c = getCard();
    if (c) {
      c.style.transform = `rotateX(${currentRotX}deg) rotateY(${currentRotY}deg) scale(1.04)`;
    }

    e.preventDefault();
  }

  function onPointerUp(e) {
    if (!isDragging) return;
    isDragging = false;

    const c = getCard();
    if (!c) return;

    // 注意：这里不移除 dragging 类！保持 animation: none，否则呼吸动画会立刻抢占 transform

    // 根据拖拽幅度动态计算回弹时长，拖得越远回得越慢
    const dist = Math.sqrt(currentRotX * currentRotX + currentRotY * currentRotY);
    const duration = Math.max(0.8, Math.min(dist * 0.018, 2.5)); // 0.8~2.5秒

    // 覆盖 .dragging 的 transition:none，用内联 !important 级别的 style
    // cubic-bezier(0.05, 0.9, 0.1, 1) → 开头猛弹、末尾非常缓慢地减速归位
    c.style.setProperty('transition', `transform ${duration}s cubic-bezier(0.05, 0.9, 0.1, 1)`, 'important');
    c.style.transform = 'rotateX(0deg) rotateY(0deg) scale(1)';

    currentRotX = 0;
    currentRotY = 0;

    // transition 结束后，移除 dragging + 清除内联样式，呼吸动画恢复
    if (breatheResumeTimer) clearTimeout(breatheResumeTimer);
    breatheResumeTimer = setTimeout(() => {
      if (c && !isDragging) {
        c.classList.remove('dragging');
        c.style.transition = '';
        c.style.transform = '';
        c.style.removeProperty('transition');
      }
    }, (duration + 0.3) * 1000);
  }

  // 鼠标事件
  document.addEventListener('mousedown', onPointerDown, { passive: false });
  document.addEventListener('mousemove', onPointerMove, { passive: false });
  document.addEventListener('mouseup', onPointerUp);

  // 触摸事件
  document.addEventListener('touchstart', onPointerDown, { passive: false });
  document.addEventListener('touchmove', onPointerMove, { passive: false });
  document.addEventListener('touchend', onPointerUp);
})();

// ============ Hover 脉冲（外层容器 scale，不打断内层呼吸） + 金色光发散 ============
(function initHoverPulse() {
  const preview = document.querySelector('.nft-preview');
  if (!preview) return;

  let pulseTimer = null;
  let mouseIsDown = false; // 追踪鼠标按下状态，拖拽时不触发 hover 效果

  // 全局监听鼠标按下/抬起
  document.addEventListener('mousedown', () => { mouseIsDown = true; });
  document.addEventListener('mouseup', () => { mouseIsDown = false; });

  preview.addEventListener('mouseenter', () => {
    // 鼠标按着左键进入（拖拽中）→ 跳过所有 hover 特效
    if (mouseIsDown) return;

    const card = preview.querySelector('.soul-card');
    const glow = preview.querySelector('.soul-card-glow');

    // ---- 金色光发散 ----
    if (glow) {
      // 移除再添加 class，确保每次 hover 都能重新播放动画
      glow.classList.remove('gold-burst');
      // 强制 reflow，让浏览器识别 class 变化
      void glow.offsetWidth;
      glow.classList.add('gold-burst');

      // 动画结束后移除 class，为下次触发做准备
      const onEnd = () => {
        glow.classList.remove('gold-burst');
        glow.removeEventListener('animationend', onEnd);
      };
      glow.addEventListener('animationend', onEnd);
    }

    // ---- 卡片脉冲放大（外层容器 scale，不影响内层拖拽/呼吸） ----
    preview.style.transition = 'transform 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
    preview.style.transform = 'scale(1.035)';

    if (pulseTimer) clearTimeout(pulseTimer);
    pulseTimer = setTimeout(() => {
      preview.style.transition = 'transform 0.5s cubic-bezier(0.25, 0.46, 0.45, 0.94)';
      preview.style.transform = 'scale(1)';
    }, 350);
  });

  // 鼠标离开时确保回到原位（金色光继续播完不打断）
  preview.addEventListener('mouseleave', () => {
    preview.style.transition = 'transform 0.4s ease-out';
    preview.style.transform = 'scale(1)';
    if (pulseTimer) {
      clearTimeout(pulseTimer);
      pulseTimer = null;
    }
  });
})();
