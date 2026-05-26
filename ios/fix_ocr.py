path = '/Users/achen/Documents/炉石传说记牌器/ios/HearthstoneTracker-iOS/Services/OCRService.swift'
with open(path, 'r') as f:
    content = f.read()

old_stop = """    /// 停止屏幕录制
    func stopRecording() async {
        do {
            try await recorder.stopCapture()
            await MainActor.run { self.isRecording = false }
        } catch {
            print("OCR 录制停止失败: \\(error.localizedDescription)")
        }
    }"""

new_stop = """    /// 停止屏幕录制
    func stopRecording() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            recorder.stopCapture { error in
                if let error = error {
                    print("OCR 录制停止失败: \\(error.localizedDescription)")
                }
                Task { @MainActor in
                    self.isRecording = false
                }
                continuation.resume()
            }
        }
    }"""

assert old_stop in content, "Could not find old stopRecording!"
content = content.replace(old_stop, new_stop)

with open(path, 'w') as f:
    f.write(content)

print("✅ Fixed OCRService.swift - removed invalid try/await on stopCapture")
