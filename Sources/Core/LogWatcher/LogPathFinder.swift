import Foundation
import AppKit

/// HSTracker 风格的日志路径自动发现
/// 支持多路径扫描 + 进程检测 + Spotlight 搜索
enum LogPathFinder {
    
    /// 候选日志路径
    private static let candidatePaths = [
        "\(NSHomeDirectory())/Library/Logs/Unity/Player.log",
        "/Applications/Hearthstone/Logs/Power.log",
        "\(NSHomeDirectory())/Library/Application Support/Blizzard/Hearthstone/Logs/Power.log",
        "\(NSHomeDirectory())/Library/Logs/Hearthstone/Power.log"
    ]
    
    /// 发现 Power.log 路径
    static func discoverPowerLog() -> String? {
        // 1. 快速检查候选路径
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                let logPath = (path as NSString).standardizingPath
                print("[LogPathFinder] 找到日志: \(logPath)")
                return logPath
            }
        }
        
        // 2. 通过 NSWorkspace 找 Hearthstone 进程获取路径
        if let processPath = findHearthstoneProcessPath() {
            let baseDir = (processPath as NSString).deletingLastPathComponent
            let logPath = "\(baseDir)/../Logs/Power.log"
            let resolved = (logPath as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: resolved) {
                print("[LogPathFinder] 通过进程找到日志: \(resolved)")
                return resolved
            }
        }
        
        // 3. Spotlight 搜索（慢但可靠）
        if let spotlightPath = searchWithSpotlight() {
            print("[LogPathFinder] Spotlight 找到日志: \(spotlightPath)")
            return spotlightPath
        }
        
        print("[LogPathFinder] 未找到 Power.log")
        return nil
    }
    
    /// 检测 Hearthstone 是否在运行
    static func isHearthstoneRunning() -> Bool {
        return NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "blizzard.hearthstone" ||
            app.bundleIdentifier == "unity.hearthstone"
        }
    }
    
    /// 通过 Hearthstone 进程获取安装路径
    private static func findHearthstoneProcessPath() -> String? {
        return NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == "blizzard.hearthstone" }?
            .bundleURL?
            .path
    }
    
    /// 使用 Spotlight 搜索 Power.log
    private static func searchWithSpotlight() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemFSName == 'Power.log'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.components(separatedBy: "\n")
            .first { !$0.isEmpty && $0.hasSuffix("Power.log") }
    }
}
