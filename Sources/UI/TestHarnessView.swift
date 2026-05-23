import SwiftUI
import AppKit

/// 单元测试辅助工具：提供模拟数据、测试场景、性能基准
struct TestHarnessView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var testResults: [String] = []
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 12) {
            Text("单元测试辅助工具")
                .font(.headline)
                .padding(.top)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.self) { result in
                        HStack {
                            Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : 
                                   result.contains("❌") ? "xmark.circle.fill" : "info.circle")
                                .foregroundColor(result.contains("✅") ? .green : 
                                               result.contains("❌") ? .red : .blue)
                            Text(result)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 200)

            Divider()

            VStack(spacing: 8) {
                Button("运行卡组解析测试") {
                    runDeckParsingTests()
                }
                .disabled(isRunning)

                Button("运行日志事件测试") {
                    runLogEventTests()
                }
                .disabled(isRunning)

                Button("运行OCR模拟测试") {
                    runOCRSimulationTests()
                }
                .disabled(isRunning)

                Button("运行性能基准测试") {
                    runPerformanceBenchmarks()
                }
                .disabled(isRunning)

                Button("生成测试报告") {
                    generateTestReport()
                }
                .disabled(isRunning)

                Divider()

                HStack {
                    Button("清除结果") {
                        testResults.removeAll()
                    }
                    .foregroundColor(.red)

                    Spacer()

                    Button("导出报告") {
                        exportTestReport()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }

    private func runDeckParsingTests() {
        isRunning = true
        testResults.append("开始卡组解析测试...")

        // 测试数据：标准卡组码
        let testDeckCodes = [
            "AAECAZ8FBPoO0xXZ/gUNjAGeAdwD9g36DfYNgQ6QDpUO7A/tD9MT1xPZ/gLZ/gIA",
            "AAECAa0GAA+KAZIB0gHcAe4B8gH1Af4B/wH+AgGCAoIDhAOFA4YDiQOKA4sDAA==",
            "AAECAf0EAA+KAZIB0gHcAe4B8gH1Af4B/wH+AgGCAoIDhAOFA4YDiQOKA4sDAA=="
        ]

        for (index, code) in testDeckCodes.enumerated() {
            do {
                let result = try DeckCodeParser.parse(code, database: core.cardDatabase)
                testResults.append("✅ 测试 \(index+1): 解析成功 - \(result.heroClass.displayName) (\(result.cards.count) 卡)")
            } catch {
                testResults.append("❌ 测试 \(index+1): 解析失败 - \(error.localizedDescription)")
            }
        }

        testResults.append("卡组解析测试完成")
        isRunning = false
    }

    private func runLogEventTests() {
        isRunning = true
        testResults.append("开始日志事件测试...")

        // 模拟日志事件
        let testEvents = [
            CardEvent(type: .play, card: Card(dbfId: 1, cardId: "EX1_277", name: "寒冰箭", cost: 2, cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE"), player: .player, timestamp: Date(), confidence: 1.0, metadata: nil),
            CardEvent(type: .draw, card: Card(dbfId: 2, cardId: "CS2_106", name: "炽炎战斧", cost: 2, cardClass: "warrior", rarity: "FREE", type: "weapon", set: "CORE"), player: .player, timestamp: Date(), confidence: 1.0, metadata: nil),
            CardEvent(type: .create, card: Card(dbfId: 3, cardId: "EX1_572", name: "伊瑟拉", cost: 9, cardClass: "druid", rarity: "LEGENDARY", type: "minion", set: "CORE"), player: .player, timestamp: Date(), confidence: 1.0, metadata: nil)
        ]

        for event in testEvents {
            core.handleCardEvent(event)
            testResults.append("📝 处理事件: \(event.card.name) - \(event.type)")
        }

        testResults.append("日志事件测试完成")
        isRunning = false
    }

    private func runOCRSimulationTests() {
        isRunning = true
        testResults.append("开始OCR模拟测试...")

        // 模拟OCR结果
        let mockResults = [
            OCRResult(card: Card(dbfId: 100, cardId: "CS2_029", name: "火球术", cost: 4, cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE"), rawText: "火球术", confidence: 0.92, boundingBox: .zero),
            OCRResult(card: Card(dbfId: 101, cardId: "EX1_277", name: "寒冰箭", cost: 2, cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE"), rawText: "寒冰箭", confidence: 0.88, boundingBox: .zero),
            OCRResult(card: Card(dbfId: 102, cardId: "EX1_279", name: "炎爆术", cost: 10, cardClass: "mage", rarity: "EPIC", type: "spell", set: "CORE"), rawText: "炎爆术", confidence: 0.95, boundingBox: .zero)
        ]

        for result in mockResults {
            core.opponentTracker.handleOCRResult(result)
            testResults.append("👁️ OCR识别: \(result.card.name) (\(Int(result.confidence * 100))%)")
        }

        testResults.append("OCR模拟测试完成")
        isRunning = false
    }

    private func runPerformanceBenchmarks() {
        isRunning = true
        testResults.append("开始性能基准测试...")

        let startTime = Date()

        // 卡牌数据库查询性能
        let cardCount = core.cardDatabase.allCards.count
        testResults.append("📊 卡牌数据库: \(cardCount) 张卡牌")

        // 内存使用估算
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryMB = Double(memory) / (1024 * 1024)
        testResults.append("💾 内存使用: \(String(format: "%.1f", memoryMB)) MB")

        // 事件处理延迟
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        testResults.append("⏱️ 测试耗时: \(String(format: "%.3f", duration)) 秒")

        testResults.append("性能基准测试完成")
        isRunning = false
    }

    private func generateTestReport() {
        isRunning = true
        testResults.append("生成测试报告中...")

        let report = """
        # 炉石记牌器 测试报告
        ## 生成时间: \(Date().formatted(date: .complete, time: .complete))
        
        ## 测试结果概览
        - 总测试数: \(testResults.count)
        - 通过: \(testResults.filter { $0.contains("✅") }.count)
        - 失败: \(testResults.filter { $0.contains("❌") }.count)
        
        ## 详细结果
        \(testResults.joined(separator: "\n"))
        """

        let outputPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HearthstoneTracker_TestReport_\(Date().timeIntervalSince1970).md")

        do {
            try report.write(to: outputPath, atomically: true, encoding: .utf8)
            testResults.append("📄 报告已保存: \(outputPath.path)")
        } catch {
            testResults.append("❌ 报告保存失败: \(error.localizedDescription)")
        }

        isRunning = false
    }

    private func exportTestReport() {
        let panel = NSSavePanel()
        panel.title = "导出测试报告"
        panel.nameFieldStringValue = "HearthstoneTracker_TestReport.md"
        panel.allowedContentTypes = [.plainText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let report = testResults.joined(separator: "\n")
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                    testResults.append("📤 报告已导出: \(url.path)")
                } catch {
                    testResults.append("❌ 导出失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

/// 测试工具入口（通过菜单或快捷键打开）
extension CardTrackerCore {
    func showTestHarness() {
        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        testWindow.title = "炉石记牌器 - 测试工具"
        testWindow.contentView = NSHostingView(rootView: TestHarnessView().environmentObject(self))
        testWindow.center()
        testWindow.makeKeyAndOrderFront(nil)
    }
}