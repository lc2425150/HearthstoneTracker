# 炉石传说记牌器 - Hearthstone Tracker

## 项目概述

这是一个 **macOS 炉石传说记牌器**，使用 Swift/SwiftUI 构建，支持 macOS 14.0+ (arm64)。

### 技术栈
- **语言**: Swift
- **UI 框架**: SwiftUI + AppKit
- **OCR 识别**: Apple Vision Framework
- **数据持久化**: SwiftData
- **其他**: Combine, CoreGraphics, UniformTypeIdentifiers

### 项目结构
```
Sources/
├── HearthstoneTrackerApp.swift    # App 入口
├── ContentView.swift              # 主视图
├── AppDelegate.swift              # App 代理
├── Core/
│   ├── CardTrackerCore.swift      # 核心追踪逻辑
│   └── EventPipeline.swift        # 事件管道
├── Data/
│   ├── Models/
│   │   ├── CardModels.swift       # 卡牌数据模型
│   │   └── MatchModels.swift      # 对局数据模型
│   └── Repository/
│       └── CardDataUpdater.swift  # 卡牌数据更新
├── LogMonitor/
│   ├── LogFileWatcher.swift       # 日志文件监听
│   ├── LogMonitorModule.swift     # 日志监控模块
│   └── PowerLogParser.swift       # 日志解析器
├── Recognition/
│   └── VisionOCRScanner.swift     # Vision OCR 扫描
├── Tracking/
│   └── OpponentCardTracker.swift  # 对手卡牌追踪
├── UI/
│   ├── CardImageView.swift        # 卡牌图片视图
│   ├── DebugPanelView.swift       # 调试面板
│   ├── ForEachHelpers.swift       # ForEach 辅助
│   ├── StatusView.swift           # 状态视图
│   ├── TestHarnessView.swift      # 测试视图
│   └── Overlay/
│       ├── OverlayView.swift      # 悬浮覆盖层视图
│       └── OverlayWindow.swift    # 悬浮覆盖层窗口
└── Utilities/
    ├── CardImageLoader.swift      # 卡牌图片加载
    ├── Constants.swift            # 常量定义
    ├── DeckCodeParser.swift       # 卡组代码解析
    ├── GameLauncher.swift         # 游戏启动器
    ├── HSReplayManager.swift      # HSReplay 管理
    └── VersionChecker.swift       # 版本检查
```

### 构建方式
- 使用 `build_dmg.sh` 脚本构建（非 Xcode）
- 使用 `swiftc` 编译器 + macOS SDK 直接编译
- 生成 `.app` 和 `.dmg` 包

## 技能配置

在此项目下工作时，根据任务类型自动使用以下技能：

### 必须使用的技能（适用于所有任务）

- **brainstorming** — 任何创造性工作前必须使用，包括创建新功能、构建组件、添加功能或修改行为。在实现前探索用户意图、需求和设计。
- **verification-before-completion** — 在声称工作完成、修复或通过测试之前，必须先运行验证命令并确认输出。先有证据，再有断言。

### 按任务类型使用的技能

#### 计划与设计
- **writing-plans** — 当收到多步骤任务的规范或需求时，在触碰代码之前使用
- **brainstorming** — 创建新功能、构建组件、添加功能或修改行为时使用
- **define-goal** — 定义具体、可衡量的目标

#### 编码与实现
- **test-driven-development** — 在编写实现代码之前，先写测试
- **executing-plans** — 当有书面实施计划需要在独立会话中执行时使用
- **dispatching-parallel-agents** — 面对 2 个以上无共享状态或顺序依赖的独立任务时使用
- **subagent-driven-development** — 当在当前会话中执行具有独立任务的实施计划时使用
- **using-git-worktrees** — 开始需要与当前工作区隔离的功能开发时使用

#### 调试与修复
- **systematic-debugging** — 遇到任何 bug、测试失败或意外行为时、在提出修复方案前必须使用

#### 审查与质量
- **requesting-code-review** — 完成任务、实现主要功能或合并前，验证工作是否符合要求
- **receiving-code-review** — 收到代码审查反馈后、在实施建议前使用，尤其是反馈不清楚或技术上可疑时
- **finishing-a-development-branch** — 实施完成、所有测试通过后，决定如何集成工作

#### 部署与发布
- **screenshot** — 调试覆盖层 UI 或创建截图时使用
- **openai-docs** — 需要查询 OpenAI API 文档时使用
- **gh-address-comments** — 需要处理当前分支 GitHub PR 上的审查/问题评论时，使用 gh CLI

### UI 开发注意事项
- 覆盖层窗口（OverlayWindow/OverlayView）使用透明、置顶窗口
- Vision OCR 扫描使用 Apple Vision 框架
- 日志监控使用 `FileHandle` 监听 Hearthstone 日志文件变化
- 编译时注意仅为 arm64-apple-macos14.0 架构
