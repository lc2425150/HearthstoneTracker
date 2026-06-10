import Cocoa

// MARK: - CardBarTheme

/// CardBar 主题样式
enum CardBarTheme: String, CaseIterable {
    case classic = "Classic"
    case frost = "Frost"
    case dark = "Dark"
    case minimal = "Minimal"
    
    var displayName: String { rawValue }
}

// MARK: - CardBarView

/// HSTracker 风格 CardBar 组件（AppKit 原生）
///
/// 单张卡牌的显示行，用于悬浮窗牌库追踪。
/// 四主题：Classic / Frost / Dark / Minimal（默认 Minimal）
final class CardBarView: NSView {
    
    // MARK: - 配置
    
    struct Configuration {
        let cardName: String
        let cost: Int
        let count: Int
        let rarityColor: NSColor
        let theme: CardBarTheme
        let isOpponent: Bool  // 对手卡牌使用不同配色
        
        init(cardName: String, cost: Int, count: Int = 1,
             rarityColor: NSColor = .gray, theme: CardBarTheme = .minimal,
             isOpponent: Bool = false) {
            self.cardName = cardName
            self.cost = cost
            self.count = count
            self.rarityColor = rarityColor
            self.theme = theme
            self.isOpponent = isOpponent
        }
    }
    
    // MARK: - 私有属性
    
    private let config: Configuration
    private let rowHeight: CGFloat = 24
    
    private lazy var costBadge: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        return view
    }()
    
    private lazy var costLabel: NSTextField = {
        let label = NSTextField(labelWithString: "\(config.cost)")
        label.font = NSFont.boldSystemFont(ofSize: 11)
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }()
    
    private lazy var nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: config.cardName)
        label.font = NSFont.systemFont(ofSize: 11)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var countLabel: NSTextField = {
        let label = NSTextField(labelWithString: config.count > 1 ? "x\(config.count)" : "")
        label.font = NSFont.boldSystemFont(ofSize: 10)
        label.alignment = .right
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }()
    
    // MARK: - 初始化
    
    init(config: Configuration) {
        self.config = config
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: rowHeight))
        setupViews()
        applyTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 视图布局
    
    private func setupViews() {
        // 费用徽章
        costBadge.frame = NSRect(x: 4, y: 4, width: 18, height: 18)
        costLabel.frame = costBadge.bounds
        costBadge.addSubview(costLabel)
        addSubview(costBadge)
        
        // 卡牌名称
        nameLabel.frame = NSRect(x: 26, y: 4, width: frame.width - 56, height: 18)
        addSubview(nameLabel)
        
        // 数量标签
        countLabel.frame = NSRect(x: frame.width - 28, y: 4, width: 24, height: 18)
        addSubview(countLabel)
    }
    
    // MARK: - 主题应用
    
    private func applyTheme() {
        switch config.theme {
        case .classic:
            applyClassicTheme()
        case .frost:
            applyFrostTheme()
        case .dark:
            applyDarkTheme()
        case .minimal:
            applyMinimalTheme()
        }
    }
    
    private func applyClassicTheme() {
        // 深色半透明底色，白色文字，彩色费用徽章
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.cornerRadius = 3
        
        costBadge.layer?.backgroundColor = costColor(for: config.cost).cgColor
        costLabel.textColor = .white
        
        nameLabel.textColor = .white
        nameLabel.font = NSFont.boldSystemFont(ofSize: 11)
        
        countLabel.textColor = config.rarityColor
        
        // 稀有度左边框
        let borderLayer = CALayer()
        borderLayer.frame = NSRect(x: 0, y: 1, width: 3, height: rowHeight - 2)
        borderLayer.backgroundColor = config.rarityColor.cgColor
        borderLayer.cornerRadius = 1
        layer?.addSublayer(borderLayer)
    }
    
    private func applyFrostTheme() {
        // 冰蓝透明底色，蓝色调
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.4, alpha: 0.4).cgColor
        layer?.cornerRadius = 3
        
        costBadge.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.9, alpha: 0.8).cgColor
        costLabel.textColor = .white
        
        nameLabel.textColor = NSColor(calibratedRed: 0.7, green: 0.85, blue: 1.0, alpha: 1.0)
        
        countLabel.textColor = config.rarityColor
    }
    
    private func applyDarkTheme() {
        // 纯黑不透明白字
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        layer?.cornerRadius = 3
        
        costBadge.layer?.backgroundColor = costColor(for: config.cost).cgColor
        costLabel.textColor = .white
        
        nameLabel.textColor = .white
        
        countLabel.textColor = config.rarityColor
    }
    
    private func applyMinimalTheme() {
        // 极简：几乎透明，只显示关键信息
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        costBadge.layer?.backgroundColor = costColor(for: config.cost).withAlphaComponent(0.7).cgColor
        costLabel.textColor = .white
        
        nameLabel.textColor = config.isOpponent
            ? NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.5, alpha: 0.9)
            : NSColor.white.withAlphaComponent(0.9)
        nameLabel.font = NSFont.systemFont(ofSize: 10)
        
        countLabel.textColor = config.rarityColor.withAlphaComponent(0.7)
    }
    
    // MARK: - Helpers
    
    /// 根据费用返回对应颜色
    private func costColor(for cost: Int) -> NSColor {
        switch cost {
        case 0:     return .gray
        case 1:     return NSColor(calibratedRed: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        case 2...3: return NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        case 4...6: return NSColor(calibratedRed: 0.6, green: 0.2, blue: 0.6, alpha: 1.0)
        case 7...9: return NSColor(calibratedRed: 0.8, green: 0.5, blue: 0.1, alpha: 1.0)
        default:    return NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        }
    }
    
    // MARK: - 尺寸
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: rowHeight)
    }
    
    /// 更新卡牌数量（用于抽牌/出牌后刷新）
    func updateCount(_ newCount: Int) {
        countLabel.stringValue = newCount > 1 ? "x\(newCount)" : ""
    }
}

// MARK: - CardBarListContainer

/// CardBar 列表容器：垂直排列多张卡牌
final class CardBarListView: NSView {
    
    private var cardBars: [CardBarView] = []
    private let cardSpacing: CGFloat = 1
    
    /// 设置卡牌列表
    func setCards(_ configs: [CardBarView.Configuration]) {
        // 移除旧视图
        cardBars.forEach { $0.removeFromSuperview() }
        cardBars.removeAll()
        
        var yOffset: CGFloat = 0
        
        for config in configs {
            let bar = CardBarView(config: config)
            bar.frame = NSRect(
                x: 0,
                y: yOffset,
                width: frame.width,
                height: bar.intrinsicContentSize.height
            )
            bar.autoresizingMask = [.width]
            addSubview(bar)
            cardBars.append(bar)
            
            yOffset += bar.frame.height + cardSpacing
        }
        
        let totalHeight = max(yOffset - cardSpacing, 0)
        frame.size.height = totalHeight
        invalidateIntrinsicContentSize()
    }
    
    /// 刷新指定卡牌的数量
    func updateCardCount(cardName: String, count: Int) {
        for bar in cardBars {
            // 通过 subviews 查找对应卡牌
            for subview in bar.subviews {
                if let label = subview as? NSTextField,
                   label.stringValue == cardName {
                    bar.updateCount(count)
                    return
                }
            }
        }
    }
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: frame.height)
    }
}
