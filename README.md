# 炉石记牌器 (Hearthstone Tracker)

macOS 原生炉石传说对局助手，支持卡组码导入、日志监控、OCR 识别、对手追踪与对局统计。

## 功能架构

| 模块 | 文件 | 职责 |
|------|------|------|
| **卡组码解析** | `Utilities/DeckCodeParser.swift` | Base64 解码 + DBF ID 映射卡牌 |
| **卡牌数据** | `Repository/CardDataUpdater.swift` | HearthstoneJSON API 获取全量卡牌数据 |
| **日志监控** | `LogMonitor/LogFileWatcher.swift` | FSEvents 监听 Power.log 变动 |
| | `LogMonitor/PowerLogParser.swift` | 解析 PowerTaskList / ZONE / TAG_CHANGE |
| | `LogMonitor/LogMonitorModule.swift` | 模块入口，管道集成 |
| | `Core/EventPipeline.swift` | 日志事件 → 游戏事件翻译层 |
| **OCR 识别** | `Recognition/VisionOCRScanner.swift` | Vision 框架 OCR，兜底对手卡牌识别 |
| **对手追踪** | `Tracking/OpponentCardTracker.swift` | 对手打出卡牌统计 + 卡组推测 |
| **卡牌图片** | `Utilities/CardImageLoader.swift` | Actor 单例，内存 + 磁盘缓存 |
| | `UI/CardImageView.swift` | SwiftUI 异步缩略图组件 |
| **核心状态** | `Core/CardTrackerCore.swift` | 全局状态中心，线程安全 |
| **数据模型** | `Data/Models/CardModels.swift` | Card / TrackedDeck / DiscoveredCard |
| | `Data/Models/MatchModels.swift` | MatchRecord / SavedDeck / StatsSummary (SwiftData) |
| **对局统计** | ContentView `StatsView` | 胜率 / 场次 / 对局历史 |
| **卡组库** | ContentView `DeckLibraryView` | 保存/管理卡组 |
| **悬浮窗** | `UI/Overlay/OverlayView.swift` | 半透明悬浮层，双标签页 |
| | `UI/Overlay/OverlayWindow.swift` | NSWindow 悬浮窗生命周期 |
| **设置** | ContentView `SettingsView` | OCR开关 / 透明度 / 缓存管理 |
| **版本更新** | `Utilities/VersionChecker.swift` | GitHub Releases 检查 |
| **启动** | `Utilities/GameLauncher.swift` | 炉石进程启动检测 |
| **应用入口** | `HearthstoneTrackerApp.swift` | @main + 菜单栏 |
| | `AppDelegate.swift` | Dock 最小化行为 |

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
# Swift Package Manager (macOS 14+, Swift 6.2)
swift build

# 或 Xcode
open Package.swift
```

## 数据来源

- 卡牌数据: [HearthstoneJSON](https://hearthstonejson.com)
- 卡牌图片: `art.hearthstonejson.com/v1/render`

## 最低系统要求

- macOS 14.0 (Sonoma)
- Swift 6.2