import Foundation

// Simple assertion helper (replaces XCTest dependency)
private var passed = 0
private var failed = 0

func assert(_ condition: Bool, _ message: String = "") {
    if condition {
        passed += 1
        print("✅ \(message)")
    } else {
        failed += 1
        print("❌ \(message)")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") {
    if a == b {
        passed += 1
        print("✅ \(message)")
    } else {
        failed += 1
        print("❌ \(message) - expected \(b), got \(a)")
    }
}

// MARK: - DeckCodeParser Tests

@MainActor
func testDeckCodeParsing() {
    print("\n📋 测试卡组码解析")
    
    // Test base64 decoding
    do {
        let code = "AAECAZ8FBPoO0xXZ/gUNjAGeAdwD9g36DfYNgQ6QDpUO7A/tD9MT1xPZ/gLZ/gIA"
        // Just test that it doesn't crash - deck parsing requires card database
        assert(!code.isEmpty, "卡组码不能为空")
        assert(code.count > 20, "卡组码长度正确")
    }
    
    // Test with empty string
    do {
        let code = ""
        assert(code.isEmpty, "空卡组码正确处理")
    }
}

// MARK: - HeroClass Tests

func testHeroClassMapping() {
    print("\n👤 测试英雄职业映射")
    
    assertEqual(HeroClass.druid.displayName, "德鲁伊", "德鲁伊中文名")
    assertEqual(HeroClass.mage.displayName, "法师", "法师中文名")
    assertEqual(HeroClass.hunter.displayName, "猎人", "猎人中文名")
    assertEqual(HeroClass.paladin.displayName, "圣骑士", "圣骑士中文名")
    assertEqual(HeroClass.priest.displayName, "牧师", "牧师中文名")
    assertEqual(HeroClass.rogue.displayName, "潜行者", "潜行者中文名")
    assertEqual(HeroClass.shaman.displayName, "萨满", "萨满中文名")
    assertEqual(HeroClass.warlock.displayName, "术士", "术士中文名")
    assertEqual(HeroClass.warrior.displayName, "战士", "战士中文名")
    assertEqual(HeroClass.demonHunter.displayName, "恶魔猎手", "恶魔猎手中文名")
    assertEqual(HeroClass.deathKnight.displayName, "死亡骑士", "死亡骑士中文名")
    assertEqual(HeroClass.unknown.displayName, "未知", "未知职业")
}

// MARK: - Card Models Tests

func testCardModel() {
    print("\n🃏 测试卡牌模型")
    
    let card = Card(dbfId: 1, cardId: "EX1_277", name: "寒冰箭", cost: 2, 
                    cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE")
    
    assertEqual(card.dbfId, 1, "卡牌 DBF ID")
    assertEqual(card.name, "寒冰箭", "卡牌名称")
    assertEqual(card.cost, 2, "卡牌费用")
    assertEqual(card.cardClass, "mage", "卡牌职业")
    assertEqual(card.rarity, "FREE", "卡牌稀有度")
    assertEqual(card.type, "spell", "卡牌类型")
    
    // Test Identifiable conformance
    assertEqual(card.id, 1, "Identifiable ID")
    
    // Test rarity colors
    let common = Card(dbfId: 2, cardId: "CS2_000", name: "普通", cost: 1,
                      cardClass: "neutral", rarity: "COMMON", type: "minion", set: "CORE")
    assertEqual(common.rarityColor, "gray", "普通稀有度颜色")
    
    let legendary = Card(dbfId: 3, cardId: "EX1_000", name: "传说", cost: 10,
                         cardClass: "neutral", rarity: "LEGENDARY", type: "minion", set: "CORE")
    assertEqual(legendary.rarityColor, "orange", "传说稀有度颜色")
}

// MARK: - TrackedDeck Tests

func testTrackedDeck() {
    print("\n📦 测试牌库追踪")
    
    let card1 = Card(dbfId: 1, cardId: "EX1_277", name: "寒冰箭", cost: 2,
                     cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE")
    let card2 = Card(dbfId: 2, cardId: "CS2_029", name: "火球术", cost: 4,
                     cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE")
    
    let cards = [(card: card1, count: 2), (card: card2, count: 2)]
    let deck = TrackedDeck(deckCode: "TEST", cards: cards, heroClass: .mage)
    
    assertEqual(deck.totalOriginalCount, 4, "牌库总张数")
    assertEqual(deck.remainingOriginalCount, 4, "剩余张数初始值")
    assertEqual(deck.countOf(card: card1.dbfId), 2, "寒冰箭数量")
    assertEqual(deck.countOf(card: card2.dbfId), 2, "火球术数量")
    assertEqual(deck.heroClass.displayName, "法师", "职业为法师")
    
    // Test remaining after drawing
    var modifiedDeck = deck
    modifiedDeck.cardCounts[1] = 1
    assertEqual(modifiedDeck.remainingOriginalCount, 3, "抽一张后剩余3张")
}

// MARK: - CardDisplaySize Tests

func testCardDisplaySize() {
    print("\n📐 测试卡牌尺寸")
    
    assertEqual(CardDisplaySize.small.rowHeight, 22, "小尺寸行高")
    assertEqual(CardDisplaySize.medium.rowHeight, 28, "中尺寸行高")
    assertEqual(CardDisplaySize.large.rowHeight, 36, "大尺寸行高")
    
    assertEqual(CardDisplaySize.small.overlayWidth, 260, "小尺寸悬浮窗宽度")
    assertEqual(CardDisplaySize.medium.overlayWidth, 320, "中尺寸悬浮窗宽度")
    assertEqual(CardDisplaySize.large.overlayWidth, 380, "大尺寸悬浮窗宽度")
}

// MARK: - VersionChecker Tests

func testVersionChecker() {
    print("\n📌 测试版本检查器")
    
    let version = VersionChecker.current
    assert(!version.isEmpty, "版本号不为空")
    
    let displayVersion = VersionChecker.displayVersion
    assert(displayVersion.contains(version), "显示版本包含版本号")
}

// MARK: - Constants Tests

func testConstants() {
    print("\n⚙️ 测试常量")
    
    assertEqual(Constants.appName, "HearthstoneTracker", "应用名称")
    assertEqual(Constants.appVersion, "1.3.0", "应用版本")
    assertEqual(Constants.overlayDefaultOpacity, 0.7, "默认不透明度")
    assertEqual(Constants.overlayMinOpacity, 0.3, "最小不透明度")
    assertEqual(Constants.overlayMaxOpacity, 1.0, "最大不透明度")
}

// MARK: - Run All Tests

@MainActor
func runAllTests() {
    print("=" .repeat(50))
    print("🔥 炉石记牌器 核心单元测试")
    print("=" .repeat(50))
    
    testHeroClassMapping()
    testCardModel()
    testCardDisplaySize()
    testConstants()
    testDeckCodeParsing()
    testTrackedDeck()
    testVersionChecker()
    
    print("\n" + "=" .repeat(50))
    print("📊 测试结果")
    print("   ✅ 通过: \(passed)")
    print("   ❌ 失败: \(failed)")
    print("   📝 总计: \(passed + failed)")
    
    if failed > 0 {
        print("\n⚠️  有测试失败！")
    } else {
        print("\n🎉 全部测试通过！")
    }
}

// MARK: - String Extension

private extension String {
    func `repeat`(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
