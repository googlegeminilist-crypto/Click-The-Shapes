//
//  ContentView.swift
//  Click The Shapes
//
//  Created by Thomas Mellor on 30/01/2026.
//

import SwiftUI
import Combine
import AVFoundation
import StoreKit
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// MARK: - Analytics Wrapper
enum AnalyticsHelper {
    static func log(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif
    }
    static func setProperty(_ value: String, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
}

// MARK: - Debug Logging
@inline(__always)
nonisolated func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

// MARK: - Game Constants (optimized for older phones like iPhone XS Max)
struct GameConstants {
    static let level1WinScore = 500
    static let level2WinScore = 1000
    static let level3WinScore = 1500
    static let level4WinScore = 2000
    static let maxStars = 40
    static let maxParticles = 50
    static let maxFireballs = 30
    static let shapeCount = 8
    static let powerUpInterval: TimeInterval = 5.0
    static let trapBoxDuration: TimeInterval = 1.2  // How long a shape stays as a trap box
    static let trapBoxInterval: TimeInterval = 2.0  // How often shapes turn into trap boxes
    static let level3ShapeSpeed: CGFloat = 1.8      // Faster movement in Level 3
    static let level3ShrinkRate: CGFloat = 0.15      // How fast shapes shrink per frame
    static let level3MinSize: CGFloat = 25           // Smallest a shape can shrink to
    static let level3MaxSize: CGFloat = 60           // Normal size shapes reset to
    static let smallShapeThreshold: CGFloat = 35     // Below this = small = 5 points
}

// MARK: - Shape Types
enum ShapeType: CaseIterable {
    case star, circle, triangle, square, pentagon
}

// MARK: - Game Colors
struct GameColors {
    static let neonGreen = Color(red: 0, green: 1, blue: 0.53)
    static let neonPink = Color(red: 1, green: 0, blue: 1)
    static let neonCyan = Color(red: 0, green: 1, blue: 1)
    static let neonYellow = Color(red: 1, green: 1, blue: 0)
    static let neonOrange = Color(red: 1, green: 0.4, blue: 0)

    static let shapeColors: [Color] = [neonGreen, neonPink, neonCyan, neonYellow, Color(red: 1, green: 0, blue: 0.53)]
}

// MARK: - Star Colors for Level 2
struct StarColors {
    static let colors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (1.0, 1.0, 1.0),     // White
        (0.6, 0.8, 1.0),     // Blue-white
        (1.0, 0.85, 0.6),    // Warm yellow
        (1.0, 0.5, 0.5),     // Red
        (0.7, 0.7, 1.0),     // Pale blue
        (1.0, 0.6, 0.2),     // Orange
        (0.8, 0.6, 1.0),     // Purple
        (0.4, 1.0, 0.8),     // Teal
        (1.0, 0.4, 0.7),     // Pink
    ]
}

// MARK: - Star Model
class BackgroundStar: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var brightness: CGFloat
    var twinkleSpeed: CGFloat
    var starColorR: CGFloat
    var starColorG: CGFloat
    var starColorB: CGFloat
    var level2Size: CGFloat  // Bigger size for Level 2

    // Level 3 depth/parallax properties
    var depth: CGFloat       // 0.0 = far away, 1.0 = close (affects size, speed, brightness)
    var driftX: CGFloat      // Parallax drift speed X
    var driftY: CGFloat      // Parallax drift speed Y
    var streakLength: CGFloat // Longer = faster feel

    init(bounds: CGSize) {
        x = CGFloat.random(in: 0...bounds.width)
        y = CGFloat.random(in: 0...bounds.height)
        size = CGFloat.random(in: 1...2.5)
        level2Size = CGFloat.random(in: 1.5...4.0)
        brightness = CGFloat.random(in: 0.3...1.0)
        twinkleSpeed = CGFloat.random(in: 0.02...0.05)

        // Assign a random star colour
        let c = StarColors.colors.randomElement()!
        starColorR = c.r
        starColorG = c.g
        starColorB = c.b

        // Depth layer: 0 = far background, 1 = near foreground
        depth = CGFloat.random(in: 0...1)
        driftX = 0
        driftY = 0
        streakLength = 0
    }

    func setupForLevel3(bounds: CGSize) {
        // Drift from center outward for warp-speed feel
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        let dx = x - centerX
        let dy = y - centerY
        let dist = max(hypot(dx, dy), 1)
        let speed = (depth * 0.8 + 0.2) // Near stars move faster
        driftX = (dx / dist) * speed
        driftY = (dy / dist) * speed
        streakLength = depth * 6 + 1  // Near stars have longer streaks
    }

    func updateLevel3(bounds: CGSize) {
        x += driftX
        y += driftY

        // Wrap around when off screen
        if x < -10 || x > bounds.width + 10 || y < -10 || y > bounds.height + 10 {
            // Respawn near center with random offset
            let centerX = bounds.width / 2
            let centerY = bounds.height / 2
            x = centerX + CGFloat.random(in: -80...80)
            y = centerY + CGFloat.random(in: -80...80)
            let dx = x - centerX
            let dy = y - centerY
            let dist = max(hypot(dx, dy), 1)
            let speed = (depth * 0.8 + 0.2)
            driftX = (dx / dist) * speed
            driftY = (dy / dist) * speed
        }

        // Still twinkle
        brightness += twinkleSpeed
        if brightness > 1 || brightness < 0.3 {
            twinkleSpeed *= -1
        }
    }

    func update() {
        brightness += twinkleSpeed
        if brightness > 1 || brightness < 0.3 {
            twinkleSpeed *= -1
        }
    }
}

// MARK: - Orbiting Star
struct OrbitingStar: Identifiable {
    let id = UUID()
    var angle: CGFloat
    var distance: CGFloat
    var speed: CGFloat
    var size: CGFloat
    var isRed: Bool
    var twinklePhase: CGFloat

    mutating func update() {
        angle += speed
        twinklePhase += 0.1
    }
}

// MARK: - Constellation Shape Model
class ConstellationShape: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat = 60
    var color: Color
    var shapeType: ShapeType
    var pulsePhase: CGFloat = 0
    var orbitingStars: [OrbitingStar] = []
    var isTrapBox: Bool = false
    var trapBoxTimer: Date?
    var isShrinking: Bool = false
    var baseSize: CGFloat = 60  // The current actual size (changes in Level 3)

    init(bounds: CGSize) {
        x = CGFloat.random(in: 80...max(81, bounds.width - 80))
        y = CGFloat.random(in: 150...max(151, bounds.height - 150))
        vx = CGFloat.random(in: -0.4...0.4)
        vy = CGFloat.random(in: -0.4...0.4)
        color = GameColors.shapeColors.randomElement()!
        shapeType = ShapeType.allCases.randomElement()!

        // Create orbiting stars (reduced for performance)
        for i in 0..<3 {
            orbitingStars.append(OrbitingStar(
                angle: CGFloat(i) * (.pi * 2 / 3),
                distance: size + 20 + CGFloat.random(in: 0...15),
                speed: CGFloat.random(in: -0.02...0.02),
                size: CGFloat.random(in: 2...4),
                isRed: i % 2 == 0,
                twinklePhase: CGFloat.random(in: 0...(.pi * 2))
            ))
        }
    }

    func reset(bounds: CGSize, level: Int = 1) {
        x = CGFloat.random(in: 80...max(81, bounds.width - 80))
        y = CGFloat.random(in: 150...max(151, bounds.height - 150))
        color = GameColors.shapeColors.randomElement()!
        shapeType = ShapeType.allCases.randomElement()!

        if level >= 3 {
            // Level 3: faster movement, reset to full size and start shrinking
            let speed = GameConstants.level3ShapeSpeed
            vx = CGFloat.random(in: -speed...speed)
            vy = CGFloat.random(in: -speed...speed)
            // Make sure they don't move too slowly
            if abs(vx) < 0.5 { vx = vx < 0 ? -0.5 : 0.5 }
            if abs(vy) < 0.5 { vy = vy < 0 ? -0.5 : 0.5 }
            baseSize = GameConstants.level3MaxSize
            isShrinking = true
        } else {
            vx = CGFloat.random(in: -0.4...0.4)
            vy = CGFloat.random(in: -0.4...0.4)
            baseSize = 60
            isShrinking = false
        }
    }

    func update(bounds: CGSize, level: Int = 1) {
        x += vx
        y += vy

        if x < 80 || x > bounds.width - 80 { vx *= -1 }
        if y < 150 || y > bounds.height - 150 { vy *= -1 }

        pulsePhase += 0.05

        // Level 3: shapes shrink over time
        if level >= 3 && isShrinking && !isTrapBox {
            baseSize -= GameConstants.level3ShrinkRate
            if baseSize <= GameConstants.level3MinSize {
                baseSize = GameConstants.level3MinSize
                isShrinking = false
            }
        }

        for i in orbitingStars.indices {
            orbitingStars[i].update()
        }
    }

    func isClicked(at point: CGPoint) -> Bool {
        let distance = hypot(point.x - x, point.y - y)
        return distance < baseSize
    }

    var isSmall: Bool {
        baseSize <= GameConstants.smallShapeThreshold
    }
}

// MARK: - Particle Model
class Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var life: CGFloat = 1.0
    var decay: CGFloat
    var color: Color

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        let angle = CGFloat.random(in: 0...(.pi * 2))
        let speed = CGFloat.random(in: 2...5)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
        size = CGFloat.random(in: 2...5)
        decay = CGFloat.random(in: 0.02...0.04)
        color = GameColors.shapeColors.randomElement()!
    }

    func update() {
        x += vx
        y += vy
        life -= decay
        vx *= 0.96
        vy *= 0.96
    }

    var isDead: Bool { life <= 0 }
}

// MARK: - Fireball Particle
class FireballParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var life: CGFloat = 1.0
    var decay: CGFloat

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        let angle = CGFloat.random(in: 0...(.pi * 2))
        let speed = CGFloat.random(in: 4...10)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
        size = CGFloat.random(in: 8...20)
        decay = CGFloat.random(in: 0.015...0.025)
    }

    func update() {
        x += vx
        y += vy
        vy += 0.15 // gravity
        life -= decay
        vx *= 0.97
        vy *= 0.97
    }

    var isDead: Bool { life <= 0 }
}

// MARK: - Power Up Model
class PowerUp: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var fallSpeed: CGFloat = 2.5
    var size: CGFloat = 50
    var pulsePhase: CGFloat = 0
    var isActive = true

    init(bounds: CGSize) {
        x = CGFloat.random(in: 60...max(61, bounds.width - 60))
        y = -60
    }

    func update(bounds: CGSize) {
        guard isActive else { return }
        y += fallSpeed
        pulsePhase += 0.1

        if y > bounds.height + 100 {
            isActive = false
        }
    }

    func isClicked(at point: CGPoint) -> Bool {
        guard isActive else { return false }
        return hypot(point.x - x, point.y - y) < size
    }
}

// MARK: - Snake Segment
struct SnakeSegment: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
}

// MARK: - Snake AI
class Snake {
    var segments: [SnakeSegment] = []
    var segmentSize: CGFloat = 8
    var speed: CGFloat = 3.0
    var targetLength = 5

    init(bounds: CGSize) {
        let startX = bounds.width / 2
        let startY = bounds.height / 2
        for i in 0..<5 {
            segments.append(SnakeSegment(
                x: startX - CGFloat(i) * segmentSize * 2,
                y: startY
            ))
        }
    }

    func update(shapes: [ConstellationShape], bounds: CGSize, powerUp: PowerUp?, onEatShape: (ConstellationShape) -> Void, onEatPowerUp: (PowerUp) -> Void) {
        guard !segments.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        let headX = segments[0].x
        let headY = segments[0].y

        // Find nearest shape
        var nearestShape: ConstellationShape?
        var nearestShapeDist = CGFloat.infinity

        for shape in shapes {
            let dist = hypot(shape.x - headX, shape.y - headY)
            if dist < nearestShapeDist {
                nearestShapeDist = dist
                nearestShape = shape
            }
        }

        // Check if power-up is closer (prioritize power-ups!)
        var targetX: CGFloat = nearestShape?.x ?? headX
        var targetY: CGFloat = nearestShape?.y ?? headY

        if let pu = powerUp, pu.isActive {
            let powerUpDist = hypot(pu.x - headX, pu.y - headY)
            if powerUpDist < nearestShapeDist + 100 {
                targetX = pu.x
                targetY = pu.y
            }
        }

        // Move head towards target
        let angle = atan2(targetY - headY, targetX - headX)
        var newX = headX + cos(angle) * speed
        var newY = headY + sin(angle) * speed

        // Clamp to screen bounds
        newX = min(max(0, newX), bounds.width)
        newY = min(max(0, newY), bounds.height)

        // Check if snake eats the power-up (larger detection radius)
        if let pu = powerUp, pu.isActive {
            let distToPowerUp = hypot(pu.x - newX, pu.y - newY)
            if distToPowerUp < pu.size {
                onEatPowerUp(pu)
            }
        }

        // Check if snake eats the shape
        if let target = nearestShape {
            let distToShape = hypot(target.x - newX, target.y - newY)
            if distToShape < segmentSize + target.size / 2 {
                grow()
                onEatShape(target)
            }
        }

        // Add new head position
        segments.insert(SnakeSegment(x: newX, y: newY), at: 0)

        // Remove tail to maintain length
        while segments.count > targetLength {
            segments.removeLast()
        }

        // Maintain segment spacing
        let maxUpdate = min(25, segments.count)
        for i in 1..<maxUpdate {
            let prev = segments[i - 1]
            var current = segments[i]
            let dx = prev.x - current.x
            let dy = prev.y - current.y
            let dist = hypot(dx, dy)

            if dist > segmentSize * 2, dist > 0 {
                let ratio = (segmentSize * 2) / dist
                current.x = prev.x - dx * ratio
                current.y = prev.y - dy * ratio
                // Clamp segments to screen
                current.x = min(max(0, current.x), bounds.width)
                current.y = min(max(0, current.y), bounds.height)
                segments[i] = current
            }
        }
    }

    func grow() {
        targetLength += 3
    }
}

// MARK: - Sound Manager
class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var shapeTapURL: URL?
    private var shapeTapPlayers: [AVAudioPlayer] = []
    private var isSetup = false

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            debugLog("Audio session error: \(error)")
        }
    }

    private func setupBackgroundMusic() {
        guard !isSetup else { return }

        // Try to find the audio file
        var url: URL?

        // Try bundle first
        if let bundleURL = Bundle.main.url(forResource: "Untitled", withExtension: "wav") {
            url = bundleURL
            debugLog("Found audio in bundle: \(bundleURL)")
        }

        guard let audioURL = url else {
            debugLog("Background music file 'Untitled.wav' not found in bundle")
            debugLog("Bundle path: \(Bundle.main.bundlePath)")
            if let resources = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
                debugLog("WAV files in bundle: \(resources)")
            }
            return
        }

        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: audioURL)
            backgroundMusicPlayer?.delegate = self
            backgroundMusicPlayer?.numberOfLoops = -1
            backgroundMusicPlayer?.volume = 0.5
            backgroundMusicPlayer?.prepareToPlay()
            isSetup = true
            debugLog("Background music loaded successfully")
        } catch {
            debugLog("Error loading background music: \(error)")
        }
    }

    func playBackgroundMusic() {
        setupAudioSession()
        setupBackgroundMusic()
        if backgroundMusicPlayer?.play() == true {
            debugLog("Music started playing")
        } else {
            debugLog("Music failed to play")
        }
    }

    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }

    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        setupAudioSession()
        backgroundMusicPlayer?.play()
    }

    func stopAllShapeTapSounds() {
        for player in shapeTapPlayers {
            player.stop()
        }
        shapeTapPlayers.removeAll()
    }

    func playSparkle() {
        AudioServicesPlaySystemSound(1104)
    }

    func playSnakeEat() {
        AudioServicesPlaySystemSound(1052)
    }

    func playExplosion() {
        AudioServicesPlaySystemSound(1053)
    }

    func playShapeTap() {
        // Find URL once
        if shapeTapURL == nil {
            shapeTapURL = Bundle.main.url(forResource: "alex_jauk-strange-echoing-noises-230895", withExtension: "mp3")
            if shapeTapURL == nil {
                debugLog("Shape tap sound NOT found in bundle")
                return
            }
        }

        guard let url = shapeTapURL else { return }

        // Clean up finished players — limit pool to prevent memory buildup
        shapeTapPlayers.removeAll { !$0.isPlaying }
        guard shapeTapPlayers.count < 5 else { return }

        // Create a fresh player each tap so sounds overlap for fast tapping
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            shapeTapPlayers.append(player)
        } catch {
            debugLog("Error playing shape tap sound: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        debugLog("Audio finished: \(flag)")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        debugLog("Audio decode error: \(error?.localizedDescription ?? "unknown")")
    }
}

// MARK: - Store Manager (In-App Purchase)
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let fullGameProductID = "krakastan3_icloud.com.Click_The_Shapes.fullgame"

    @Published var fullGamePurchased: Bool = false
    @Published var fullGameProduct: Product?
    @Published var isPurchasing = false

    private var transactionListener: Task<Void, Error>?

    init() {
        // Check if already purchased (also check old key for backward compat)
        fullGamePurchased = UserDefaults.standard.bool(forKey: "fullGamePurchased")
            || UserDefaults.standard.bool(forKey: "soundPackPurchased")

        // Listen for transactions
        transactionListener = listenForTransactions()

        // Load products
        Task {
            await loadProducts()
            await checkCurrentEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchaseStatus(transaction)
                    await transaction.finish()
                } catch {
                    debugLog("Transaction verification failed: \(error)")
                }
            }
        }
    }

    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [StoreManager.fullGameProductID])
            fullGameProduct = products.first
            debugLog("Loaded product: \(fullGameProduct?.displayName ?? "none")")
        } catch {
            debugLog("Failed to load products: \(error)")
        }
    }

    @MainActor
    func checkCurrentEntitlements() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == StoreManager.fullGameProductID {
                    fullGamePurchased = true
                    UserDefaults.standard.set(true, forKey: "fullGamePurchased")
                }
            } catch {
                debugLog("Entitlement check failed: \(error)")
            }
        }
    }

    @MainActor
    func purchaseFullGame() async {
        guard let product = fullGameProduct else {
            debugLog("Product not loaded yet")
            return
        }

        isPurchasing = true
        AnalyticsHelper.log("purchase_started", parameters: nil)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchaseStatus(transaction)
                await transaction.finish()
                AnalyticsHelper.log("purchase_completed", parameters: nil)
            case .userCancelled:
                AnalyticsHelper.log("purchase_cancelled", parameters: nil)
                debugLog("User cancelled purchase")
            case .pending:
                debugLog("Purchase pending")
            @unknown default:
                break
            }
        } catch {
            debugLog("Purchase failed: \(error)")
        }
        isPurchasing = false
    }

    @MainActor
    func restorePurchases() async {
        AnalyticsHelper.log("restore_purchases", parameters: nil)
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {
            debugLog("Restore failed: \(error)")
        }
    }

    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func updatePurchaseStatus(_ transaction: StoreKit.Transaction) async {
        if transaction.productID == StoreManager.fullGameProductID {
            fullGamePurchased = true
            UserDefaults.standard.set(true, forKey: "fullGamePurchased")
            AnalyticsHelper.setProperty("true", forName: "full_game_purchased")
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - Game View Model
class GameViewModel: ObservableObject {
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        powerUpTimer?.invalidate()
        trapBoxTimer?.invalidate()
    }

    @Published var score = 0
    @Published var snakeScore = 0
    @Published var gameOver = false
    @Published var gameStarted = false
    @Published var showIntro = true
    @Published var winMessage = ""
    @Published var winColor = GameColors.neonGreen
    @Published var updateTrigger = false
    @Published var currentLevel = 1
    @Published var showLevelTransition = false
    @Published var showUnlockPrompt = false
    @Published var hardcoreMode = false
    @Published var tapSoundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(tapSoundEnabled, forKey: "tapSoundEnabled")
        }
    }

    var stars: [BackgroundStar] = []
    var shapes: [ConstellationShape] = []
    var particles: [Particle] = []
    var fireballs: [FireballParticle] = []
    var powerUp: PowerUp?
    var snake: Snake?
    var snake2: Snake?
    var pointsPopup: (x: CGFloat, y: CGFloat, points: Int)?
    var pointsPopupTime: Date?

    @AppStorage("userWins") var userWins = 0
    @AppStorage("snakeWins") var snakeWins = 0

    var bounds: CGSize = .zero
    private var displayLink: CADisplayLink?
    private var powerUpTimer: Timer?
    private var trapBoxTimer: Timer?

    var winningScore: Int {
        switch currentLevel {
        case 1: return GameConstants.level1WinScore
        case 2: return GameConstants.level2WinScore
        case 3: return GameConstants.level3WinScore
        default: return GameConstants.level4WinScore
        }
    }

    private var isSetup = false

    func setupGame(bounds: CGSize) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        self.bounds = bounds

        // Only set up once
        guard !isSetup else { return }
        isSetup = true

        // Load saved tap sound preference
        if UserDefaults.standard.object(forKey: "tapSoundEnabled") != nil {
            tapSoundEnabled = UserDefaults.standard.bool(forKey: "tapSoundEnabled")
        }

        // Create stars
        stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }

        // Create shapes
        shapes = (0..<GameConstants.shapeCount).map { _ in ConstellationShape(bounds: bounds) }

        // Create snake
        snake = Snake(bounds: bounds)

        // Start game loop
        startGameLoop()
    }

    func startGame() {
        showIntro = false
        if displayLink == nil {
            startGameLoop()
        }
        SoundManager.shared.playBackgroundMusic()
        AnalyticsHelper.log("game_start", parameters: ["hardcore_mode": hardcoreMode ? 1 : 0])
    }

    func startGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
        let link = CADisplayLink(target: self, selector: #selector(gameLoop))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link

        // Power-up spawn timer
        powerUpTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.powerUpInterval, repeats: true) { [weak self] _ in
            self?.spawnPowerUp()
        }
    }

    func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
        powerUpTimer?.invalidate()
        powerUpTimer = nil
        trapBoxTimer?.invalidate()
        trapBoxTimer = nil
    }

    func pauseGame() {
        displayLink?.isPaused = true
        powerUpTimer?.invalidate()
        powerUpTimer = nil
        trapBoxTimer?.invalidate()
        trapBoxTimer = nil
        SoundManager.shared.pauseBackgroundMusic()
    }

    func resumeGame() {
        guard !gameOver else { return }
        displayLink?.isPaused = false
        if displayLink == nil && isSetup {
            startGameLoop()
        }
        if !showIntro {
            SoundManager.shared.resumeBackgroundMusic()
            // Restart power-up spawn timer
            if powerUpTimer == nil {
                powerUpTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.powerUpInterval, repeats: true) { [weak self] _ in
                    self?.spawnPowerUp()
                }
            }
            if currentLevel >= 2 {
                startTrapBoxTimer()
            }
        }
    }

    @objc func gameLoop() {
        guard !gameOver, !showIntro, bounds.width > 0, bounds.height > 0 else { return }

        // Update stars
        for star in stars {
            if currentLevel >= 3 {
                star.updateLevel3(bounds: bounds)
            } else {
                star.update()
            }
        }

        // Update shapes
        for shape in shapes {
            shape.update(bounds: bounds, level: currentLevel)
        }

        // Update snake (only if game started)
        if gameStarted, !gameOver {
            snake?.update(shapes: shapes, bounds: bounds, powerUp: powerUp, onEatShape: { [weak self] shape in
                self?.snakeAteShape(shape)
            }, onEatPowerUp: { [weak self] pu in
                self?.snakeAtePowerUp(pu)
            })
            if !gameOver {
                snake2?.update(shapes: shapes, bounds: bounds, powerUp: powerUp, onEatShape: { [weak self] shape in
                    self?.snakeAteShape(shape)
                }, onEatPowerUp: { [weak self] pu in
                    self?.snakeAtePowerUp(pu)
                })
            }
        }

        // Update power-up
        powerUp?.update(bounds: bounds)
        if let pu = powerUp, !pu.isActive {
            powerUp = nil
        }

        // Update particles
        for particle in particles {
            particle.update()
        }
        particles.removeAll { $0.isDead }
        while particles.count > GameConstants.maxParticles {
            particles.removeFirst()
        }

        // Update fireballs
        for fireball in fireballs {
            fireball.update()
        }
        fireballs.removeAll { $0.isDead }
        while fireballs.count > GameConstants.maxFireballs {
            fireballs.removeFirst()
        }

        // Revert trap boxes back to shapes after duration
        if currentLevel >= 2 {
            let now = Date()
            for shape in shapes {
                if shape.isTrapBox, let timer = shape.trapBoxTimer,
                   now.timeIntervalSince(timer) >= GameConstants.trapBoxDuration {
                    shape.isTrapBox = false
                    shape.trapBoxTimer = nil
                }
            }
        }

        // Clear points popup after delay
        if let popupTime = pointsPopupTime, Date().timeIntervalSince(popupTime) > 0.8 {
            pointsPopup = nil
            pointsPopupTime = nil
        }

        updateTrigger.toggle()
    }

    func spawnPowerUp() {
        guard powerUp == nil, !gameOver, !showIntro else { return }
        powerUp = PowerUp(bounds: bounds)
    }

    func handleTap(at point: CGPoint) {
        guard !gameOver, !showIntro, !showLevelTransition else { return }

        // Check shapes (user can no longer click power-ups - snake gets them)
        for shape in shapes {
            if shape.isClicked(at: point) {
                if !gameStarted {
                    gameStarted = true
                }

                if shape.isTrapBox {
                    // Clicked a trap box! Minus 10 points
                    score = max(0, score - 10)
                    showPoints(at: point, points: -10)
                    AnalyticsHelper.log("trap_box_hit", parameters: ["score": score, "current_level": currentLevel])
                    if tapSoundEnabled { SoundManager.shared.playExplosion() }

                    // Red particles for trap box
                    for _ in 0..<8 {
                        let p = Particle(x: point.x, y: point.y)
                        p.color = .red
                        particles.append(p)
                    }

                    // Revert to shape after being clicked
                    shape.isTrapBox = false
                    shape.trapBoxTimer = nil
                } else {
                    // Level 3: small shapes give 5 points, normal give 10
                    let points = (currentLevel >= 3 && shape.isSmall) ? 5 : 10
                    addScore(points)
                    showPoints(at: point, points: points)
                    if tapSoundEnabled {
                        if StoreManager.shared.fullGamePurchased {
                            SoundManager.shared.playShapeTap()
                        } else {
                            SoundManager.shared.playSparkle()
                        }
                    }

                    // Create particles — Level 4 gets a colorful explosion burst
                    if currentLevel >= 4 {
                        let burstColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]
                        for i in 0..<12 {
                            let p = Particle(x: point.x, y: point.y)
                            p.color = burstColors[i % burstColors.count]
                            p.size = CGFloat.random(in: 3...7)
                            particles.append(p)
                        }
                        for _ in 0..<4 {
                            fireballs.append(FireballParticle(x: point.x, y: point.y))
                        }
                    } else {
                        for _ in 0..<8 {
                            particles.append(Particle(x: point.x, y: point.y))
                        }
                    }

                    shape.reset(bounds: bounds, level: currentLevel)
                }
                break
            }
        }
    }

    func snakeAteShape(_ shape: ConstellationShape) {
        guard !gameOver else { return }
        snakeScore += 10
        showPoints(at: CGPoint(x: shape.x, y: shape.y), points: 10)
        if tapSoundEnabled { SoundManager.shared.playSnakeEat() }

        // Create particles
        for _ in 0..<10 {
            particles.append(Particle(x: shape.x, y: shape.y))
        }

        shape.reset(bounds: bounds, level: currentLevel)

        if snakeScore >= winningScore {
            endGame(message: "SNAKE WINS!", color: GameColors.neonPink, snakeWon: true)
        }
    }

    func snakeAtePowerUp(_ pu: PowerUp) {
        guard !gameOver, pu.isActive else { return }
        let point = CGPoint(x: pu.x, y: pu.y)
        pu.isActive = false
        powerUp = nil

        if tapSoundEnabled { SoundManager.shared.playExplosion() }

        // Create explosion fireballs
        for _ in 0..<15 {
            fireballs.append(FireballParticle(x: point.x, y: point.y))
        }

        // Destroy nearby shapes - SNAKE gets exactly 20 points (double) for power-up
        let explosionRadius: CGFloat = 250
        var destroyedCount = 0

        for shape in shapes {
            let dist = hypot(shape.x - point.x, shape.y - point.y)
            if dist < explosionRadius {
                // Create fireballs at shape location
                for _ in 0..<5 {
                    fireballs.append(FireballParticle(x: shape.x, y: shape.y))
                }

                destroyedCount += 1
                shape.reset(bounds: bounds, level: currentLevel)
            }
        }

        // Snake ALWAYS gets exactly 20 points for power-up (double points)
        snakeScore += 20
        showPoints(at: point, points: 20)

        // Snake grows extra from power-up
        snake?.grow()
        snake?.grow()
        snake2?.grow()
        snake2?.grow()

        if snakeScore >= winningScore {
            endGame(message: "SNAKE WINS!", color: GameColors.neonPink, snakeWon: true)
        }
    }

    func addScore(_ points: Int) {
        guard !gameOver else { return }
        score += points
        if currentLevel == 1 && score >= GameConstants.level1WinScore {
            if StoreManager.shared.fullGamePurchased {
                transitionToLevel2()
            } else {
                // Pause game and show unlock prompt
                displayLink?.invalidate()
                displayLink = nil
                powerUpTimer?.invalidate()
                powerUpTimer = nil
                trapBoxTimer?.invalidate()
                trapBoxTimer = nil
                showUnlockPrompt = true
                AnalyticsHelper.log("unlock_prompt_shown", parameters: ["score": score])
            }
        } else if currentLevel == 2 && score >= GameConstants.level2WinScore {
            transitionToLevel3()
        } else if currentLevel == 3 && score >= GameConstants.level3WinScore {
            transitionToLevel4()
        } else if currentLevel == 4 && score >= GameConstants.level4WinScore {
            endGame(message: "YOU WIN!", color: GameColors.neonGreen, snakeWon: false)
        }
    }

    func transitionToLevel2() {
        AnalyticsHelper.log("level_complete", parameters: ["level": 1, "score": score])
        currentLevel = 2
        showLevelTransition = true
        gameStarted = false  // Snake waits until user taps a shape

        // Add more stars for the deeper space background
        let extraStars = (0..<20).map { _ in BackgroundStar(bounds: bounds) }
        stars.append(contentsOf: extraStars)

        // Reset snake score to give player a fair start in Level 2
        snakeScore = 0

        // Reset snake
        snake = Snake(bounds: bounds)

        // Start trap box timer (will only activate shapes once transition is done)
        startTrapBoxTimer()

        // Hide transition after 2 seconds — game resumes on first tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showLevelTransition = false
        }
    }

    func transitionToLevel3() {
        AnalyticsHelper.log("level_complete", parameters: ["level": 2, "score": score])
        currentLevel = 3
        showLevelTransition = true
        gameStarted = false  // Snake waits until user taps a shape

        // Add even more stars for depth effect and set up parallax
        let extraStars = (0..<25).map { _ in BackgroundStar(bounds: bounds) }
        stars.append(contentsOf: extraStars)
        for star in stars {
            star.setupForLevel3(bounds: bounds)
        }

        // Reset snake score
        snakeScore = 0

        // Reset snake (faster in Level 3)
        snake = Snake(bounds: bounds)
        snake?.speed = 4.0

        // Reset all shapes with Level 3 properties (fast + shrinking)
        for shape in shapes {
            shape.reset(bounds: bounds, level: 3)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        // Keep trap boxes active in Level 3
        startTrapBoxTimer()

        // Hide transition after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showLevelTransition = false
        }
    }

    func transitionToLevel4() {
        AnalyticsHelper.log("level_complete", parameters: ["level": 3, "score": score])
        currentLevel = 4
        showLevelTransition = true
        gameStarted = false

        // Add more stars
        let extraStars = (0..<15).map { _ in BackgroundStar(bounds: bounds) }
        stars.append(contentsOf: extraStars)
        for star in stars {
            star.setupForLevel3(bounds: bounds)
        }

        // Reset snake score
        snakeScore = 0

        // First snake — fast
        snake = Snake(bounds: bounds)
        snake?.speed = 4.5

        // Second snake — spawns from opposite side, also fast
        snake2 = Snake(bounds: bounds)
        snake2?.speed = 3.5

        // Reset shapes with Level 3+ properties (fast + shrinking)
        for shape in shapes {
            shape.reset(bounds: bounds, level: 4)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        startTrapBoxTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showLevelTransition = false
        }
    }

    func startTrapBoxTimer() {
        trapBoxTimer?.invalidate()
        trapBoxTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.trapBoxInterval, repeats: true) { [weak self] _ in
            self?.turnRandomShapesToTrapBoxes()
        }
    }

    func turnRandomShapesToTrapBoxes() {
        guard currentLevel >= 2, !gameOver, !showIntro else { return }

        // Turn 1-3 random shapes into trap boxes
        let availableShapes = shapes.filter { !$0.isTrapBox }
        let count = min(Int.random(in: 1...3), availableShapes.count)

        for shape in availableShapes.shuffled().prefix(count) {
            shape.isTrapBox = true
            shape.trapBoxTimer = Date()
        }
    }

    func showPoints(at point: CGPoint, points: Int) {
        pointsPopup = (x: point.x, y: point.y, points: points)
        pointsPopupTime = Date()
    }

    func endGame(message: String, color: Color, snakeWon: Bool) {
        guard !gameOver else { return }
        gameOver = true
        winMessage = message
        winColor = color

        if snakeWon {
            snakeWins += 1
        } else {
            userWins += 1
            LeaderboardManager.shared.recordWin(totalWins: userWins)
        }

        stopGameLoop()
        SoundManager.shared.stopAllShapeTapSounds()
        SoundManager.shared.stopBackgroundMusic()

        AnalyticsHelper.log("game_end", parameters: [
            "snake_won": snakeWon ? 1 : 0,
            "score": score,
            "snake_score": snakeScore,
            "current_level": currentLevel,
            "hardcore_mode": hardcoreMode ? 1 : 0
        ])
        AnalyticsHelper.setProperty("\(userWins)", forName: "total_user_wins")
        AnalyticsHelper.setProperty("\(snakeWins)", forName: "total_snake_wins")
    }

    func goHome() {
        stopGameLoop()
        SoundManager.shared.stopAllShapeTapSounds()
        SoundManager.shared.stopBackgroundMusic()
        score = 0
        snakeScore = 0
        gameOver = false
        gameStarted = false
        currentLevel = 1
        showLevelTransition = false
        showUnlockPrompt = false
        hardcoreMode = false
        showIntro = true
        particles.removeAll()
        fireballs.removeAll()
        powerUp = nil
        stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }
        for shape in shapes {
            shape.reset(bounds: bounds, level: 1)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }
        snake = Snake(bounds: bounds)
        snake2 = nil
    }

    func restartGame() {
        score = 0
        snakeScore = 0
        gameOver = false
        gameStarted = false
        currentLevel = 1
        showLevelTransition = false
        hardcoreMode = false
        particles.removeAll()
        fireballs.removeAll()
        powerUp = nil

        // Reset stars back to Level 1 count
        stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }

        for shape in shapes {
            shape.reset(bounds: bounds, level: 1)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        snake = Snake(bounds: bounds)
        snake2 = nil
        startGameLoop()
        SoundManager.shared.playBackgroundMusic()
    }

    func restartCurrentLevel() {
        let level = currentLevel
        gameOver = false
        gameStarted = false
        snakeScore = 0
        particles.removeAll()
        fireballs.removeAll()
        powerUp = nil

        // Set score to start of current level
        switch level {
        case 1:
            score = 0
            stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }
        case 2:
            score = GameConstants.level1WinScore
            // Keep Level 2 star count
            stars = (0..<(GameConstants.maxStars + 20)).map { _ in BackgroundStar(bounds: bounds) }
            startTrapBoxTimer()
        case 3:
            score = GameConstants.level2WinScore
            stars = (0..<(GameConstants.maxStars + 45)).map { _ in BackgroundStar(bounds: bounds) }
            for star in stars {
                star.setupForLevel3(bounds: bounds)
            }
            startTrapBoxTimer()
        case 4:
            score = GameConstants.level3WinScore
            stars = (0..<(GameConstants.maxStars + 60)).map { _ in BackgroundStar(bounds: bounds) }
            for star in stars {
                star.setupForLevel3(bounds: bounds)
            }
            startTrapBoxTimer()
        default:
            score = 0
        }

        for shape in shapes {
            shape.reset(bounds: bounds, level: level)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        snake = Snake(bounds: bounds)
        if level >= 3 {
            snake?.speed = level >= 4 ? 4.5 : 4.0
        }
        if level >= 4 {
            snake2 = Snake(bounds: bounds)
            snake2?.speed = 3.5
        } else {
            snake2 = nil
        }

        startGameLoop()
        SoundManager.shared.playBackgroundMusic()
    }
}

// MARK: - Shape Drawing Views
struct StarShapeView: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            var path = Path()

            for i in 0..<5 {
                let angle = CGFloat(i) * (.pi * 2 / 5) - .pi / 2
                let x = center.x + cos(angle) * size
                let y = center.y + sin(angle) * size

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                let innerAngle = angle + .pi / 5
                let innerX = center.x + cos(innerAngle) * (size * 0.4)
                let innerY = center.y + sin(innerAngle) * (size * 0.4)
                path.addLine(to: CGPoint(x: innerX, y: innerY))
            }
            path.closeSubpath()

            context.stroke(path, with: .color(color), lineWidth: 3)
        }
        .frame(width: size * 2.5, height: size * 2.5)
    }
}

struct ShapeView: View {
    let shape: ConstellationShape

    var body: some View {
        let pulse = sin(shape.pulsePhase) * 0.2 + 1
        let currentSize = shape.baseSize * pulse

        ZStack {
            if shape.isTrapBox {
                // Trap box appearance - red/danger filled box
                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: currentSize * 0.9, height: currentSize * 0.9)
                    .overlay(
                        Rectangle()
                            .stroke(Color.red, lineWidth: 3)
                    )
                    .shadow(color: .red.opacity(0.8), radius: 10)

                // Warning X
                ZStack {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: currentSize * 0.6, height: 4)
                        .rotationEffect(.degrees(45))
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: currentSize * 0.6, height: 4)
                        .rotationEffect(.degrees(-45))
                }
            } else {
                // Orbiting stars
                ForEach(shape.orbitingStars) { star in
                    let x = cos(star.angle) * star.distance
                    let y = sin(star.angle) * star.distance
                    let brightness = (sin(star.twinklePhase) + 1) / 2 * 0.8 + 0.2

                    Circle()
                        .fill(star.isRed ? Color.red : Color.blue)
                        .frame(width: star.size, height: star.size)
                        .opacity(brightness)
                        .offset(x: x, y: y)
                }

                // Main shape
                Group {
                    switch shape.shapeType {
                    case .star:
                        StarShapeView(size: currentSize * 0.5, color: shape.color)
                    case .circle:
                        Circle()
                            .stroke(shape.color, lineWidth: 3)
                            .frame(width: currentSize, height: currentSize)
                    case .triangle:
                        TriangleShape()
                            .stroke(shape.color, lineWidth: 3)
                            .frame(width: currentSize, height: currentSize)
                    case .square:
                        Rectangle()
                            .stroke(shape.color, lineWidth: 3)
                            .frame(width: currentSize * 0.8, height: currentSize * 0.8)
                    case .pentagon:
                        PentagonShape()
                            .stroke(shape.color, lineWidth: 3)
                            .frame(width: currentSize, height: currentSize)
                    }
                }
                .shadow(color: shape.color.opacity(0.6), radius: 8)
            }
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height) / 2

        for i in 0..<3 {
            let angle = CGFloat(i) * (.pi * 2 / 3) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * size,
                y: center.y + sin(angle) * size
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct PentagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height) / 2

        for i in 0..<5 {
            let angle = CGFloat(i) * (.pi * 2 / 5) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * size,
                y: center.y + sin(angle) * size
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Snake View
struct SnakeView: View {
    let snake: Snake
    var glowing: Bool = false

    var body: some View {
        let segments = snake.segments
        let maxVisible = min(30, segments.count)

        Canvas { context, size in
            guard maxVisible > 0 else { return }

            // Draw glow layer for second snake
            if glowing {
                for i in 0..<maxVisible {
                    let segment = segments[i]
                    let glowSize = snake.segmentSize * 4
                    context.fill(
                        Circle().path(in: CGRect(
                            x: segment.x - glowSize,
                            y: segment.y - glowSize,
                            width: glowSize * 2,
                            height: glowSize * 2
                        )),
                        with: .color(Color.cyan.opacity(0.15))
                    )
                }
            }

            // Draw segments
            for i in 0..<maxVisible {
                let segment = segments[i]
                let brightness = 1 - (Double(i) / Double(maxVisible)) * 0.5
                let color: Color
                if glowing {
                    let hue = (Double(i * 8) + 180).truncatingRemainder(dividingBy: 360) / 360
                    color = Color(hue: hue, saturation: 0.6, brightness: brightness)
                } else {
                    let hue = Double(i * 10).truncatingRemainder(dividingBy: 360) / 360
                    color = Color(hue: hue, saturation: 1, brightness: brightness)
                }

                // Draw segment
                context.fill(
                    Circle().path(in: CGRect(
                        x: segment.x - snake.segmentSize,
                        y: segment.y - snake.segmentSize,
                        width: snake.segmentSize * 2,
                        height: snake.segmentSize * 2
                    )),
                    with: .color(color)
                )

                // Draw connecting line
                if i < maxVisible - 1 && i < 30 {
                    let next = segments[i + 1]
                    var path = Path()
                    path.move(to: CGPoint(x: segment.x, y: segment.y))
                    path.addLine(to: CGPoint(x: next.x, y: next.y))
                    context.stroke(path, with: .color(color), lineWidth: snake.segmentSize * 1.5)
                }
            }

            // Draw eyes on head
            if let head = segments.first {
                let eyeColor: Color = glowing ? .cyan : .white
                context.fill(
                    Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 4, height: 4)),
                    with: .color(eyeColor)
                )
                context.fill(
                    Circle().path(in: CGRect(x: head.x + 2, y: head.y - 6, width: 4, height: 4)),
                    with: .color(eyeColor)
                )
            }
        }
    }
}

// MARK: - Power Up View
struct PowerUpView: View {
    let powerUp: PowerUp

    var body: some View {
        let pulse = sin(powerUp.pulsePhase) * 0.3 + 1

        ZStack {
            // Fireballs cluster
            ForEach(0..<5, id: \.self) { i in
                let offsetX: CGFloat = [-12, 10, -8, 14, 0][i]
                let offsetY: CGFloat = [-10, -5, 12, 8, -2][i]
                let baseSize: CGFloat = [14, 12, 16, 10, 18][i]
                let size = baseSize * pulse

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow, .orange, .red],
                            center: .center,
                            startRadius: 0,
                            endRadius: size
                        )
                    )
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)
            }

            // Bonus label
            Text("BONUS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .red, radius: 3)
        }
        .position(x: powerUp.x, y: powerUp.y)
    }
}

// MARK: - Intro Overlay
struct IntroOverlay: View {
    let onStart: () -> Void
    let onStartHardcore: () -> Void
    var onStartLevel4: () -> Void = {}
    @ObservedObject var store = StoreManager.shared
    @ObservedObject var leaderboard = LeaderboardManager.shared
    @State private var showLeaderboard = false
    @State private var showNamePrompt = false
    @State private var nameInput = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            ScrollView {
            VStack(spacing: 25) {
                Text("CLICK THE SHAPES")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(GameColors.neonGreen)
                    .shadow(color: GameColors.neonGreen, radius: 10)

                VStack(alignment: .leading, spacing: 15) {
                    RuleRow(icon: "target", text: "Tap shapes to earn 10 points", color: .yellow)
                    RuleRow(icon: "flame.fill", text: "Snake gets fireballs for bonus points!", color: .orange)
                    RuleRow(icon: "tortoise.fill", text: "Snake starts hunting on first tap!", color: GameColors.neonPink)
                    RuleRow(icon: "trophy.fill", text: "First to 500 points wins!", color: GameColors.neonGreen)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)

                // Full Game IAP
                VStack(spacing: 10) {
                    if store.fullGamePurchased {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(GameColors.neonGreen)
                            Text("Full Game Unlocked")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(GameColors.neonGreen)
                        }
                    } else {
                        Button {
                            Task { await store.purchaseFullGame() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.open.fill")
                                    .foregroundColor(.black)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Full Game")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                    if let price = store.fullGameProduct?.displayPrice {
                                        Text(price)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.black.opacity(0.7))
                                    } else {
                                        Text("Loading...")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.black.opacity(0.5))
                                    }
                                    Text("Levels 2 & 3 + Sound Pack + Hardcore mode")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 25)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [GameColors.neonYellow, GameColors.neonOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: GameColors.neonYellow, radius: 5)
                        }
                        .disabled(store.isPurchasing)
                        .opacity(store.isPurchasing ? 0.6 : 1)

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Leaderboard
                Button { showLeaderboard = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.black)
                        Text("LEADERBOARD")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [GameColors.neonYellow, GameColors.neonOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: GameColors.neonYellow, radius: 5)
                }

                if leaderboard.hasSetName {
                    Button { showNamePrompt = true } label: {
                        Text("Playing as: \(leaderboard.playerName)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }

                #if DEBUG
                Button {
                    store.fullGamePurchased.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.fullGamePurchased ? "lock.open.fill" : "lock.fill")
                        Text(store.fullGamePurchased ? "DEBUG: Locked" : "DEBUG: Unlock Full Game")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }

                Button {
                    onStartLevel4()
                } label: {
                    Text("DEBUG: Skip to Level 4")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                #endif

                Button(action: onStart) {
                    Text("START GAME")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [GameColors.neonGreen, GameColors.neonCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: GameColors.neonGreen, radius: 10)
                }
                .padding(.top, 10)

                if store.fullGamePurchased {
                    Button(action: onStartHardcore) {
                        VStack(spacing: 4) {
                            Text("HARDCORE MODE")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                            Text("You can't restart at any point")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [GameColors.neonPink, GameColors.neonOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: GameColors.neonPink, radius: 8)
                    }
                }
            }
            .padding(30)
            }
        }
        .onAppear {
            if !leaderboard.hasSetName {
                showNamePrompt = true
            }
        }
        .alert("Enter Your Name", isPresented: $showNamePrompt) {
            TextField("Display name", text: $nameInput)
            Button("Save") {
                let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    leaderboard.playerName = trimmed
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This name will appear on the global leaderboard.")
        }
        .fullScreenCover(isPresented: $showLeaderboard) {
            LeaderboardView()
        }
    }
}

struct RuleRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 16, design: .monospaced))
        }
    }
}

// MARK: - Unlock Overlay
struct UnlockOverlay: View {
    let onPurchaseComplete: () -> Void
    let onReplayLevel1: () -> Void
    @ObservedObject var store = StoreManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("LEVEL 1 COMPLETE!")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(GameColors.neonGreen)
                    .shadow(color: GameColors.neonGreen, radius: 10)

                Text("Unlock the full game to continue")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 8) {
                    RuleRow(icon: "2.circle.fill", text: "Level 2 — More shapes & speed", color: GameColors.neonCyan)
                    RuleRow(icon: "3.circle.fill", text: "Level 3 — Ultimate challenge", color: GameColors.neonPink)
                    RuleRow(icon: "speaker.wave.3.fill", text: "Premium tap sounds", color: GameColors.neonYellow)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                Button {
                    Task {
                        await store.purchaseFullGame()
                        if store.fullGamePurchased {
                            onPurchaseComplete()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.black)
                        VStack(spacing: 2) {
                            Text("UNLOCK FULL GAME")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                            if let price = store.fullGameProduct?.displayPrice {
                                Text(price)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [GameColors.neonGreen, GameColors.neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: GameColors.neonGreen, radius: 10)
                }
                .disabled(store.isPurchasing)
                .opacity(store.isPurchasing ? 0.6 : 1)

                Button {
                    Task {
                        await store.restorePurchases()
                        if store.fullGamePurchased {
                            onPurchaseComplete()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Button(action: onReplayLevel1) {
                    Text("Replay Level 1")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(GameColors.neonYellow)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(GameColors.neonYellow.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Win Overlay
struct WinOverlay: View {
    let message: String
    let color: Color
    let levelText: String
    let hardcoreMode: Bool
    let onRestart: () -> Void
    let onRestartLevel: () -> Void

    @State private var titleScale: CGFloat = 1.0
    @State private var buttonGlow: CGFloat = 8.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 25) {
                Text(message)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .shadow(color: color, radius: 15)
                    .scaleEffect(titleScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                            titleScale = 1.1
                        }
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            buttonGlow = 20.0
                        }
                    }

                if !hardcoreMode {
                    // Restart Level button - glowing pulsing green (hidden in hardcore mode)
                    Button(action: onRestartLevel) {
                        Text("RESTART \(levelText)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(
                                GameColors.neonGreen
                            )
                            .cornerRadius(12)
                            .shadow(color: GameColors.neonGreen, radius: buttonGlow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GameColors.neonGreen.opacity(0.8), lineWidth: 2)
                            )
                    }
                }

                // Play Again (from Level 1) button
                Button(action: onRestart) {
                    Text("PLAY AGAIN")
                        .font(.system(size: hardcoreMode ? 20 : 16, weight: .bold, design: .monospaced))
                        .foregroundColor(hardcoreMode ? .black : .white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, hardcoreMode ? 15 : 12)
                        .background(hardcoreMode ? GameColors.neonGreen : Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .shadow(color: hardcoreMode ? GameColors.neonGreen : .clear, radius: hardcoreMode ? buttonGlow : 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hardcoreMode ? GameColors.neonGreen.opacity(0.8) : Color.white.opacity(0.3), lineWidth: hardcoreMode ? 2 : 1)
                        )
                }
            }
        }
    }
}

// MARK: - Tap Gesture View
struct TapGestureView: UIViewRepresentable {
    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    class Coordinator: NSObject {
        var onTap: (CGPoint) -> Void

        init(onTap: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            onTap(location)
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var game = GameViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient - evolves per level
                Group {
                    if game.currentLevel >= 3 {
                        // Level 3: deep 3D warp space with galaxy center
                        ZStack {
                            Color.black

                            // Central warp/galaxy glow
                            RadialGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.05, blue: 0.3).opacity(0.6),
                                    Color(red: 0.08, green: 0.0, blue: 0.2).opacity(0.4),
                                    Color(red: 0.03, green: 0.0, blue: 0.1).opacity(0.2),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geometry.size.width * 0.5
                            )

                            // Warm nebula arm (top-right)
                            RadialGradient(
                                colors: [Color(red: 0.3, green: 0.1, blue: 0.0).opacity(0.25), .clear],
                                center: UnitPoint(x: 0.8, y: 0.15),
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )

                            // Cool nebula arm (bottom-left)
                            RadialGradient(
                                colors: [Color(red: 0.0, green: 0.1, blue: 0.3).opacity(0.25), .clear],
                                center: UnitPoint(x: 0.15, y: 0.85),
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )

                            // Pink nebula wisp (center-left)
                            RadialGradient(
                                colors: [Color(red: 0.25, green: 0.0, blue: 0.15).opacity(0.2), .clear],
                                center: UnitPoint(x: 0.2, y: 0.4),
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.35
                            )

                            // Teal highlight (center-right)
                            RadialGradient(
                                colors: [Color(red: 0.0, green: 0.15, blue: 0.2).opacity(0.15), .clear],
                                center: UnitPoint(x: 0.75, y: 0.55),
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.3
                            )
                        }
                    } else if game.currentLevel >= 2 {
                        // Level 2: Deep space with nebula-like colours
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.02, green: 0.0, blue: 0.08),
                                    Color(red: 0.0, green: 0.0, blue: 0.0),
                                    Color(red: 0.05, green: 0.0, blue: 0.1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            RadialGradient(
                                colors: [Color(red: 0.15, green: 0.0, blue: 0.25).opacity(0.4), .clear],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.6
                            )
                            RadialGradient(
                                colors: [Color(red: 0.0, green: 0.05, blue: 0.2).opacity(0.3), .clear],
                                center: .bottomLeading,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                            RadialGradient(
                                colors: [Color(red: 0.2, green: 0.0, blue: 0.1).opacity(0.2), .clear],
                                center: UnitPoint(x: 0.3, y: 0.6),
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.4
                            )
                        }
                    } else {
                        // Level 1: Simple purple space
                        RadialGradient(
                            colors: [Color(red: 0.1, green: 0, blue: 0.2), .black],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(geometry.size.width, geometry.size.height)
                        )
                    }
                }
                .ignoresSafeArea()

                // Game canvas - redraws on updateTrigger
                GameCanvasView(game: game)
                    .id(game.updateTrigger)

                // Shapes
                ForEach(game.shapes) { shape in
                    ShapeView(shape: shape)
                        .position(x: shape.x, y: shape.y)
                        .id("\(shape.id)-\(game.updateTrigger)")
                }

                // Snake
                if let snake = game.snake {
                    SnakeView(snake: snake)
                        .id(game.updateTrigger)
                }

                // Second snake (Level 4) — with glow
                if let snake2 = game.snake2 {
                    SnakeView(snake: snake2, glowing: true)
                        .id(game.updateTrigger)
                }

                // Power-up
                if let powerUp = game.powerUp, powerUp.isActive {
                    PowerUpView(powerUp: powerUp)
                        .id(game.updateTrigger)
                }

                // Points popup
                if let popup = game.pointsPopup {
                    Text(popup.points >= 0 ? "+\(popup.points)" : "\(popup.points)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(popup.points >= 0 ? .yellow : .red)
                        .shadow(color: popup.points >= 0 ? .yellow : .red, radius: 10)
                        .position(x: popup.x, y: popup.y - 30)
                        .id(game.updateTrigger)
                }

                // Tap gesture layer
                TapGestureView { location in
                    game.handleTap(at: location)
                }

                // Header (on top of tap gesture so buttons are tappable)
                VStack {
                    // Level indicator + home button
                    HStack {
                        Button(action: { game.goHome() }) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                        }

                        Text("LEVEL \(game.currentLevel)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(game.currentLevel == 1 ? GameColors.neonCyan : game.currentLevel == 2 ? .red : GameColors.neonOrange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(game.currentLevel == 1 ? GameColors.neonCyan : game.currentLevel == 2 ? .red : GameColors.neonOrange, lineWidth: 1)
                            )
                    }
                    .padding(.top, 50)

                    HStack {
                        // Snake score (left) + sound toggle below
                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading) {
                                Text("Snake")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                Text("\(game.snakeScore)")
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(GameColors.neonPink)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(GameColors.neonPink, lineWidth: 2)
                            )
                            .allowsHitTesting(false)

                            // Tap sound toggle
                            Button(action: {
                                game.tapSoundEnabled.toggle()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: game.tapSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                        .font(.system(size: 12))
                                    Text(game.tapSoundEnabled ? "Sound On" : "Sound Off")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                }
                                .foregroundColor(game.tapSoundEnabled ? GameColors.neonCyan : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(game.tapSoundEnabled ? GameColors.neonCyan : .gray, lineWidth: 1)
                                )
                            }
                        }

                        Spacer()
                            .allowsHitTesting(false)

                        // Target score
                        VStack {
                            Text("Target")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("\(game.winningScore)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(GameColors.neonYellow)
                        }
                        .allowsHitTesting(false)

                        Spacer()
                            .allowsHitTesting(false)

                        // Player score (right)
                        VStack(alignment: .trailing) {
                            Text("You")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Text("\(game.score)")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(GameColors.neonGreen)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(GameColors.neonGreen, lineWidth: 2)
                        )
                        .allowsHitTesting(false)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)

                    Spacer()
                        .allowsHitTesting(false)

                    // Win record
                    HStack(spacing: 30) {
                        VStack {
                            Text("YOUR WINS")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("\(game.userWins)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(GameColors.neonGreen)
                        }

                        VStack {
                            Text("SNAKE WINS")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("\(game.snakeWins)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(GameColors.neonPink)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GameColors.neonGreen, lineWidth: 1)
                    )
                    .padding(.bottom, 30)
                    .allowsHitTesting(false)
                }
                .allowsHitTesting(true)

                // Intro overlay
                if game.showIntro {
                    IntroOverlay(onStart: {
                        game.startGame()
                    }, onStartHardcore: {
                        game.hardcoreMode = true
                        game.startGame()
                    }, onStartLevel4: {
                        game.startGame()
                        game.score = GameConstants.level3WinScore
                        game.transitionToLevel4()
                    })
                }

                // Level transition overlay
                if game.showLevelTransition {
                    ZStack {
                        Color.black.opacity(0.85)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            Text("LEVEL \(game.currentLevel)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(game.currentLevel == 2 ? .red : game.currentLevel == 4 ? GameColors.neonCyan : GameColors.neonOrange)
                                .shadow(color: game.currentLevel == 2 ? .red : game.currentLevel == 4 ? GameColors.neonCyan : GameColors.neonOrange, radius: 15)

                            if game.currentLevel == 2 {
                                Text("Watch out for TRAP BOXES!")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)

                                Text("Shapes will turn into red boxes\nClick them and lose 10 points!")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else if game.currentLevel == 3 {
                                Text("Shapes are SHRINKING!")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)

                                Text("Shapes move fast and shrink!\nSmall shapes = only 5 points\nTrap boxes are still active!")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else if game.currentLevel == 4 {
                                Text("TWO SNAKES!")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(GameColors.neonCyan)

                                Text("A second glowing snake joins the hunt!\nBoth snakes share the same score\nShapes explode when you tap them!")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .transition(.opacity)
                }

                // Unlock prompt (after beating Level 1 without IAP)
                if game.showUnlockPrompt {
                    UnlockOverlay(
                        onPurchaseComplete: {
                            game.showUnlockPrompt = false
                            game.transitionToLevel2()
                        },
                        onReplayLevel1: {
                            game.showUnlockPrompt = false
                            game.restartGame()
                        }
                    )
                }

                // Win overlay
                if game.gameOver {
                    WinOverlay(
                        message: game.winMessage,
                        color: game.winColor,
                        levelText: "LEVEL \(game.currentLevel)",
                        hardcoreMode: game.hardcoreMode,
                        onRestart: {
                            game.restartGame()
                        },
                        onRestartLevel: {
                            game.restartCurrentLevel()
                        }
                    )
                }
            }
            .onAppear {
                game.setupGame(bounds: geometry.size)
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            game.pauseGame()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            game.resumeGame()
        }
    }
}

// MARK: - Game Canvas View
struct GameCanvasView: View {
    let game: GameViewModel

    var body: some View {
        Canvas { context, size in
            let isLevel2 = game.currentLevel >= 2
            let isLevel3 = game.currentLevel >= 3

            // Draw stars
            for star in game.stars {
                let starColor = Color(
                    red: star.starColorR,
                    green: star.starColorG,
                    blue: star.starColorB
                )

                if isLevel3 {
                    // Level 3+: 3D depth stars with motion streaks
                    let depthSize = (star.depth * 3.0 + 1.0)
                    let depthBrightness = star.brightness * (star.depth * 0.6 + 0.4)

                    // Motion streak trail (skip short streaks)
                    if star.streakLength > 3 {
                        let streakEndX = star.x - star.driftX * star.streakLength
                        let streakEndY = star.y - star.driftY * star.streakLength
                        var path = Path()
                        path.move(to: CGPoint(x: star.x, y: star.y))
                        path.addLine(to: CGPoint(x: streakEndX, y: streakEndY))
                        context.stroke(
                            path,
                            with: .color(starColor.opacity(depthBrightness * 0.3)),
                            lineWidth: depthSize * 0.5
                        )
                    }

                    // Star core only (skip glow for performance)
                    context.fill(
                        Circle().path(in: CGRect(
                            x: star.x - depthSize / 2,
                            y: star.y - depthSize / 2,
                            width: depthSize,
                            height: depthSize
                        )),
                        with: .color(starColor.opacity(depthBrightness))
                    )

                } else if isLevel2 {
                    // Level 2: Coloured stars (no glow for performance)
                    let drawSize = star.level2Size
                    context.fill(
                        Circle().path(in: CGRect(
                            x: star.x - drawSize / 2,
                            y: star.y - drawSize / 2,
                            width: drawSize,
                            height: drawSize
                        )),
                        with: .color(starColor.opacity(star.brightness))
                    )
                } else {
                    // Level 1: Simple white stars
                    context.fill(
                        Circle().path(in: CGRect(
                            x: star.x - star.size / 2,
                            y: star.y - star.size / 2,
                            width: star.size,
                            height: star.size
                        )),
                        with: .color(.white.opacity(star.brightness))
                    )
                }
            }

            // Draw fireballs (single draw per fireball for performance)
            for fireball in game.fireballs {
                let s = fireball.size
                context.fill(
                    Circle().path(in: CGRect(
                        x: fireball.x - s / 2,
                        y: fireball.y - s / 2,
                        width: s,
                        height: s
                    )),
                    with: .color(.orange.opacity(fireball.life))
                )
            }

            // Draw particles
            for particle in game.particles {
                context.fill(
                    Circle().path(in: CGRect(
                        x: particle.x - particle.size / 2,
                        y: particle.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )),
                    with: .color(particle.color.opacity(particle.life))
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
