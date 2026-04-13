#!/bin/bash
# ============================================
# SBTI NFT 一键部署脚本
# 支持 testnet / mainnet 环境切换
# ============================================
#
# 用法:
#   ./deploy.sh testnet     # 部署到 BSC 测试网（便宜价格）
#   ./deploy.sh mainnet     # 部署到 BSC 正式网（正式价格）
#   ./deploy.sh             # 默认 = testnet
#
# 环境差异:
#   testnet: mintPrice = 0.018 BNB, BSC Testnet (ChainID 97)
#   mainnet: mintPrice = 0.018 BNB, BSC Mainnet (ChainID 56)
#

set -e

# ============ 1. 确定目标环境 ============
ENV="${1:-testnet}"

if [[ "$ENV" != "testnet" && "$ENV" != "mainnet" ]]; then
    echo "❌ 无效环境: $ENV"
    echo "   用法: ./deploy.sh [testnet|mainnet]"
    exit 1
fi

ENV_FILE=".env.${ENV}"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 找不到环境配置文件: $ENV_FILE"
    echo "   请先复制 .env.example 并填写配置"
    exit 1
fi

# ============ 2. 加载环境变量 ============
set -a
source "$ENV_FILE"
set +a

echo ""
echo "╔══════════════════════════════════════╗"
if [ "$ENV" = "mainnet" ]; then
echo "║  🚀 SBTI NFT — BSC Mainnet 正式部署  ║"
else
echo "║  🧪 SBTI NFT — BSC Testnet 测试部署  ║"
fi
echo "╚══════════════════════════════════════╝"
echo ""

# ============ 3. 安全检查 ============
if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "your_mainnet_private_key_here" ]; then
    echo "❌ 请先在 $ENV_FILE 中填入你的钱包私钥！"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo "❌ 请先在 $ENV_FILE 中填入 RPC_URL！"
    exit 1
fi

# 正式网额外确认
if [ "$ENV" = "mainnet" ]; then
    echo "⚠️  你正在部署到 BSC Mainnet（正式网），这将消耗真实 BNB！"
    echo ""
    echo "   网络:     BSC Mainnet (Chain ID: 56)"
    echo "   RPC:      $RPC_URL"
    echo "   价格:     $(echo "scale=6; $MINT_PRICE / 1000000000000000000" | bc) BNB"
    echo ""
    read -p "   确认继续？(yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "❌ 已取消"
        exit 0
    fi
    echo ""
fi

# ============ 4. 打印配置摘要 ============
echo "📋 部署配置:"
echo "   环境:     $ENV"
echo "   网络:     $RPC_URL"
echo "   Chain ID: ${CHAIN_ID:-auto}"
echo "   价格:     $(echo "scale=6; $MINT_PRICE / 1000000000000000000" | bc) BNB ($MINT_PRICE wei)"
echo "   自动设价: ${AUTO_SET_PRICE:-false}"
echo ""

# ============ 5. 编译合约 ============
echo "📦 编译合约..."
forge build
echo "✅ 编译完成"
echo ""

# ============ 6. 部署 ============
echo "🔗 部署到 $ENV..."
forge script script/Deploy.s.sol:DeploySBTI \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    -vvv

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ 部署完成！                        ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "📌 下一步:"
echo "   1. 复制合约地址更新到 frontend/app.js 中的 CONTRACT_ADDRESS"
echo "   2. 在 ${EXPLORER_URL:-区块浏览器} 上验证合约"
if [ "$ENV" = "testnet" ]; then
echo "   3. 测试完成后，运行 ./deploy.sh mainnet 部署正式版"
fi
echo ""
