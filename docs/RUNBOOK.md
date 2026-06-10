# 运行手册

## 编译
```bash
cd /Users/achen/Documents/炉石传说记牌器
bash build_dmg.sh
```

## 运行
```bash
open .build/HearthstoneTracker.app
# 或双击 .build/HearthstoneTracker.dmg
```

## 关键文件速查
- 入口: `Sources/HearthstoneTrackerApp.swift`
- 核心协调: `Sources/Core/CardTrackerCore.swift` (旧) / `Sources/Core/CoreManager.swift` (新)
- AI引擎: `Sources/AI/AIManager.swift`
- 卡牌数据: `Sources/Data/Models/CardModels.swift`
- 悬浮窗: `Sources/UI/Overlay/OverWindowController.swift`
- 设置: `Sources/Core/Settings.swift`

## 开发日志
- `docs/DEVELOPMENT_CONTEXT.md` — 完整上下文
- `docs/superpowers/specs/` — 设计文档
- `docs/superpowers/plans/` — 实施计划
- `CHANGELOG-v2.0.md` — 变更日志
