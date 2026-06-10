# 炉石传说记牌器 v2.0 开发日志

> 构建日期：2026-06-09
> 基于：v1.4.0 + HSTracker (⭐1248) 架构研究

---

## 概述

对现有 v1.4.0 进行全面架构重构（方案B），融合 HSTracker 成熟的 macOS 记牌器技术，
新增 6 大功能模块和 AI 能力升级。

## 技能使用记录

执行过程中调用的 skill：
1. **brainstorming** — 需求探索、UI 设计视觉助手、架构方案对比
2. **writing-plans** — 编写分阶段实施计划
3. **subagent-driven-development** — 分任务执行

## 研究引用

- **HSTracker** (https://github.com/HearthSim/HSTracker) — macOS 炉石记牌器行业标准
  - 参考：OverWindowController、WindowManager、Watcher 体系、CardBar 主题、Card 数据模型、日志路径发现
  - 本项目中按 HSTracker 方式改为：单例架构、CoreManager 协调器、纯 AppKit 悬浮窗

## 开发阶段

### Phase 1: 基础设施重构 (5 Tasks)
| Task | 文件 | 说明 |
|------|------|------|
| 数据安全 | `KeychainManager.swift` | API Key Keychain 存储 |
| 数据安全 | `scripts/migrate_v1_to_v2.sh` | v1→v2 备份脚本 |
| 数据安全 | `AIManager.swift` | API Key 迁移 Keychain |
| 架构 | `CoreManager.swift` | HSTracker 风格协调器 |
| 架构 | `Settings.swift` | 静态配置类 |
| 架构 | `AppDelegate.swift` | 单例模式改造 |
| 悬浮窗 | `OverWindowController.swift` | HSTracker 基类 |
| 悬浮窗 | `WindowManager.swift` | 统一窗口管理器 |
| 悬浮窗 | `TrackerWindowController.swift` | 牌库追踪窗 |
| 日志 | `LogPathFinder.swift` | 日志自动发现 |
| 游戏 | `GameManager.swift` | 进程监控+Watcher |

### Phase 2: 数据层重构
| Task | 文件 | 说明 |
|------|------|------|
| 模型 | `CardModels.swift` | 新增15字段(enName, attack, health, races, mechanics等) |
| 搜索 | `CardModels.swift` | 5种查询方法(allStoredCards, byEnglishName, byClass, byCostRange, byMechanic, search) |
| 缓存 | `CardImageCache.swift` | 三级LRU缓存(内存→磁盘→网络) |

### Phase 3: AI 引擎升级
| Task | 文件 | 说明 |
|------|------|------|
| 手牌预测 | `HandPredictor.swift` | 对手手牌推测Prompt+响应解析 |
| 留牌建议 | `MulliganAdvisor.swift` | 起手留牌策略Prompt+解析 |
| 卡组优化 | `DeckOptimizer.swift` | 卡组分析Prompt |
| 回合摘要 | `RoundSummarizer.swift` | 回合总结Prompt |
| 集成 | `AIManager.swift` | 4个子分析器调度方法 |

### Phase 4: 新功能模块
| Task | 文件 | 说明 |
|------|------|------|
| 胜率 | `StatsManager.swift` | 按职业/对阵/趋势统计 |
| 对手记忆 | `OpponentMemoryManager.swift` | 对手画像+历史记录 |
| 数据导出 | `DataExporter.swift` | CSV导出+分享面板 |

### Phase 5: UI 增强
| Task | 文件 | 说明 |
|------|------|------|
| 统计页 | `ContentView.swift` | 职业胜率柱状图+对手记忆列表 |
| 设置页 | `ContentView.swift` | 数据导出+缓存清理按钮 |
| AI控制 | `ContentView.swift` | 手牌预测/留牌建议/卡组优化按钮 |

## 新增文件清单

```
Sources/
├── AI/Analyzers/
│   ├── HandPredictor.swift        (新建)
│   ├── MulliganAdvisor.swift      (新建)
│   ├── DeckOptimizer.swift        (新建)
│   └── RoundSummarizer.swift      (新建)
├── Core/
│   ├── CoreManager.swift          (新建)
│   ├── Settings.swift             (新建)
│   ├── GameManager.swift          (新建)
│   └── LogWatcher/
│       └── LogPathFinder.swift    (新建)
├── Data/
│   └── Cache/
│       └── CardImageCache.swift   (新建)
├── Features/
│   ├── Stats/StatsManager.swift   (新建)
│   ├── OpponentMemory/            (新建)
│   │   └── OpponentMemoryManager.swift
│   └── Export/DataExporter.swift  (新建)
├── Utilities/
│   └── KeychainManager.swift      (新建)
└── UI/Overlay/
    ├── OverWindowController.swift (新建)
    ├── WindowManager.swift        (新建)
    └── TrackerWindowController.swift (新建)
```

## 修改文件清单

```
Sources/
├── AppDelegate.swift              (HSTracker单例改造)
├── HearthstoneTrackerApp.swift    (适配新架构)
├── AI/AIManager.swift             (Keychain+4分析器)
├── Core/CardTrackerCore.swift     (Keychain集成)
├── Data/Models/CardModels.swift   (15新字段+搜索引擎)
├── Data/Models/MatchModels.swift  (移除内联KeychainManager)
├── Utilities/Constants.swift      (Keychain常量+LogPathFinder)
├── Utilities/HSReplayManager.swift(统一KeychainManager)
└── ContentView.swift              (统计/设置/AI按钮增强)
scripts/
├── migrate_v1_to_v2.sh           (新建)
└── build_dmg.sh                   (不变)
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift 5.9+ | 开发语言 |
| SwiftUI | 主窗口 UI |
| AppKit | 悬浮窗 (OverWindowController) |
| SwiftData | 本地持久化 |
| Keychain Services | API Key 安全存储 |
| Combine | 事件总线 |
| Apple Vision | OCR 识别 |
| HearthstoneJSON | 卡牌数据源 |

## 构建方式

```bash
cd /Users/achen/Documents/炉石传说记牌器
bash build_dmg.sh
# 输出: .build/HearthstoneTracker.dmg
```

## 参考项目

- **HSTracker** (https://github.com/HearthSim/HSTracker) — macOS 炉石记牌器行业标准，⭐1248
  - 参考：OverWindowController、WindowManager、Watcher 体系、CardBar、Card 数据模型
- **现有 v1.4.0** — AI 集成、OCR 识别、卡组管理、悬浮窗
