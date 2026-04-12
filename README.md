# 🪦 SBTI × NFT — 灵魂墓碑人格测试

> **买 NFT → 做人格测试 → 结果永久刻在链上墓碑**

## 概念

将爆火的 SBTI 人格测试与 NFT 结合：
- 🎫 **Mint NFT** — 购买一张空白灵魂卡片
- 📝 **做测试** — 31道题，15维度人格分析
- 🪦 **生成墓碑** — 测试结果永久上链，NFT 变成你的灵魂墓碑
- 🎨 **链上 SVG** — 根据人格类型动态生成独一无二的墓碑图片

## 技术栈

- **合约**: Solidity + Foundry (ERC-721)
- **前端**: HTML + Vanilla JS + ethers.js
- **链**: Base L2 (低 gas)
- **存储**: 链上 SVG 动态生成

## 项目结构

```
sbti/
├── contracts/          # 智能合约
│   └── SBTINft.sol     # 核心 NFT 合约
├── frontend/           # 前端 DApp
│   ├── index.html      # 主页面
│   ├── app.js          # 主逻辑
│   ├── sbti-engine.js  # SBTI 算法引擎
│   └── style.css       # 样式
├── script/             # 部署脚本
├── test/               # 合约测试
└── README.md
```

## 玩法流程

```
用户连接钱包 → Mint NFT (空白卡片)
     ↓
开始答题 (31道题)
     ↓
前端计算 15 维度分数
     ↓
曼哈顿距离匹配 → 得出人格类型
     ↓
调用合约 inscribe() → 结果上链
     ↓
NFT 从空白卡片 → 灵魂墓碑 (链上 SVG)
     ↓
可在 OpenSea / OKX Wallet 查看
```

## 27 种人格结局

CTRL(拿捏者) · ATM-er(送钱者) · BOSS(领导者) · SEXY(尤物) · DEAD(死者) · MONK(僧人) ...
+ HHHH(傻乐者) · DRUNK(酒鬼) 两个隐藏款
