# 炉石传说记牌器 v2.0 — 开发上下文

> 最后更新：2026-06-09 | 项目路径：`/Users/achen/Documents/炉石传说记牌器`

---

## 一、项目概要

macOS 炉石传说记牌器，Swift/SwiftUI 构建，macOS 14.0+ (arm64)。
从 v1.4.0 全面架构重构（方案B），融合 HSTracker (⭐1248) 成熟技术。

### 构建方式
```bash
cd /Users/achen/Documents/炉石传说记牌器
bash build_dmg.sh
# 输出: .build/HearthstoneTracker.dmg (App: .build/HearthstoneTracker.app)
```

### 核心技术栈
| 技术 | 用途 |
|------|------|
| Swift 5.9+ | 开发语言 |
| SwiftUI | 主窗口 UI |
| AppKit | 悬浮窗 (OverWindowController) |
| SwiftData | 本地持久化 |
| Keychain Services | API Key 安全存储 |
| Apple Vision | OCR 识别 |
| Combine | 事件总线 |
| HearthstoneJSON | 卡牌数据源 |

---

## 二、架构决策（遵循 HSTracker 风格）

### 核心模式：Singleton + CoreManager 链式访问
```swift
// 访问方式
AppDelegate.instance().coreManager.game.windowManager
AppDelegate.instance().coreManager.cardDatabase
```

### 悬浮窗：纯 AppKit + XIB（HSTracker 原生方式）
- `OverWindowController` — 无边框透明置顶窗口基类
- `WindowManager` — 统一窗口管理器
- `CardBar` — 多主题卡牌显示组件

### 配置：静态 Settings 类（HSTracker 风格）
```swift
Settings.aiProviderType    // @UserDefault 包装器
Settings.aiApiKey          // Keychain 读取（安全存储）
```

### API Key 存储
- 使用 Keychain（非 UserDefaults）
- `KeychainManager` 封装
- 首次启动自动迁移旧数据

---

## 三、开发阶段记录

### Phase 1: 基础设施重构 ✅
| 文件 | 说明 |
|------|------|
| `Sources/Utilities/KeychainManager.swift` | Keychain 封装 + HSReplay 支持 |
| `Sources/Core/CoreManager.swift` | HSTracker 风格协调器 |
| `Sources/Core/Settings.swift` | 静态配置 + @UserDefault |
| `Sources/AppDelegate.swift` | 单例模式 (AppDelegate.instance()) |
| `Sources/Core/GameManager.swift` | 进程监控 + Watcher 管理 |
| `Sources/Core/LogWatcher/LogPathFinder.swift` | 日志自动发现 |
| `Sources/UI/Overlay/OverWindowController.swift` | 悬浮窗基类 |
| `Sources/UI/Overlay/WindowManager.swift` | 窗口管理器 |
| `Sources/UI/Overlay/TrackerWindowController.swift` | 牌库追踪窗 |
| `scripts/migrate_v1_to_v2.sh` | v1→v2 备份脚本 |

### Phase 2: 数据层 ✅
| 文件 | 说明 |
|------|------|
| `Sources/Data/Models/CardModels.swift` | 新增15字段(enName/attack/health/race/mechanics/spellSchool等) |
| `Sources/Data/Cache/CardImageCache.swift` | 三级LRU缓存(内存→磁盘→网络) |

### Phase 3: AI 引擎 ✅
| 文件 | 说明 |
|------|------|
| `Sources/AI/Analyzers/HandPredictor.swift` | 对手手牌预测 |
| `Sources/AI/Analyzers/MulliganAdvisor.swift` | 留牌策略建议 |
| `Sources/AI/Analyzers/DeckOptimizer.swift` | 卡组优化分析 |
| `Sources/AI/Analyzers/RoundSummarizer.swift` | 回合摘要 |
| `Sources/AI/AIManager.swift` | 集成4分析器 + Keychain API Key |

### Phase 4: 新功能模块 ✅
| 文件 | 说明 |
|------|------|
| `Sources/Features/Stats/StatsManager.swift` | 按职业/对阵/趋势胜率统计 |
| `Sources/Features/OpponentMemory/OpponentMemoryManager.swift` | 对手画像+历史记录 |
| `Sources/Features/Export/DataExporter.swift` | CSV导出+分享面板 |

### Phase 5: UI 增强 ✅
| 文件 | 说明 |
|------|------|
| `Sources/ContentView.swift` | 统计页: 职业胜率柱状图+对手记忆; 设置: 数据导出+AI分析按钮 |
| `Sources/UI/AI/AISuggestionWindow.swift` | AI悬浮窗(修复EnvironmentObject闪退) |

---

## 四、项目文件结构

```
Sources/
├── HearthstoneTrackerApp.swift      [@main] SwiftUI 入口
├── AppDelegate.swift                HSTracker单例+CoreManager初始化
├── ContentView.swift                主视图(4 Tab: 牌库/统计/卡组库/设置)
│
├── Core/
│   ├── CardTrackerCore.swift        [@MainActor] 核心协调器(兼容旧版)
│   ├── CoreManager.swift            HSTracker风格协调器(新版)
│   ├── Settings.swift               静态配置类
│   ├── GameManager.swift            游戏管理器
│   ├── EventPipeline.swift          事件管道
│   └── LogWatcher/
│       ├── LogFileWatcher.swift     文件监控
│       ├── LogPathFinder.swift      日志路径自动发现
│       └── PowerLogParser.swift     日志解析
│
├── AI/
│   ├── AIManager.swift              AI引擎核心+4分析器调度
│   ├── AIModelProvider.swift        提供商协议+AISuggestion模型
│   ├── Providers.swift              11家模型实现
│   ├── GameStateFormatter.swift     游戏状态格式化
│   └── Analyzers/
│       ├── HandPredictor.swift      手牌预测
│       ├── MulliganAdvisor.swift    留牌建议
│       ├── DeckOptimizer.swift      卡组优化
│       └── RoundSummarizer.swift    回合摘要
│
├── Data/
│   ├── Models/
│   │   ├── CardModels.swift         [@Model] Card模型(含15扩展字段)
│   │   └── MatchModels.swift        [@Model] MatchRecord+Stats
│   ├── Repository/CardDataUpdater.swift
│   └── Cache/CardImageCache.swift   三级LRU图片缓存
│
├── Features/
│   ├── Stats/StatsManager.swift     胜率统计
│   ├── OpponentMemory/OpponentMemoryManager.swift 对手记忆
│   └── Export/DataExporter.swift    数据导出
│
├── UI/
│   ├── Overlay/
│   │   ├── OverWindowController.swift  悬浮窗基类
│   │   ├── WindowManager.swift         窗口管理器
│   │   ├── TrackerWindowController.swift
│   │   └── OverlayView/OverlayWindow.swift (旧版兼容)
│   ├── AI/AISuggestionWindow.swift     AI建议悬浮窗
│   └── (其他视图文件)
│
├── LogMonitor/                     日志监控模块
├── Recognition/VisionOCRScanner.swift OCR识别
├── Tracking/OpponentCardTracker.swift 对手追踪
└── Utilities/
    ├── KeychainManager.swift       Keychain安全存储
    └── Constants.swift             常量定义
```

---

## 五、已知问题与注意事项

### 已修复的 Bug
1. ✅ `@Published` 不能用于计算属性 — 改为 stored + didSet
2. ✅ 内联 KeychainManager 命名冲突 — 合并到统一 KeychainManager
3. ✅ AISuggestionWindow `@EnvironmentObject` 缺失闪退 — 改为参数注入
4. ✅ `@main` 冲突 — `HearthstoneTrackerApp` 保留 `@main`，`AppDelegate` 作为委托
5. ✅ `analyzeHandPrediction`/`analyzeMulligan` 不显示结果 — 增加 `self.lastSuggestion` 赋值
6. ✅ cardPool count 硬编码为1 — 改为从 `cardCounts` 读取

### 编译警告（可忽略）
```
CGWindowListCreateImage 已废弃 → 后续迁移至 ScreenCaptureKit
await GameStateFormatter.format() 无异步操作 → 纯同步方法
KeychainManager.saveHSReplayToken 返回值未使用 → 已加 @discardableResult
```

### 设计遗留
- `AIPanelView` 使用 `Core` 参数而非 `@EnvironmentObject`（为避免闪退的有意设计）
- 悬浮窗内容目前部分使用 SwiftUI（通过 NSHostingView），未来可迁移至纯 AppKit 以完全对齐 HSTracker

---

## 六、参考资料

### 设计文档
- `docs/superpowers/specs/2026-06-09-hearthstone-tracker-v2-design.md` (17KB)
- `docs/superpowers/plans/2026-06-09-phase1-infrastructure.md` (22KB)
- `CHANGELOG-v2.0.md` (5.6KB)

### 参考项目
- **HSTracker** (https://github.com/HearthSim/HSTracker) — macOS 行业标准，⭐1248
  - OverWindowController、WindowManager、Watcher 体系、CardBar、Card 数据模型
  - 本项目中按 HSTracker 方式：单例架构、CoreManager 协调器、纯 AppKit 悬浮窗

### 数据源
- HearthstoneJSON API: https://api.hearthstonejson.com/v1/latest/zhCN/cards.json
- 卡牌图片: https://art.hearthstonejson.com/v1/render/latest/zhCN/256x/{cardId}.png

---

## 七、下一次执行指引

1. 先阅读本文件（DEVELOPMENT_CONTEXT.md）恢复上下文
2. 检查 AGENTS.md 获取技能配置
3. `bash build_dmg.sh` 编译验证
4. 如需运行: `open .build/HearthstoneTracker.app`

### 后续可做方向
- Phase 6: 单元测试 + 集成测试
- CardBar 卡牌显示组件（AppKit 原生）
- 对局录像回放 Replay 播放器 UI
- 智能卡组推荐（HSReplay 热门数据）
- 多账号追踪
- ScreenCaptureKit 迁移（替代 CGWindowListCreateImage）

## 六、已知 Bug 及解决方案

### macOS 26.x IMK 输入法 Bug（2026-06-10 已修复）
**问题**: `TextEditor` 触发中文输入法后，IMK 框架内部 TUINSWindow 关闭级联到主窗口，导致 App 被系统终止。
**解决方案**: 
- 使用 `TextField` 代替 `TextEditor`
- `@FocusState` 管理焦点
- AppDelegate 窗口健康检查 + 自动恢复
- Info.plist 窗口恢复键

### SwiftData 多 ModelContainer 冲突（2026-06-09 已修复）
**问题**: StatsManager 创建独立 ModelContainer。
**解决方案**: 共享 CardTrackerCore 的 CardDatabase 实例。

## 七、快速启动
```bash
cd /Users/achen/Documents/炉石传说记牌器
bash build_dmg.sh        # 编译 (~16-30秒)
open .build/HearthstoneTracker.app  # 运行
```
