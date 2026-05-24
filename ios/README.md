# 炉边记牌器 (iOS)

炉石传说 iOS 记牌器，支持手动追踪、卡组管理、对局统计。

## 功能

- **卡组管理**：导入卡组码、创建卡组、卡牌列表查看
- **实时追踪**：手动追踪手牌、牌库、已打出牌、发现牌
- **对局统计**：胜率统计、按职业/卡组分类、连胜记录
- **卡牌数据**：自动从 HearthstoneJSON 更新卡牌数据库
- **OCR 识别**：通过屏幕录制 + Vision 框架识别卡牌（可选）

## 在 Xcode 中打开

### 方式一：使用 Swift Package Manager (推荐)

```bash
open Package.swift
```

### 方式二：创建 Xcode 项目

1. 在 Xcode 中选 `File > New > Project`
2. 选择 `iOS > App`，点 Next
3. 填写：
   - Product Name: `HearthstoneTracker`
   - Team: (个人开发者账号或 None)
   - Organization Identifier: `com.yourname`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - 取消勾选所有选项
4. 点 Next，选择 `ios/` 目录
5. 创建后，删除默认生成的文件
6. 将 `HearthstoneTracker-iOS/` 目录下所有文件拖入项目
7. 确保 `Info.plist` 在项目中正确引用

### 构建并运行

1. 连接你的 iPhone，或在模拟器中运行
2. 选择目标设备
3. `Cmd + R` 构建运行
4. 首次启动会自动下载卡牌数据

## 项目结构

```
HearthstoneTracker-iOS/
├── HearthstoneTrackerApp.swift   # 应用入口
├── ContentView.swift             # 主视图 (TabView)
├── Info.plist                    # 应用配置
├── Assets.xcassets/              # 资源文件
├── Views/
│   ├── DeckLibraryView.swift     # 卡组库
│   ├── DeckDetailView.swift      # 卡组详情
│   ├── LiveMatchView.swift       # 实时对战追踪
│   ├── StatsView.swift           # 统计
│   └── SettingsView.swift        # 设置
├── Models/
│   └── CardModels.swift          # 数据模型
├── Services/
│   ├── CardDataService.swift     # 卡牌数据服务
│   ├── CardImageLoader.swift     # 卡图加载
│   ├── TrackingService.swift     # 对战追踪
│   └── OCRService.swift          # 屏幕录制 OCR
└── Utilities/
    ├── DeckCodeParser.swift      # 卡组码解析
    └── Constants.swift           # 常量定义
```

## 使用说明

1. **导入卡组**：在「牌库」Tab 点击 +，粘贴卡组码即可
2. **开始追踪**：点击卡组进入详情，点「开始对局追踪」
3. **操作**：点击手牌 = 打出，长按手牌 = 显示菜单（弃牌/消灭）
4. **抽牌**：点「抽牌」按钮，或「下一回合」自动抽牌
5. **发现牌**：点「添加发现牌」搜索并添加
6. **结束对局**：选择胜利或失败

## 数据来源

- 卡牌数据: [HearthstoneJSON](https://hearthstonejson.com)
- 卡牌图片: `art.hearthstonejson.com`

## 系统要求

- iOS 18.0+
- Xcode 16+
- Swift 6.2
