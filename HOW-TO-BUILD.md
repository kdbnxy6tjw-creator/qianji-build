# 把 v2.0.0 装进手机（不装 iOS 17.5、不用本地 Xcode）

> 这份说明解决的是：**所有 v2.0 更新（Q弹玻璃 / 文字显隐 / 右滑删除 / 回收站 / 统一动画 / 导出去重）都在源码里，必须重新编译一次才能进 IPA。**
> 你本地 Xcode 15.4 缺 iOS 17.5 平台组件，所以把编译搬到 GitHub 自带的 macOS 机器上做。
> 全程不用装任何东西，也不用签名的 ldid。

---

## 先看清楚：不要再用旧的图标注入包

`QianJi-Icon-Injector.zip` 是给**你之前那个 v1.0 旧 IPA**换图标用的。
跑它得到的是「换了新图标的 v1.0」，**没有任何 v2.0 功能**。这次请忽略它。

本包里的 `Icons/` 已经是新图标，编译时会自己进 `.app`，不需要再注入。

---

## 方案：GitHub Actions 云编译（约 5 分钟，纯网页操作）

GitHub 的 macOS 机器自带完整 Xcode 和 iOS SDK，**不需要下载 17.5 组件**。

### 第 1 步：解压

```bash
cd ~/Downloads
unzip -o QianJi-v2.0.0-cloudbuild.zip
```

得到 `QianJiV2/` 文件夹。

### 第 2 步：建一个 GitHub 仓库

1. 打开 https://github.com/new
2. 仓库名随便填，例如 `qianji-build`
3. **选 Public**（公开仓库的 macOS runner 免费且不计分钟；私有仓库会按 10 倍扣额度）
4. 不要勾 "Add a README"、不要选 .gitignore
5. 点 **Create repository**

### 第 3 步：上传文件（关键：`.github` 必须一起传）

创建后点 **uploading an existing file**（或 "Add file → Upload files"）。

在 Mac Finder 里按 **`Cmd + Shift + .`** 显示隐藏文件，然后把 `QianJiV2/` **里面的所有内容**拖进上传区：

```
.github/            ← 隐藏文件夹，必须传（少了它 Actions 不会触发）
Core/
Theme/
Features/
Icons/
scripts/
MoneyNote.xcodeproj/
Info.plist
README.md
VERSION.md
BUILD_TAG.txt
HOW-TO-BUILD.md
```

> 注意：是把 **文件夹里的内容** 拖进去，不要连外层 `QianJiV2/` 一起拖，否则工程会多套一层目录。

拉到页面底部点 **Commit changes**。

### 第 4 步：跑编译

1. 仓库页点顶部 **Actions**
2. 左侧选 **build-qianji-v2-unsigned-ipa**
3. 右侧 **Run workflow** → 再点一次 **Run workflow**
4. 等 3~8 分钟，圆点变绿 ✅

### 第 5 步：下载 IPA

点进那次运行 → 页面底部 **Artifacts** → 下载 `QianJi-v2.0.0-unsigned-ipa`。
解压 zip 得到 **`QianJi-v2.0.0-unsigned.ipa`**。

### 第 6 步：装手机

传到 iPhone「文件」App → 打开方式选 **TrollStore** → 安装。
巨魔会自行伪签名，**本地不用 ldid、不用签名工具**。

---

## 如果你习惯用命令行推（比网页上传更不容易漏 `.github`）

```bash
cd ~/Downloads/QianJiV2
git init
git add -A
git commit -m "QianJi v2.0.0"
git branch -M main
git remote add origin https://github.com/你的用户名/qianji-build.git
git push -u origin main
```

推上去后会自动触发一次编译（push main 也会跑）；也可以去 Actions 手动 Run workflow。

---

## 怎么确认拿到的是 v2.0.0 而不是旧版

装上后看这四处，任意一处不对就是装成 v1.0 了：

1. **设置页底部版本**：显示 `钱迹 · v2.0.0`
2. **设置页多出「外观与手感」**：显示底栏文字 / 显示＋页类别文字 / 删除前二次确认 三个开关
3. **设置页多出「回收站」**入口，点进去是二级页，可选 3/7/30 天 / 不自动清理
4. **底栏切 tab 有 Q弹玻璃胶囊**，＋页收支切换也是同款；交易列表**从右往左滑**能删账目，删完弹「已移入回收站」

---

## 这个包里有什么

| 路径 | 内容 |
|---|---|
| `Theme/Motion.swift` | 全 app 唯一动画真源（snap / pop / settle / easeOut） |
| `Theme/GlassCapsule.swift` | Q弹玻璃胶囊，无折射无扭曲，白黑描边 |
| `Theme/FloatingTabBar.swift` | 文字可隐藏、图标放大、底栏高度不变 |
| `Features/RecycleBin/RecycleBinView.swift` | 回收站二级页 |
| `Core/RecycleStore.swift` | 回收站查询 / 过期文案 |
| `Core/MNEntities.swift` | `MNTransaction.deletedAt`（软删除，Core Data 轻量迁移） |
| `Core/Stores.swift` | 软删除 / 恢复 / 彻底删除 / 进前台清过期 |
| `Features/Settings/Backup.swift` | 导出 version 2 + 按 UUID 去重导入 |
| `Features/Settings/SettingsView.swift` | 外观开关 + 回收站入口 + 版本号 2.0.0 |
| `Icons/` | 24 个新图标 PNG（满幅方形、白牌 ¥、绿色＋） |
| `.github/workflows/build-ipa.yml` | 云编译：编译 → 注入图标 → 自检 → 上传 IPA |

版本严格按 SemVer 2.0.0：`MARKETING_VERSION = 2.0.0`，`CURRENT_PROJECT_VERSION = 2`。

---

## 常见问题

**Q：Actions 里报错 `Found no destinations`？**
云端不应出现。若出现，说明仓库传漏了 `MoneyNote.xcodeproj/xcshareddata/xcschemes/QianJi.xcscheme`，或外层多套了一层目录。确认 `MoneyNote.xcodeproj` 在仓库根目录。

**Q：编出来的 IPA 图标是空的？**
不会：workflow 里有 `cp Icons/*.png` 和出包自检（缺 `AppIcon60x60@2x.png` 会直接失败）。

**Q：装的时候巨魔报签名错？**
改了 `.app` 内容后旧签名失效是正常的，巨魔安装时会重签。若仍失败，把 IPA 重新用巨魔打开一次。

**Q：我还是想本地编译？**
装一次 iOS 17.5 组件后即可：`bash scripts/build_unsigned_ipa.sh`。脚本同样会注入图标并自检。
