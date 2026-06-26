#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FCPX 工具箱"
VERSION="0.5.0"
EXEC="FCPXToolbox"
CONFIG="${1:-release}"
OUT="$ROOT/dist/native-v0.5/$APP_NAME.app"

# 用 Swift Package Manager 构建（替代旧的 swiftc 单目录编译）。
( cd "$ROOT/native" && swift build -c "$CONFIG" )
BIN="$(cd "$ROOT/native" && swift build -c "$CONFIG" --show-bin-path)/$EXEC"

mkdir -p "$ROOT/dist/native-v0.5"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

cp "$BIN" "$OUT/Contents/MacOS/$EXEC"

# 复制 SwiftPM 生成的资源包（字体、本地化字符串）。资源通过 Bundle.module 访问，
# 该包必须随可执行文件一起进入 .app，否则 Geist Mono 字体与本地化会缺失。
BIN_DIR="$(dirname "$BIN")"
RES_BUNDLE="$BIN_DIR/FCPXToolbox_FCPXToolbox.bundle"
if [ -d "$RES_BUNDLE" ]; then
  cp -R "$RES_BUNDLE" "$OUT/Contents/Resources/"
fi

if [ -f "$ROOT/assets/AppIcon.icns" ]; then
  cp "$ROOT/assets/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
fi

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$EXEC</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.gary23333.fcpxtools</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

chmod +x "$OUT/Contents/MacOS/$EXEC"
xattr -cr "$OUT"
codesign --force --deep --sign - "$OUT" >/dev/null 2>&1 || true
echo "$OUT"
