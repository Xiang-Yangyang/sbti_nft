# 🧪 SBTI NFT 测试网部署指南

> **适用场景**：开发测试、功能验证、前端联调  
> **目标网络**：BSC Testnet (Chain ID: 97)  
> **特点**：免费测试币、快速迭代、无真实资金风险

---

## 📋 目录

- [前置准备](#前置准备)
- [快速部署](#快速部署)
- [详细步骤](#详细步骤)
- [常见问题](#常见问题)
- [从测试网到主网](#从测试网到主网)

---

## 前置准备

### 1. 安装开发工具

```bash
# 确认 Foundry 已安装
forge --version

# 如果没装，运行：
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 获取测试网 BNB

测试网 BNB 完全免费，从水龙头领取：

| 水龙头 | 链接 | 每次额度 | 冷却时间 |
|---|---|---|---|
| **官方水龙头** | https://testnet.bnbchain.org/faucet-smart | 0.5 tBNB | 24h |
| **备用水龙头 1** | https://www.bnbchain.org/en/testnet-faucet | 0.1 tBNB | 24h |
| **备用水龙头 2** | https://stakely.io/faucet/binance-testnet-bnb | 0.5 tBNB | 24h |

**所需测试币**：约 0.05 - 0.1 tBNB（部署 + 测试用）

### 3. 创建测试钱包

**⚠️ 重要提示**：
- ✅ **必须**使用专门的测试钱包
- ❌ **禁止**使用有真实资产的钱包
- ❌ **禁止**使用主网钱包私钥

```bash
# 方法 1: MetaMask 创建新账户（推荐）
# 设置 → 高级 → 显示测试网络 → 切换到 BSC Testnet → 创建账户

# 方法 2: Cast 生成新钱包
cast wallet new
```

### 4. 配置环境变量

复制并编辑 `.env.testnet`：

```bash
cd /path/to/sbti_nft
cp .env.example .env.testnet
vim .env.testnet
```

**必须填写的配置**：

```bash
# ============================================
# 🧪 SBTI NFT — BSC Testnet 测试环境配置
# ============================================

# ⚠️ 只用测试钱包的私钥！
PRIVATE_KEY=0xYOUR_TEST_WALLET_PRIVATE_KEY_HERE

# 网络配置（默认即可）
RPC_URL=https://bsc-testnet-rpc.publicnode.com
CHAIN_ID=97
EXPLORER_URL=https://testnet.bscscan.com

# 合约参数
# 测试网使用便宜价格，方便测试
MINT_PRICE=100000000000000          # 0.0001 BNB
AUTO_SET_PRICE=true

# 合约验证（可选，留空也行）
SCAN_API_KEY=
```

---

## 快速部署

### 一键部署脚本

```bash
cd /path/to/sbti_nft

# 1. 清理旧部署（可选）
rm -rf broadcast/ cache/

# 2. 部署到测试网
./deploy.sh testnet
```

**预期输出**：

```
╔══════════════════════════════════════╗
║  🧪 SBTI NFT — BSC Testnet 测试部署  ║
╚══════════════════════════════════════╝

📋 部署配置:
   环境:     testnet
   网络:     https://bsc-testnet-rpc.publicnode.com
   Chain ID: 97
   价格:     0.0001 BNB (100000000000000 wei)
   自动设价: true

📦 编译合约...
✅ 编译完成

🔗 部署到 testnet...

=== Deployment Summary ===
Renderer: 0x1234...abcd
Contract: 0x5678...efgh
Final Mint Price (wei): 100000000000000
Max Supply: 16384
Owner: 0xYourAddress...

╔══════════════════════════════════════╗
║  ✅ 部署完成！                        ║
╚══════════════════════════════════════╝
```

### 记录合约地址

```bash
# 复制控制台输出的两个地址：
Renderer: 0x...
Contract: 0x...

# 或从部署记录中获取：
cat broadcast/Deploy.s.sol/97/run-latest.json | jq -r '.transactions[].contractAddress'
```

---

## 详细步骤

### Step 1: 编译合约

```bash
forge build
```

**检查是否有错误**：
- ✅ `Compiler run successful!` → 继续
- ❌ 有报错 → 检查 Solidity 版本和依赖

### Step 2: 运行测试（推荐）

```bash
# 运行单元测试
forge test

# 查看 Gas 报告
forge test --gas-report

# 测试覆盖率
forge coverage
```

### Step 3: 执行部署

```bash
# 加载环境变量
source .env.testnet

# 部署合约
forge script script/Deploy.s.sol:DeploySBTI \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    -vvv
```

**部署流程**：
1. 先部署 `SBTIRenderer` 渲染合约
2. 再部署 `SBTINft` 主合约（传入 Renderer 地址）
3. 如果 `AUTO_SET_PRICE=true`，自动调用 `setMintPrice()`

### Step 4: 验证部署

```bash
# 检查合约是否有代码
cast code 0xYourContractAddress --rpc-url $RPC_URL

# 查询 Mint 价格
cast call 0xYourContractAddress "mintPrice()(uint256)" --rpc-url $RPC_URL

# 查询 Owner
cast call 0xYourContractAddress "owner()(address)" --rpc-url $RPC_URL

# 查询最大供应量
cast call 0xYourContractAddress "MAX_SUPPLY()(uint256)" --rpc-url $RPC_URL
```

### Step 5: 更新前端配置

编辑 `frontend/config.js`：

```javascript
const SBTI_CONFIG = {
  // ============ 合约地址 ============
  CONTRACT_ADDRESS: '0xYourNewContractAddress',  // 👈 改这里
  RENDERER_ADDRESS: '0xYourNewRendererAddress',  // 👈 改这里

  // ... 其他配置保持不变
};
```

### Step 6: 测试前端

```bash
# 启动本地服务器
cd frontend
python3 -m http.server 8000

# 浏览器访问
open http://localhost:8000
```

**测试清单**：
- [ ] 连接 MetaMask（切换到 BSC Testnet）
- [ ] Mint NFT（支付 0.0001 tBNB）
- [ ] 查看 My Collection
- [ ] 做人格测试 → 铭刻
- [ ] 查看 SVG 渲染结果
- [ ] 检查 tokenURI 和 metadata

---

## 常见问题

### 1. 部署失败：`insufficient funds`

**原因**：测试网 BNB 不足

**解决**：
```bash
# 查询余额
cast balance 0xYourAddress --rpc-url $RPC_URL

# 去水龙头领取测试币
open https://testnet.bnbchain.org/faucet-smart
```

### 2. 部署失败：`nonce too low` 或 `already known`

**原因**：之前的交易卡在 mempool 里

**解决**：
```bash
# 查看当前 nonce
cast nonce 0xYourAddress --rpc-url $RPC_URL

# 发一笔空交易清理卡住的 nonce
cast send 0xYourAddress \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --nonce YOUR_NONCE \
    --gas-price 3gwei \
    --value 0 \
    --legacy

# 清理缓存重新部署
rm -rf broadcast/ cache/
./deploy.sh testnet
```

### 3. 部署失败：`replacement transaction underpriced`

**原因**：新交易的 gas price 低于 mempool 中的旧交易

**解决**：
```bash
# 用更高的 gas price 部署
forge script script/Deploy.s.sol:DeploySBTI \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --with-gas-price 5000000000 \  # 5 gwei
    -vvv
```

### 4. RPC 超时或连接失败

**原因**：公共 RPC 节点不稳定

**解决**：换一个 RPC 节点

```bash
# 编辑 .env.testnet，尝试以下 RPC：
RPC_URL=https://bsc-testnet-rpc.publicnode.com          # 默认
# RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545  # 官方 1
# RPC_URL=https://data-seed-prebsc-2-s1.binance.org:8545  # 官方 2
# RPC_URL=https://endpoints.omniatech.io/v1/bsc/testnet/public  # Omniatech
```

### 5. 前端连接不上合约

**检查清单**：
- [ ] MetaMask 是否切换到 BSC Testnet？
- [ ] `config.js` 中的合约地址是否正确？
- [ ] 合约是否真的部署成功（用 BscScan 查）？
- [ ] 浏览器控制台有没有报错？

```javascript
// 打开浏览器控制台（F12），检查：
console.log(CONTRACT_ADDRESS);  // 合约地址对吗？
console.log(await provider.getNetwork());  // chainId 是 97 吗？
```

### 6. Mint 交易失败

**可能原因**：
1. **Gas 不足** → 钱包里充值更多 tBNB
2. **支付金额不对** → 检查 `mintPrice()`
3. **已达到最大供应量** → 检查 `totalSupply()` vs `MAX_SUPPLY`

```bash
# 检查合约状态
cast call $CONTRACT_ADDRESS "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $CONTRACT_ADDRESS "mintPrice()(uint256)" --rpc-url $RPC_URL
cast call $CONTRACT_ADDRESS "MAX_SUPPLY()(uint256)" --rpc-url $RPC_URL
```

---

## 从测试网到主网

测试网验证完毕后，部署主网只需要 3 步：

### 1. 修改价格

编辑 `contracts/SBTINft.sol`：

```solidity
// 测试网（当前）
uint256 public mintPrice = 0.0001 ether;  // 测试用

// 主网（改成正式价格）
uint256 public mintPrice = 0.018 ether;   // 正式价格
```

编辑 `.env.mainnet`：

```bash
MINT_PRICE=18000000000000000  # 0.018 BNB
AUTO_SET_PRICE=false          # 主网用合约默认值
```

### 2. 切换主网配置

```bash
# 填写主网钱包私钥和配置
vim .env.mainnet

# ⚠️ 确保：
# - 使用真实钱包（有足够 BNB）
# - RPC_URL 换成主网的（推荐 NodeReal）
# - SCAN_API_KEY 填写 BscScan API Key（用于验证合约）
```

### 3. 部署主网

```bash
# ⚠️ 最后确认一遍配置！
cat .env.mainnet

# 部署主网（会有二次确认）
./deploy.sh mainnet

# 更新前端配置
# 1. 把 config.js 改成 config.mainnet.js
# 2. index.html 引用 config.mainnet.js
# 3. 更新合约地址 + RPC + 区块浏览器 URL
```

**详细主网部署步骤**：见 [`MAINNET_DEPLOY_GUIDE.md`](./MAINNET_DEPLOY_GUIDE.md)

---

## 测试网 vs 主网对比

| 项目 | 测试网 | 主网 |
|---|---|---|
| **Chain ID** | 97 | 56 |
| **RPC** | `bsc-testnet-rpc.publicnode.com` | `bsc-dataseed1.bnbchain.org` |
| **浏览器** | testnet.bscscan.com | bscscan.com |
| **Mint 价格** | 0.0001 BNB（测试用） | 0.018 BNB（正式） |
| **测试币** | 免费领取 | 真实 BNB，需购买 |
| **风险** | 零风险 | 真实资金，需谨慎 |
| **用途** | 开发测试、功能验证 | 正式上线 |

---

## 快速参考

### 常用命令

```bash
# 编译
forge build

# 测试
forge test -vvv

# 部署测试网
./deploy.sh testnet

# 查询合约
cast call $CONTRACT_ADDRESS "mintPrice()(uint256)" --rpc-url $RPC_URL

# 查询余额
cast balance $YOUR_ADDRESS --rpc-url $RPC_URL

# 清理缓存
rm -rf broadcast/ cache/ out/
```

### 测试网资源

| 资源 | 链接 |
|---|---|
| 🚰 水龙头 | https://testnet.bnbchain.org/faucet-smart |
| 🔍 区块浏览器 | https://testnet.bscscan.com |
| 📡 RPC 列表 | https://docs.bnbchain.org/docs/rpc |
| 📖 官方文档 | https://docs.bnbchain.org/docs/learn/intro |

### 合约地址示例

```bash
# 测试网最新部署（供参考）
Renderer: 0x515FA86dEcB6565905E880875Dd2D8455443b113
Contract: 0xB6279d850B63cfBba46B08b3eD92D0175019ce55

# 主网地址（部署后填入）
Renderer: TBD
Contract: TBD
```

---

## 下一步

- ✅ 测试网部署成功 → [主网部署指南](./MAINNET_DEPLOY_GUIDE.md)
- 📊 查看成本分析 → [BSC 成本分析](./BSC_COST_ANALYSIS.md)
- 🎨 配置前端 → [前端配置说明](../frontend/README.md)
- 📈 营销推广 → [营销方案](./marketing/README.md)

---

**最后提醒**：
- 🔐 **测试钱包私钥不要和主网钱包混用**
- 💰 **测试网 BNB 无价值，可以随便用**
- 🧪 **充分测试后再部署主网**
- 📝 **记录每次部署的合约地址和交易哈希**

祝部署顺利！🚀
