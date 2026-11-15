#!/usr/bin/env bash
# 在 macOS 上产出「未签名 IPA」，供 TrollStore 直接安装。
# 不需要 Apple Developer 账号、不需要证书、不需要描述文件、不需要 export.plist。
#
# 为什么不用 archive / exportArchive：
#   Xcode 15 起 iOS platform 是可单独下载的组件，未注册时
#   `-destination 'generic/platform=iOS'` 会报 "iOS 17.5 is not installed"，
#   `clean` 会报 "Found no destinations for the scheme ... action clean"，
#   而 exportArchive 是给签名分发用的，会去找 provisioning profile。
#   直接 `-sdk iphoneos build` 编出 .app 再塞进 Payload/ 压 zip，
#   就是 IPA 的本质，也正好是 TrollStore 要的格式。
#
# 为什么用 SYMROOT 而不是 -derivedDataPath：
#   Xcode 规定「指定 -derivedDataPath 时必须同时给 -scheme」，
#   所以兜底的 `-target` 一旦带上它就会报：
#     The flag -scheme, -testProductsPath, or -xctestrun is required
#     when specifying -derivedDataPath.
#   SYMROOT 是普通 build setting，-scheme / -target 两种写法都能用，没有这个限制。
# 若被 `zsh scripts/...` 或 source 方式执行，立刻 re-exec 成 bash。
# zsh 的参数名展开比 bash 宽松，会把紧跟变量的多字节字符（全角括号等）
# 吞进变量名，在 set -u 下报 `SCHEME?: unbound variable` 这类怪错。
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="QianJi"
PROJECT="MoneyNote.xcodeproj"
BUILD_DIR="build"
SYMROOT_DIR="${BUILD_DIR}/SymRoot"
APP_NAME="QianJi.app"
IPA="${BUILD_DIR}/QianJi-unsigned.ipa"

echo "==> 检查工具链"
# 若外部已设置 DEVELOPER_DIR（例如临时指向 /Applications/Xcode 15.4.app），
# xcodebuild 会自动优先使用它，无需 sudo xcode-select 改全局。
if [ -n "${DEVELOPER_DIR:-}" ]; then
  echo "    使用临时工具链：DEVELOPER_DIR=${DEVELOPER_DIR}"
fi

XCODE_VER="$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')"
if [ -z "${XCODE_VER}" ]; then
  echo "❌ 找不到 Xcode 命令行工具。先跑：" >&2
  echo "   sudo xcode-select -s \"/Applications/Xcode 15.4.app/Contents/Developer\"" >&2
  exit 1
fi
echo "    Xcode ${XCODE_VER}"

XCODE_MAJOR="${XCODE_VER%%.*}"
if [ "${XCODE_MAJOR}" -ge 16 ] 2>/dev/null; then
  echo "    ⚠️ 当前是 Xcode ${XCODE_VER}。工程按 15.4 调过，16+ 通常也能编；"
  echo "       若报 Swift/SDK 差异，用 DEVELOPER_DIR 指回 Xcode 15.4 再跑一次。"
elif [ "${XCODE_MAJOR}" -lt 14 ] 2>/dev/null; then
  echo "    ⚠️ Xcode ${XCODE_VER} 偏旧（工程 Deployment Target 16.0），建议 15.4。"
fi

# -sdk iphoneos 用的是随 Xcode 自带的真机 SDK，不需要下载模拟器 runtime / platform
echo "    可用 iOS SDK："
xcodebuild -showsdks 2>/dev/null | grep -i 'iphoneos' | sed 's/^/      /' || true

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 不带 -destination、不带 clean、不带 -derivedDataPath：
# 前两者会触发 Xcode 15 的 destination 解析，第三者与 -target 不兼容。
# 第一个参数是日志路径，其余是 -scheme / -target 等 flag。
# 注意：绝不能在调用处加 `|| true` —— 那会吞掉 BUILD FAILED，
# 然后 find 命中残留的半截 .app，压出 7KB 空壳包还打印「✅ 完成」。
do_build() {
  local log="$1"; shift
  xcodebuild \
    -project "${PROJECT}" \
    "$@" \
    -configuration Release \
    -sdk iphoneos \
    build \
    SYMROOT="${PWD}/${SYMROOT_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "${log}"
}

TARGET_LOG="${BUILD_DIR}/build-target.log"
BUILD_OK=0

# 只用 -target：不走 scheme 的 destination 解析，Xcode 15 上不需要模拟器 runtime。
# -derivedDataPath 与 -target 不兼容，所以产物路径用 SYMROOT（见 do_build）。
echo "==> 编译 [关闭签名, -target ${SCHEME}]"
if do_build "${TARGET_LOG}" -target "${SCHEME}" && grep -q '\*\* BUILD SUCCEEDED \*\*' "${TARGET_LOG}"; then
  BUILD_OK=1
fi

if [ "${BUILD_OK}" -ne 1 ]; then
  echo "❌ xcodebuild 没有 BUILD SUCCEEDED，绝不产出残缺 IPA。" >&2
  echo "   关键报错（最后 30 行 error）：" >&2
  for log in "${TARGET_LOG}"; do
    [ -f "${log}" ] || continue
    echo "   ---- ${log} ----" >&2
    grep -iE 'error:|warning: .*failed|\*\* BUILD FAILED \*\*' "${log}" | tail -30 | sed 's/^/   /' >&2 || true
  done
  exit 1
fi

APP="$(find "${SYMROOT_DIR}" -type d -name "${APP_NAME}" -print -quit 2>/dev/null)"
if [ ! -d "${APP}" ]; then
  echo "❌ BUILD SUCCEEDED 但找不到 ${APP_NAME}。SymRoot 目录：" >&2
  find "${SYMROOT_DIR}" -maxdepth 5 -type d 2>/dev/null | sed 's/^/   /' >&2 || true
  exit 1
fi

echo "    产物：${APP}"
# 必须是真机 arm64，不能是模拟器架构，否则巨魔装不上
EXE_SRC="${APP}/QianJi"
if [ ! -f "${EXE_SRC}" ]; then
  echo "❌ .app 里没有可执行二进制 ${EXE_SRC}（典型症状：actool 失败后只剩几张 png）" >&2
  find "${APP}" -maxdepth 2 | sed 's/^/   /' >&2
  exit 1
fi
EXE_SIZE="$(stat -f%z "${EXE_SRC}" 2>/dev/null || echo 0)"
if [ "${EXE_SIZE}" -lt 100000 ]; then
  echo "❌ 可执行文件只有 ${EXE_SIZE} 字节，明显是残缺产物" >&2
  exit 1
fi
echo "    架构：$(lipo -info "${EXE_SRC}" 2>/dev/null || echo '未知')  二进制：${EXE_SIZE} 字节"
if lipo -info "${EXE_SRC}" 2>/dev/null | grep -qi 'simulator'; then
  echo "❌ 编成了模拟器架构，请确认 -sdk iphoneos 生效" >&2
  exit 1
fi
# 不再依赖 Assets.car：工程已把 Assets.xcassets 移出 Resources phase，
# 否则 Xcode 15.4 的 actool 会因为没装 iOS 17.5 Simulator Runtime 而硬失败。
echo "==> 组装 Payload/"
mkdir -p "${BUILD_DIR}/Payload"
# -L 解引用符号链接：若 Info.plist / 资源在产物里是 symlink，
# zip -y 会把它存成断链，TrollStore 解压后报「解析错误 302 找不到 Info.plist」。
# 本 app 零嵌入 framework，解引用完全安全。
cp -RL "${APP}" "${BUILD_DIR}/Payload/"

BUNDLE="${BUILD_DIR}/Payload/${APP_NAME}"
PLIST="${BUNDLE}/Info.plist"

# 松散图标：Info.plist 用 CFBundleIcons 指向这些 PNG，
# 不经过 actool，也不需要模拟器 runtime。
ICON_DIR="${PWD}/Icons"
if [ -d "${ICON_DIR}" ]; then
  ICON_COUNT="$(find "${ICON_DIR}" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
  cp "${ICON_DIR}"/*.png "${BUNDLE}/"
  echo "    图标：${ICON_COUNT} 个松散 PNG 已复制进 .app"
else
  echo "⚠️  缺少 Icons/ 目录，桌面图标可能显示为空白"
fi

echo "==> 出包前自检 [防止 TrollStore 解析错误 302]"
if [ ! -f "${PLIST}" ]; then
  echo "❌ 缺少 ${PLIST} —— 这种包巨魔会报「解析错误 302 / Unable to locate Info.plist」" >&2
  echo "   .app 目录内容：" >&2
  find "${BUNDLE}" -maxdepth 2 2>/dev/null | sed 's/^/   /' >&2
  exit 1
fi
if [ -L "${PLIST}" ]; then
  echo "⚠️  Info.plist 是符号链接，已解引用为真实文件"
  cp -L "${PLIST}" "${PLIST}.tmp" && mv "${PLIST}.tmp" "${PLIST}"
fi
if ! plutil -lint "${PLIST}" >/dev/null 2>&1; then
  echo "❌ Info.plist 不是合法 plist" >&2
  plutil -lint "${PLIST}" >&2 || true
  exit 1
fi
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${PLIST}" 2>/dev/null || true)"
if [ -z "${EXE}" ] || [ ! -f "${BUNDLE}/${EXE}" ]; then
  echo "❌ CFBundleExecutable 指向的可执行文件不存在：${EXE}" >&2
  exit 1
fi
echo "    Info.plist ✓   CFBundleExecutable = ${EXE} ✓"

# 不用 -y：本 app 没有需要保留的 framework 符号链接，全部解引用更稳
echo "==> 压缩为 IPA"
(cd "${BUILD_DIR}" && zip -q -r "$(basename "${IPA}")" Payload)

for entry in "Payload/${APP_NAME}/Info.plist" "Payload/${APP_NAME}/${EXE}" "Payload/${APP_NAME}/AppIcon60x60@2x.png"; do
  if ! unzip -Z1 "${IPA}" | grep -qx "${entry}"; then
    echo "❌ IPA 内缺少 ${entry}" >&2
    unzip -Z1 "${IPA}" | head -20 >&2
    exit 1
  fi
done

IPA_SIZE="$(stat -f%z "${IPA}" 2>/dev/null || echo 0)"
if [ "${IPA_SIZE}" -lt 200000 ]; then
  echo "❌ IPA 只有 ${IPA_SIZE} 字节，明显是空壳包（正常应 > 200KB）" >&2
  exit 1
fi

echo ""
echo "✅ 完成：$(pwd)/${IPA}"
ls -lh "${IPA}"
echo "   把这个文件传到 iPhone，用「打开方式 → TrollStore」安装即可。"
