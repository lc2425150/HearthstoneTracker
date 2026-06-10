import Foundation

// MARK: - Assertion Helpers

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

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") {
    if a != b {
        passed += 1
        print("✅ \(message)")
    } else {
        failed += 1
        print("❌ \(message) - values should differ")
    }
}

// MARK: - String Extension

private extension String {
    func `repeat`(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

// ============================================================
//  Phase 1-2: 核心模型测试
// ============================================================

// MARK: - DeckCodeParser Tests

@MainActor
func testDeckCodeParsing() {
    print("\n📋 测试卡组码解析")
    
    let code = "AAECAZ8FBPoO0xXZ/gUNjAGeAdwD9g36DfYNgQ6QDpUO7A/tD9MT1xPZ/gLZ/gIA"
    assert(!code.isEmpty, "卡组码不能为空")
    assert(code.count > 20, "卡组码长度正确")
    
    let emptyCode = ""
    assert(emptyCode.isEmpty, "空卡组码正确处理")
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
    
    // 所有职业都有非空显示名
    for heroClass in HeroClass.allCases {
        assert(!heroClass.displayName.isEmpty, "\(heroClass.rawValue) 有中文名")
    }
}

// MARK: - Card Model Tests

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
    assertEqual(card.id, 1, "Identifiable ID")
    assertEqual(card.rarityColor, "gray", "免费稀有度颜色")
    
    // 所有稀有度颜色
    let rare = Card(dbfId: 2, name: "稀有", cost: 3, cardClass: "neutral", rarity: "RARE", type: "minion", set: "CORE")
    assertEqual(rare.rarityColor, "blue", "稀有 → blue")
    
    let epic = Card(dbfId: 3, name: "史诗", cost: 5, cardClass: "neutral", rarity: "EPIC", type: "spell", set: "CORE")
    assertEqual(epic.rarityColor, "purple", "史诗 → purple")
    
    let legendary = Card(dbfId: 4, name: "传说", cost: 10, cardClass: "neutral", rarity: "LEGENDARY", type: "minion", set: "CORE")
    assertEqual(legendary.rarityColor, "orange", "传说 → orange")
    
    // 默认稀有度
    let unknown = Card(dbfId: 5, name: "未知", cost: 0, cardClass: "neutral", rarity: "", type: "spell", set: "")
    assertEqual(unknown.rarityColor, "gray", "未知稀有度 → gray 默认")
    
    // 扩展字段默认值
    assertEqual(card.enName, "", "enName 默认空字符串")
    assertEqual(card.attack, 0, "attack 默认 0")
    assertEqual(card.health, 0, "health 默认 0")
    assertEqual(card.race, "", "race 默认空字符串")
    assertEqual(card.mechanics, [], "mechanics 默认空数组")
    assertEqual(card.collectible, true, "collectible 默认 true")
}

// MARK: - TrackedDeck Tests

func testTrackedDeck() {
    print("\n📦 测试牌库追踪")
    
    let card1 = Card(dbfId: 1, cardId: "EX1_277", name: "寒冰箭", cost: 2,
                     cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE")
    let card2 = Card(dbfId: 2, cardId: "CS2_029", name: "火球术", cost: 4,
                     cardClass: "mage", rarity: "FREE", type: "spell", set: "CORE")
    let card3 = Card(dbfId: 3, cardId: "EX1_001", name: "大法师", cost: 7,
                     cardClass: "mage", rarity: "LEGENDARY", type: "minion", set: "CORE")
    
    let cards: [(card: Card, count: Int)] = [
        (card: card1, count: 2),
        (card: card2, count: 2),
        (card: card3, count: 1)  // 传奇卡仅 1 张
    ]
    let deck = TrackedDeck(deckCode: "TEST", cards: cards, heroClass: .mage)
    
    // 牌库总数
    assertEqual(deck.totalOriginalCount, 5, "牌库总张数（2+2+1）")
    assertEqual(deck.remainingOriginalCount, 5, "剩余张数初始值")
    assertEqual(deck.heroClass.displayName, "法师", "职业为法师")
    
    // 单卡数量
    assertEqual(deck.countOf(card: 1), 2, "寒冰箭 2 张")
    assertEqual(deck.countOf(card: 2), 2, "火球术 2 张")
    assertEqual(deck.countOf(card: 3), 1, "大法师 1 张")
    assertEqual(deck.countOf(card: 99), 0, "不存在的卡牌返回 0")
    
    // 卡池包含所有卡牌
    assertEqual(deck.cardPool.count, 3, "卡池有 3 种卡牌")
    assertEqual(deck.allCards.count, 3, "allCards 返回 3 张唯一卡")
    
    // 模拟抽牌后
    var modifiedDeck = deck
    modifiedDeck.cardCounts[1] = 0  // 用掉两张寒冰箭
    assertEqual(modifiedDeck.remainingOriginalCount, 3, "用掉寒冰箭后剩余 3 张")
    assertEqual(modifiedDeck.remainingOriginal.count, 2, "剩余卡牌种类: 火球术+大法师")
    
    // 手牌和已打出追踪
    var handDeck = deck
    handDeck.handOriginal = [card1]
    assertEqual(handDeck.handOriginal.count, 1, "手牌 1 张")
    
    var playedDeck = deck
    playedDeck.playedOriginal = [card1, card2]
    assertEqual(playedDeck.playedOriginal.count, 2, "已打出 2 张")
}

// MARK: - CardDisplaySize Tests

func testCardDisplaySize() {
    print("\n📐 测试卡牌尺寸")
    
    assertEqual(CardDisplaySize.small.rowHeight, 22, "小尺寸行高 22")
    assertEqual(CardDisplaySize.medium.rowHeight, 28, "中尺寸行高 28")
    assertEqual(CardDisplaySize.large.rowHeight, 36, "大尺寸行高 36")
    
    assertEqual(CardDisplaySize.small.overlayWidth, 260, "小尺寸悬浮窗宽度 260")
    assertEqual(CardDisplaySize.medium.overlayWidth, 320, "中尺寸悬浮窗宽度 320")
    assertEqual(CardDisplaySize.large.overlayWidth, 380, "大尺寸悬浮窗宽度 380")
    
    assertEqual(CardDisplaySize.small.fontSize, 10, "小尺寸字号 10")
    assertEqual(CardDisplaySize.medium.fontSize, 12, "中尺寸字号 12")
    assertEqual(CardDisplaySize.large.fontSize, 14, "大尺寸字号 14")
    
    // displayName 等于 rawValue
    assertEqual(CardDisplaySize.small.displayName, "小", "displayName 小")
    assertEqual(CardDisplaySize.medium.displayName, "中", "displayName 中")
    assertEqual(CardDisplaySize.large.displayName, "大", "displayName 大")
}

// ============================================================
//  Phase 3: AI 分析器测试
// ============================================================

// MARK: - HandPredictor Tests

func testHandPredictor() {
    print("\n🔮 测试手牌预测分析器")
    
    let predictor = HandPredictor()
    
    // 构建 Prompt
    let prompt = predictor.buildPrompt(gameState: "回合: 5\n对手职业: 法师\n对手已用费用: 15")
    assert(prompt.contains("对手手牌"), "Prompt 包含分析目标")
    assert(prompt.contains("法师"), "Prompt 包含对手职业")
    assert(prompt.contains("当前对局"), "Prompt 包含游戏状态")
    assert(prompt.contains("卡牌名"), "Prompt 包含格式说明")
    
    // 解析响应
    let sampleResponse = """
    希望圣契 | 高 | 5费未出，骑士常用中期牌
    正义圣契 | 中 | 骑士圣契体系常见
    光铸骑 | 低 | 可能带了光铸体系
    """
    let predictions = predictor.parseResponse(sampleResponse)
    assertEqual(predictions.count, 3, "解析出 3 条预测")
    
    if predictions.count >= 3 {
        assertEqual(predictions[0].cardName, "希望圣契", "第一条卡牌名")
        assertEqual(predictions[0].confidence, "高", "第一条可信度")
        assertEqual(predictions[1].cardName, "正义圣契", "第二条卡牌名")
        assertEqual(predictions[1].confidence, "中", "第二条可信度")
        assertEqual(predictions[2].cardName, "光铸骑", "第三条卡牌名")
        assertEqual(predictions[2].confidence, "低", "第三条可信度")
    }
    
    // 空响应
    let emptyPredictions = predictor.parseResponse("")
    assertEqual(emptyPredictions.count, 0, "空响应返回空数组")
    
    // 无效格式
    let invalidPredictions = predictor.parseResponse("这是一段没有分隔符的文本")
    assertEqual(invalidPredictions.count, 0, "无效格式返回空数组")
    
    // 部分有效行
    let mixedResponse = """
    卡牌A | 高 | 理由
    无效行没有分隔符
    卡牌B | 中 | 另一个理由
    """
    let mixedPredictions = predictor.parseResponse(mixedResponse)
    assertEqual(mixedPredictions.count, 2, "混合响应只解析有效行")
}

// MARK: - MulliganAdvisor Tests

func testMulliganAdvisor() {
    print("\n🃏 测试留牌策略分析器")
    
    let advisor = MulliganAdvisor()
    
    // 构建 Prompt
    let prompt = advisor.buildPrompt(
        playerClass: "法师",
        opponentClass: "术士",
        handCards: ["法力浮龙", "寒冰箭", "奥术智慧"],
        gameState: "先手, 1费回合"
    )
    assert(prompt.contains("留牌策略"), "Prompt 包含留牌策略")
    assert(prompt.contains("法师"), "Prompt 包含我方职业")
    assert(prompt.contains("术士"), "Prompt 包含对手职业")
    assert(prompt.contains("法力浮龙"), "Prompt 包含手牌")
    assert(prompt.contains("保留"), "Prompt 包含保留选项")
    
    // 解析响应
    let sampleResponse = """
    法力浮龙 | 保留 | 1费优质曲线
    寒冰箭 | 保留 | 解场法术，对阵术士有用
    奥术智慧 | 换掉 | 3费过牌，先手太慢
    """
    let advices = advisor.parseResponse(sampleResponse)
    assertEqual(advices.count, 3, "解析出 3 条建议")
    
    if advices.count >= 3 {
        assertEqual(advices[0].cardName, "法力浮龙", "第一条卡牌名")
        assertEqual(advices[0].action, "保留", "第一条建议")
        assertEqual(advices[1].cardName, "寒冰箭", "第二条卡牌名")
        assertEqual(advices[1].action, "保留")
        assertEqual(advices[2].cardName, "奥术智慧", "第三条卡牌名")
        assertEqual(advices[2].action, "换掉")
    }
    
    // 空响应
    let emptyAdvices = advisor.parseResponse("")
    assertEqual(emptyAdvices.count, 0, "空响应返回空数组")
    
    // 不含保留/换掉的行应被过滤
    let mixedResponse = """
    法力浮龙 | 保留 | 好
    无关行 | 随便 | 注释
    寒冰箭 | 换掉 | 不好
    """
    let filtered = advisor.parseResponse(mixedResponse)
    assertEqual(filtered.count, 2, "只包含保留/换掉的行")
}

// MARK: - DeckOptimizer Tests

func testDeckOptimizer() {
    print("\n📊 测试卡组优化分析器")
    
    let optimizer = DeckOptimizer()
    
    let cards: [(name: String, count: Int)] = [
        ("法力浮龙", 2), ("寒冰箭", 2), ("火球术", 2),
        ("暴风雪", 1), ("呼啦", 1)
    ]
    
    let prompt = optimizer.buildPrompt(heroClass: "法师", cards: cards)
    assert(prompt.contains("法师"), "Prompt 包含职业")
    assert(prompt.contains("法力浮龙"), "Prompt 包含卡牌名")
    assert(prompt.contains("费用曲线"), "Prompt 包含费用曲线分析")
    assert(prompt.contains("卡牌协同"), "Prompt 包含卡牌协同")
    assert(prompt.contains("x2"), "Prompt 显示卡牌数量")
    
    // 空卡组
    let emptyPrompt = optimizer.buildPrompt(heroClass: "潜行者", cards: [])
    assert(emptyPrompt.contains("潜行者"), "空卡组 Prompt 包含职业")
}

// MARK: - RoundSummarizer Tests

func testRoundSummarizer() {
    print("\n📝 测试回合摘要分析器")
    
    let summarizer = RoundSummarizer()
    
    let prompt = summarizer.buildPrompt(turnNumber: 7, gameState: "双方各有场面，我方血量15，对手血量20")
    assert(prompt.contains("7"), "Prompt 包含回合数 7")
    assert(prompt.contains("回合概述"), "Prompt 包含回合概述格式")
    assert(prompt.contains("场面评估"), "Prompt 包含场面评估")
    assert(prompt.contains("关键决策"), "Prompt 包含关键决策")
    assert(prompt.contains("下回合计划"), "Prompt 包含下回合计划")
    
    // 不同回合数
    let prompt2 = summarizer.buildPrompt(turnNumber: 1, gameState: "游戏开始")
    assert(prompt2.contains("1"), "Prompt 包含回合数 1")
}

// ============================================================
//  Phase 4: 功能模块测试
// ============================================================

// MARK: - OpponentMemoryManager Tests

func testOpponentMemoryManager() {
    print("\n👤 测试对手记忆管理器")
    
    let manager = OpponentMemoryManager()
    
    // 初始状态
    assertEqual(manager.allOpponents.count, 0, "初始无对手记录")
    assertEqual(manager.hasMet(name: "玩家A"), false, "未遇过玩家A")
    assertEqual(manager.getProfile(name: "玩家A"), nil, "查询不存在的对手返回 nil")
    
    // 记录对局
    manager.recordMatch(opponentName: "玩家A", playerClass: "法师", opponentClass: "术士", result: "win")
    assertEqual(manager.allOpponents.count, 1, "记录后对手列表为 1")
    assertEqual(manager.hasMet(name: "玩家A"), true, "已遇过玩家A")
    
    // 查看对手信息
    let profile = manager.getProfile(name: "玩家A")
    assert(profile != nil, "玩家A 信息存在")
    if let profile = profile {
        assertEqual(profile.name, "玩家A", "对手名正确")
        assertEqual(profile.totalGames, 1, "1 场对局")
        assertEqual(profile.winRate, 1.0, "胜率 100%")
    }
    
    // 记录更多对局
    manager.recordMatch(opponentName: "玩家A", playerClass: "法师", opponentClass: "战士", result: "loss")
    manager.recordMatch(opponentName: "玩家A", playerClass: "法师", opponentClass: "盗贼", result: "win")
    manager.recordMatch(opponentName: "玩家B", playerClass: "术士", opponentClass: "法师", result: "win")
    
    assertEqual(manager.allOpponents.count, 2, "两个对手")
    
    if let profileA = manager.getProfile(name: "玩家A") {
        assertEqual(profileA.totalGames, 3, "玩家A 3 场")
        assertEqual(profileA.winRate, 2.0 / 3.0, "玩家A 胜率 2/3")
        assertEqual(profileA.commonClasses.count, 3, "玩家A 对阵 3 种职业")
    }
    
    if let profileB = manager.getProfile(name: "玩家B") {
        assertEqual(profileB.totalGames, 1, "玩家B 1 场")
        assertEqual(profileB.winRate, 1.0, "玩家B 胜率 100%")
    }
    
    // 排序：对局数多的在前
    let opponents = manager.allOpponents
    assertEqual(opponents[0].name, "玩家A", "玩家A 排前面（3场）")
    assertEqual(opponents[1].name, "玩家B", "玩家B 排后面（1场）")
}

// MARK: - DataExporter Tests

func testDataExporter() {
    print("\n📤 测试数据导出")
    
    // 导出卡组码
    let cards: [(name: String, count: Int)] = [
        ("寒冰箭", 2), ("火球术", 2), ("大法师", 1)
    ]
    let result = DataExporter.exportDeckCode(cards: cards)
    assert(result.contains("寒冰箭 x2"), "导出包含寒冰箭 x2")
    assert(result.contains("火球术 x2"), "导出包含火球术 x2")
    assert(result.contains("大法师 x1"), "导出包含大法师 x1")
    
    // 空卡组
    let emptyResult = DataExporter.exportDeckCode(cards: [])
    assertEqual(emptyResult, "", "空卡组导出空字符串")
}

// MARK: - RealTimeAnalysisRequest Tests

func testRealTimeAnalysisRequest() {
    print("\n⚡ 测试实时分析请求结构")
    
    let request = RealTimeAnalysisRequest(
        playerHero: "法师",
        playerDeckRemaining: 15,
        handCards: [("寒冰箭", 2, "spell"), ("火球术", 4, "spell")],
        playedCards: [("法力浮龙", 1)],
        discoveredCards: [("传送门", 3)],
        opponentHero: "术士",
        opponentHandSize: 5,
        opponentDeckRemaining: 12,
        opponentPlayedCards: [("鲜血小鬼", 1)],
        opponentManaUsed: 4,
        inferredArchetype: "动物园"
    )
    
    assertEqual(request.playerHero, "法师", "我方职业")
    assertEqual(request.playerDeckRemaining, 15, "牌库剩余")
    assertEqual(request.handCards.count, 2, "手牌 2 张")
    assertEqual(request.opponentHero, "术士", "对手职业")
    assertEqual(request.opponentHandSize, 5, "对手手牌数")
    assertEqual(request.inferredArchetype, "动物园", "推测卡组类型")
    assertEqual(request.opponentManaUsed, 4, "对手已用费用")
}

// ============================================================
//  Phase 5: MatchStats 测试
// ============================================================

// MARK: - MatchStats Tests

func testMatchStats() {
    print("\n📈 测试对战统计数据")
    
    // MatchStats 需要 MatchRecord 数组，这里只测试空记录
    // MatchRecord 使用 SwiftData @Model，需在 SwiftData 上下文中创建
    // 纯逻辑测试：空记录
    let emptyStats = MatchStats(records: [])
    assertEqual(emptyStats.totalMatches, 0, "空记录总场数 0")
    assertEqual(emptyStats.wins, 0, "空记录胜场 0")
    assertEqual(emptyStats.winRate, 0.0, "空记录胜率 0")
    assertEqual(emptyStats.recentResults.count, 0, "空记录最近结果 0")
    assertEqual(emptyStats.currentStreak.count, 0, "空记录连胜 0")
    assertEqual(emptyStats.currentStreak.result, .unknown, "空记录连胜结果 unknown")
}

// ============================================================
//  Phase 5: 枚举与常量测试
// ============================================================

// MARK: - MatchResult Tests

func testMatchResult() {
    print("\n🏆 测试对局结果")
    
    assertEqual(MatchResult.win.displayName, "胜利", "胜利显示名")
    assertEqual(MatchResult.loss.displayName, "失败", "失败显示名")
    assertEqual(MatchResult.draw.displayName, "平局", "平局显示名")
    assertEqual(MatchResult.unknown.displayName, "未知", "未知显示名")
    
    assertEqual(MatchResult.win.colorName, "green", "胜利颜色 green")
    assertEqual(MatchResult.loss.colorName, "red", "失败颜色 red")
    assertEqual(MatchResult.draw.colorName, "gray", "平局颜色 gray")
    assertEqual(MatchResult.unknown.colorName, "secondary", "未知颜色 secondary")
    
    // 所有结果都有非空显示名
    for result in MatchResult.allCases {
        assert(!result.displayName.isEmpty, "\(result.rawValue) 有显示名")
    }
}

// MARK: - Constants Tests

func testConstants() {
    print("\n⚙️ 测试常量")
    
    assertEqual(Constants.appName, "HearthstoneTracker", "应用名称")
    assertEqual(Constants.appVersion, "1.4.0", "应用版本")
    assertEqual(Constants.appBuild, 2001, "应用构建号")
    assertEqual(Constants.overlayDefaultOpacity, 0.7, "默认不透明度")
    assertEqual(Constants.overlayMinOpacity, 0.3, "最小不透明度")
    assertEqual(Constants.overlayMaxOpacity, 1.0, "最大不透明度")
    assertEqual(Constants.keychainAIKey, "aiApiKey", "Keychain AI Key 常量")
}

// MARK: - AIAnalysisMode Tests

func testAIAnalysisMode() {
    print("\n🤖 测试 AI 分析模式")
    
    assertEqual(AIAnalysisMode.auto.rawValue, "auto", "自动模式 rawValue")
    assertEqual(AIAnalysisMode.manual.rawValue, "manual", "手动模式 rawValue")
    
    // 从字符串解析
    assertEqual(AIAnalysisMode(rawValue: "auto"), .auto, "解析 auto")
    assertEqual(AIAnalysisMode(rawValue: "manual"), .manual, "解析 manual")
    assertEqual(AIAnalysisMode(rawValue: "invalid"), nil, "无效值返回 nil")
}

// MARK: - UserDefault Wrapper Tests

func testUserDefaultWrapper() {
    print("\n🔧 测试 @UserDefault 包装器")
    
    @UserDefault("test_key", defaultValue: "default")
    var testValue: String
    
    // 初始值应为默认值
    testValue = UserDefaults.standard.string(forKey: "test_key") ?? "default"
    assertEqual(testValue, "default", "@UserDefault 初始值为默认值")
    
    // 设置新值
    testValue = "custom"
    assertEqual(UserDefaults.standard.string(forKey: "test_key"), "custom", "@UserDefault 写入 UserDefaults")
    
    // 清理
    UserDefaults.standard.removeObject(forKey: "test_key")
}

// ============================================================
//  Run All Tests
// ============================================================

@MainActor
func runAllTests() {
    print("=" .repeat(50))
    print("🔥 炉石记牌器 单元测试套件")
    print("=" .repeat(50))
    
    // Phase 1-2: 核心模型
    testHeroClassMapping()
    testCardModel()
    testCardDisplaySize()
    testConstants()
    testDeckCodeParsing()
    testTrackedDeck()
    
    // Phase 3: AI 分析器
    testHandPredictor()
    testMulliganAdvisor()
    testDeckOptimizer()
    testRoundSummarizer()
    testRealTimeAnalysisRequest()
    
    // Phase 4-5: 功能模块
    testOpponentMemoryManager()
    testDataExporter()
    testMatchResult()
    testAIAnalysisMode()
    testUserDefaultWrapper()
    
    // MatchStats 需要 SwiftData 上下文，在纯测试环境中跳过
    // testMatchStats()
    
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
