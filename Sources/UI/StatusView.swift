import SwiftUI
import AppKit

struct StatusView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var isGameRunning = false
    @State private var isChecking = false
    @State private var autoCheckTimer: Timer?
    @State private var autoCheckDeadline: Date?

    var body: some View {
        HStack(spacing: 12) {
            // 状态指示灯（点击刷新）
            Button(action: refreshStatus) {
                Circle()
                    .fill(isGameRunning ? Color.green : Color.red)
                    .frame(width: 14, height: 14)
                    .shadow(color: isGameRunning ? .green.opacity(0.8) : .red.opacity(0.8), radius: 4)
                    .overlay(
                        isChecking
                            ? ProgressView().scaleEffect(0.5).tint(.white)
                            : nil
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("点击刷新游戏状态")

            Text(isChecking ? "检测中..." : (isGameRunning ? "炉石运行中" : "炉石未运行"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            // 悬浮窗开关按钮
            Button(action: { core.toggleOverlay() }) {
                Image(systemName: core.isOverlayVisible ? "rectangle.on.rectangle" : "rectangle")
                    .font(.system(size: 12))
                Text(core.isOverlayVisible ? "关闭悬浮窗" : "悬浮窗")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(core.isOverlayVisible ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
            )
            .help("切换记牌器悬浮窗")

            // 启动战网按钮
            Button(action: launchBattleNet) {
                Text("启动战网")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onDisappear {
            stopAutoCheck()
        }
    }

    private func refreshStatus() {
        checkGameStatus()
    }

    private func startAutoCheck() {
        let now = Date()
        if let deadline = autoCheckDeadline, now < deadline {
            scheduleNextCheck()
        }
    }

    private func scheduleNextCheck() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            checkGameStatus()
            if let deadline = autoCheckDeadline, Date() < deadline {
                scheduleNextCheck()
            } else {
                stopAutoCheck()
            }
        }
    }

    private func stopAutoCheck() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil
    }

    private func checkGameStatus() {
        isChecking = true
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "pgrep -x 'Hearthstone'"]
            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let running = !(output?.isEmpty ?? true)

                DispatchQueue.main.async {
                    isGameRunning = running
                    isChecking = false
                }
            } catch {
                DispatchQueue.main.async {
                    isGameRunning = false
                    isChecking = false
                    stopAutoCheck()
                }
            }
        }
    }

    private func launchBattleNet() {
        // 搜索 Battle.net 安装路径（使用 mdfind + 预设路径）
        let searchPaths = [
            "/Volumes/T7/Applications/Battle.net.app",
            "/Applications/Battle.net.app",
            "/Applications/Blizzard Battle.net.app",
            "/Users/\(NSUserName())/Applications/Battle.net.app",
            "/Users/\(NSUserName())/Library/Application Support/Battle.net/Versions/Battle.net.app",
        ]
        
        // 先用 mdfind 搜索
        let spotlightPaths = findAppViaSpotlight("Battle.net.app")
        let allPaths = spotlightPaths + searchPaths
        
        for path in allPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                if let error = error {
                    print("[StatusView] Failed to launch Battle.net from \(path): \(error)")
                } else {
                    print("[StatusView] Launched Battle.net from \(path)")
                }
            }
            autoCheckDeadline = Date().addingTimeInterval(5 * 60)
            startAutoCheck()
            return
        }
        
        // 最后尝试：通过 bundle identifier 启动
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.battle.app") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                if let error = error {
                    print("[StatusView] Failed to launch via bundle ID: \(error)")
                } else {
                    print("[StatusView] Launched Battle.net via bundle ID")
                }
            }
            autoCheckDeadline = Date().addingTimeInterval(5 * 60)
            startAutoCheck()
            return
        }
        
        print("[StatusView] Battle.net not found on this system")
    }
    
    private func findAppViaSpotlight(_ appName: String) -> [String] {
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemFSName == '\(appName)'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: "\n").filter { !$0.isEmpty }
        } catch {
            return []
        }
    }
}