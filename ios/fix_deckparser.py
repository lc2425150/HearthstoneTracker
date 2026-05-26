import re

path = '/Users/achen/Documents/炉石传说记牌器/ios/HearthstoneTracker-iOS/Utilities/DeckCodeParser.swift'
with open(path, 'r') as f:
    content = f.read()

# Replace the entire decompress function
old_func = """    private static func decompress(_ data: [UInt8]) -> [UInt8]? {
        guard !data.isEmpty else { return nil }

        let compressedSize = data.count
        let decompressedSize = compressedSize * 4  // 估计解压后大小
        var decompressed = [UInt8](repeating: 0, count: decompressedSize)

        let result = data.withUnsafeBytes { srcPtr in
            decompressed.withUnsafeMutableBytes { dstPtr in
                guard srcPtr.baseAddress != nil, dstPtr.baseAddress != nil else {
                    return -1
                }
                // 使用 libz
                return data.withUnsafeBytes { srcBuf in
                    let s = srcBuf.bindMemory(to: UInt8.self)
                    guard let srcBase = s.baseAddress else { return -1 }
                    return decompressed.withUnsafeMutableBytes { dstBuf in
                        let d = dstBuf.bindMemory(to: UInt8.self)
                        guard let dstBase = d.baseAddress else { return -1 }
                        // Attempt to decompress using zlib
                        let size = compression_decode_buffer(
                            dstBase, decompressedSize,
                            srcBase, compressedSize,
                            nil,
                            COMPRESSION_ZLIB
                        )
                        return Int(size)
                    }
                }
            }
        }

        guard result > 0 else { return nil }
        return Array(decompressed.prefix(result))
    }"""

new_func = """    private static func decompress(_ data: [UInt8]) -> [UInt8]? {
        guard !data.isEmpty else { return nil }

        let compressedSize = data.count
        let decompressedSize = compressedSize * 4
        var decompressed = [UInt8](repeating: 0, count: decompressedSize)

        let result = data.withUnsafeBytes { srcRawPtr in
            decompressed.withUnsafeMutableBytes { dstRawPtr in
                guard let srcBase = srcRawPtr.baseAddress,
                      let dstBase = dstRawPtr.baseAddress else {
                    return -1
                }
                let src = srcBase.assumingMemoryBound(to: UInt8.self)
                let dst = dstBase.assumingMemoryBound(to: UInt8.self)

                let size = compression_decode_buffer(
                    dst, decompressedSize,
                    src, compressedSize,
                    nil,
                    COMPRESSION_ZLIB
                )
                return Int(size)
            }
        }

        guard result > 0 else { return nil }
        return Array(decompressed.prefix(result))
    }"""

assert old_func in content, "Could not find old decompress function!"
content = content.replace(old_func, new_func)

with open(path, 'w') as f:
    f.write(content)

print("✅ Fixed DeckCodeParser.swift - removed overlapping access to decompressed")
