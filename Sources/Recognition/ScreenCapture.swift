import Cocoa
import ScreenCaptureKit
import CoreGraphics

// MARK: - ScreenCapture

/// ScreenCaptureKit 截图工具（macOS 14.0+）
///
/// 替代已废弃的 CGWindowListCreateImage。
/// 提供 async 截图接口，自动请求权限。
enum ScreenCapture {
    
    /// 截取指定区域的屏幕快照
    /// - Parameter region: 屏幕坐标区域
    /// - Returns: CGImage，失败时返回 nil
    @MainActor
    static func capture(region: CGRect) async -> CGImage? {
        // 先尝试 ScreenCaptureKit（macOS 14.0+ 推荐方式）
        if #available(macOS 14.0, *) {
            if let image = try? await captureWithScreenCaptureKit(region: region) {
                return image
            }
        }
        // 降级：使用 CGWindowListCreateImage（已废弃但可用）
        return captureWithCG(region: region)
    }
    
    /// 截取 Hearthstone 游戏窗口快照
    @MainActor
    static func captureHearthstoneWindow() async -> CGImage? {
        guard let windowRect = findHearthstoneWindow() else { return nil }
        return await capture(region: windowRect)
    }
    
    // MARK: - ScreenCaptureKit (macOS 14.0+)
    
    @available(macOS 14.0, *)
    private static func captureWithScreenCaptureKit(region: CGRect) async throws -> CGImage? {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { return nil }
        
        let config = SCStreamConfiguration()
        config.width = Int(region.width * 2)
        config.height = Int(region.height * 2)
        config.capturesAudio = false
        config.showsCursor = false
        config.scalesToFit = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let capture = SingleFrameCapture()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        try stream.addStreamOutput(capture, type: .screen, sampleHandlerQueue: .main)
        try await stream.startCapture()
        
        // 获取全屏截图后裁剪到指定区域
        var image = try await capture.captureFrame()
        
        try await stream.stopCapture()
        
        // 如需要裁剪区域且图片足够大，做裁剪
        if let fullImage = image,
           fullImage.width > Int(region.width),
           fullImage.height > Int(region.height) {
            let scaleX = CGFloat(fullImage.width) / CGFloat(display.width)
            let scaleY = CGFloat(fullImage.height) / CGFloat(display.height)
            let cropRect = CGRect(
                x: region.origin.x * scaleX,
                y: region.origin.y * scaleY,
                width: region.width * scaleX,
                height: region.height * scaleY
            )
            if let cropped = fullImage.cropping(to: cropRect) {
                image = cropped
            }
        }
        
        return image
    }
    
    // MARK: - CG 方式（降级）
    
    private static func captureWithCG(region: CGRect) -> CGImage? {
        let image = CGWindowListCreateImage(
            region,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
        if image == nil {
            print("[ScreenCapture] CG 截图失败 (x=\(region.origin.x), y=\(region.origin.y), w=\(region.size.width), h=\(region.size.height))")
        }
        return image
    }
    
    // MARK: - 窗口查找
    
    /// 查找 Hearthstone 窗口位置
    static func findHearthstoneWindow() -> CGRect? {
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

// MARK: - SingleFrameCapture

/// 单帧截图捕获器
@available(macOS 14.0, *)
private class SingleFrameCapture: NSObject, SCStreamOutput {
    
    private var continuation: CheckedContinuation<CGImage?, Error>?
    
    func stream(_ stream: SCStream, didOutput sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let continuation = continuation,
              let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        self.continuation = nil
        
        // CVPixelBuffer → CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            continuation.resume(returning: cgImage)
        } else {
            continuation.resume(returning: nil)
        }
    }
    
    func captureFrame() async throws -> CGImage? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
}
