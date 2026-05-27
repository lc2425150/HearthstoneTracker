# 炉石记牌器 (Hearthstone Tracker)

**版本 1.3.0** | macOS 原生炉石传说对局助手

支持卡组码导入、日志监控、OCR 识别、对手追踪与对局统计。基于 [HearthSim/HSTracker](https://github.com/HearthSim/HSTracker) 设计模式。

## 功能架构

| 模块 | 职责 |
|------|------|
| **卡组码解析** | Base64 解码 + DBF ID 映射卡牌 |
| **卡牌数据** | HearthstoneJSON API 获取全量卡牌数据 |
| **日志监控** | FSEvents 监听 Power.log 变动，解析 PowerTaskList / ZONE / TAG_CHANGE |
| **OCR 识别** | Vision 框架 OCR，兜底对手卡牌识别 |
| **对手追踪** | 对手打出卡牌统计 + 卡组推测 |
| **对局统计** | 胜率 / 场次 / 对局历史 |
| **卡组库** | 保存/管理卡组 |
| **悬浮窗** | 半透明悬浮层，双标签页，游戏内叠加 |
| **卡牌图片** | Actor 单例，内存 + 磁盘缓存 |
| **版本更新** | GitHub Releases 检查 |

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd + I` | 导入卡组码 |
| `Cmd + U` | 检查卡牌更新 |
| `Cmd + T` | 开始/暂停追踪 |
| `Cmd + Shift + O` | 切换悬浮窗 |
| `Cmd + Shift + S` | OCR 扫描 |
| `Cmd + Option + O` | 对手追踪 |
| `Cmd + Shift + R` | 重置对局 |

## 构建

```bash
# 编译打包 (DMG)
bash build_dmg.sh

# 运行单元测试 (43 用例)
XCODE_SDK="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
XCODE_SWIFT="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SOURCES=()
while IFS= read -r f; do [[ "$f" != *App.swift ]] && SOURCES+=("$f"); done < <(find Sources Tests -name "*.swift" -type f | sort)
$XCODE_SWIFT -o .build/tests -target arm64-apple-macos14.0 -sdk "$XCODE_SDK" -parse-as-library -Onone -num-threads 1 \
  -framework SwiftUI -framework AppKit -framework Foundation -framework Combine -framework Vision \
  -framework UniformTypeIdentifiers -framework CoreGraphics -framework CoreFoundation -framework SwiftData "${SOURCES[@]}"
./.build/tests
```

## 数据来源

- 卡牌数据: [HearthstoneJSON](https://hearthstonejson.com)
- 卡牌图片: `art.hearthstonejson.com/v1/render`
- 参考项目: [HearthSim/HSTracker](https://github.com/HearthSim/HSTracker) (⭐1247)

## 最低系统要求

- macOS 14.0 (Sonoma) arm64
- Swift 6.2+

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.3.0 | 2026-05-26 | 参考 HSTracker 架构优化，修复所有编译器警告，添加单元测试(43用例)，优化 OCR 架构 |
| 1.2.0 | 2026-05-26 | 卡组库、统计、设置面板、HSReplay 集成 |
| 1.1.0 | 2026-05-24 | 覆盖层窗口、OCR 识别、对手追踪 |
| 1.0.0 | 2026-05-23 | 初始版本 |
