# 炉边记牌器 - iOS 版

炉石传说手机版记牌器，基于 SwiftUI + SwiftData 开发。

## 功能

- **卡组管理**：创建、编辑、导入/导出卡组（支持炉石卡组代码）
- **实时记牌**：对局中追踪剩余卡牌、已抽/已打牌
- **统计**：胜率统计、职业对阵分析
- **OCR 识别**：通过屏幕录制识别卡牌（需要 iOS 17+）
- **卡牌图鉴**：浏览全部卡牌数据

## 系统要求

- iOS 17.0+
- Xcode 15.0+ (推荐 Xcode 16+)
- 真机调试需要 Apple Developer 账号（免费也可）

## 构建方法

### 方法一：Xcode 打开项目

```bash
# 1. 生成 Xcode 项目文件
cd ios
python3 gen_json_project.py

# 2. 用 Xcode 打开
open HearthstoneTracker.xcodeproj
```

### 方法二：命令行构建

```bash
# Simulator 构建
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -target HearthstoneTracker -sdk iphonesimulator build

# 真机构建（需要签名）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -target HearthstoneTracker -sdk iphoneos build
```

### 方法三：Swift Package Manager

用 Xcode 打开 `ios/Package.swift`，选择 iOS 目标运行。

## 项目结构

```
ios/
├── HearthstoneTracker-iOS/       # 源代码
│   ├── HearthstoneTrackerApp.swift  # App 入口
│   ├── ContentView.swift            # 主视图
│   ├── Models/                      # 数据模型 (SwiftData)
│   ├── Views/                       # 视图层
│   ├── Services/                    # 服务层 (OCR, 追踪, 数据)
│   └── Utilities/                   # 工具 (卡组解析)
├── gen_json_project.py           # 项目文件生成器
├── Package.swift                 # SwiftPM 配置
└── README.md
```

## 真机安装

1. 连接 iPhone 到 Mac
2. Xcode > 选择 iPhone 目标 > Run (⌘R)
3. Xcode 会自动处理签名和安装

> **注意**：首次连接真机需要 Xcode 下载对应 iOS 版本的 DeviceSupport 文件
> （Xcode > Settings > Components > iOS 设备支持）
