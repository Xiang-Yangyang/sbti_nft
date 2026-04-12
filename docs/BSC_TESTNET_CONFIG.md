# ⛓️ BSC Testnet 配置指南

> **更新日期**：2026年4月12日  
> **网络名称**：BNB Smart Chain Testnet  
> **状态**：已部署 SBTI NFT 合约 ✅

---

## 1. 网络基本参数

| 参数 | 值 |
|------|------|
| **网络名称** | BNB Smart Chain Testnet |
| **Chain ID** | `97` |
| **货币符号** | tBNB |
| **区块浏览器** | https://testnet.bscscan.com |

---

## 2. RPC 节点

### 公共 RPC（免费，无需 API Key）

| 提供方 | URL | 备注 |
|--------|-----|------|
| **PublicNode** | `https://bsc-testnet-rpc.publicnode.com` | ⭐ 项目当前使用 |
| **BNB Chain 官方** | `https://data-seed-prebsc-1-s1.bnbchain.org:8545` | 官方节点 |
| **BNB Chain 官方 2** | `https://data-seed-prebsc-2-s1.bnbchain.org:8545` | 备用节点 |
| **BNB Chain 官方 3** | `https://data-seed-prebsc-1-s2.bnbchain.org:8545` | 备用节点 |
| **BNB Chain 官方 4** | `https://data-seed-prebsc-2-s2.bnbchain.org:8545` | 备用节点 |
| **Ankr** | `https://rpc.ankr.com/bsc_testnet_chapel` | Ankr 免费节点 |

### 付费 RPC（高可用/高速率）

| 提供方 | URL 示例 | 说明 |
|--------|----------|------|
| **QuickNode** | `https://xxx.bsc-testnet.quiknode.pro/xxx` | 需注册，有免费额度 |
| **Alchemy** | `https://bnb-testnet.g.alchemy.com/v2/YOUR_KEY` | 需注册 |
| **Infura** | `https://bsc-testnet.infura.io/v3/YOUR_KEY` | 需注册 |
| **NodeReal** | `https://bsc-testnet.nodereal.io/v1/YOUR_KEY` | BNB Chain 生态 |

### WSS (WebSocket)

| 提供方 | URL |
|--------|-----|
| **PublicNode** | `wss://bsc-testnet-rpc.publicnode.com` |

---

## 3. 水龙头（Faucet）— 领取测试币 tBNB

| 水龙头 | URL | 每次额度 | 备注 |
|--------|-----|----------|------|
| **BNB Chain 官方** | https://www.bnbchain.org/en/testnet-faucet | 0.3 tBNB | ⭐ 推荐 |
| **QuickNode** | https://faucet.quicknode.com/binance-smart-chain/bnb-testnet | 0.1 tBNB | 无需登录 |
| **Chainlink** | https://faucets.chain.link/bnb-chain-testnet | 0.1 tBNB | 需要 GitHub 登录 |
| **Moralis** | https://moralis.io/faucets/bnb-chain-testnet | 0.1 tBNB | 需注册 |

> 💡 **提示**：每个水龙头通常有冷却时间（12-24小时），建议多个交替使用。

---

## 4. 钱包添加 BSC Testnet

### MetaMask 手动添加

1. 打开 MetaMask → 设置 → 网络 → 添加网络
2. 填入以下信息：

```
网络名称:     BNB Smart Chain Testnet
RPC URL:      https://bsc-testnet-rpc.publicnode.com
链 ID:        97
货币符号:     tBNB
区块浏览器:   https://testnet.bscscan.com
```

### MetaMask 一键添加（代码方式）

```javascript
await window.ethereum.request({
  method: 'wallet_addEthereumChain',
  params: [{
    chainId: '0x61',           // 97 的十六进制
    chainName: 'BNB Smart Chain Testnet',
    nativeCurrency: {
      name: 'tBNB',
      symbol: 'tBNB',
      decimals: 18,
    },
    rpcUrls: ['https://bsc-testnet-rpc.publicnode.com'],
    blockExplorerUrls: ['https://testnet.bscscan.com'],
  }],
});
```

### OKX Wallet

1. 打开 OKX Wallet → 管理网络 → 搜索 "BSC Testnet"
2. 或手动添加（参数同上）

### Binance Wallet

Binance Web3 Wallet 内置支持 BSC Testnet，在网络列表中搜索 "BNB Smart Chain Testnet" 即可切换。

---

## 5. 项目合约信息

### 已部署合约

| 合约 | 地址 | 验证状态 |
|------|------|----------|
| **SBTINft** | [`0x3A1EfA877F5f36D7e54C182C859324Dc9bAd1a74`](https://testnet.bscscan.com/address/0x3A1EfA877F5f36D7e54C182C859324Dc9bAd1a74) | - |

### 合约参数

| 参数 | 值 |
|------|------|
| **Token Name** | SBTI Soul Stele |
| **Token Symbol** | SBTI |
| **Mint Price** | 0.0001 tBNB |
| **Max Supply** | 10,000 |
| **标准** | ERC-721 |
| **Solidity 版本** | 0.8.24 |

### 合约方法

| 方法 | 类型 | 说明 |
|------|------|------|
| `mint()` | payable | 铸造空白灵魂碑，需支付 0.0001 tBNB |
| `inscribe(tokenId, personalityIndex, dimensions, matchPercent)` | write | 铭刻测试结果到 NFT |
| `tokenURI(tokenId)` | view | 获取 NFT 元数据（链上 SVG 动态生成） |
| `getSoulStele(tokenId)` | view | 解包灵魂碑数据 |
| `isInscribed(tokenId)` | view | 查询 NFT 是否已铭刻 |
| `totalSupply()` | view | 已铸造总量 |
| `mintPrice()` | view | 当前铸造价格 |
| `setMintPrice(newPrice)` | onlyOwner | 修改铸造价格 |
| `withdraw()` | onlyOwner | 提取合约余额 |

---

## 6. 开发环境配置

### .env 文件

```bash
# ⚠️ 只用测试钱包的私钥！不要用有真实资产的钱包！
PRIVATE_KEY=0x你的测试钱包私钥
PUBLIC_KEY=0x你的测试钱包地址

# BSC Testnet RPC
BSC_TESTNET_RPC_URL=https://bsc-testnet-rpc.publicnode.com

# (可选) BscScan API Key — 合约验证用
BSCSCAN_API_KEY=你的BscScan_API_Key
```

### foundry.toml

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = true

[rpc_endpoints]
bsc_testnet = "https://bsc-testnet-rpc.publicnode.com"

[etherscan]
bsc_testnet = { key = "${BSCSCAN_API_KEY}", url = "https://api-testnet.bscscan.com/api" }
```

### 前端 app.js 关键配置

```javascript
// 合约地址
const CONTRACT_ADDRESS = '0x3A1EfA877F5f36D7e54C182C859324Dc9bAd1a74';

// 链 ID 校验
const EXPECTED_CHAIN_ID = 97;
const CHAIN_NAME = 'BSC Testnet';

// RPC（只读查询用）
const RPC_URL = 'https://bsc-testnet-rpc.publicnode.com';
```

---

## 7. 部署流程

### 前置条件

- 安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)
- 测试钱包里有 tBNB（从水龙头领取）
- `.env` 文件已配置私钥

### 编译

```bash
cd sbti
forge build
```

### 部署（一键脚本）

```bash
chmod +x deploy.sh
./deploy.sh
```

### 部署（手动）

```bash
source .env

forge script script/Deploy.s.sol:DeploySBTI \
  --rpc-url https://bsc-testnet-rpc.publicnode.com \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv
```

### 合约验证（可选）

```bash
forge verify-contract \
  --chain-id 97 \
  --compiler-version v0.8.24 \
  --optimizer-runs 200 \
  0x合约地址 \
  contracts/SBTINft.sol:SBTINft \
  --etherscan-api-key $BSCSCAN_API_KEY \
  --verifier-url https://api-testnet.bscscan.com/api
```

---

## 8. 常用命令速查

```bash
# 编译合约
forge build

# 运行测试
forge test -vvv

# 本地节点
anvil --chain-id 97

# 部署到本地
forge script script/Deploy.s.sol:DeploySBTI \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast

# 查询合约（用 cast）
cast call 0x3A1EfA877F5f36D7e54C182C859324Dc9bAd1a74 "totalSupply()" --rpc-url https://bsc-testnet-rpc.publicnode.com
cast call 0x3A1EfA877F5f36D7e54C182C859324Dc9bAd1a74 "mintPrice()" --rpc-url https://bsc-testnet-rpc.publicnode.com

# 启动前端
cd frontend && python3 -m http.server 8080
```

---

## 9. 常见问题

### Q: MetaMask 提示 "Chain ID 不匹配"？
**A**: 确保钱包已切换到 BSC Testnet（Chain ID: 97），不是 BSC Mainnet（Chain ID: 56）。

### Q: 交易一直 pending？
**A**: BSC Testnet 偶尔会拥堵，可以尝试：
1. 换一个 RPC 节点
2. 等待几分钟
3. 在 MetaMask 中 "加速" 交易

### Q: 没有 tBNB 怎么办？
**A**: 使用上面列出的水龙头领取，每个水龙头可领 0.1-0.3 tBNB，多个交替使用。

### Q: Gas 费怎么设？
**A**: BSC Testnet 的 gas price 通常是 10 Gwei，单次 mint 大约消耗 0.0001-0.001 tBNB gas。项目中已设置 `gasLimit: 150000`。

### Q: 合约部署失败报 "insufficient funds"？
**A**: 确保测试钱包有足够的 tBNB 支付部署 gas（建议至少 0.1 tBNB）。

### Q: BscScan 上看不到合约源码？
**A**: 需要执行合约验证（见第 7 节），验证后才能在区块浏览器上查看源码和交互。

---

## 10. 相关链接

| 资源 | URL |
|------|-----|
| **BSC Testnet 浏览器** | https://testnet.bscscan.com |
| **BSC Mainnet 浏览器** | https://bscscan.com |
| **BNB Chain 官方文档** | https://docs.bnbchain.org |
| **BscScan API** | https://docs.bscscan.com |
| **Foundry 文档** | https://book.getfoundry.sh |
| **OpenZeppelin Contracts** | https://docs.openzeppelin.com/contracts |
| **BSC Testnet 状态** | https://testnet.bscscan.com/nodetracker |

---

> 📝 **注意**：BSC Testnet 的代币 (tBNB) 没有真实价值，仅用于测试。**切勿在测试网上使用持有真实资产的钱包私钥！**
