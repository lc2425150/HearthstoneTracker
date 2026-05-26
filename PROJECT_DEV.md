# 炉石传说记牌器 - 开发规范文档

## 项目概述

macOS 炉石记牌器，Swift/SwiftUI + AppKit，支持 macOS 14.0+ (arm64)

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
    ├── CardImageLoader.swift      # 卡牌图片加载 Actor
    ├── Constants.swift            # 常量
    ├── DeckCodeParser.swift       # 卡组码解析
    ├── GameLauncher.swift         # 游戏启动器
    ├── HSReplayManager.swift      # HSReplay OAuth + 上传
    └── VersionChecker.swift       # 版本检查
```

## 关键数据模型

### TrackedDeck (struct)
- `cardCounts: [Int: Int]` — dbfId → 剩余张数
- `cardPool: [Int: Card]` — dbfId → Card 对象
- `allOriginalCards: [(card: Card, count: Int)]` — 全部原始卡牌含数量
- `remainingOriginal: [Card]` — 牌库中还有剩余张数的卡牌
- `handOriginal: [Card]` — 手牌
- `playedOriginal: [Card]` — 已打出
- `discoveredCards: [DiscoveredCard]` — 发现/生成的卡牌

### CardDatabase (@MainActor)
- 管理 ModelContainer
- fetchMatches() / fetchDecks() / card(for dbfId:)

## 构建方式

```bash
cd /Users/achen/Documents/炉石传说记牌器
bash build_dmg.sh
```

- 编译器: `/Volumes/T7/Applications/Xcode.app` 中的 swiftc
- SDK: macOS 14.0
- 架构: arm64
- 单线程编译防 OOM（`-num-threads 1`）
- 输出: `.build/HearthstoneTracker.dmg`

## GitHub 同步

```bash
cd /Users/achen/Documents/炉石传说记牌器
git add -A && git commit -m "描述变更" && git push origin main
```

- 每次版本改动后先同步 GitHub，再进行后续开发

## 编码规范

1. **@Model 类**需要添加 Identifiable 扩展
2. **ForEach 编译错误解法**：使用 `Array(zip(cards.indices, cards)), id: \.0` 模式
3. **@CommandsBuilder** 是 Swift 6.3 的正确属性名（不是 @CommandBuilder）
4. **OverlayWindowController** 必须继承 NSObject 才能实现 NSWindowDelegate
5. **私有属性**：TrackedDeck.cardCounts/cardPool 不应 private(set)，因为 CardTrackerCore 需要在外部修改
6. **卡牌数据来源 URL** 使用 zhCN 以获取中文卡牌名
7. **全屏支持**使用 `fullScreenAuxiliary` + `CGShieldingWindowLevel`

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| OOM 编译崩溃 | 多线程编译内存不足 | `-num-threads 1` |
| 卡牌 25 张显示 | 唯一卡牌去重统计 | 用 `allOriginalCards` + count 徽章 |
| 启动卡顿 | ModelContainer 同步初始化 | 改用 lazy 初始化 |
| 悬浮窗不贴合 | 窗口位置追踪逻辑 | OverlayWindow.positionNextToHearthstone() |
