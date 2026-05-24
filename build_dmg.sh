#!/bin/bash
set -e
cd "$(dirname "$0")"

XCODE_SWIFT="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
XCODE_SDK="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

if [ ! -f "$XCODE_SWIFT" ]; then
  echo "❌ 未找到 Xcode 工具链"
  exit 1
fi

BUILD_DIR=".build"
APP_NAME="HearthstoneTracker"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
START=$(date +%s)

echo "🔨 炉石记牌器 编译打包"
echo "Swift: $($XCODE_SWIFT --version 2>&1 | head -1 | sed 's/.*Swift version //' | sed 's/ (.*//')"

mkdir -p "$BUILD_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

SOURCES=()
while IFS= read -r f; do
  SOURCES+=("$f")
done < <(find Sources -name "*.swift" -type f | sort)

echo "📝 ${#SOURCES[@]} 个源文件"
echo "⚙️  编译中（并行模式）..."

# 使用 -j 并行编译前端任务，-Onone 减少优化时间
$XCODE_SWIFT \
  -o "$BUILD_DIR/$APP_NAME" \
  -target arm64-apple-macos14.0 \
  -sdk "$XCODE_SDK" \
  -module-name "HearthstoneTracker" \
  -parse-as-library \
  -Onone \
  -j 4 \
  -framework SwiftUI -framework AppKit -framework Foundation \
  -framework Combine -framework Vision \
  -framework UniformTypeIdentifiers -framework CoreGraphics \
  -framework CoreFoundation -framework SwiftData \
  "${SOURCES[@]}"

echo "✅ 编译成功！（耗时 $(( $(date +%s) - START )) 秒）"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp Sources/Resources/Info.plist "$APP_BUNDLE/Contents/"
[ -d "Sources/Resources/AppIcon.iconset" ] && \
  iconutil -c icns Sources/Resources/AppIcon.iconset \
  -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null

DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
echo "📦 打包 DMG..."
rm -f "$DMG_PATH"
hdiutil create -ov -format UDZO -volname "炉石记牌器" \
  -srcfolder "$APP_BUNDLE" "$DMG_PATH" 2>/dev/null

echo ""
echo "🎉 完成！"
echo "   DMG: $(realpath "$DMG_PATH") ($(du -h "$DMG_PATH" | cut -f1))"
echo "   App: $(realpath "$APP_BUNDLE")"
