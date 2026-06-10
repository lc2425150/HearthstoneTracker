import Foundation

/// 日志文件监听器：监控 Power.log 文件变化，增量读取新行并送交解析器
final class LogFileWatcher: @unchecked Sendable {
    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastFileSize: UInt64 = 0
    private let parser: PowerLogParser
    private let queue = DispatchQueue(label: "com.hts.logwatcher", qos: .utility)

    var isRunning: Bool { dispatchSource != nil }

    init(parser: PowerLogParser) {
        self.parser = parser
    }

    // MARK: - Public

    func startWatching(paths: [String]) {
        guard !isRunning else { return }

        let resolvedPath = resolveLogPath(from: paths)
        guard let path = resolvedPath else {
            print("[LogWatcher] No valid log file found")
            return
        }

        print("[LogWatcher] Monitoring: \(path)")
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) ?? 0
        print("[LogWatcher] File size: \(fileSize)")

        do {
            fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            lastFileSize = (attributes[.size] as? UInt64) ?? 0

            // 定位到文件末尾，仅监听增量
            try fileHandle?.seekToEnd()

            // 读取启动前的已有内容（首次启动时可选）
            // 这里跳过已有内容，仅追踪新行

        } catch {
            print("[LogWatcher] Failed to open log: \(error)")
            return
        }

        // 使用 DispatchSource 监听文件变化
        let fd = fileHandle?.fileDescriptor ?? -1
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.readNewLines()
        }

        source.setCancelHandler { [weak self] in
            try? self?.fileHandle?.close()
            self?.fileHandle = nil
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    // MARK: - Private

    private func resolveLogPath(from paths: [String]) -> String? {
        let fm = FileManager.default
        for path in paths {
            let resolved = (path as NSString).expandingTildeInPath
            if fm.fileExists(atPath: resolved) {
                return resolved
            }
        }
        return nil
    }

    private func readNewLines() {
        guard let handle = fileHandle else { return }

        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }

        guard let text = String(data: data, encoding: .utf8) else {
            // 尝 GBK/GB2312 编码（游戏日志可能用 GB 编码）
            let enc = CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
            if let gbk = String(data: data, encoding: String.Encoding(rawValue: enc)) {
                parseLines(gbk)
            }
            return
        }

        parseLines(text)
    }

    private func parseLines(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        // 限制单次处理行数，防止主线程卡顿
        let maxLinesPerBatch = 500
        let totalLines = lines.count
        
        Task { @MainActor in
            // 分块处理：每批最多 500 行，避免主线程长时间阻塞
            var index = 0
            while index < totalLines {
                let end = min(index + maxLinesPerBatch, totalLines)
                for i in index..<end {
                    parser.feedLine(lines[i])
                }
                index = end
                // 如果还有更多行，让出主线程以响应 UI 事件
                if index < totalLines {
                    await Task.yield()
                }
            }
        }
    }
}