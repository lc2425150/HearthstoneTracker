import Foundation
import Vision
import UIKit
import ReplayKit

// MARK: - OCR Service (Screen Recording + Vision)

/// iOS 端 OCR 服务：通过 ReplayKit 录制屏幕 + Vision 识别卡牌
/// 注意：需要用户在设置中启用屏幕录制权限
final class OCRService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var lastRecognizedText: String = ""
    @Published var confidence: Float = 0

    private let recorder = RPScreenRecorder.shared()
    private var isProcessing = false

    override init() {
        super.init()
        recorder.isMicrophoneEnabled = false
    }

    /// 开始屏幕录制（用于 OCR）
    func startRecording() async -> Bool {
        guard recorder.isAvailable else { return false }

        do {
            try await recorder.startCapture(
                handler: { [weak self] sampleBuffer, bufferType, error in
                    guard let self = self,
                          bufferType == .video,
                          !self.isProcessing else { return }
                    self.processFrame(sampleBuffer)
                }
            )
            await MainActor.run { self.isRecording = true }
            return true
        } catch {
            print("OCR 录制启动失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 停止屏幕录制
    func stopRecording() async {
        do {
            try await recorder.stopCapture()
            await MainActor.run { self.isRecording = false }
        } catch {
            print("OCR 录制停止失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 帧处理

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }
        isProcessing = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        // 限制处理频率
        performOCR(on: pixelBuffer) { [weak self] result in
            DispatchQueue.main.async {
                self?.lastRecognizedText = result.text
                self?.confidence = result.confidence
                self?.isProcessing = false
            }
        }
    }

    // MARK: - Vision OCR

    private func performOCR(on pixelBuffer: CVPixelBuffer, completion: @escaping (OCRResult) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(OCRResult(text: "", confidence: 0))
                return
            }

            var recognizedText = ""
            var maxConfidence: Float = 0

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                if !recognizedText.isEmpty {
                    recognizedText += " "
                }
                recognizedText += topCandidate.string
                maxConfidence = max(maxConfidence, topCandidate.confidence)
            }

            completion(OCRResult(text: recognizedText, confidence: maxConfidence))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

struct OCRResult {
    let text: String
    let confidence: Float
}
