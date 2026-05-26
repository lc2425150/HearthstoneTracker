#!/bin/bash
# 炉边记牌器 - iOS 构建脚本
# 使用方法:
#   ./build_ios.sh              # 构建 Simulator 版本
#   ./build_ios.sh device       # 构建真机版本 (需要签名)
#   ./build_ios.sh ipa          # 构建 IPA

set -e
cd "$(dirname "$0")"

# 检测 Xcode 路径
if [ -d "/Volumes/T7/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Volumes/T7/Applications/Xcode.app/Contents/Developer"
elif [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "Using Xcode: $DEVELOPER_DIR"

# 生成项目文件
python3 gen_json_project.py

MODE="${1:-simulator}"

case "$MODE" in
    simulator)
        echo "Building for Simulator..."
        xcodebuild -target HearthstoneTracker -sdk iphonesimulator -arch arm64 build
        echo "✅ Simulator build complete"
        ;;
    device)
        echo "Building for iOS Device..."
        xcodebuild -target HearthstoneTracker -sdk iphoneos \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
            SWIFT_COMPILATION_MODE=singlefile build
        echo "✅ Device build complete"
        ;;
    ipa)
        echo "Building IPA..."
        xcodebuild -target HearthstoneTracker -sdk iphoneos \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
            SWIFT_COMPILATION_MODE=singlefile build
        
        # Create IPA
        cd build
        mkdir -p Payload
        cp -r Release-iphoneos/HearthstoneTracker.app Payload/
        zip -r HearthstoneTracker.ipa Payload
        rm -rf Payload
        echo "✅ IPA created: build/HearthstoneTracker.ipa"
        ;;
    *)
        echo "Usage: $0 [simulator|device|ipa]"
        exit 1
        ;;
esac
