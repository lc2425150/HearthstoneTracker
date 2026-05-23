/// 日志监控模块入口
/// Phase 3 核心：LogFileWatcher + PowerLogParser 组合
///
/// 模块职责：
/// - PowerLogParser:  逐行解析 Power.log，维护实体状态机，检测卡牌事件
/// - LogFileWatcher:  DispatchSource 监听文件变化，增量读取新行
/// - EventPipeline:   连接解析器与核心状态机，格式化事件并转发

// 模块入口文件，所有类型在此文件已单独定义
// - PowerLogParser.swift  → 日志解析引擎
// - LogFileWatcher.swift  → 文件监听器
// - EventPipeline.swift   → 事件管道（位于 Core/）

// 模块结构：
//   LogMonitor/
//   ├── LogMonitorModule.swift  ← 当前文件（模块说明）
//   ├── PowerLogParser.swift    ← 状态机日志解析
//   └── LogFileWatcher.swift    ← DispatchSource 文件监听