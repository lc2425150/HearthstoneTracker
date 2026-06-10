import Foundation
import Vision
import AppKit
import SwiftData
import Combine

// MARK: - 屏幕截取降级方案
/// 仅在 ScreenCaptureKit 不可用时调用
private func captureWindowScreenshotLegacy(region: CGRect) -> CGImage? {
    let cgImage = CGWindowListCreateImage(region, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    if cgImage == nil {
        print("[OCR] Legacy capture failed (x=\(region.origin.x), y=\(region.origin.y), w=\(region.size.width), h=\(region.size.height))")
    }
    return cgImage
}

/// Vision OCR 扫描器：对屏幕区域截图进行文字识别，匹配卡牌名称
/// 使用 ScreenCaptureKit (macOS 14.0+) 替代已废弃的 CGWindowListCreateImage
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
        Task {
            // 使用 ScreenCaptureKit 截图（需 MainActor）
            let cgImage = await ScreenCapture.capture(region: region) ?? captureWindowScreenshotLegacy(region: region)
            guard let cgImage else { return }
            // 后台线程识别
            recognitionQueue.async { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.recognize(cgImage: cgImage)
                }
            }
        }
    }

    /// 扫描炉石游戏窗口
    func scanGameWindow() {
        Task {
            // 查找窗口 + 截图（使用 ScreenCaptureKit）
            guard let windowRect = ScreenCapture.findHearthstoneWindow() else {
                print("[OCR] Hearthstone window not found")
                return
            }
            let cgImage = await ScreenCapture.capture(region: windowRect) ?? captureWindowScreenshotLegacy(region: windowRect)
            guard let cgImage else { return }
            // 主线程识别
            self.recognize(cgImage: cgImage)
        }
    }

    // MARK: - Private Recognition

    private func recognize(cgImage: CGImage) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("[OCR] Recognition error: \(error)")
                return
            }
            self?.processResults(request.results)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.minimumTextHeight = 0.01

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

            guard text.count >= 2 else { continue }

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

        let unique = deduplicate(ocrResults)

        DispatchQueue.main.async { [weak self] in
            self?.onResult?(unique)
        }
    }

    // MARK: - Card Matching

    private func fuzzyMatchCard(text: String) -> [Card] {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespaces)
        var matches: [Card] = []

        if let exact = cardDatabase.card(forName: text) {
            matches.append(exact)
            return matches
        }

        let allCards = cardDatabase.allCards

        for card in allCards {
            let cardName = card.name.lowercased()

            if cardName.contains(normalized) || normalized.contains(cardName) {
                matches.append(card)
                continue
            }

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
