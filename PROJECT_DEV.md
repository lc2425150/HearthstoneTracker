# 炉石传说记牌器 - 开发规范文档

## 项目概述

macOS 炉石记牌器，Swift/SwiftUI + AppKit，支持 macOS 14.0+ (arm64)

**当前版本**: 1.3.0 (build 9)
**更新日期**: 2026-05-26

## 技术栈

| 模块 | 技术 |
|------|------|
| UI 框架 | SwiftUI + AppKit |
| OCR 识别 | Apple Vision Framework |
| 数据持久化 | SwiftData (ModelContainer) |
| 窗口管理 | NSWindow + NSWindowDelegate |
| 图像加载 | URLSession + 磁盘缓存 Actor |
| 日志监控 | FileHandle + Timer 轮询 |
| 构建工具 | swiftc 命令行 + build_dmg.sh |

## 项目结构

```
Sources/
├── HearthstoneTrackerApp.swift   # @main 入口
├── AppDelegate.swift             # 应用代理 + 窗口最小化
├── ContentView.swift             # 主界面 + 设置 + DeckLibrary
├── Core/
│   ├── CardTrackerCore.swift     # 核心协调器（ObservableObject）
│   └── EventPipeline.swift       # 日志事件翻译器
├── Data/
│   ├── Models/
│   │   ├── CardModels.swift      # Card(@Model) + TrackedDeck + CardDatabase
│   │   └── MatchModels.swift     # MatchRecord(@Model) + SavedDeck(@Model)
│   └── Repository/
│       └── CardDataUpdater.swift  # 多来源卡牌数据更新
├── LogMonitor/
│   ├── LogFileWatcher.swift       # 日志文件监听
│   ├── LogMonitorModule.swift     # 日志监控模块
│   └── PowerLogParser.swift       # Power.log 解析器
├── Recognition/
│   └── VisionOCRScanner.swift     # Vision OCR 扫描
├── Tracking/
│   └── OpponentCardTracker.swift  # 对手卡牌追踪
├── UI/
│   ├── ForEachHelpers.swift       # 卡牌列表视图组件
│   ├── CardImageView.swift        # 卡牌缩略图组件
│   ├── DebugPanelView.swift       # 调试面板
│   ├── StatusView.swift           # 游戏状态栏
│   ├── TestHarnessView.swift      # 测试工具
│   └── Overlay/
│       ├── OverlayView.swift      # 悬浮窗主视图
│       └── OverlayWindow.swift    # 悬浮窗窗口管理器
└── Utilities/
│   ├── CardImageLoader.swift      # 卡牌图片加载 Actor
│   ├── Constants.swift            # 常量
│   ├── DeckCodeParser.swift       # 卡组码解析
│   ├── GameLauncher.swift         # 游戏启动器
│   ├── HSReplayManager.swift      # HSReplay OAuth + 上传
│   └── VersionChecker.swift       # 版本检查
└── Tests/
    └── CoreTests.swift            # 单元测试 (43 测试用例)
    └── TestRunner.swift           # 测试入口
```

## 版本历史

| 版本 | Build | 日期 | 变更内容 |
|------|-------|------|----------|
| 1.0.0 | 1 | 2025-05-23 | 初始版本 |
| 1.1.0 | 3 | 2025-05-24 | 添加覆盖层窗口、OCR扫描、对手追踪 |
| 1.2.0 | 8 | 2025-05-26 | 添加卡组库、统计、设置面板、HSReplay集成 |
| **1.3.0** | **9** | **2026-05-26** | 参考 HSTracker 架构优化：修复所有编译器警告、添加 XCTest 兼容单元测试、优化 VisionOCR 非隔离截图、修复 Actor 并发问题、统一版本管理 |

## 参考项目

本项目参考了 [HearthSim/HSTracker](https://github.com/HearthSim/HSTracker) (⭐1247) 的设计模式：

| 特性 | HSTracker 方案 | 本实现方案 |
|------|---------------|-----------|
| 数据库 | Realm (Swift) | SwiftData (@Model) |
| 依赖管理 | Carthage + Mono | 零外部依赖 |
| 内存读取 | HearthMirror (C#) | Vision OCR (Apple) |
| 更新 | Sparkle | GitHub Releases |
| 构建 | Xcode + Fastlane | swiftc 命令行 |
| 测试 | XCTest | 独立测试套件 (43用例) |

## 构建方式

```bash
cd /Users/achen/Documents/炉石传说记牌器

# 编译生产版本
bash build_dmg.sh

# 运行单元测试
# 编译测试：
XCODE_SDK="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
XCODE_SWIFT="/Volumes/T7/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SOURCES=(); while IFS= read -r f; do [[ "$f" != *App.swift ]] && SOURCES+=("$f"); done < <(find Sources Tests -name "*.swift" -type f | sort)
$XCODE_SWIFT -o .build/tests -target arm64-apple-macos14.0 -sdk "$XCODE_SDK" -parse-as-library -Onone -num-threads 1 \
  -framework SwiftUI -framework AppKit -framework Foundation -framework Combine -framework Vision \
  -framework UniformTypeIdentifiers -framework CoreGraphics -framework CoreFoundation -framework SwiftData "${SOURCES[@]}"
./.build/tests
```

## 编码规范

1. **@Model 类**需要添加 Identifiable 扩展
2. **ForEach 编译错误解法**：使用 `Array(zip(cards.indices, cards)), id: \.0` 模式
3. **@CommandsBuilder** 是 Swift 6.3 的正确属性名（不是 @CommandBuilder）
4. **OverlayWindowController** 必须继承 NSObject 才能实现 NSWindowDelegate
5. **私有属性**：TrackedDeck.cardCounts/cardPool 不应 private(set)，因为 CardTrackerCore 需要在外部修改
6. **卡牌数据来源 URL** 使用 zhCN 以获取中文卡牌名
7. **全屏支持**使用 `fullScreenAuxiliary` + `CGShieldingWindowLevel`
8. **Actor 并发**：CardImageLoader 使用 actor 隔离，后台截图使用 fileprivate 函数避免 @MainActor 约束

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| OOM 编译崩溃 | 多线程编译内存不足 | `-num-threads 1` |
| 卡牌 25 张显示 | 唯一卡牌去重统计 | 用 `allOriginalCards` + count 徽章 |
| 启动卡顿 | ModelContainer 同步初始化 | 改用 lazy 初始化 |
| 悬浮窗不贴合 | 窗口位置追踪逻辑 | OverlayWindow.positionNextToHearthstone() |
| codesign 失败 | .DS_Store 或资源分支 | 运行 `xattr -cr AppBundle` 后重试 |
| CGWindowListCreateImage 废弃 | macOS 14.0+ API 变更 | 后续迁移至 ScreenCaptureKit |
