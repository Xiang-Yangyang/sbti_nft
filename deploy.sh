#!/bin/bash
# SBTI NFT 一键部署到 BSC Testnet 测试网
# 使用前请先在 .env 文件中填入你的钱包私钥

set -e

echo "🚀 SBTI NFT 部署到 BSC Testnet..."
echo ""

# 加载环境变量
source .env

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ 请先在 .env 文件中填入你的钱包私钥！"
    exit 1
fi

echo "📦 编译合约..."
forge build

echo ""
echo "🔗 部署到 BSC Testnet (Chain ID: 97)..."
forge script script/Deploy.s.sol:DeploySBTI \
    --rpc-url https://bsc-testnet-rpc.publicnode.com \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vvv

echo ""
echo "✅ 部署完成！请复制合约地址更新到 frontend/app.js 中的 CONTRACT_ADDRESS"
