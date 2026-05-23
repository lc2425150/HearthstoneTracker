import Foundation
import Vision
import AppKit
import SwiftData
import Combine

/// Vision OCR 扫描器：对屏幕区域截图进行文字识别，匹配卡牌名称
@MainActor
final class VisionOCRScanner {
    private let cardDatabase: CardDatabase
    private let recognitionQueue = DispatchQueue(label: "com.hts.ocr", qos: .userInitiated)

    /// OCR 结果回调：识别到的卡牌列表及其置信度
    var onResult: (([OCRResult]) -> Void)?

    init(database: CardDatabase) {
        self.cardDatabase = database
    }

    // MARK: - Public

    /// 扫描指定区域（Cocoa 坐标系）
    func scan(region: CGRect) {
        recognitionQueue.async { [weak self] in
            self?.captureAndRecognize(region: region)
        }
    }

    /// 扫描当前前台窗口的整个区域
    func scanFullScreen() {
        guard let screen = NSScreen.main else { return }
        scan(region: screen.frame)
    }

    /// 扫描炉石游戏窗口（查找 Hearthstone 进程窗口）
    func scanGameWindow() {
        guard let window = findHearthstoneWindow() else {
            print("[OCR] Hearthstone window not found")
            return
        }
        scan(region: window)
    }

    // MARK: - Private Capture

    private func captureAndRecognize(region: CGRect) {
        // 使用 CGWindowListCreateImage 截取指定区域
        let listOption: CGWindowListOption = .optionOnScreenOnly
        let imageOption: CGWindowImageOption = .bestResolution
        guard let cgImage = CGWindowListCreateImage(region, listOption, kCGNullWindowID, imageOption) else {
            print("[OCR] Failed to capture screen region")
            return
        }

        recognize(cgImage: cgImage)
    }

    private func recognize(cgImage: CGImage) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("[OCR] Recognition error: \(error)")
                return
            }
            self?.processResults(request.results)
        }

        // 配置识别参数
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.minimumTextHeight = 0.01  // 极小文字也尝试识别

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[OCR] Request failed: \(error)")
        }
    }

    // MARK: - Result Processing

    private func processResults(_ results: [Any]?) {
        guard let observations = results as? [VNRecognizedTextObservation] else { return }

        var ocrResults: [OCRResult] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

            // 跳过过短或无意义的文本
            guard text.count >= 2 else { continue }

            // 在卡牌数据库中搜索匹配
            let matchedCards = fuzzyMatchCard(text: text)

            for card in matchedCards {
                ocrResults.append(OCRResult(
                    card: card,
                    rawText: text,
                    confidence: Double(candidate.confidence),
                    boundingBox: observation.boundingBox
                ))
            }
        }

        // 去重：同一卡牌多次识别只保留置信度最高的
        let unique = deduplicate(ocrResults)

        DispatchQueue.main.async { [weak self] in
            self?.onResult?(unique)
        }
    }

    // MARK: - Card Matching

    private func fuzzyMatchCard(text: String) -> [Card] {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespaces)
        var matches: [Card] = []

        // 精确匹配
        if let exact = cardDatabase.card(forName: text) {
            matches.append(exact)
            return matches
        }

        // 模糊匹配：搜索所有卡牌名称
        let allCards = cardDatabase.allCards

        for card in allCards {
            let cardName = card.name.lowercased()

            // 包含匹配
            if cardName.contains(normalized) || normalized.contains(cardName) {
                matches.append(card)
                continue
            }

            // 编辑距离匹配（允许 2 个字符的差异）
            if levenshteinDistance(normalized, cardName) <= 2 {
                matches.append(card)
            }
        }

        return matches
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1), b = Array(s2)
        let m = a.count, n = b.count
        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var prev = [Int](0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    curr[j] = prev[j-1]
                } else {
                    curr[j] = min(prev[j], curr[j-1], prev[j-1]) + 1
                }
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    // MARK: - Deduplication

    private func deduplicate(_ results: [OCRResult]) -> [OCRResult] {
        var best: [Int: OCRResult] = [:]

        for result in results {
            let dbfId = result.card.dbfId
            if let existing = best[dbfId], existing.confidence >= result.confidence {
                continue
            }
            best[dbfId] = result
        }

        return Array(best.values)
    }

    // MARK: - Window Detection

    private func findHearthstoneWindow() -> CGRect? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let name = window[kCGWindowName as String] as? String else { continue }
            if name.contains("Hearthstone") || name.contains("炉石") {
                if let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat] {
                    return CGRect(
                        x: boundsDict["X"] ?? 0,
                        y: boundsDict["Y"] ?? 0,
                        width: boundsDict["Width"] ?? 0,
                        height: boundsDict["Height"] ?? 0
                    )
                }
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

struct OCRResult {
    let card: Card
    let rawText: String
    let confidence: Double
    let boundingBox: CGRect
}

// MARK: - CardDatabase Extension for OCR

@MainActor
extension CardDatabase {
    /// 按名称搜索卡牌
    func card(forName name: String) -> Card? {
        let normalized = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.name == normalized }
        )
        do {
            return try modelContainer.mainContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    /// 获取全部卡牌（用于模糊匹配）
    var allCards: [Card] {
        let descriptor = FetchDescriptor<Card>()
        do {
            return try modelContainer.mainContext.fetch(descriptor)
        } catch {
            return []
        }
    }
}