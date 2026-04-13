# BSC 主网部署完整教程 (独立操作指南)

> **安全第一!** 本教程教你如何不依赖 AI,独立完成主网部署,保护私钥安全。

---

## 📋 准备清单

- [ ] 一个全新的钱包地址(用于主网部署)
- [ ] 0.02 BNB (在钱包里)
- [ ] 已安装 Foundry (forge/cast 工具)
- [ ] 本项目代码

---

## 第一步: 生成主网专用钱包 🔐

### 方法 A: 用 cast 命令生成(推荐)

```bash
# 1. 生成新钱包
cast wallet new

# 输出示例:
# Successfully created new keypair.
# Address:     0xAbC1234567890DEF...  👈 这是你的公钥地址
# Private key: 0x1234abcd...          👈 这是你的私钥
```

**立刻做这些事:**
1. ✅ 把 **Private key** 复制到安全的地方(密码管理器/加密笔记)
2. ✅ 把 **Address** 记下来
3. ⚠️ **千万不要分享私钥给任何人(包括 AI)**

---

### 方法 B: 用 MetaMask 创建

1. 打开 MetaMask 钱包
2. 点击右上角头像 → "创建账户" → "创建新账户"
3. 点击账户详情 → "导出私钥" → 输入密码
4. 复制私钥保存到安全的地方

---

## 第二步: 给钱包充值 💰

1. 复制你的 **Address**(公钥地址)
2. 从交易所(币安/OKX 等)提币到这个地址
3. 提币金额: **0.02 BNB** (网络选 BNB Smart Chain/BEP20)
4. 等待到账(通常 1-3 分钟)

**验证到账:**
```bash
# 查询余额
cast balance 你的地址 --rpc-url https://bsc-dataseed.binance.org

# 或者去 BscScan 查看
# https://bscscan.com/address/你的地址
```

---

## 第三步: 配置环境变量 ⚙️

### 1. 复制主网配置文件模板

```bash
cd /Users/xiangyangyang/Programme/Projects/game_nft/sbti_nft
cp .env.mainnet .env.mainnet.real
```

### 2. 编辑 `.env.mainnet.real` 文件

用你喜欢的编辑器打开(VS Code/Sublime/vim 都行):

```bash
code .env.mainnet.real
# 或者
vim .env.mainnet.real
```

把文件内容改成这样:

```bash
# BSC 主网 RPC
RPC_URL=https://bsc-dataseed.binance.org

# 你的主网钱包私钥 (第一步生成的那个 0x 开头的 64 位十六进制)
PRIVATE_KEY=0x你的私钥粘贴到这里

# 验证器 API Key (可选,用于自动验证合约)
# 去 https://bscscan.com/myapikey 申请
# 免费,注册后就能创建 API Key
ETHERSCAN_API_KEY=你的BscScan_API_Key

# Mint 价格 (已设置为 0.018 BNB,不用改)
MINT_PRICE=18000000000000000

# 链 ID (BSC 主网固定为 56)
CHAIN_ID=56
```

**保存文件后,检查一下:**
```bash
# 确认文件存在
ls -la .env.mainnet.real

# 确认 .gitignore 已忽略这个文件 (避免误提交)
grep "\.env\.mainnet\.real" .gitignore || echo ".env.mainnet.real" >> .gitignore
```

---

## 第四步: 部署合约 🚀

### 完整部署脚本

把下面的命令**一次性全部执行**:

```bash
#!/bin/bash
# 进入项目目录
cd /Users/xiangyangyang/Programme/Projects/game_nft/sbti_nft

# 加载环境变量
source .env.mainnet.real

# 确认配置
echo "========================================"
echo "部署配置确认:"
echo "========================================"
echo "RPC: $RPC_URL"
echo "钱包地址: $(cast wallet address --private-key $PRIVATE_KEY)"
echo "当前余额: $(cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL | awk '{printf "%.6f BNB", $1/1e18}')"
echo "Mint 价格: $MINT_PRICE wei ($(python3 -c "print($MINT_PRICE / 1e18)") BNB)"
echo "========================================"
read -p "确认无误按回车继续,按 Ctrl+C 取消..."

# 部署合约 (Forge 会自动部署两个合约并设置关联)
echo ""
echo "🚀 开始部署..."
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvv

# 部署完成
echo ""
echo "✅ 部署完成!"
echo "📂 部署记录保存在: broadcast/Deploy.s.sol/56/run-latest.json"
```

---

### 如何执行部署

**方式 1: 复制粘贴到终端(推荐新手)**

1. 打开终端
2. 把上面的整段代码全部复制
3. 粘贴到终端
4. 按回车

**方式 2: 保存为脚本执行**

```bash
# 1. 把上面的代码保存为 deploy_mainnet.sh
cat > deploy_mainnet.sh << 'SCRIPT'
# (把上面的完整脚本粘贴到这里)
SCRIPT

# 2. 给脚本执行权限
chmod +x deploy_mainnet.sh

# 3. 运行
./deploy_mainnet.sh
```

---

## 第五步: 部署成功后做什么 🎉

### 1. 查看部署记录

```bash
cat broadcast/Deploy.s.sol/56/run-latest.json | jq '.transactions[] | {contract: .contractName, address: .contractAddress}'
```

你会看到两个合约地址:
```json
{
  "contract": "SBTIRenderer",
  "address": "0xABC123..."
}
{
  "contract": "SBTINft",
  "address": "0xDEF456..."
}
```

**记录这两个地址!** 特别是 **SBTINft 地址**,这是你的 NFT 主合约。

---

### 2. 在 BscScan 验证合约

部署脚本带 `--verify` 参数会自动验证,稍等 1-2 分钟后访问:

```
https://bscscan.com/address/你的SBTINft地址
```

应该能看到绿色的 ✅ 标记和源码。

---

### 3. 更新前端配置

编辑 `frontend/config.js`:

```javascript
const CONTRACT_ADDRESS = '0xDEF456...'; // 👈 改成你的 SBTINft 地址
```

---

### 4. 测试 mint 功能

```bash
# 用小号钱包测试 mint (不要用部署钱包)
cast send 你的SBTINft地址 \
  "mint()" \
  --value 0.018ether \
  --rpc-url https://bsc-dataseed.binance.org \
  --private-key 测试钱包私钥
```

---

## 第六步: 部署前端到 GitHub Pages 🌐

### 1. 更新代码

```bash
git add frontend/config.js
git commit -m "Update contract address for mainnet"
git push origin main
```

### 2. 前端会自动部署

GitHub Actions 会自动部署到:
```
https://你的用户名.github.io/game_nft/
```

等 1-2 分钟后访问测试。

---

## 🔒 安全提醒

### ✅ 做这些:
- ✅ 用全新钱包部署主网(不要用测试网那个)
- ✅ 私钥保存在加密的地方(密码管理器)
- ✅ 部署完立刻从终端历史删除私钥
- ✅ 定期 `withdraw()` 提取合约余额

### ❌ 不要做:
- ❌ 不要把 `.env.mainnet.real` 提交到 git
- ❌ 不要在公开聊天/截图里暴露私钥
- ❌ 不要用交易所钱包部署(可能不支持合约)
- ❌ 不要在部署钱包里存大量 BNB

---

## 📊 管理操作

部署后你可能需要的操作:

### 改 mint 价格
```bash
cast send 你的SBTINft地址 \
  "setMintPrice(uint256)" \
  新价格(单位wei) \
  --rpc-url https://bsc-dataseed.binance.org \
  --private-key $PRIVATE_KEY
```

### 提取收入
```bash
cast send 你的SBTINft地址 \
  "withdraw()" \
  --rpc-url https://bsc-dataseed.binance.org \
  --private-key $PRIVATE_KEY
```

### 更换渲染器
```bash
cast send 你的SBTINft地址 \
  "setRenderer(address)" \
  新渲染器地址 \
  --rpc-url https://bsc-dataseed.binance.org \
  --private-key $PRIVATE_KEY
```

---

## ❓ 常见问题

### Q1: 部署失败提示 "insufficient funds"
**A:** 钱包余额不足,再充点 BNB。

### Q2: 部署卡住不动
**A:** 可能是 RPC 超时,按 `Ctrl+C` 停止,换个 RPC 重试:
```bash
# 备用 RPC
RPC_URL=https://bsc-dataseed1.defibit.io
# 或者
RPC_URL=https://rpc.ankr.com/bsc
```

### Q3: 验证失败
**A:** 等几分钟再刷新 BscScan,或者手动验证:
```bash
forge verify-contract \
  合约地址 \
  contracts/SBTINft.sol:SBTINft \
  --chain-id 56 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Q4: 如何确认部署成功?
**A:** 看到这些就成功了:
- ✅ 终端显示 "Transaction: 0x..."
- ✅ BscScan 能查到合约地址
- ✅ 能调用 `mintPrice()` 读取价格

---

## 🎯 总结

1. **生成钱包** → 保护好私钥
2. **充值 0.02 BNB** → 够部署了
3. **配置 `.env.mainnet.real`** → 填入私钥和 RPC
4. **运行部署脚本** → 一行命令搞定
5. **记录合约地址** → 更新前端配置
6. **推送代码** → GitHub Pages 自动部署

**成本:** ≈ ¥30  
**时间:** ≈ 10 分钟  
**难度:** ⭐⭐☆☆☆

祝你部署顺利! 🚀
