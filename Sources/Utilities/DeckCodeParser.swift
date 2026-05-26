import Foundation

/// 炉石卡组码解析器
/// 支持格式版本 1 和 2，动态读取卡牌数量（不限定 30/40）
enum DeckCodeParser {

    // MARK: - Errors

    enum ParseError: Error, LocalizedError {
        case invalidBase64
        case invalidFormat
        case unknownVersion(Int)

        var errorDescription: String? {
            switch self {
            case .invalidBase64: return "卡组码 Base64 解码失败"
            case .invalidFormat: return "卡组码格式无效"
            case .unknownVersion(let v): return "不支持的卡组码版本: \(v)"
            }
        }
    }

    // MARK: - Public

    @MainActor
    static func parse(_ deckString: String, database: CardDatabase) throws -> DeckImportResult {
        let bytes = try decodeBase64(deckString)

        guard bytes.count > 2 else { throw ParseError.invalidFormat }

        // 跳过保留字节
        var offset = 1

        // 读取版本号
        let version = try readVarInt(bytes, offset: &offset)

        // 读取英雄
        let heroDBFId = try readVarInt(bytes, offset: &offset)

        // 读取卡牌列表
        let cardInfos: [CardInfo]
        switch version {
        case 1:
            cardInfos = try parseV1(bytes, offset: &offset)
        case 2:
            cardInfos = try parseV2(bytes, offset: &offset)
        default:
            throw ParseError.unknownVersion(version)
        }

        // 匹配数据库中的卡牌
        let cards = resolveCards(cardInfos, database: database)

        // 推断职业
        let heroClass = inferHeroClass(from: heroDBFId)

        return DeckImportResult(
            cards: cards,
            totalCount: cardInfos.reduce(0) { $0 + $1.count },
            heroClass: heroClass,
            heroDBFId: heroDBFId
        )
    }

    // MARK: - Private Decoding

    private static func decodeBase64(_ input: String) throws -> [UInt8] {
        // 去除可能的空白字符和非 Base64 字符（如中文）
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ParseError.invalidBase64 }

        // 只保留标准 Base64 字符（A-Z, a-z, 0-9, +, /, =）
        let validChars = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        let filtered = cleaned.filter { validChars.contains($0) }
        guard !filtered.isEmpty else { throw ParseError.invalidBase64 }

        // 炉石使用标准 Base64 字母表补全后再解码
        var padded = filtered
        let remainder = filtered.count % 4
        if remainder > 0 {
            padded += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: padded) else {
            throw ParseError.invalidBase64
        }

        return Array(data)
    }

    private static func readVarInt(_ bytes: [UInt8], offset: inout Int) throws -> Int {
        var result = 0
        var shift = 0

        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1

            result |= Int(byte & 0x7F) << shift
            shift += 7

            if byte & 0x80 == 0 {
                return result
            }
        }

        throw ParseError.invalidFormat
    }

    private static func parseV1(_ bytes: [UInt8], offset: inout Int) throws -> [CardInfo] {
        var dbfIds: [Int] = []

        while offset < bytes.count {
            let id = try readVarInt(bytes, offset: &offset)
            dbfIds.append(id)
        }

        // V1 格式：相邻相同 ID 表示 2 张，单独出现表示 1 张
        var result: [CardInfo] = []
        var i = 0
        while i < dbfIds.count {
            if i + 1 < dbfIds.count && dbfIds[i] == dbfIds[i + 1] {
                result.append(CardInfo(dbfId: dbfIds[i], count: 2))
                i += 2
            } else {
                result.append(CardInfo(dbfId: dbfIds[i], count: 1))
                i += 1
            }
        }

        return result
    }

    private static func parseV2(_ bytes: [UInt8], offset: inout Int) throws -> [CardInfo] {
        var result: [CardInfo] = []

        while offset < bytes.count {
            let dbfId = try readVarInt(bytes, offset: &offset)
            let count = try readVarInt(bytes, offset: &offset)
            result.append(CardInfo(dbfId: dbfId, count: count))
        }

        return result
    }

    // MARK: - Card Resolution

    @MainActor
    private static func resolveCards(_ infos: [CardInfo], database: CardDatabase) -> [DeckCard] {
        return infos.map { info in
            if let card = database.card(for: info.dbfId) {
                return DeckCard(card: card, count: info.count)
            } else {
                // 数据库中暂无此卡，创建占位记录
                let placeholder = Card(
                    dbfId: info.dbfId,
                    name: "未知卡牌 #\(info.dbfId)",
                    cost: 0,
                    cardClass: "NEUTRAL",
                    rarity: "FREE",
                    type: "MINION",
                    set: "UNKNOWN"
                )
                return DeckCard(card: placeholder, count: info.count)
            }
        }
    }

    private static func inferHeroClass(from dbfId: Int) -> HeroClass {
        // 根据常见英雄 DBF ID 范围推断
        // 后期可通过数据库精确匹配
        switch dbfId {
        case 7:    return .warrior
        case 31:   return .hunter
        case 274:  return .shaman
        case 637:  return .druid
        case 671:  return .rogue
        case 813:  return .paladin
        case 893:  return .priest
        case 930:  return .warlock
        case 1066: return .mage
        case 56550: return .demonHunter
        case 78065: return .deathKnight
        default:   return .unknown
        }
    }
}

// MARK: - Supporting Types

struct CardInfo {
    let dbfId: Int
    let count: Int
}

struct DeckCard {
    let card: Card
    let count: Int
}

struct DeckImportResult {
    let cards: [DeckCard]
    let totalCount: Int
    let heroClass: HeroClass
    let heroDBFId: Int
}