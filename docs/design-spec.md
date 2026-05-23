# Hearthstone Deck Tracker for macOS - Design Specification

## Overview
A macOS deck tracker for Hearthstone that overlays on top of the game window, tracking both player and opponent cards, with special handling for discovered/randomly generated cards.

## Core Features

### 1. Deck Code Import & Initialization
- Parse Hearthstone deck codes (Base64 encoded)
- Dynamically detect deck size (30 or 40 cards) from the code
- Match DBF IDs against local card database
- Initialize player's deck with exact card list

### 2. Real-time Card Tracking
**Primary source:** Hearthstone `Power.log` file
- Monitor log file changes in real-time
- Parse events: `DRAW`, `PLAY`, `DISCARD`, `DESTROY`, `DISCOVER`, `CREATE_GAME`
- Track both player and opponent actions

**Secondary source:** OCR via Vision Framework
- Screenshot capture when log parsing fails
- Recognize card names and costs from game screen
- Confidence-based fallback mechanism

### 3. Discovered/Random Card Tracking
- Separate tracking for cards not in original deck
- **Discovered cards:** Track discovery pool and selected option
- **Randomly generated cards:** Track source card and generated result
- Visual distinction in UI (different background/icon)

### 4. Deck State Management
**Player Deck:**
- Original deck cards (from deck code)
- Discovered/generated cards (separate tracking)
- Remaining cards in deck
- Cards in hand/played/destroyed
- Draw probability calculator

**Opponent Deck:**
- Inferred deck based on class and meta data
- Tracked played cards
- Threat assessment (possible AOE, key cards, secrets)
- Secret type deduction

### 5. UI Modes
**Overlay Mode (Default):**
- Transparent `NSWindow` with `.floating` level
- Mouse events ignored (`ignoresMouseEvents = true`)
- Minimal display: remaining cards, key probabilities
- Always on top of game window

**Window Mode:**
- Full-featured standalone window
- Detailed statistics, match history, card library
- Toggle between modes via hotkey or double-click

## Architecture

### Component Diagram
```
┌─────────────────────────────────────────────────────┐
│                    macOS Application                 │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │               Card Tracking Core             │   │
│  │  ┌─────────┐ ┌─────────┐ ┌──────────────┐  │   │
│  │  │ Log     │ │ OCR     │ │ Deck Code    │  │   │
│  │  │ Parser  │ │ Engine  │ │ Parser       │  │   │
│  │  └────┬────┘ └────┬────┘ └──────┬───────┘  │   │
│  │       │           │              │          │   │
│  │       ▼           ▼              ▼          │   │
│  │  ┌─────────────────────────────────────┐   │   │
│  │  │         Unified Card Events         │   │   │
│  │  │ • Type (draw/play/discover/etc.)    │   │   │
│  │  │ • Card ID/name/cost                 │   │   │
│  │  │ • Player/Opponent                   │   │   │
│  │  │ • Timestamp + confidence            │   │   │
│  │  └─────────────────┬───────────────────┘   │   │
│  │                    │                        │   │
│  │  ┌─────────────────┼────────────────────┐  │   │
│  │  │      Deck State Manager              │  │   │
│  │  │  ┌─────────────┐ ┌──────────────┐   │  │   │
│  │  │  │ Player Deck │ │ Opponent Deck│   │  │   │
│  │  │  │ • Original  │ │ • Inferred   │   │  │   │
│  │  │  │ • Discovered│ │ • Played     │   │  │   │
│  │  │  │ • Remaining │ │ • Threats    │   │  │   │
│  │  │  └─────────────┘ └──────────────┘   │  │   │
│  │  └─────────────────┬────────────────────┘  │   │
│  │                    │                        │   │
│  │  ┌─────────────────┼────────────────────┐  │   │
│  │  │      Probability Calculator           │  │   │
│  │  │ • Next draw chances                  │  │   │
│  │  │ • Key card probabilities             │  │   │
│  │  │ • Threat assessment                  │  │   │
│  │  └─────────────────┬────────────────────┘  │   │
│  └────────────────────┼────────────────────────┘   │
│                       │                             │
│  ┌────────────────────┼─────────────────────┐      │
│  │        UI Layer                          │      │
│  │  ┌──────────────┐ ┌──────────────────┐  │      │
│  │  │ Overlay View │ │ Window View      │  │      │
│  │  │ • Minimal    │ │ • Full stats     │  │      │
│  │  │ • Transparent│ │ • Match history  │  │      │
│  │  │ • Always top │ │ • Card library   │  │      │
│  │  └──────────────┘ └──────────────────┘  │      │
│  └─────────────────────────────────────────┘      │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │          Data Management                    │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────────┐   │   │
│  │  │ Local   │ │ Network │ │ CloudKit    │   │   │
│  │  │ Storage │ │ Updates │ │ (Future)    │   │   │
│  │  └─────────┘ └─────────┘ └─────────────┘   │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Data Flow
1. **Deck Initialization:** Deck code → Parse → Match cards → Initialize player deck
2. **Game Start:** Detect new game → Reset tracking → Start monitoring
3. **Real-time Tracking:** Log events → Parse → Update deck state → UI refresh
4. **Fallback:** Log missing → OCR capture → Recognize → Update with confidence
5. **UI Update:** Deck state changes → Calculate probabilities → Update overlay/window

## Technical Implementation

### 1. Log Parser
- **File:** `~/Library/Logs/Unity/Player.log` (or `Power.log` in game directory)
- **Monitoring:** `DispatchSourceFileSystemObject` for real-time changes
- **Key patterns:**
  - `GameState.DebugPrintPower()` for card events
  - `DISCOVER` events with options
  - `CREATE_GAME` for random generation
  - Entity IDs and card DBF IDs

### 2. OCR Engine
- **Framework:** Apple Vision Framework (`VNRecognizeTextRequest`)
- **Capture:** `CGWindowListCreateImage` for screen capture
- **Region detection:** Game window detection via `CGWindowListCopyWindowInfo`
- **Optimization:** Capture only card name/region areas

### 3. Deck State Manager
```swift
class DeckStateManager {
    struct Deck {
        var originalCards: [Card]  // From deck code
        var discoveredCards: [DiscoveredCard]  // Separate tracking
        var remainingOriginal: [Card]
        var remainingDiscovered: [DiscoveredCard]
        var playedCards: [Card]
        var handCards: [Card]
    }
    
    struct DiscoveredCard {
        var card: Card
        var source: DiscoverySource  // .discover(pool: [Card]), .random(from: Card)
        var timestamp: Date
    }
}
```

### 4. UI Components
**Overlay Window:**
```swift
class OverlayWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}
```

**Card Display Views:**
- `OriginalCardView`: Normal appearance
- `DiscoveredCardView`: Special border/background, source indicator
- `ProbabilityBadge`: Draw probability display
- `ThreatIndicator`: Opponent threat assessment

### 5. Data Storage
- **Card Database:** Local SQLite with card metadata (updated via network)
- **Match History:** SwiftData for match records
- **User Preferences:** `UserDefaults` for settings

## User Interface Design

### Overlay Mode
```
┌─────────────────────────────────────┐
│ Hearthstone Deck Tracker            │
│                                     │
│ Player Deck (12 remaining)          │
│ ├─ Original (10)                    │
│ │  ├─ 1⚡: Fire Fly ×2              │
│ │  ├─ 2⚡: Vicious Fledgling ×1     │
│ │  └─ ...                           │
│ └─ Discovered (2)                   │
│    ├─ Cobalt Scalebane ★            │
│    └─ Primordial Drake ★            │
│                                     │
│ Opponent (Mage)                     │
│ ├─ Played: 8 cards                  │
│ ├─ Secret: 1 (likely Counterspell)  │
│ └─ Possible: Flamestrike, Blizzard  │
│                                     │
│ Next draw: Fireball (15%)           │
└─────────────────────────────────────┘
```

### Window Mode
- **Deck View:** Full card list with filtering/sorting
- **Match Stats:** Win rates, class matchups, duration
- **History:** Recent matches with replay details
- **Settings:** Hotkeys, overlay appearance, data management

## Configuration & Settings

### Required Permissions
1. **Screen Recording:** For OCR capture
2. **Accessibility:** For window detection (optional)
3. **File Access:** For log file monitoring

### User Preferences
- **Overlay:** Position, transparency, font size
- **Hotkeys:** Toggle overlay, switch modes, screenshot
- **Tracking:** Enable/disable OCR, log parsing
- **Updates:** Auto-check for card data updates

## Future Extensions
1. **Cloud Sync:** Match history across devices
2. **Deck Recommendations:** Meta analysis and suggestions
3. **Replay System:** Match recording and playback
4. **Streamer Mode:** Hide sensitive information for streaming
5. **Multi-language Support:** Card names in different languages

## Success Criteria
1. **Accuracy:** Card tracking accuracy >95% in normal gameplay
2. **Performance:** <5% CPU usage during gameplay
3. **Reliability:** No crashes during 8+ hour sessions
4. **Usability:** Intuitive setup, minimal configuration required
5. **Compatibility:** Works with latest Hearthstone patch

## Risks & Mitigations
- **Risk:** Hearthstone log format changes
  - **Mitigation:** Modular parser with version detection
- **Risk:** OCR performance on different screen resolutions
  - **Mitigation:** Configurable capture regions, multiple recognition attempts
- **Risk:** Game updates breaking compatibility
  - **Mitigation:** Quick-release update mechanism, community testing

## Development Phases
1. **Phase 1:** Core log parsing + deck state management
2. **Phase 2:** Basic overlay UI
3. **Phase 3:** OCR fallback system
4. **Phase 4:** Advanced features (probability, threats)
5. **Phase 5:** Polish, testing, release

---

*Document version: 1.0*  
*Last updated: 2026-05-23*  
*Author: Marvis (Hearthstone Deck Tracker Design)*