import Foundation
import Compression

// MARK: - Hearthstone Deck Code Parser

/// 解析炉石传说卡组码（Base64 编码）
/// 格式参考: https://github.com/HearthSim/HSDeckCode
enum DeckCodeParser {
    enum ParserError: Error, LocalizedError {
        case invalidLength
        case invalidBase64
        case invalidVersion
        case invalidHero
        case decompressionFailed
        case invalidCardCount

        var errorDescription: String? {
            switch self {
            case .invalidLength: return "卡组码长度无效"
            case .invalidBase64: return "卡组码格式无效"
            case .invalidVersion: return "不支持的卡组码版本"
            case .invalidHero: return "无法识别职业"
            case .decompressionFailed: return "数据解压失败"
            case .invalidCardCount: return "卡牌数量异常"
            }
        }
    }

    /// 解析结果
    struct DeckCodeResult {
        let heroClass: String
        let cardDbfIds: [Int]
        let version: Int
    }

    /// 解析卡组码，返回 DBF ID 列表和职业
    static func parse(_ deckCode: String) throws -> DeckCodeResult {
        // 1. 解码 Base64
        let normalizedCode = deckCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        guard let decodedData = Data(base64Encoded: normalizedCode) else {
            throw ParserError.invalidBase64
        }

        let data = [UInt8](decodedData)
        guard data.count >= 3 else {
            throw ParserError.invalidLength
        }

        // 2. 解析头部: [版本(1 byte)] [模式/1位 + 飞行/1位 + 保留/2位 + 职业/4位]
        let version = Int(data[0])

        guard version <= 1 else {
            throw ParserError.invalidVersion
        }

        // 职业编码 (4 bits in second byte)
        let heroClassBitIndex = 2  // bits 2..5 (using 0-indexed from bit 0)
        let heroClassCode = (Int(data[1]) >> heroClassBitIndex) & 0b1111
        let heroClass = heroClassFromCode(heroClassCode)

        // 3. 解压数据 (third byte onward)
        let compressedData = Array(data[2...])
        guard let decompressed = decompress(compressedData) else {
            throw ParserError.decompressionFailed
        }

        // 4. 解析卡牌 DBF ID
        var dbfIds = [Int]()
        var index = 0

        while index < decompressed.count {
            // 读取 varint
            let (count, bytesRead1) = readVarint(decompressed, start: index)
            index += bytesRead1

            guard count > 0 else { break }

            let (dbfId, bytesRead2) = readVarint(decompressed, start: index)
            index += bytesRead2

            for _ in 0..<count {
                dbfIds.append(dbfId)
            }
        }

        guard !dbfIds.isEmpty else {
            throw ParserError.invalidCardCount
        }

        return DeckCodeResult(heroClass: heroClass, cardDbfIds: dbfIds, version: version)
    }

    // MARK: - Private

    private static func heroClassFromCode(_ code: Int) -> String {
        let classes: [Int: String] = [
            2: "DRUID",
            3: "HUNTER",
            4: "MAGE",
            5: "PALADIN",
            6: "PRIEST",
            7: "ROGUE",
            8: "SHAMAN",
            9: "WARLOCK",
            10: "WARRIOR",
            14: "DEMONHUNTER",
            15: "DEATHKNIGHT"
        ]
        return classes[code] ?? "NEUTRAL"
    }

    private static func readVarint(_ data: [UInt8], start: Int) -> (value: Int, bytesRead: Int) {
        var value = 0
        var shift = 0
        var index = start

        while index < data.count {
            let byte = data[index]
            value |= Int(byte & 0x7F) << shift
            shift += 7
            index += 1
            if byte & 0x80 == 0 {
                break
            }
        }

        return (value, index - start)
    }

    private static func decompress(_ data: [UInt8]) -> [UInt8]? {
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
    }
}
