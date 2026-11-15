#!/usr/bin/env bash
# 从 1024 母图重生成 Icons/ 各尺寸。用 macOS 自带 sips，不需要装任何依赖。
# 用法：bash scripts/make_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="Assets.xcassets/AppIcon.appiconset/AppIcon.png"
[ -f "$SRC" ] || { echo "缺少母图 $SRC" >&2; exit 1; }
mkdir -p Icons
make() { sips -z "$2" "$2" "$SRC" --out "Icons/$1" >/dev/null 2>&1; }
make "AppIcon20x20.png" 20
make "AppIcon20x20@2x.png" 40
make "AppIcon20x20@3x.png" 60
make "AppIcon20x20~ipad.png" 20
make "AppIcon20x20@2x~ipad.png" 40
make "AppIcon29x29.png" 29
make "AppIcon29x29@2x.png" 58
make "AppIcon29x29@3x.png" 87
make "AppIcon29x29~ipad.png" 29
make "AppIcon29x29@2x~ipad.png" 58
make "AppIcon40x40.png" 40
make "AppIcon40x40@2x.png" 80
make "AppIcon40x40@3x.png" 120
make "AppIcon40x40~ipad.png" 40
make "AppIcon40x40@2x~ipad.png" 80
make "AppIcon57x57.png" 57
make "AppIcon57x57@2x.png" 114
make "AppIcon60x60.png" 60
make "AppIcon60x60@2x.png" 120
make "AppIcon60x60@3x.png" 180
make "AppIcon76x76~ipad.png" 76
make "AppIcon76x76@2x~ipad.png" 152
make "AppIcon83.5x83.5@2x~ipad.png" 167
make "AppIcon1024x1024.png" 1024
echo "完成：$(find Icons -name '*.png' | wc -l | tr -d ' ') 个图标"
