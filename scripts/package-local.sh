#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FCPX 工具箱"
NATIVE_APP_NAME="FCPX 工具箱"
VERSION="0.4.0"
PAYLOAD="$HOME/Library/Application Support/FCPX Tools/FCPXToolboxPayload.app"
SOURCE_APP="$ROOT/dist/native-v0.4/$NATIVE_APP_NAME.app"
LAUNCHER="/Applications/$APP_NAME.app"
PACKAGE_DIR="$ROOT/dist/FCPXTools-$VERSION"

"$ROOT/scripts/build-native.sh" >/dev/null

rm -rf "$PACKAGE_DIR" "$ROOT/dist/FCPXTools-$VERSION.zip"
mkdir -p "$PACKAGE_DIR"
ditto --noextattr --noqtn "$SOURCE_APP" "$PACKAGE_DIR/FCPXToolboxPayload.app"

cat > "$PACKAGE_DIR/安装.command" <<'INSTALL'
#!/bin/sh
set -eu
BASE="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FCPX 工具箱"
APP_SUPPORT="$HOME/Library/Application Support/FCPX Tools"
PAYLOAD="$APP_SUPPORT/FCPXToolboxPayload.app"
LAUNCHER="/Applications/$APP_NAME.app"

mkdir -p "$APP_SUPPORT"
rm -rf "$PAYLOAD" "$LAUNCHER"
/usr/bin/ditto --noextattr --noqtn "$BASE/FCPXToolboxPayload.app" "$PAYLOAD"
/usr/bin/xattr -cr "$PAYLOAD"

cat > /tmp/fcpx-tools-launcher.applescript <<APPLESCRIPT
do shell script "rm -rf /tmp/FCPXToolboxRuntime.app && /usr/bin/ditto --noextattr --noqtn '$PAYLOAD' /tmp/FCPXToolboxRuntime.app && /usr/bin/xattr -cr /tmp/FCPXToolboxRuntime.app && /usr/bin/codesign --force --deep --sign - /tmp/FCPXToolboxRuntime.app && /usr/bin/open /tmp/FCPXToolboxRuntime.app"
APPLESCRIPT

/usr/bin/osacompile -o "$LAUNCHER" /tmp/fcpx-tools-launcher.applescript
if [ -f "$PAYLOAD/Contents/Resources/AppIcon.icns" ]; then
  /bin/cp "$PAYLOAD/Contents/Resources/AppIcon.icns" "$LAUNCHER/Contents/Resources/applet.icns"
fi
/usr/bin/xattr -cr "$LAUNCHER"
/usr/bin/codesign --force --deep --sign - "$LAUNCHER" >/dev/null 2>&1 || true
echo "已安装：$LAUNCHER"
INSTALL

chmod +x "$PACKAGE_DIR/安装.command"
( cd "$ROOT/dist" && /usr/bin/zip -qry -X "FCPXTools-$VERSION.zip" "FCPXTools-$VERSION" )

mkdir -p "$(dirname "$PAYLOAD")"
rm -rf "$PAYLOAD" "$LAUNCHER"
ditto --noextattr --noqtn "$SOURCE_APP" "$PAYLOAD"
xattr -cr "$PAYLOAD"
sh "$PACKAGE_DIR/安装.command"

echo "$ROOT/dist/FCPXTools-$VERSION.zip"
