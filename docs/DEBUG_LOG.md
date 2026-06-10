# 开发日志 - 最终 Bug 修复记录

> 最后更新：2026-06-10

## 已修复的崩溃型 Bug

### Bug 1: macOS IMK 输入法框架导致 App 被系统终止（最高优先级 🔴）
**严重程度**: 🔴 致命 - App 启动 20-30 秒后被系统终止
**根因**: macOS 26.x 的 Input Method Kit (IMK) Bug
- `TextEditor` 触发中文输入法后，IMK 创建内部 `TUINSWindow`
- IMK 框架 (`TextInputUIMacHelper`, `TUINSCursorUIController`) 调用 `[TUINSWindow close]`
- 内部窗口关闭级联到我们的主窗口 → 系统 watchdog 终止进程
- 控制台错误: `error messaging the mach port for IMKCFRunLoopWakeUpReliable`
- 无 `.ips` 崩溃报告（系统直接终止，非 App 崩溃）

**修复**:
1. **`ContentView.swift` — DeckView**：`TextEditor` → `TextField`
   - 使用单行 `TextField` + `.textFieldStyle(.roundedBorder)`
   - 添加 `@FocusState` 管理焦点，`onAppear` 自动失焦
   - 添加 `.onSubmit` 快捷导入
2. **`AppDelegate.swift`**：增强窗口关闭防护
   - 添加 `window.isReleasedWhenClosed = false`
   - 添加 `handleWindowDidResignMain` 监听 IMK 焦点抢夺
   - 添加 `startWindowHealthCheck()` 定时器（每2秒检查窗口健康）
   - 添加 `applicationDidBecomeActive` 窗口恢复
3. **`Info.plist`**：添加窗口恢复支持
   - `NSApplicationSupportsSecureRestorableState`
   - `NSWindowRestorationEnabled`

**效果**: App 稳定运行 3+ 分钟无终止 ✅

### Bug 2: 三个独立 CardDatabase 实例 → SwiftData 存储冲突崩溃
**严重程度**: 🔴 致命
**问题**: 3 个独立 `CardDatabase` 实例，各有自己的 `ModelContainer`
**修复**: `StatsManager` 共享 `CardTrackerCore` 的 `cardDatabase`

### Bug 3: ModelContainer try! → 存储损坏直接崩溃
**严重程度**: 🔴 致命
**修复**: `try` + 失败降级到内存存储

### Bug 4: LogFileWatcher 主线程洪泛
**严重程度**: 🟡 高
**修复**: 单 Task 内分批处理 (500行/批) + `Task.yield()`

### Bug 5: AISuggestionWindow @EnvironmentObject 闪退
**严重程度**: 🟡 高
**修复**: `@EnvironmentObject` → 参数注入 (`core: CardTrackerCore?`)

## 已修复的功能性 Bug

### Bug 6: EventPipeline @Published + PassthroughSubject
**文件**: `EventPipeline.swift`
**修复**: 改为 `let`，移除冗余 `DispatchQueue.main.async`

### Bug 7: PowerLogParser.reset() 不彻底
**文件**: `PowerLogParser.swift`
**修复**: 同步清除 `playerDeckDBFIds` 和 `gameInProgress`

### Bug 8: StatsManager 初始化顺序
**文件**: `StatsManager.swift`
**修复**: 支持延迟配置 (configure)，无数据库时优雅降级

### Bug 9: Menu 方法不存在
**文件**: `HearthstoneTrackerApp.swift`
**问题**: Menu items 调用 `core.triggerOCRScan()` 和 `core.startOpponentTracking()`
**状态**: 这些方法实际存在于 `CardTrackerCore`（之前被截断未显示），编译通过 ✅

## 编译状态
- ✅ 50 个源文件，0 错误
- ⚠️ 3 个 `CGWindowListCreateImage` deprecated 警告（降级路径，安全）
- ✅ 目标: `arm64-apple-macos14.0`
- ✅ 编译时间: ~16-30 秒

## 运行验证
- ✅ 稳定运行 3+ 分钟
- ✅ 无 `.ips` 崩溃报告
- ✅ App 窗口正常显示
- ✅ 主菜单功能正常

## 如需进一步排查
```bash
# 查看崩溃报告
ls -la ~/Library/Logs/DiagnosticReports/HearthstoneTracker-*.ips

# 实时日志
log stream --predicate 'process == "HearthstoneTracker"'

# 运行 App 并捕获输出
/Users/achen/Documents/炉石传说记牌器/.build/HearthstoneTracker.app/Contents/MacOS/HearthstoneTracker
```
