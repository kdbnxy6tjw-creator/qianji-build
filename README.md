# 钱迹 QianJi v2.0.0（iOS 16 源码工程）

纯本地记账 App，iOS 16.0+，未签名 IPA + TrollStore 安装。
版本规范：SemVer 2.0.0（见 VERSION.md）。

## 目录
- Core/       数据模型（程序化 Core Data）、设置、统计、回收站查询、备份
- Theme/      主题、触感、动画（Motion）、玻璃胶囊（GlassCapsule）、底栏、Toast
- Features/   概览 / 交易 / 记账页 / 钱包 / 设置 / 回收站
- Icons/      松散 PNG 图标（不经过 actool）
- scripts/    generate_xcodeproj.py（新增 Swift 文件后重跑）、build_unsigned_ipa.sh

## 构建（macOS + Xcode 15/16）
    python3 scripts/generate_xcodeproj.py   # 仅在增删 .swift 后需要
    bash scripts/build_unsigned_ipa.sh

脚本只用 -target + -sdk iphoneos + SYMROOT，不触发 actool、不需要模拟器 runtime、
不走签名；产物 build/QianJi-unsigned.ipa，用 TrollStore 安装。

## 数据升级说明
- v1.0 → v2.0 Core Data 轻量迁移（新增可选属性 deletedAt），本机已有账目会自动保留。
- 跨设备/重装迁移：设置页「导出备份」→ JSON 存到「文件」App →
  新装后「导入备份」选择该 JSON；导入按 UUID 去重，可重复导入。
