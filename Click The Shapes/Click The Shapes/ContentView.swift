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

// MARK: - Nebula Dust (Level 4 floating particles)
class NebulaDust: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: CGFloat
    var driftX: CGFloat
    var driftY: CGFloat
    var depth: CGFloat
    var colorR: CGFloat
    var colorG: CGFloat
    var colorB: CGFloat
    var phase: CGFloat

    init(bounds: CGSize) {
        x = CGFloat.random(in: 0...bounds.width)
        y = CGFloat.random(in: 0...bounds.height)
        depth = CGFloat.random(in: 0...1)
        size = depth * 6 + 2  // near = bigger
        opacity = depth * 0.3 + 0.05  // near = brighter, but still subtle
        driftX = CGFloat.random(in: -0.3...0.3) * (depth + 0.5)
        driftY = CGFloat.random(in: -0.2...0.2) * (depth + 0.5)
        phase = CGFloat.random(in: 0...(.pi * 2))

        // Nebula colors: purples, pinks, blues, cyans
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.5, 0.1, 0.6),   // purple
            (0.7, 0.15, 0.4),  // pink
            (0.15, 0.2, 0.7),  // blue
            (0.2, 0.5, 0.8),   // cyan-blue
            (0.4, 0.1, 0.5),   // dark purple
            (0.8, 0.3, 0.5),   // rose
        ]
        let c = palette.randomElement()!
        colorR = c.0
        colorG = c.1
        colorB = c.2
    }

    func update(bounds: CGSize) {
        x += driftX
        y += driftY
        phase += 0.015

        // Gentle bobbing
        x += sin(phase) * 0.2
        y += cos(phase * 0.7) * 0.15

        // Wrap around screen
        if x < -size { x = bounds.width + size }
        if x > bounds.width + size { x = -size }
        if y < -size { y = bounds.height + size }
        if y > bounds.height + size { y = -size }
    }
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
    var teleportTimer: Date?
    var isVisible: Bool = true
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

        if level >= 4 {
            // Level 4: fast movement, shapes teleport instead of shrinking
            let speed = GameConstants.level3ShapeSpeed * 1.2
            vx = CGFloat.random(in: -speed...speed)
            vy = CGFloat.random(in: -speed...speed)
            if abs(vx) < 0.5 { vx = vx < 0 ? -0.5 : 0.5 }
            if abs(vy) < 0.5 { vy = vy < 0 ? -0.5 : 0.5 }
            baseSize = 60
            isShrinking = false
            isVisible = true
            teleportTimer = Date().addingTimeInterval(Double.random(in: 1.5...4.0))
        } else if level >= 3 {
            // Level 3: faster movement, reset to full size and start shrinking
            let speed = GameConstants.level3ShapeSpeed
            vx = CGFloat.random(in: -speed...speed)
            vy = CGFloat.random(in: -speed...speed)
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
        if isVisible {
            x += vx
            y += vy
        }

        if x < 80 || x > bounds.width - 80 { vx *= -1 }
        if y < 150 || y > bounds.height - 150 { vy *= -1 }

        pulsePhase += 0.05

        // Level 4: shapes disappear and reappear randomly
        if level >= 4, !isTrapBox, let timer = teleportTimer {
            if Date() >= timer {
                if isVisible {
                    // Disappear
                    isVisible = false
                    teleportTimer = Date().addingTimeInterval(Double.random(in: 0.5...1.5))
                } else {
                    // Reappear at random position
                    isVisible = true
                    x = CGFloat.random(in: 80...max(81, bounds.width - 80))
                    y = CGFloat.random(in: 150...max(151, bounds.height - 150))
                    color = GameColors.shapeColors.randomElement()!
                    shapeType = ShapeType.allCases.randomElement()!
                    teleportTimer = Date().addingTimeInterval(Double.random(in: 1.5...4.0))
                }
            }
        }

        // Level 3: shapes shrink over time (not level 4)
        if level == 3 && isShrinking && !isTrapBox {
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
        guard isVisible else { return false }
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

// MARK: - Lightning Bolt (Level 4)
class LightningBolt: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var fallSpeed: CGFloat
    var size: CGFloat = 20
    var isActive = true
    var flickerPhase: CGFloat = 0

    init(bounds: CGSize) {
        x = CGFloat.random(in: 40...max(41, bounds.width - 40))
        y = -20
        fallSpeed = CGFloat.random(in: 3...5)
    }

    func update(bounds: CGSize) {
        y += fallSpeed
        flickerPhase += 0.3
        if y > bounds.height + 30 {
            isActive = false
        }
    }

    func isClicked(at point: CGPoint) -> Bool {
        guard isActive else { return false }
        return hypot(point.x - x, point.y - y) < size * 1.5
    }
}

// MARK: - Diamond Collectible
class Diamond: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat = 28
    var isActive = true
    var floatPhase: CGFloat = CGFloat.random(in: 0...(.pi * 2))
    var sparklePhase: CGFloat = 0
    var life: CGFloat = 1.0  // fades out over time

    init(bounds: CGSize) {
        x = CGFloat.random(in: 60...max(61, bounds.width - 60))
        y = CGFloat.random(in: 120...max(121, bounds.height - 120))
    }

    func update() {
        floatPhase += 0.05
        sparklePhase += 0.12
        life -= 0.007  // disappears after ~2.5 seconds
        if life <= 0 { isActive = false }
    }

    func isClicked(at point: CGPoint) -> Bool {
        guard isActive else { return false }
        return hypot(point.x - x, point.y - y) < size * 1.2
    }
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
    var speed: CGFloat = 4.5
    var targetLength = 3
    // Animation state
    var animPhase: CGFloat = 0
    var blinkTimer: CGFloat = 0
    var isBlinking = false
    var tongueOut: CGFloat = 0
    var tongueTimer: CGFloat = 0

    init(bounds: CGSize) {
        let startX = bounds.width / 2
        let startY = bounds.height / 2
        for i in 0..<3 {
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

        for shape in shapes where shape.isVisible {
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

        // Update animations
        animPhase += 0.05
        blinkTimer += 1
        tongueTimer += 1

        // Blink every ~120 frames (2 sec), stays closed for ~6 frames
        if !isBlinking && blinkTimer > 120 {
            isBlinking = true
            blinkTimer = 0
        }
        if isBlinking && blinkTimer > 6 {
            isBlinking = false
            blinkTimer = 0
        }

        // Tongue flicks every ~90 frames, out for ~20 frames
        if tongueOut <= 0 && tongueTimer > 90 {
            tongueOut = 1
            tongueTimer = 0
        }
        if tongueOut > 0 {
            tongueOut -= 0.05
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
    private var isSetup = false

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func setupBackgroundMusic() {
        guard !isSetup else { return }

        // Try to find the audio file
        var url: URL?

        // Try bundle first
        if let bundleURL = Bundle.main.url(forResource: "Untitled", withExtension: "wav") {
            url = bundleURL
        }

        guard let audioURL = url else { return }

        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: audioURL)
            backgroundMusicPlayer?.delegate = self
            backgroundMusicPlayer?.numberOfLoops = -1
            backgroundMusicPlayer?.volume = 0.5
            backgroundMusicPlayer?.prepareToPlay()
            isSetup = true
        } catch {}
    }

    func playBackgroundMusic() {
        setupAudioSession()
        setupBackgroundMusic()
        if backgroundMusicPlayer?.play() == true {
        } else {
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

    func playLevel4Music() {
        setupAudioSession()
        guard let url = Bundle.main.url(forResource: "Untitled 8", withExtension: "mp3") else {
            return
        }
        do {
            backgroundMusicPlayer?.stop()
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.delegate = self
            backgroundMusicPlayer?.numberOfLoops = -1
            backgroundMusicPlayer?.volume = 0.85
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
        } catch {}
    }

    func stopAllShapeTapSounds() {
        // No longer using AVAudioPlayer for tap sounds
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
        AudioServicesPlaySystemSound(1104)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    }
}

// MARK: - Store Manager (In-App Purchase)
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let fullGameProductID = "krakastan3_icloud.com.Click_The_Shapes.fullgame"
    static let diamonds1000ProductID = "krakastan3_icloud.com.Click_The_Shapes.diamonds1000"
    static let diamondsGrantPerPack = 1000

    @Published var fullGamePurchased: Bool = false
    @Published var fullGameProduct: Product?
    @Published var diamonds1000Product: Product?
    @Published var isPurchasing = false
    @Published var isLoadingProducts = false
    @Published var lastPurchaseError: String?

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
                } catch {}
            }
        }
    }

    @MainActor
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [
                StoreManager.fullGameProductID,
                StoreManager.diamonds1000ProductID
            ])
            for p in products {
                switch p.id {
                case StoreManager.fullGameProductID: fullGameProduct = p
                case StoreManager.diamonds1000ProductID: diamonds1000Product = p
                default: break
                }
            }
            if diamonds1000Product == nil {
                lastPurchaseError = "In-app purchases aren't available right now. Check your connection and try again."
            }
        } catch {
            lastPurchaseError = "Couldn't reach the App Store. Check your connection and try again."
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
            } catch {}
        }
        // Consumables don't appear in currentEntitlements. Drain any unfinished
        // transactions so paid-but-not-delivered packs are granted on next launch.
        for await result in StoreKit.Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                await updatePurchaseStatus(transaction)
                await transaction.finish()
            } catch {}
        }
    }

    @MainActor
    func purchaseFullGame() async {
        guard let product = fullGameProduct else {
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
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {}
        isPurchasing = false
    }

    @MainActor
    func purchaseDiamonds1000() async {
        guard let product = diamonds1000Product else {
            lastPurchaseError = "Still loading the Store. Try again in a moment."
            await loadProducts()
            return
        }

        isPurchasing = true
        AnalyticsHelper.log("purchase_diamonds_1000_started", parameters: nil)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchaseStatus(transaction)
                await transaction.finish()
                AnalyticsHelper.log("purchase_diamonds_1000_completed", parameters: nil)
            case .userCancelled:
                AnalyticsHelper.log("purchase_diamonds_1000_cancelled", parameters: nil)
            case .pending:
                lastPurchaseError = "Purchase is pending approval (e.g. Ask to Buy). Your diamonds will be granted once approved."
            @unknown default:
                break
            }
        } catch {
            lastPurchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    @MainActor
    func restorePurchases() async {
        AnalyticsHelper.log("restore_purchases", parameters: nil)
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {}
    }

    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private static let processedTxnsKey = "processedTransactionIDs"

    /// Idempotency guard for consumables. StoreKit 2 will replay any transaction
    /// whose `finish()` didn't complete (e.g. crash between persist and finish),
    /// so we record every transaction ID we've fully handled and refuse to
    /// double-grant if we see it again.
    private func hasProcessed(_ transaction: StoreKit.Transaction) -> Bool {
        let processed = UserDefaults.standard.array(forKey: Self.processedTxnsKey) as? [String] ?? []
        return processed.contains(String(transaction.id))
    }

    private func markProcessed(_ transaction: StoreKit.Transaction) {
        var processed = UserDefaults.standard.array(forKey: Self.processedTxnsKey) as? [String] ?? []
        let id = String(transaction.id)
        guard !processed.contains(id) else { return }
        processed.append(id)
        // Cap the list so it can't grow without bound for very heavy users.
        if processed.count > 500 { processed.removeFirst(processed.count - 500) }
        UserDefaults.standard.set(processed, forKey: Self.processedTxnsKey)
    }

    @MainActor
    private func updatePurchaseStatus(_ transaction: StoreKit.Transaction) async {
        if transaction.productID == StoreManager.fullGameProductID {
            // Non-consumable: idempotent by nature — setting the bool twice is harmless.
            fullGamePurchased = true
            UserDefaults.standard.set(true, forKey: "fullGamePurchased")
            AnalyticsHelper.setProperty("true", forName: "full_game_purchased")
        } else if transaction.productID == StoreManager.diamonds1000ProductID {
            // Consumable: must be idempotent. If we've already granted this exact
            // transaction (replay after crash), skip the grant — the caller will
            // still finish() it so StoreKit stops replaying.
            guard !hasProcessed(transaction) else {
                return
            }
            let current = UserDefaults.standard.integer(forKey: "diamondsCollected")
            UserDefaults.standard.set(current + StoreManager.diamondsGrantPerPack, forKey: "diamondsCollected")
            // Mark processed BEFORE returning so a crash here-or-later still
            // prevents a double-grant on replay (the diamonds are persisted; if
            // the mark write also crashes, worst case a single re-grant happens).
            markProcessed(transaction)
            AnalyticsHelper.log("diamonds_granted", parameters: ["amount": StoreManager.diamondsGrantPerPack])
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
        lightningTimer?.invalidate()
        lightningRainTimer?.invalidate()
    }

    @Published var score = 0
    @Published var snakeScore = 0
    @Published var gameOver = false
    var lossCountSinceLastAd: Int = 0
    /// Snapshot of diamond count taken right before a hardcore-mode loss zeroed it,
    /// so the rewarded-ad continue can restore them.
    var hardcoreDiamondsBeforeLoss: Int = 0
    @Published var gameStarted = false
    @Published var showIntro = true
    @Published var useRainbowSnake = false
    @Published var useWormySnake = false
    @Published var useStarSnake = false
    @Published var useBlazeSnake = false
    @Published var useNebulaSnake = false
    @Published var useCosmosSnake = false
    @Published var useEmberSnake = false
    @Published var snakeSpeedMultiplier: CGFloat = 1.0
    var diamonds: [Diamond] = []
    var diamondTimer: Timer?
    @AppStorage("diamondsCollected") var diamondsCollected = 0
    @AppStorage("starSnakePurchased") var starSnakePurchased = false
    @AppStorage("candySnakePurchased") var candySnakePurchased = false
    @AppStorage("wormySnakePurchased") var wormySnakePurchased = false
    @AppStorage("blazeSnakePurchased") var blazeSnakePurchased = false
    @AppStorage("nebulaSnakePurchased") var nebulaSnakePurchased = false
    @AppStorage("dnaSnakePurchased") var dnaSnakePurchased = false
    @AppStorage("rewardedAdsWatched") var rewardedAdsWatched = 0
    @AppStorage("emberSnakePurchased") var emberSnakePurchased = false
    @Published var winMessage = ""
    @Published var winColor = GameColors.neonGreen
    @Published var updateTrigger = false
    @Published var currentLevel = 1
    @Published var showLevelTransition = false
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
    var lightningBolts: [LightningBolt] = []
    var nebulaDust: [NebulaDust] = []
    var lightningTimer: Timer?
    // Level 4 sequence challenge
    var shapeSequence: [ShapeType] = []
    var sequenceProgress: Int = 0
    var lightningRainActive = false
    var lightningRainTimer: Timer?
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
        snake?.speed = 4.5 * snakeSpeedMultiplier

        // Start game loop
        startGameLoop()
    }

    // Call when the device rotates so the game uses the new canvas size.
    // Entities self-clamp each frame, so we just refresh the stored bounds
    // and nudge obviously-out-of-bounds positions inward.
    func updateBounds(_ newBounds: CGSize) {
        guard newBounds.width > 0, newBounds.height > 0 else { return }
        self.bounds = newBounds
        guard isSetup else { return }

        for shape in shapes {
            shape.x = min(max(80, shape.x), max(81, newBounds.width - 80))
            shape.y = min(max(150, shape.y), max(151, newBounds.height - 150))
        }
        if let s = snake, !s.segments.isEmpty {
            s.segments[0].x = min(max(0, s.segments[0].x), newBounds.width)
            s.segments[0].y = min(max(0, s.segments[0].y), newBounds.height)
        }
        if let s = snake2, !s.segments.isEmpty {
            s.segments[0].x = min(max(0, s.segments[0].x), newBounds.width)
            s.segments[0].y = min(max(0, s.segments[0].y), newBounds.height)
        }
    }

    func startGame() {
        showIntro = false
        if displayLink == nil {
            startGameLoop()
        }
        SoundManager.shared.playBackgroundMusic()
        AnalyticsHelper.log("game_start", parameters: ["hardcore_mode": hardcoreMode ? 1 : 0])
        // Start diamond spawns
        startDiamondTimer()
    }

    /// DEBUG-only — equip the Ember snake skin and start the game.
    func debugTestEmberSnake() {
        useRainbowSnake = false
        useWormySnake = false
        useStarSnake = false
        useBlazeSnake = false
        useNebulaSnake = false
        useCosmosSnake = false
        useEmberSnake = true
        startGame()
    }

    func startDiamondTimer() {
        diamondTimer?.invalidate()
        diamondTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.gameOver else { return }
            // Spawn up to 5 at once
            while self.diamonds.count < 5 {
                self.diamonds.append(Diamond(bounds: self.bounds))
            }
        }
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
        lightningTimer?.invalidate()
        lightningTimer = nil
        lightningRainTimer?.invalidate()
        lightningRainTimer = nil
        lightningRainActive = false
        diamondTimer?.invalidate()
        diamondTimer = nil
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
            if diamondTimer == nil {
                startDiamondTimer()
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

        // Update diamonds
        for diamond in diamonds {
            diamond.update()
        }
        diamonds.removeAll { !$0.isActive }

        // Update nebula dust (Level 4)
        for dust in nebulaDust {
            dust.update(bounds: bounds)
        }

        // Update lightning bolts (Level 4)
        for bolt in lightningBolts {
            bolt.update(bounds: bounds)
        }
        lightningBolts.removeAll { !$0.isActive }

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

        // Check diamonds — collect them
        for diamond in diamonds {
            if diamond.isClicked(at: point) {
                diamond.isActive = false
                diamondsCollected += 1
                if tapSoundEnabled { SoundManager.shared.playExplosion() }
                // Sparkle particles
                for _ in 0..<10 {
                    let p = Particle(x: diamond.x, y: diamond.y)
                    let colors: [Color] = [.cyan, .white, Color(red: 0.8, green: 0.6, blue: 1), .yellow]
                    p.color = colors.randomElement()!
                    p.size = CGFloat.random(in: 2...5)
                    particles.append(p)
                }
                return
            }
        }

        // Check lightning bolts (Level 4) — 50 points
        for bolt in lightningBolts {
            if bolt.isClicked(at: point) {
                bolt.isActive = false
                if !gameStarted { gameStarted = true }
                addScore(50)
                showPoints(at: point, points: 50)
                if tapSoundEnabled { SoundManager.shared.playExplosion() }
                // Blue particles
                let blueColors: [Color] = [.cyan, .blue, .white]
                for i in 0..<8 {
                    let p = Particle(x: bolt.x, y: bolt.y)
                    p.color = blueColors[i % blueColors.count]
                    particles.append(p)
                }
                return
            }
        }

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
                        SoundManager.shared.playShapeTap()
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

                    // Level 4 sequence challenge
                    if currentLevel >= 4, !lightningRainActive, !shapeSequence.isEmpty {
                        if sequenceProgress < shapeSequence.count && shape.shapeType == shapeSequence[sequenceProgress] {
                            sequenceProgress += 1
                            if sequenceProgress >= shapeSequence.count {
                                startLightningRain()
                            }
                        } else {
                            sequenceProgress = 0
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
            transitionToLevel2()
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

        // Reset snake — Level 2 speed
        snake = Snake(bounds: bounds)
        snake?.speed = 8.0 * snakeSpeedMultiplier

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
        snake?.speed = 6.5 * snakeSpeedMultiplier

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
        SoundManager.shared.playLevel4Music()

        // Create nebula dust
        nebulaDust = (0..<30).map { _ in NebulaDust(bounds: bounds) }

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
        snake?.speed = 8.0 * snakeSpeedMultiplier

        // Second snake — spawns from opposite side, also fast
        snake2 = Snake(bounds: bounds)
        snake2?.speed = 7.0 * snakeSpeedMultiplier

        // Reset shapes with Level 3+ properties (fast + shrinking)
        for shape in shapes {
            shape.reset(bounds: bounds, level: 4)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        startTrapBoxTimer()
        startLightningTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showLevelTransition = false
        }

        generateNewSequence()
    }

    func generateNewSequence() {
        var seq: [ShapeType] = []
        while seq.count < 4 {
            let next = ShapeType.allCases.randomElement()!
            if seq.last != next {
                seq.append(next)
            }
        }
        shapeSequence = seq
        sequenceProgress = 0
    }

    func startLightningRain() {
        if hardcoreMode { return }
        lightningRainActive = true
        lightningRainTimer?.invalidate()
        lightningRainTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.gameOver else { return }
            if self.lightningBolts.count < 3 {
                self.lightningBolts.append(LightningBolt(bounds: self.bounds))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) { [weak self] in
            self?.stopLightningRain()
        }
    }

    func stopLightningRain() {
        lightningRainActive = false
        lightningRainTimer?.invalidate()
        lightningRainTimer = nil
        generateNewSequence()
    }

    func startLightningTimer() {
        // Lightning only falls during lightning rain — no always-on timer
        lightningTimer?.invalidate()
        lightningTimer = nil
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
            // Hardcore mode — lose ALL diamonds when snake wins.
            // Remember the pre-loss count so the rewarded-ad continue can restore them.
            if hardcoreMode {
                hardcoreDiamondsBeforeLoss = diamondsCollected
                diamondsCollected = 0
            }
            lossCountSinceLastAd += 1
            if lossCountSinceLastAd >= 4 {
                lossCountSinceLastAd = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    InterstitialAdManager.shared.showIfReady()
                }
            }
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
        hardcoreMode = false
        showIntro = true
        particles.removeAll()
        fireballs.removeAll()
        lightningBolts.removeAll()
        diamonds.removeAll()
        nebulaDust.removeAll()
        shapeSequence.removeAll()
        sequenceProgress = 0
        lightningRainActive = false
        lightningRainTimer?.invalidate()
        lightningRainTimer = nil
        powerUp = nil
        stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }
        for shape in shapes {
            shape.reset(bounds: bounds, level: 1)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }
        snake = Snake(bounds: bounds)
        snake?.speed = 4.5 * snakeSpeedMultiplier
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
        lightningBolts.removeAll()
        diamonds.removeAll()
        nebulaDust.removeAll()
        shapeSequence.removeAll()
        sequenceProgress = 0
        lightningRainActive = false
        lightningRainTimer?.invalidate()
        lightningRainTimer = nil
        powerUp = nil

        // Reset stars back to Level 1 count
        stars = (0..<GameConstants.maxStars).map { _ in BackgroundStar(bounds: bounds) }

        for shape in shapes {
            shape.reset(bounds: bounds, level: 1)
            shape.isTrapBox = false
            shape.trapBoxTimer = nil
        }

        snake = Snake(bounds: bounds)
        snake?.speed = 4.5 * snakeSpeedMultiplier
        snake2 = nil
        startGameLoop()
        SoundManager.shared.playBackgroundMusic()
        startDiamondTimer()
    }

    /// Reward-ad "continue" — carry on from the exact moment of death.
    /// No level restart. Shapes stay where they were, the snake keeps its
    /// length and position. Only the snake's score is zeroed so the game
    /// doesn't immediately end again from the same losing condition.
    func continueWithSameScore() {
        guard gameOver else { return }
        if lossCountSinceLastAd > 0 { lossCountSinceLastAd -= 1 }
        // Knock the snake's score below the winning threshold so the same
        // "snake won" condition doesn't re-fire on the next frame.
        snakeScore = 0
        gameOver = false
        gameStarted = true
        startGameLoop()
        startDiamondTimer()
        if currentLevel >= 4 {
            SoundManager.shared.playLevel4Music()
        } else {
            SoundManager.shared.playBackgroundMusic()
        }
    }

    /// Hardcore-mode reward-ad continuation: restores the diamonds the player
    /// had before the loss but still sends them back to Level 1.
    func restoreHardcoreDiamondsAndRestart() {
        if lossCountSinceLastAd > 0 { lossCountSinceLastAd -= 1 }
        let toRestore = hardcoreDiamondsBeforeLoss
        diamondsCollected = toRestore
        hardcoreDiamondsBeforeLoss = 0
        restartGame()
    }

    func restartCurrentLevel() {
        let level = currentLevel
        gameOver = false
        gameStarted = false
        snakeScore = 0
        particles.removeAll()
        fireballs.removeAll()
        lightningBolts.removeAll()
        diamonds.removeAll()
        nebulaDust.removeAll()
        shapeSequence.removeAll()
        sequenceProgress = 0
        lightningRainActive = false
        lightningRainTimer?.invalidate()
        lightningRainTimer = nil
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
        if level >= 4 {
            snake?.speed = 8.0 * snakeSpeedMultiplier
        } else if level >= 3 {
            snake?.speed = 6.5 * snakeSpeedMultiplier
        } else if level >= 2 {
            snake?.speed = 8.0 * snakeSpeedMultiplier
        } else {
            snake?.speed = 4.5 * snakeSpeedMultiplier
        }
        if level >= 4 {
            snake2 = Snake(bounds: bounds)
            snake2?.speed = 7.0 * snakeSpeedMultiplier
            nebulaDust = (0..<30).map { _ in NebulaDust(bounds: bounds) }
        } else {
            snake2 = nil
            nebulaDust.removeAll()
        }

        startGameLoop()
        startDiamondTimer()
        if currentLevel >= 4 {
            SoundManager.shared.playLevel4Music()
            startLightningTimer()
        } else {
            SoundManager.shared.playBackgroundMusic()
        }
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
    var isLevel4: Bool = false

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

                // Level 4: flashing "Click Me" inside trap boxes
                if isLevel4 {
                    Text("Click Me")
                        .font(.system(size: max(7, currentSize * 0.16), weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .opacity(sin(shape.pulsePhase * 3) > 0 ? 1 : 0.1)
                        .offset(y: currentSize * 0.25)
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

// MARK: - Sequence Shape Icon (Level 4 HUD)
struct SequenceShapeIcon: View {
    let shapeType: ShapeType
    private let iconSize: CGFloat = 22

    var body: some View {
        Group {
            switch shapeType {
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(GameColors.neonYellow)
            case .circle:
                Circle()
                    .stroke(GameColors.neonCyan, lineWidth: 2)
                    .frame(width: iconSize, height: iconSize)
            case .triangle:
                TriangleShape()
                    .stroke(GameColors.neonGreen, lineWidth: 2)
                    .frame(width: iconSize, height: iconSize)
            case .square:
                Rectangle()
                    .stroke(GameColors.neonOrange, lineWidth: 2)
                    .frame(width: iconSize * 0.8, height: iconSize * 0.8)
            case .pentagon:
                PentagonShape()
                    .stroke(GameColors.neonPink, lineWidth: 2)
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .frame(width: iconSize, height: iconSize)
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
    var useRainbow: Bool = false
    var useWormy: Bool = false
    var useStar: Bool = false
    var useBlaze: Bool = false
    var useCosmos: Bool = false
    var useEmber: Bool = false

    var body: some View {
        let segments = snake.segments
        let maxVisible = min(50, segments.count)

        Canvas { context, size in
            guard maxVisible > 0 else { return }

            // Glow aura for Level 4 second snake (any skin)
            if glowing {
                for i in 0..<maxVisible {
                    let seg = segments[i]
                    let gs = snake.segmentSize * 4
                    context.fill(Circle().path(in: CGRect(x: seg.x - gs, y: seg.y - gs, width: gs * 2, height: gs * 2)), with: .color(Color.cyan.opacity(0.08)))
                }
            }

            if useRainbow && !glowing {
                // --- Rainbow snake (original) ---
                for i in 0..<maxVisible {
                    let segment = segments[i]
                    let hue = Double(i * 10).truncatingRemainder(dividingBy: 360) / 360
                    let brightness = 1 - (Double(i) / Double(maxVisible)) * 0.5
                    let color = Color(hue: hue, saturation: 1, brightness: brightness)

                    context.fill(
                        Circle().path(in: CGRect(
                            x: segment.x - snake.segmentSize,
                            y: segment.y - snake.segmentSize,
                            width: snake.segmentSize * 2,
                            height: snake.segmentSize * 2
                        )),
                        with: .color(color)
                    )

                    if i < maxVisible - 1 && i < 30 {
                        let next = segments[i + 1]
                        var path = Path()
                        path.move(to: CGPoint(x: segment.x, y: segment.y))
                        path.addLine(to: CGPoint(x: next.x, y: next.y))
                        context.stroke(path, with: .color(color), lineWidth: snake.segmentSize * 1.5)
                    }
                }
                if let head = segments.first {
                    context.fill(
                        Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 4, height: 4)),
                        with: .color(.white)
                    )
                    context.fill(
                        Circle().path(in: CGRect(x: head.x + 2, y: head.y - 6, width: 4, height: 4)),
                        with: .color(.white)
                    )
                }
                return
            }

            // --- Cosmos snake — deep-space body with sparkling stars and a
            // dispersing rainbow dust trail behind it.
            if useCosmos {
                drawCosmosSnake(context: &context, segments: segments,
                                maxVisible: maxVisible, snake: snake)
                return
            }

            // --- Ember snake — dark scaly skin with flickering fire orbs.
            if useEmber {
                drawEmberSnake(context: &context, segments: segments,
                               maxVisible: maxVisible, snake: snake)
                return
            }

            // --- Wormy snake — green watercolour worm with bulging eyes ---
            // --- Star snake — violet/blue shimmering skin with twinkling stars ---
            // --- Blaze snake — blue and red shining skin like candy style ---
            if useBlaze {
                for i in 0..<maxVisible {
                    let segment = segments[i]
                    let brightness = 1 - (Double(i) / Double(maxVisible)) * 0.35
                    let shimmer = sin(Double(snake.animPhase) * 4 + Double(i) * 0.5) * 0.5 + 0.5

                    // Alternating blue and red with shimmer
                    let isBlue = (i / 2) % 2 == 0
                    let color: Color
                    if isBlue {
                        color = Color(red: 0.1 + shimmer * 0.15, green: 0.2 + shimmer * 0.2, blue: 0.8 + shimmer * 0.2).opacity(brightness)
                    } else {
                        color = Color(red: 0.85 + shimmer * 0.15, green: 0.1 + shimmer * 0.1, blue: 0.1 + shimmer * 0.15).opacity(brightness)
                    }

                    // Shining glow
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize * 2, y: segment.y - snake.segmentSize * 2, width: snake.segmentSize * 4, height: snake.segmentSize * 4)),
                        with: .color(color.opacity(0.12)))

                    // Segment
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize, y: segment.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(color))

                    // Connecting line
                    if i < maxVisible - 1 {
                        let next = segments[i + 1]
                        var path = Path()
                        path.move(to: CGPoint(x: segment.x, y: segment.y))
                        path.addLine(to: CGPoint(x: next.x, y: next.y))
                        context.stroke(path, with: .color(color), lineWidth: snake.segmentSize * 1.5)
                    }

                    // Shine highlight on each segment
                    let shine = max(0, sin(snake.animPhase * 6 + CGFloat(i) * 1.2))
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize * 0.3, y: segment.y - snake.segmentSize * 0.8, width: snake.segmentSize * 0.6, height: snake.segmentSize * 0.4)),
                        with: .color(.white.opacity(Double(shine) * 0.35)))
                }

                // Head — shimmering purple (blue + red mix)
                if let head = segments.first {
                    let headShimmer = sin(Double(snake.animPhase) * 3) * 0.5 + 0.5
                    let headColor = Color(red: 0.5 + headShimmer * 0.3, green: 0.1, blue: 0.5 + headShimmer * 0.3)
                    context.fill(
                        Circle().path(in: CGRect(x: head.x - snake.segmentSize, y: head.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(headColor))
                    context.fill(Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 4, height: 4)), with: .color(.white))
                    context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 6, width: 4, height: 4)), with: .color(.white))
                }
                return
            }

            if useStar {
                // Half blue / half yellow rainbow style with sparkles
                for i in 0..<maxVisible {
                    let segment = segments[i]
                    let brightness = 1 - (Double(i) / Double(maxVisible)) * 0.4

                    // Half blue, half yellow — splits at midpoint
                    let halfPoint = maxVisible / 2
                    let shimmer = sin(Double(snake.animPhase) * 3 + Double(i) * 0.4) * 0.15
                    let color: Color
                    if i < halfPoint {
                        // Blue half — shifts between deep blue and sky blue
                        color = Color(red: 0.1 + shimmer, green: 0.3 + shimmer, blue: 0.85 + shimmer).opacity(brightness)
                    } else {
                        // Yellow half — shifts between gold and bright yellow
                        color = Color(red: 0.95 + shimmer, green: 0.8 + shimmer, blue: 0.1 + shimmer).opacity(brightness)
                    }

                    // Glow
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize * 2, y: segment.y - snake.segmentSize * 2, width: snake.segmentSize * 4, height: snake.segmentSize * 4)),
                        with: .color(color.opacity(0.15)))

                    // Segment
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize, y: segment.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(color))

                    // Connecting line
                    if i < maxVisible - 1 {
                        let next = segments[i + 1]
                        var path = Path()
                        path.move(to: CGPoint(x: segment.x, y: segment.y))
                        path.addLine(to: CGPoint(x: next.x, y: next.y))
                        context.stroke(path, with: .color(color), lineWidth: snake.segmentSize * 1.5)
                    }

                    // Sparkles on every 2nd segment
                    if i % 2 == 0 {
                        let twinkle = max(0, sin(snake.animPhase * 7 + CGFloat(i) * 1.8))
                        let starR = snake.segmentSize * 0.35 * twinkle
                        if starR > 0.3 {
                            let ox = cos(CGFloat(i) * 2.3) * snake.segmentSize * 0.4
                            let oy = sin(CGFloat(i) * 2.3) * snake.segmentSize * 0.4
                            let sx = segment.x + ox
                            let sy = segment.y + oy
                            // 4-point star
                            var s1 = Path()
                            s1.move(to: CGPoint(x: sx, y: sy - starR))
                            s1.addLine(to: CGPoint(x: sx + starR * 0.2, y: sy))
                            s1.addLine(to: CGPoint(x: sx, y: sy + starR))
                            s1.addLine(to: CGPoint(x: sx - starR * 0.2, y: sy))
                            s1.closeSubpath()
                            var s2 = Path()
                            s2.move(to: CGPoint(x: sx - starR, y: sy))
                            s2.addLine(to: CGPoint(x: sx, y: sy + starR * 0.2))
                            s2.addLine(to: CGPoint(x: sx + starR, y: sy))
                            s2.addLine(to: CGPoint(x: sx, y: sy - starR * 0.2))
                            s2.closeSubpath()
                            context.fill(s1, with: .color(.white.opacity(Double(twinkle) * 0.9)))
                            context.fill(s2, with: .color(.white.opacity(Double(twinkle) * 0.9)))
                        }
                    }
                }

                // Head — blue/yellow split
                if let head = segments.first {
                    let headShimmer = sin(Double(snake.animPhase) * 3) * 0.5 + 0.5
                    let headColor = Color(red: 0.1 + headShimmer * 0.85, green: 0.3 + headShimmer * 0.5, blue: 0.85 - headShimmer * 0.75)
                    context.fill(
                        Circle().path(in: CGRect(x: head.x - snake.segmentSize, y: head.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(headColor))
                    context.fill(Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 4, height: 4)), with: .color(.white))
                    context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 6, width: 4, height: 4)), with: .color(.white))
                }

                return
            }

            // OLD STAR CODE REMOVED

            if useWormy {
                // Universe snake — deep space body with twinkling stars
                for i in 0..<maxVisible {
                    let segment = segments[i]
                    let fade = 1 - (Double(i) / Double(maxVisible)) * 0.3

                    // Deep space colours — dark purple/blue base
                    let depthShift = sin(Double(snake.animPhase) * 0.5 + Double(i) * 0.2) * 0.5 + 0.5
                    let bodyColor = Color(red: 0.08 + depthShift * 0.1, green: 0.02 + depthShift * 0.05, blue: 0.2 + depthShift * 0.15)

                    // Nebula glow around each segment
                    let nebulaHue = (Double(i) * 0.05 + Double(snake.animPhase) * 0.1).truncatingRemainder(dividingBy: 1.0)
                    let nebulaColor = Color(hue: nebulaHue, saturation: 0.6, brightness: 0.8)
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize * 2.5, y: segment.y - snake.segmentSize * 2.5, width: snake.segmentSize * 5, height: snake.segmentSize * 5)),
                        with: .color(nebulaColor.opacity(fade * 0.1)))

                    // Dark body
                    context.fill(
                        Circle().path(in: CGRect(x: segment.x - snake.segmentSize, y: segment.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(bodyColor.opacity(fade)))

                    // Connecting line
                    if i < maxVisible - 1 {
                        let next = segments[i + 1]
                        var path = Path()
                        path.move(to: CGPoint(x: segment.x, y: segment.y))
                        path.addLine(to: CGPoint(x: next.x, y: next.y))
                        context.stroke(path, with: .color(bodyColor.opacity(fade)), lineWidth: snake.segmentSize * 1.5)
                    }

                    // Twinkling stars on every 2nd segment
                    if i % 2 == 0 {
                        let twinkle1 = max(0, sin(snake.animPhase * 6 + CGFloat(i) * 1.7))
                        let starHue1 = (Double(snake.animPhase) * 0.3 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1.0)
                        let starColor1 = Color(hue: starHue1, saturation: 0.5, brightness: 1)
                        let starR1 = snake.segmentSize * 0.3 * twinkle1
                        let ox1 = cos(CGFloat(i) * 2.1) * snake.segmentSize * 0.4
                        let oy1 = sin(CGFloat(i) * 2.1) * snake.segmentSize * 0.4

                        // Star glow
                        context.fill(
                            Circle().path(in: CGRect(x: segment.x + ox1 - starR1 * 2, y: segment.y + oy1 - starR1 * 2, width: starR1 * 4, height: starR1 * 4)),
                            with: .color(starColor1.opacity(Double(twinkle1) * 0.3)))

                        // 4-point star
                        if starR1 > 0.5 {
                            var s1 = Path()
                            s1.move(to: CGPoint(x: segment.x + ox1, y: segment.y + oy1 - starR1))
                            s1.addLine(to: CGPoint(x: segment.x + ox1 + starR1 * 0.2, y: segment.y + oy1))
                            s1.addLine(to: CGPoint(x: segment.x + ox1, y: segment.y + oy1 + starR1))
                            s1.addLine(to: CGPoint(x: segment.x + ox1 - starR1 * 0.2, y: segment.y + oy1))
                            s1.closeSubpath()
                            context.fill(s1, with: .color(.white.opacity(Double(twinkle1) * 0.9)))
                            var s2 = Path()
                            s2.move(to: CGPoint(x: segment.x + ox1 - starR1, y: segment.y + oy1))
                            s2.addLine(to: CGPoint(x: segment.x + ox1, y: segment.y + oy1 + starR1 * 0.2))
                            s2.addLine(to: CGPoint(x: segment.x + ox1 + starR1, y: segment.y + oy1))
                            s2.addLine(to: CGPoint(x: segment.x + ox1, y: segment.y + oy1 - starR1 * 0.2))
                            s2.closeSubpath()
                            context.fill(s2, with: .color(.white.opacity(Double(twinkle1) * 0.9)))
                        }
                    }

                    // Second star on opposite side every 3rd segment
                    if i % 3 == 0 {
                        let twinkle2 = max(0, sin(snake.animPhase * 5 + CGFloat(i) * 2.5))
                        let ox2 = cos(CGFloat(i) * 3.5) * snake.segmentSize * 0.5
                        let oy2 = sin(CGFloat(i) * 3.5) * snake.segmentSize * 0.5
                        context.fill(
                            Circle().path(in: CGRect(x: segment.x + ox2 - 1, y: segment.y + oy2 - 1, width: 2, height: 2)),
                            with: .color(.white.opacity(Double(twinkle2) * 0.7)))
                    }
                }

                // Head — dark with bright star
                if let head = segments.first {
                    context.fill(
                        Circle().path(in: CGRect(x: head.x - snake.segmentSize, y: head.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                        with: .color(Color(red: 0.1, green: 0.05, blue: 0.25)))
                    // Bright twinkling eyes
                    let eyeTwinkle = (sin(snake.animPhase * 4) + 1) / 2
                    let eyeColor = Color(hue: Double(snake.animPhase * 0.3).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 1)
                    context.fill(Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 4, height: 4)), with: .color(eyeColor.opacity(0.5 + eyeTwinkle * 0.5)))
                    context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 6, width: 4, height: 4)), with: .color(eyeColor.opacity(0.5 + eyeTwinkle * 0.5)))
                }

                return
            }

            // --- Candy snake (default) — only if not wormy ---
            guard !useWormy && !useStar && !useBlaze else {
                if glowing {
                    // Glow aura
                    let glowCol: Color = useStar ? Color(red: 0.4, green: 0.3, blue: 0.9) : .cyan
                    for i in 0..<maxVisible {
                        let seg = segments[i]
                        let glowSize = snake.segmentSize * 4
                        context.fill(
                            Circle().path(in: CGRect(x: seg.x - glowSize, y: seg.y - glowSize, width: glowSize * 2, height: glowSize * 2)),
                            with: .color(glowCol.opacity(0.1))
                        )
                    }
                }

                // If Star snake selected, draw star snake body + head instead of wormy
                if useStar {
                    let ssS = snake.segmentSize
                    for i in stride(from: maxVisible - 1, through: 1, by: -1) {
                        let seg = segments[i]
                        let fade = 1 - (Double(i) / Double(maxVisible)) * 0.2
                        let taper = 1.0 - CGFloat(i) / CGFloat(maxVisible) * 0.45
                        let bodyW = ssS * 2.2 * taper
                        let bodyH = ssS * 1.4 * taper
                        let nextI = min(i + 1, segments.count - 1)
                        let prevI = max(i - 1, 0)
                        let angle = atan2(segments[prevI].y - segments[nextI].y, segments[prevI].x - segments[nextI].x)
                        let wave = sin(snake.animPhase * 3 + CGFloat(i) * 0.5) * taper * 3.0
                        let perpX = -sin(angle) * wave
                        let perpY = cos(angle) * wave
                        let oblongT = CGAffineTransform(translationX: seg.x + perpX, y: seg.y + perpY).rotated(by: angle)
                        let shimmer = sin(snake.animPhase * 2 + CGFloat(i) * 0.4) * 0.5 + 0.5
                        let violet = Color(red: 0.35 + shimmer * 0.15, green: 0.2 + shimmer * 0.15, blue: 0.7 + shimmer * 0.15)

                        // Shadow
                        let shT = CGAffineTransform(translationX: seg.x + perpX + 1.5, y: seg.y + perpY + 3).rotated(by: angle)
                        var sh = Path(); sh.addEllipse(in: CGRect(x: -bodyW * 1.2, y: -bodyH * 0.6, width: bodyW * 2.4, height: bodyH * 1.2))
                        context.fill(sh.applying(shT), with: .color(Color.black.opacity(fade * 0.25)))
                        // Dark bottom
                        var db = Path(); db.addEllipse(in: CGRect(x: -bodyW, y: bodyH * 0.0, width: bodyW * 2, height: bodyH * 0.6))
                        context.fill(db.applying(oblongT), with: .color(Color(red: 0.08, green: 0.03, blue: 0.25).opacity(fade * 0.5)))
                        // Main body
                        var body = Path(); body.addEllipse(in: CGRect(x: -bodyW, y: -bodyH / 2, width: bodyW * 2, height: bodyH))
                        context.fill(body.applying(oblongT), with: .color(violet.opacity(fade * 0.7)))
                        // Highlight
                        var hl = Path(); hl.addEllipse(in: CGRect(x: -bodyW * 0.5, y: -bodyH * 0.5, width: bodyW, height: bodyH * 0.3))
                        context.fill(hl.applying(oblongT), with: .color(Color(red: 0.6, green: 0.55, blue: 0.95).opacity(fade * 0.4)))
                        // Specular
                        var sp = Path(); sp.addEllipse(in: CGRect(x: -bodyW * 0.12, y: -bodyH * 0.47, width: bodyW * 0.24, height: bodyH * 0.12))
                        context.fill(sp.applying(oblongT), with: .color(Color.white.opacity(fade * 0.35)))
                    }
                    // Star head photo
                    if let head = segments.first, segments.count >= 2 {
                        let lookI = min(5, segments.count - 1)
                        let angle = atan2(head.y - segments[lookI].y, head.x - segments[lookI].x)
                        if let headImg = UIImage(named: "star_snake_head") ?? (Bundle.main.path(forResource: "star_snake_head", ofType: "png").flatMap { UIImage(contentsOfFile: $0) }) {
                            let headW: CGFloat = 32
                            let headH: CGFloat = headW * (headImg.size.height / headImg.size.width)
                            let resolved = context.resolve(Image(uiImage: headImg))
                            context.translateBy(x: head.x, y: head.y)
                            context.rotate(by: Angle(radians: Double(angle)))
                            context.draw(resolved, in: CGRect(x: -headW * 0.25, y: -headH / 2, width: headW, height: headH))
                            context.rotate(by: Angle(radians: -Double(angle)))
                            context.translateBy(x: -head.x, y: -head.y)
                        }
                    }
                    return
                }

                // Draw full wormy snake (same as non-glowing) for both snakes
                let lightGreenW = Color(red: 0.55, green: 0.75, blue: 0.35)
                let darkGreenW = Color(red: 0.35, green: 0.55, blue: 0.2)
                let ssW = snake.segmentSize

                // Body
                for i in stride(from: maxVisible - 1, through: 1, by: -1) {
                    let seg = segments[i]
                    let fade = 1 - (Double(i) / Double(maxVisible)) * 0.2
                    let taper = 1.0 - CGFloat(i) / CGFloat(maxVisible) * 0.5
                    let bodyW = ssW * 2.2 * taper
                    let bodyH = ssW * 1.4 * taper
                    let nextI = min(i + 1, segments.count - 1)
                    let prevI = max(i - 1, 0)
                    let angle = atan2(segments[prevI].y - segments[nextI].y, segments[prevI].x - segments[nextI].x)
                    let wave = sin(snake.animPhase * 3 + CGFloat(i) * 0.5) * taper * 3.0
                    let perpX = -sin(angle) * wave
                    let perpY = cos(angle) * wave
                    let isDarkBand = (i % 4 == 0)
                    let bodyColor = (isDarkBand ? darkGreenW : lightGreenW).opacity(fade)
                    let oblongT = CGAffineTransform(translationX: seg.x + perpX, y: seg.y + perpY).rotated(by: angle)

                    var blur = Path()
                    blur.addEllipse(in: CGRect(x: -bodyW * 1.3, y: -bodyH * 0.7, width: bodyW * 2.6, height: bodyH * 1.4))
                    context.fill(blur.applying(oblongT), with: .color(darkGreenW.opacity(fade * 0.12)))
                    var body = Path()
                    body.addEllipse(in: CGRect(x: -bodyW, y: -bodyH / 2, width: bodyW * 2, height: bodyH))
                    context.fill(body.applying(oblongT), with: .color(darkGreenW.opacity(fade * 0.7)))
                    var tummy = Path()
                    tummy.addEllipse(in: CGRect(x: -bodyW * 0.7, y: 0, width: bodyW * 1.4, height: bodyH * 0.55))
                    context.fill(tummy.applying(oblongT), with: .color(lightGreenW.opacity(fade * 0.8)))
                    var ring = Path()
                    ring.move(to: CGPoint(x: 0, y: -bodyH * 0.65))
                    ring.addQuadCurve(to: CGPoint(x: 0, y: bodyH * 0.65), control: CGPoint(x: bodyW * 0.25, y: 0))
                    context.stroke(ring.applying(oblongT), with: .color(Color.black.opacity(fade * 0.35)), lineWidth: max(0.3, 1.3 * taper))
                }

                // Head
                if let head = segments.first, segments.count >= 2 {
                    let lookI = min(3, segments.count - 1)
                    let angle = atan2(head.y - segments[lookI].y, head.x - segments[lookI].x)
                    let hs = ssW * 2.8
                    let ht = CGAffineTransform(translationX: head.x, y: head.y).rotated(by: angle)

                    var headShape = Path()
                    headShape.addEllipse(in: CGRect(x: -hs * 0.55, y: -hs * 0.7, width: hs * 1.1, height: hs * 1.4))
                    context.fill(headShape.applying(ht), with: .color(lightGreenW.opacity(0.75)))

                    for side in [-1.0, 1.0] {
                        let eyeLocal = CGPoint(x: hs * 0.15, y: CGFloat(side) * hs * 0.3 - hs * 0.45)
                        let ep = eyeLocal.applying(ht)
                        let eyeR: CGFloat = hs * 0.26
                        context.fill(Circle().path(in: CGRect(x: ep.x - eyeR, y: ep.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(Color(red: 0.92, green: 0.9, blue: 0.5).opacity(0.8)))
                        let ringR = eyeR * 0.55
                        context.fill(Circle().path(in: CGRect(x: ep.x - ringR, y: ep.y - ringR - 1, width: ringR * 2, height: ringR * 2)), with: .color(Color(red: 0.95, green: 0.92, blue: 0.45)))
                        let pupilR = eyeR * 0.25
                        context.fill(Circle().path(in: CGRect(x: ep.x - pupilR + 1, y: ep.y - pupilR - 1, width: pupilR * 2, height: pupilR * 2)), with: .color(.black))
                    }
                }

                return
            }

            // Glow layer for Level 4 second snake
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

            // Candy snake — exact match to hand drawing, bright colours
            if !glowing {
                let yellow = Color(red: 0.95, green: 0.8, blue: 0.0)
                let green = Color(red: 0.1, green: 0.7, blue: 0.15)
                let darkOutline = Color(red: 0.1, green: 0.1, blue: 0.05)
                let ss = snake.segmentSize

                // Body — wavy oblongs that get smaller towards tail
                for i in stride(from: maxVisible - 1, through: 1, by: -1) {
                    let seg = segments[i]
                    let fade = 1 - (Double(i) / Double(maxVisible)) * 0.2

                    // Taper: big at head, gradually smaller at tail
                    let taper = 1.0 - CGFloat(i) / CGFloat(maxVisible) * 0.45
                    let oblongW = ss * 2.5 * taper   // width along body direction
                    let oblongH = ss * 1.5 * taper   // height perpendicular

                    // Direction at this segment
                    let nextI = min(i + 1, segments.count - 1)
                    let prevI = max(i - 1, 0)
                    let angle = atan2(segments[prevI].y - segments[nextI].y, segments[prevI].x - segments[nextI].x)

                    // Wave offset perpendicular to movement
                    let wave = sin(snake.animPhase * 3 + CGFloat(i) * 0.5) * taper * 3.0
                    let perpX = -sin(angle) * wave
                    let perpY = cos(angle) * wave

                    // Green bands or yellow
                    let isGreenBand = (i % 6 < 2)
                    let bodyColor = (isGreenBand ? green : yellow).opacity(fade)

                    // Draw soft ellipse — no hard edges
                    let oblongT = CGAffineTransform(translationX: seg.x + perpX, y: seg.y + perpY).rotated(by: angle)

                    // Outer soft blur
                    var blur = Path()
                    blur.addEllipse(in: CGRect(x: -oblongW * 1.3, y: -oblongH * 0.7, width: oblongW * 2.6, height: oblongH * 1.4))
                    context.fill(blur.applying(oblongT), with: .color(bodyColor.opacity(fade * 0.25)))

                    // Main body fill — soft ellipse
                    var oblong = Path()
                    oblong.addEllipse(in: CGRect(x: -oblongW, y: -oblongH / 2, width: oblongW * 2, height: oblongH))
                    context.fill(oblong.applying(oblongT), with: .color(bodyColor))
                }

                // Pointed tail tip
                if maxVisible > 3 {
                    let tail = segments[maxVisible - 1]
                    let prev = segments[maxVisible - 2]
                    let tAngle = atan2(prev.y - tail.y, prev.x - tail.x)
                    let tipLen: CGFloat = ss * 3
                    var tip = Path()
                    tip.move(to: CGPoint(x: 0, y: -ss * 0.3))
                    tip.addLine(to: CGPoint(x: -tipLen, y: 0))
                    tip.addLine(to: CGPoint(x: 0, y: ss * 0.3))
                    tip.closeSubpath()
                    let tipT = CGAffineTransform(translationX: tail.x, y: tail.y).rotated(by: tAngle + .pi)
                    context.fill(tip.applying(tipT), with: .color(yellow.opacity(0.6)))
                }

                // Head — exact copy of drawing: triangular, green top, yellow bottom
                if let head = segments.first, segments.count >= 2 {
                    let lookI = min(3, segments.count - 1)
                    let angle = atan2(head.y - segments[lookI].y, head.x - segments[lookI].x)
                    let cosA = cos(angle)
                    let sinA = sin(angle)
                    let hs = ss * 2.2

                    let ht = CGAffineTransform(translationX: head.x, y: head.y).rotated(by: angle)

                    // Full head outline — pointed snout, curvy bottom, steep top
                    var headShape = Path()
                    headShape.move(to: CGPoint(x: hs * 1.4, y: 0))  // snout tip
                    // Bottom — big round curve (belly/jaw)
                    headShape.addCurve(
                        to: CGPoint(x: -hs * 0.6, y: hs * 0.35),
                        control1: CGPoint(x: hs * 0.9, y: hs * 0.55),
                        control2: CGPoint(x: hs * 0.1, y: hs * 0.7))
                    // Back of head
                    headShape.addCurve(
                        to: CGPoint(x: -hs * 0.6, y: -hs * 0.55),
                        control1: CGPoint(x: -hs * 0.75, y: hs * 0.1),
                        control2: CGPoint(x: -hs * 0.75, y: -hs * 0.25))
                    // Top — lump/bump then curves steeply down to pointed snout
                    headShape.addCurve(
                        to: CGPoint(x: hs * 0.2, y: -hs * 0.75),
                        control1: CGPoint(x: -hs * 0.3, y: -hs * 0.7),
                        control2: CGPoint(x: 0, y: -hs * 0.85))
                    headShape.addCurve(
                        to: CGPoint(x: hs * 1.4, y: 0),
                        control1: CGPoint(x: hs * 0.5, y: -hs * 0.65),
                        control2: CGPoint(x: hs * 1.1, y: -hs * 0.25))
                    headShape.closeSubpath()

                    // Yellow bottom — curvy jaw
                    var bottomHalf = Path()
                    bottomHalf.move(to: CGPoint(x: hs * 1.4, y: 0))
                    bottomHalf.addCurve(
                        to: CGPoint(x: -hs * 0.6, y: hs * 0.35),
                        control1: CGPoint(x: hs * 0.9, y: hs * 0.55),
                        control2: CGPoint(x: hs * 0.1, y: hs * 0.7))
                    bottomHalf.addLine(to: CGPoint(x: -hs * 0.6, y: 0))
                    bottomHalf.addLine(to: CGPoint(x: hs * 1.4, y: 0))
                    bottomHalf.closeSubpath()
                    context.fill(bottomHalf.applying(ht), with: .color(Color(red: 0.95, green: 0.82, blue: 0.0)))

                    // Green top — steep slope
                    var topHalf = Path()
                    topHalf.move(to: CGPoint(x: hs * 1.4, y: 0))
                    topHalf.addLine(to: CGPoint(x: -hs * 0.6, y: 0))
                    topHalf.addCurve(
                        to: CGPoint(x: -hs * 0.6, y: -hs * 0.55),
                        control1: CGPoint(x: -hs * 0.7, y: -hs * 0.05),
                        control2: CGPoint(x: -hs * 0.75, y: -hs * 0.3))
                    // Lump then steep drop to point
                    topHalf.addCurve(
                        to: CGPoint(x: hs * 0.2, y: -hs * 0.75),
                        control1: CGPoint(x: -hs * 0.3, y: -hs * 0.7),
                        control2: CGPoint(x: 0, y: -hs * 0.85))
                    topHalf.addCurve(
                        to: CGPoint(x: hs * 1.4, y: 0),
                        control1: CGPoint(x: hs * 0.5, y: -hs * 0.65),
                        control2: CGPoint(x: hs * 1.1, y: -hs * 0.25))
                    topHalf.closeSubpath()
                    context.fill(topHalf.applying(ht), with: .color(Color(red: 0.05, green: 0.72, blue: 0.18)))

                    // Dark outline around whole head
                    context.stroke(headShape.applying(ht), with: .color(darkOutline), lineWidth: 2.0)

                    // Big round eye — sits high and back on the head
                    let eyePos = CGPoint(x: hs * 0.1, y: -hs * 0.2).applying(ht)
                    let eyeR: CGFloat = hs * 0.32
                    // Black ring around eye
                    context.fill(
                        Circle().path(in: CGRect(x: eyePos.x - eyeR - 1, y: eyePos.y - eyeR - 1, width: (eyeR + 1) * 2, height: (eyeR + 1) * 2)),
                        with: .color(darkOutline))
                    // White outer
                    context.fill(
                        Circle().path(in: CGRect(x: eyePos.x - eyeR, y: eyePos.y - eyeR, width: eyeR * 2, height: eyeR * 2)),
                        with: .color(.white))
                    // Blue-teal iris
                    let irisR = eyeR * 0.72
                    context.fill(
                        Circle().path(in: CGRect(x: eyePos.x - irisR, y: eyePos.y - irisR, width: irisR * 2, height: irisR * 2)),
                        with: .color(Color(red: 0.0, green: 0.35, blue: 0.65)))
                    // Black pupil — big
                    let pupilR = eyeR * 0.5
                    context.fill(
                        Circle().path(in: CGRect(x: eyePos.x - pupilR, y: eyePos.y - pupilR, width: pupilR * 2, height: pupilR * 2)),
                        with: .color(.black))
                    // White highlight
                    let hlR = eyeR * 0.2
                    context.fill(
                        Circle().path(in: CGRect(x: eyePos.x + hlR, y: eyePos.y - hlR * 2, width: hlR * 2, height: hlR * 2)),
                        with: .color(.white))

                    // Smile — curved line on the yellow jaw area
                    var smile = Path()
                    let smileStart = CGPoint(x: hs * 0.9, y: hs * 0.1).applying(ht)
                    let smileEnd = CGPoint(x: hs * 0.2, y: hs * 0.25).applying(ht)
                    let smileCtrl = CGPoint(x: hs * 0.55, y: hs * 0.35).applying(ht)
                    smile.move(to: smileStart)
                    smile.addQuadCurve(to: smileEnd, control: smileCtrl)
                    context.stroke(smile, with: .color(darkOutline), lineWidth: 1.5)

                    // Tongue — always visible, black forked, sticks out from mouth
                    let tongueLen: CGFloat = hs * 1.2 + sin(snake.animPhase * 4) * hs * 0.4  // wiggles
                    let fLen = hs * 0.4
                    let tStart = CGPoint(x: head.x + cosA * hs * 1.4, y: head.y + sinA * hs * 1.4)
                    let tEnd = CGPoint(x: tStart.x + cosA * tongueLen, y: tStart.y + sinA * tongueLen)
                    // Main tongue
                    var t = Path(); t.move(to: tStart); t.addLine(to: tEnd)
                    context.stroke(t, with: .color(.black), lineWidth: 1.5)
                    // Left fork
                    var lf = Path(); lf.move(to: tEnd)
                    lf.addLine(to: CGPoint(x: tEnd.x + cosA * fLen + sinA * fLen * 0.5, y: tEnd.y + sinA * fLen - cosA * fLen * 0.5))
                    context.stroke(lf, with: .color(.black), lineWidth: 1.2)
                    // Right fork
                    var rf = Path(); rf.move(to: tEnd)
                    rf.addLine(to: CGPoint(x: tEnd.x + cosA * fLen - sinA * fLen * 0.5, y: tEnd.y + sinA * fLen + cosA * fLen * 0.5))
                    context.stroke(rf, with: .color(.black), lineWidth: 1.2)
                }
            }

            // Glowing snake (Level 4 second snake)
            if glowing {
                // Cyan glow aura
                for i in 0..<maxVisible {
                    let seg = segments[i]
                    let glowSize = snake.segmentSize * 4
                    context.fill(
                        Circle().path(in: CGRect(x: seg.x - glowSize, y: seg.y - glowSize, width: glowSize * 2, height: glowSize * 2)),
                        with: .color(Color.cyan.opacity(0.1))
                    )
                }

                if useRainbow {
                    // Glowing rainbow segments
                    for i in 0..<maxVisible {
                        let seg = segments[i]
                        let hue = (Double(i * 8) + 180).truncatingRemainder(dividingBy: 360) / 360
                        let brightness = 1 - (Double(i) / Double(maxVisible)) * 0.5
                        let color = Color(hue: hue, saturation: 0.6, brightness: brightness)
                        context.fill(
                            Circle().path(in: CGRect(x: seg.x - snake.segmentSize, y: seg.y - snake.segmentSize, width: snake.segmentSize * 2, height: snake.segmentSize * 2)),
                            with: .color(color)
                        )
                        if i < maxVisible - 1 {
                            let next = segments[i + 1]
                            var path = Path()
                            path.move(to: CGPoint(x: seg.x, y: seg.y))
                            path.addLine(to: CGPoint(x: next.x, y: next.y))
                            context.stroke(path, with: .color(color), lineWidth: snake.segmentSize * 1.5)
                        }
                    }
                    if let head = segments.first {
                        context.fill(Circle().path(in: CGRect(x: head.x - 6, y: head.y - 7, width: 5, height: 5)), with: .color(.cyan))
                        context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 7, width: 5, height: 5)), with: .color(.cyan))
                    }
                } else {
                    // Glowing candy snake — same body/head but with glow
                    let yellow = Color(red: 0.95, green: 0.8, blue: 0.0)
                    let green = Color(red: 0.1, green: 0.7, blue: 0.15)
                    let ss = snake.segmentSize

                    for i in stride(from: maxVisible - 1, through: 1, by: -1) {
                        let seg = segments[i]
                        let fade = 1 - (Double(i) / Double(maxVisible)) * 0.2
                        let taper = 1.0 - CGFloat(i) / CGFloat(maxVisible) * 0.45
                        let oblongW = ss * 2.5 * taper
                        let oblongH = ss * 1.5 * taper
                        let nextI = min(i + 1, segments.count - 1)
                        let prevI = max(i - 1, 0)
                        let angle = atan2(segments[prevI].y - segments[nextI].y, segments[prevI].x - segments[nextI].x)
                        let wave = sin(snake.animPhase * 3 + CGFloat(i) * 0.5) * taper * 3.0
                        let perpX = -sin(angle) * wave
                        let perpY = cos(angle) * wave
                        let isGreenBand = (i % 6 < 2)
                        let bodyColor = (isGreenBand ? green : yellow).opacity(fade)
                        let oblongT = CGAffineTransform(translationX: seg.x + perpX, y: seg.y + perpY).rotated(by: angle)
                        var blur = Path()
                        blur.addEllipse(in: CGRect(x: -oblongW * 1.3, y: -oblongH * 0.7, width: oblongW * 2.6, height: oblongH * 1.4))
                        context.fill(blur.applying(oblongT), with: .color(bodyColor.opacity(fade * 0.25)))
                        var oblong = Path()
                        oblong.addEllipse(in: CGRect(x: -oblongW, y: -oblongH / 2, width: oblongW * 2, height: oblongH))
                        context.fill(oblong.applying(oblongT), with: .color(bodyColor))
                    }

                    // Candy head on glowing snake
                    if let head = segments.first, segments.count >= 2 {
                        let lookI = min(3, segments.count - 1)
                        let angle = atan2(head.y - segments[lookI].y, head.x - segments[lookI].x)
                        let hs = ss * 2.2
                        let ht = CGAffineTransform(translationX: head.x, y: head.y).rotated(by: angle)

                        var headShape = Path()
                        headShape.move(to: CGPoint(x: hs * 1.4, y: 0))
                        headShape.addCurve(to: CGPoint(x: -hs * 0.6, y: hs * 0.35), control1: CGPoint(x: hs * 0.9, y: hs * 0.55), control2: CGPoint(x: hs * 0.1, y: hs * 0.7))
                        headShape.addCurve(to: CGPoint(x: -hs * 0.6, y: -hs * 0.55), control1: CGPoint(x: -hs * 0.75, y: hs * 0.1), control2: CGPoint(x: -hs * 0.75, y: -hs * 0.25))
                        headShape.addCurve(to: CGPoint(x: hs * 0.2, y: -hs * 0.75), control1: CGPoint(x: -hs * 0.3, y: -hs * 0.7), control2: CGPoint(x: 0, y: -hs * 0.85))
                        headShape.addCurve(to: CGPoint(x: hs * 1.4, y: 0), control1: CGPoint(x: hs * 0.5, y: -hs * 0.65), control2: CGPoint(x: hs * 1.1, y: -hs * 0.25))
                        headShape.closeSubpath()
                        context.fill(headShape.applying(ht), with: .color(Color(red: 0.05, green: 0.72, blue: 0.18)))

                        let eyePos = CGPoint(x: hs * 0.1, y: -hs * 0.2).applying(ht)
                        let eyeR: CGFloat = hs * 0.32
                        context.fill(Circle().path(in: CGRect(x: eyePos.x - eyeR, y: eyePos.y - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(.white))
                        context.fill(Circle().path(in: CGRect(x: eyePos.x - eyeR * 0.5, y: eyePos.y - eyeR * 0.5, width: eyeR, height: eyeR)), with: .color(.black))
                    }
                }
            }
        }
    }

    /// Drawing helper for the Cosmos snake — extracted to keep the
    /// Canvas closure's type-checker load manageable.
    private func drawCosmosSnake(context: inout GraphicsContext,
                                 segments: [SnakeSegment],
                                 maxVisible: Int,
                                 snake: Snake) {
        let s: CGFloat = snake.segmentSize
        let phase: Double = Double(snake.animPhase)

        // Dust trail.
        let trailMax: Int = min(maxVisible, 28)
        for i in 1..<trailMax {
            let segment = segments[i]
            let progress: Double = Double(i) / Double(trailMax)
            let fade: Double = 1.0 - progress
            for j in 0..<3 {
                let seed: Double = Double(i * 7 + j * 31)
                let t: Double = phase * 0.4 + seed
                let drift: Double = Double(i) * 1.4 + Double(j) * 1.5
                let ox: Double = sin(t) * drift
                let oy: Double = cos(t * 1.3 + seed * 0.1) * drift
                let hueRaw: Double = Double(i) * 0.07 + Double(j) * 0.31 + phase * 0.02
                let hue: Double = hueRaw.truncatingRemainder(dividingBy: 1.0)
                let dustColor = Color(hue: hue, saturation: 0.95, brightness: 1.0)
                let dustSize: CGFloat = CGFloat(2.0 + fade * 4.0)
                let cx: CGFloat = segment.x + CGFloat(ox)
                let cy: CGFloat = segment.y + CGFloat(oy)
                let halo: CGFloat = dustSize * 2.4
                context.fill(
                    Circle().path(in: CGRect(x: cx - halo / 2, y: cy - halo / 2,
                                             width: halo, height: halo)),
                    with: .color(dustColor.opacity(fade * 0.18))
                )
                context.fill(
                    Circle().path(in: CGRect(x: cx - dustSize / 2, y: cy - dustSize / 2,
                                             width: dustSize, height: dustSize)),
                    with: .color(dustColor.opacity(fade * 0.85))
                )
            }
        }

        // Per-segment swarm of orbiting twinkling stars.
        let palette: [(Color, Color)] = [
            (Color(red: 0.85, green: 0.95, blue: 1.00), Color(red: 0.45, green: 0.75, blue: 1.00)),
            (Color(red: 1.00, green: 0.80, blue: 0.95), Color(red: 1.00, green: 0.40, blue: 0.85)),
            (Color(red: 1.00, green: 0.95, blue: 0.65), Color(red: 1.00, green: 0.80, blue: 0.30)),
            (Color(red: 0.75, green: 1.00, blue: 0.95), Color(red: 0.20, green: 1.00, blue: 0.85)),
            (Color(red: 0.95, green: 0.80, blue: 1.00), Color(red: 0.75, green: 0.40, blue: 1.00)),
            (Color(red: 1.00, green: 0.85, blue: 0.85), Color(red: 1.00, green: 0.30, blue: 0.55)),
        ]
        let starsPerSegment: Int = 4
        for i in 0..<maxVisible {
            let segment = segments[i]
            for k in 0..<starsPerSegment {
                let kd: Double = Double(k)
                let orbitPhase: Double = phase * 1.6 + Double(i) * 0.35 + kd * 1.5708
                let orbitRadius: CGFloat = s * CGFloat(0.7 + kd * 0.32)
                let sx: CGFloat = segment.x + CGFloat(cos(orbitPhase)) * orbitRadius
                let sy: CGFloat = segment.y + CGFloat(sin(orbitPhase)) * orbitRadius
                let twinkleArg: Double = phase * 5.5 + Double(i * 11 + k * 23)
                let twinkle: Double = sin(twinkleArg) * 0.5 + 0.5

                let pIdx: Int = (i * 3 + k * 7) % palette.count
                let core: Color = palette[pIdx].0
                let halo: Color = palette[pIdx].1

                let haloSize: CGFloat = CGFloat(2.0 + twinkle * 2.5)
                context.fill(
                    Circle().path(in: CGRect(x: sx - haloSize, y: sy - haloSize,
                                             width: haloSize * 2, height: haloSize * 2)),
                    with: .color(halo.opacity(0.10 + twinkle * 0.18))
                )
                let innerHaloSize: CGFloat = CGFloat(1.0 + twinkle * 1.0)
                context.fill(
                    Circle().path(in: CGRect(x: sx - innerHaloSize, y: sy - innerHaloSize,
                                             width: innerHaloSize * 2, height: innerHaloSize * 2)),
                    with: .color(halo.opacity(0.30 + twinkle * 0.30))
                )
                let coreSize: CGFloat = 1.0
                context.fill(
                    Circle().path(in: CGRect(x: sx - coreSize / 2, y: sy - coreSize / 2,
                                             width: coreSize, height: coreSize)),
                    with: .color(core.opacity(0.75 + twinkle * 0.25))
                )
                let spikeLen: CGFloat = CGFloat(1.0 + twinkle * 3.0)
                var spike = Path()
                spike.move(to: CGPoint(x: sx - spikeLen, y: sy))
                spike.addLine(to: CGPoint(x: sx + spikeLen, y: sy))
                spike.move(to: CGPoint(x: sx, y: sy - spikeLen))
                spike.addLine(to: CGPoint(x: sx, y: sy + spikeLen))
                context.stroke(spike,
                               with: .color(core.opacity(0.4 + twinkle * 0.5)),
                               lineWidth: 0.35)
            }
        }

        // Cosmic head.
        if let head = segments.first {
            let headRadius: CGFloat = s * 1.3
            context.fill(
                Circle().path(in: CGRect(x: head.x - headRadius, y: head.y - headRadius,
                                         width: headRadius * 2, height: headRadius * 2)),
                with: .color(Color(red: 0.06, green: 0.02, blue: 0.18))
            )
            let eyeOuter = Color(red: 1.0, green: 0.4, blue: 0.9)
            let eyeInner = Color(red: 0.5, green: 1.0, blue: 1.0)
            context.fill(Circle().path(in: CGRect(x: head.x - 9, y: head.y - 9, width: 8, height: 8)),
                         with: .color(eyeOuter.opacity(0.5)))
            context.fill(Circle().path(in: CGRect(x: head.x + 1, y: head.y - 9, width: 8, height: 8)),
                         with: .color(eyeOuter.opacity(0.5)))
            context.fill(Circle().path(in: CGRect(x: head.x - 8, y: head.y - 8, width: 6, height: 6)),
                         with: .color(eyeInner))
            context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 8, width: 6, height: 6)),
                         with: .color(eyeInner))
            context.fill(Circle().path(in: CGRect(x: head.x - 6, y: head.y - 6, width: 2, height: 3)),
                         with: .color(.black))
            context.fill(Circle().path(in: CGRect(x: head.x + 4, y: head.y - 6, width: 2, height: 3)),
                         with: .color(.black))
        }
    }

    /// Drawing helper for the Ember snake — extracted from `body` to keep
    /// the Canvas closure's type-checker load manageable.
    private func drawEmberSnake(context: inout GraphicsContext,
                                segments: [SnakeSegment],
                                maxVisible: Int,
                                snake: Snake) {
        let s: CGFloat = snake.segmentSize
        let phase: Double = Double(snake.animPhase)

        for i in 0..<maxVisible {
            let segment = segments[i]
            let progress: Double = Double(i) / Double(max(maxVisible, 1))
            let darken: Double = 1.0 - progress * 0.4

            let bodyR: Double = 0.18 * darken
            let bodyG: Double = 0.05 * darken
            let bodyB: Double = 0.04 * darken
            let bodyColor = Color(red: bodyR, green: bodyG, blue: bodyB)

            let halo: CGFloat = s * 2.2
            let heatColor = Color(red: 1.0, green: 0.4, blue: 0.05)
            context.fill(
                Circle().path(in: CGRect(x: segment.x - halo, y: segment.y - halo,
                                         width: halo * 2, height: halo * 2)),
                with: .color(heatColor.opacity(0.10))
            )
            context.fill(
                Circle().path(in: CGRect(x: segment.x - s, y: segment.y - s,
                                         width: s * 2, height: s * 2)),
                with: .color(bodyColor)
            )

            // Diamond scale pattern.
            let scaleSize: CGFloat = s * 0.55
            let h: CGFloat = scaleSize * 0.5
            let scR: Double = 0.55 * darken
            let scG: Double = 0.10 * darken
            let scB: Double = 0.05 * darken
            let scaleColor = Color(red: scR, green: scG, blue: scB)
            let offsets: [(CGFloat, CGFloat)] = [
                (-0.4, -0.3), (0.4, -0.3),
                (-0.4, 0.3),  (0.4, 0.3)
            ]
            for (idx, offset) in offsets.enumerated() {
                let cx: CGFloat = segment.x + offset.0 * s
                let cy: CGFloat = segment.y + offset.1 * s
                var diamond = Path()
                diamond.move(to: CGPoint(x: cx, y: cy - h))
                diamond.addLine(to: CGPoint(x: cx + h, y: cy))
                diamond.addLine(to: CGPoint(x: cx, y: cy + h))
                diamond.addLine(to: CGPoint(x: cx - h, y: cy))
                diamond.closeSubpath()
                let alpha: Double = idx % 2 == 0 ? 0.85 : 0.55
                context.fill(diamond, with: .color(scaleColor.opacity(alpha)))
            }

            // Connecting band.
            if i < maxVisible - 1 && i < 30 {
                let next = segments[i + 1]
                var path = Path()
                path.move(to: CGPoint(x: segment.x, y: segment.y))
                path.addLine(to: CGPoint(x: next.x, y: next.y))
                context.stroke(path, with: .color(bodyColor), lineWidth: s * 1.5)
            }

            // Two flickering fire orbs orbiting each segment.
            for k in 0..<2 {
                let kd: Double = Double(k)
                let orbitPhase: Double = phase * 1.4 + Double(i) * 0.3 + kd * 3.1416
                let orbitRadius: CGFloat = s * 1.05
                let fx: CGFloat = segment.x + CGFloat(cos(orbitPhase)) * orbitRadius
                let fy: CGFloat = segment.y + CGFloat(sin(orbitPhase)) * orbitRadius
                let flickerArg: Double = phase * 6.0 + Double(i * 7 + k * 19)
                let flicker: Double = sin(flickerArg) * 0.35 + 0.65
                let orbSize: CGFloat = CGFloat(2.0 + flicker * 2.5)

                let outerColor = Color(red: 1.0, green: 0.3, blue: 0.0)
                let outerSize: CGFloat = orbSize * 2.6
                context.fill(
                    Circle().path(in: CGRect(x: fx - outerSize / 2, y: fy - outerSize / 2,
                                             width: outerSize, height: outerSize)),
                    with: .color(outerColor.opacity(flicker * 0.4))
                )
                let midColor = Color(red: 1.0, green: 0.55, blue: 0.05)
                context.fill(
                    Circle().path(in: CGRect(x: fx - orbSize / 2, y: fy - orbSize / 2,
                                             width: orbSize, height: orbSize)),
                    with: .color(midColor.opacity(flicker))
                )
                let coreSize: CGFloat = orbSize * 0.45
                let coreColor = Color(red: 1.0, green: 0.95, blue: 0.55)
                context.fill(
                    Circle().path(in: CGRect(x: fx - coreSize / 2, y: fy - coreSize / 2,
                                             width: coreSize, height: coreSize)),
                    with: .color(coreColor.opacity(flicker * 0.95))
                )
            }
        }

        // Head — dark scaly with bright orange-red eyes.
        if let head = segments.first {
            let headRadius: CGFloat = s * 1.25
            context.fill(
                Circle().path(in: CGRect(x: head.x - headRadius, y: head.y - headRadius,
                                         width: headRadius * 2, height: headRadius * 2)),
                with: .color(Color(red: 0.10, green: 0.03, blue: 0.02))
            )
            let eyeOuter = Color(red: 1.0, green: 0.4, blue: 0.0)
            let eyeInner = Color(red: 1.0, green: 0.95, blue: 0.4)
            context.fill(Circle().path(in: CGRect(x: head.x - 8, y: head.y - 7, width: 6, height: 6)),
                         with: .color(eyeOuter))
            context.fill(Circle().path(in: CGRect(x: head.x + 2, y: head.y - 7, width: 6, height: 6)),
                         with: .color(eyeOuter))
            context.fill(Circle().path(in: CGRect(x: head.x - 7, y: head.y - 6, width: 4, height: 4)),
                         with: .color(eyeInner))
            context.fill(Circle().path(in: CGRect(x: head.x + 3, y: head.y - 6, width: 4, height: 4)),
                         with: .color(eyeInner))
            context.fill(Circle().path(in: CGRect(x: head.x - 5, y: head.y - 5, width: 1.5, height: 3)),
                         with: .color(.black))
            context.fill(Circle().path(in: CGRect(x: head.x + 4, y: head.y - 5, width: 1.5, height: 3)),
                         with: .color(.black))
        }
    }
}

// MARK: - Power Up View
// MARK: - Lightning Bolt View
struct LightningBoltView: View {
    let bolt: LightningBolt

    var body: some View {
        let flicker = sin(bolt.flickerPhase) > 0 ? 1.0 : 0.5
        let s = bolt.size

        Canvas { context, size in
            // Glow
            context.fill(
                Circle().path(in: CGRect(x: s * 0.5 - s, y: s * 0.5 - s, width: s * 2, height: s * 2)),
                with: .color(Color.cyan.opacity(0.15 * flicker))
            )

            // Lightning bolt shape (⚡)
            var path = Path()
            path.move(to: CGPoint(x: s * 0.6, y: 0))
            path.addLine(to: CGPoint(x: s * 0.25, y: s * 0.45))
            path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.45))
            path.addLine(to: CGPoint(x: s * 0.35, y: s))
            path.addLine(to: CGPoint(x: s * 0.75, y: s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.45, y: s * 0.5))
            path.closeSubpath()

            context.fill(path, with: .color(Color.cyan.opacity(flicker)))
            context.stroke(path, with: .color(Color.white.opacity(flicker * 0.8)), lineWidth: 1)
        }
        .frame(width: s, height: s)
    }
}

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
    var onDebugTestEmber: () -> Void = {}
    @Binding var useRainbowSnake: Bool
    @Binding var useWormySnake: Bool
    @Binding var useStarSnake: Bool
    @Binding var useBlazeSnake: Bool
    @Binding var useCosmosSnake: Bool
    @Binding var useEmberSnake: Bool
    @Binding var snakeSpeedMultiplier: CGFloat
    @ObservedObject var store = StoreManager.shared
    @ObservedObject var leaderboard = LeaderboardManager.shared
    @State private var showLeaderboard = false
    @State private var showNamePrompt = false
    @State private var nameInput = ""
    @State private var showNameRejected = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            ScrollView { introContent }
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
                guard !trimmed.isEmpty else { return }
                if DisplayNameFilter.isLikelyProfane(trimmed) {
                    nameInput = ""
                    showNameRejected = true
                } else {
                    leaderboard.playerName = trimmed
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This name will appear on the global leaderboard.")
        }
        .alert("Name Not Allowed", isPresented: $showNameRejected) {
            Button("Try Again") { showNamePrompt = true }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please choose a different display name.")
        }
        .fullScreenCover(isPresented: $showLeaderboard) {
            LeaderboardView()
        }
    }

    @ViewBuilder
    private var introContent: some View {
            VStack(spacing: 25) {
                Text("CLICK THE SHAPES")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(GameColors.neonGreen)
                    .shadow(color: GameColors.neonGreen, radius: 10)

                // Diamond count
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                    Text(UserDefaults.standard.integer(forKey: "diamondsCollected") >= 1000 ? "\(UserDefaults.standard.integer(forKey: "diamondsCollected") / 1000)K" : "\(UserDefaults.standard.integer(forKey: "diamondsCollected"))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 15) {
                    RuleRow(icon: "target", text: "Tap shapes to earn 10 points", color: .yellow)
                    RuleRow(icon: "flame.fill", text: "Snake gets fireballs for bonus points!", color: .orange)
                    RuleRow(icon: "🐍", text: "Snake starts hunting on first tap!", color: GameColors.neonPink)
                    RuleRow(icon: "trophy.fill", text: "First to 500 points wins!", color: GameColors.neonGreen)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)


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

                // Snake skin chooser
                VStack(spacing: 6) {
                    Text("CHOOSE SNAKE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Candy snake (default) — actual painting as icon
                        Button {
                            let purchased = UserDefaults.standard.bool(forKey: "candySnakePurchased")
                            if purchased {
                                useRainbowSnake = false; useWormySnake = false; useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false
                            } else if UserDefaults.standard.integer(forKey: "diamondsCollected") >= 1000 {
                                // Spend 1000 diamonds to unlock
                                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "diamondsCollected") - 1000, forKey: "diamondsCollected")
                                UserDefaults.standard.set(true, forKey: "candySnakePurchased")
                                useRainbowSnake = false; useWormySnake = false; useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false
                            }
                        } label: {
                            let purchased = UserDefaults.standard.bool(forKey: "candySnakePurchased")
                            let dCount = UserDefaults.standard.integer(forKey: "diamondsCollected")
                            let canBuy = dCount >= 1000
                            VStack(spacing: 6) {
                                ZStack {
                                    Canvas { ctx, sz in
                                        let green = Color(red: 0.1, green: 0.7, blue: 0.15)
                                        let yellow = Color(red: 0.95, green: 0.8, blue: 0)
                                        for i in 0..<7 {
                                            let x = CGFloat(i) * 7 + 4
                                            let y = sz.height / 2 + sin(CGFloat(i) * 0.7) * 3
                                            let s: CGFloat = i == 6 ? 5 : 3.5
                                            let c = (i / 2) % 2 == 0 ? yellow : green
                                            // Soft watercolour blur
                                            ctx.fill(Circle().path(in: CGRect(x: x - s * 1.4, y: y - s * 1.4, width: s * 2.8, height: s * 2.8)), with: .color(c.opacity(0.2)))
                                            ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(c.opacity(0.75)))
                                            if i < 6 {
                                                let nx = CGFloat(i + 1) * 7 + 4
                                                let ny = sz.height / 2 + sin(CGFloat(i + 1) * 0.7) * 3
                                                var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: nx, y: ny))
                                                ctx.stroke(p, with: .color(c.opacity(0.7)), lineWidth: 3)
                                            }
                                        }
                                        // Head with eye
                                        let hx: CGFloat = 46; let hy = sz.height / 2 + sin(6 * 0.7) * 3
                                        ctx.fill(Circle().path(in: CGRect(x: hx - 5, y: hy - 5, width: 10, height: 10)), with: .color(green))
                                        ctx.fill(Circle().path(in: CGRect(x: hx - 3, y: hy - 4, width: 2, height: 2)), with: .color(.white))
                                        ctx.fill(Circle().path(in: CGRect(x: hx + 1, y: hy - 4, width: 2, height: 2)), with: .color(.white))
                                    }.frame(width: 42, height: 22).opacity(purchased ? 1 : 0.3)
                                    if !purchased {
                                        Image(systemName: canBuy ? "lock.open.fill" : "lock.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(canBuy ? GameColors.neonYellow : .gray)
                                    }
                                }
                                Text(purchased ? "Candy" : (canBuy ? "Unlock 1K💎" : "\(dCount)/1K💎"))
                                    .font(.system(size: purchased ? 8 : 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(purchased ? (!useRainbowSnake && !useWormySnake && !useStarSnake && !useBlazeSnake ? .white : .gray) : (canBuy ? GameColors.neonYellow : .gray))
                            }
                            .padding(8)
                            .background(Color.white.opacity(!useRainbowSnake && !useWormySnake && !useStarSnake && !useBlazeSnake ? 0.08 : 0))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(!useRainbowSnake && !useWormySnake && !useStarSnake && !useBlazeSnake ? GameColors.neonGreen : Color.gray.opacity(0.3), lineWidth: !useRainbowSnake && !useWormySnake && !useStarSnake && !useBlazeSnake ? 2 : 1)
                            )
                        }
                        // Rainbow snake
                        Button { useRainbowSnake = true; useWormySnake = false; useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false } label: {
                            VStack(spacing: 4) {
                                Canvas { ctx, sz in
                                    let w = sz.width
                                    for i in 0..<7 {
                                        let x = CGFloat(i) * 7 + 4
                                        let y = sz.height / 2 + sin(CGFloat(i) * 0.8) * 3
                                        let s: CGFloat = i == 6 ? 5 : 3.5
                                        let hue = Double(i * 10).truncatingRemainder(dividingBy: 360) / 360
                                        let c = Color(hue: hue, saturation: 1, brightness: 1 - Double(i) * 0.05)
                                        ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(c))
                                        if i < 6 {
                                            let nx = CGFloat(i + 1) * 7 + 4
                                            let ny = sz.height / 2 + sin(CGFloat(i + 1) * 0.8) * 3
                                            var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: nx, y: ny))
                                            ctx.stroke(p, with: .color(c), lineWidth: 3)
                                        }
                                    }
                                    // Eyes
                                    let hx = CGFloat(6) * 7 + 4
                                    let hy = sz.height / 2 + sin(6 * 0.8) * 3
                                    ctx.fill(Circle().path(in: CGRect(x: hx - 3, y: hy - 4, width: 2, height: 2)), with: .color(.white))
                                    ctx.fill(Circle().path(in: CGRect(x: hx + 1, y: hy - 4, width: 2, height: 2)), with: .color(.white))
                                }.frame(width: 42, height: 22)
                                Text("Rainbow")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(useRainbowSnake ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(useRainbowSnake ? GameColors.neonGreen : Color.gray.opacity(0.3), lineWidth: useRainbowSnake ? 2 : 1)
                            )
                        }
                        // Wormy snake — actual painting as icon
                        Button {
                            let p = UserDefaults.standard.bool(forKey: "wormySnakePurchased")
                            if p { useWormySnake = true; useRainbowSnake = false; useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false }
                            else if UserDefaults.standard.integer(forKey: "diamondsCollected") >= 1000 {
                                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "diamondsCollected") - 1000, forKey: "diamondsCollected")
                                UserDefaults.standard.set(true, forKey: "wormySnakePurchased")
                                useWormySnake = true; useRainbowSnake = false; useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false
                            }
                        } label: {
                            let p = UserDefaults.standard.bool(forKey: "wormySnakePurchased")
                            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
                            VStack(spacing: 4) {
                                ZStack {
                                    Canvas { ctx, sz in
                                        for i in 0..<7 {
                                            let x = CGFloat(i) * 7 + 4
                                            let y = sz.height / 2 + sin(CGFloat(i) * 0.7) * 3
                                            let s: CGFloat = i == 6 ? 5 : 3.5
                                            let c = Color(red: 0.08 + Double(i) * 0.01, green: 0.02, blue: 0.2 + Double(i) * 0.02)
                                            // Nebula glow
                                            ctx.fill(Circle().path(in: CGRect(x: x - s * 1.5, y: y - s * 1.5, width: s * 3, height: s * 3)), with: .color(Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.15)))
                                            ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(c))
                                            // Stars
                                            if i % 2 == 0 {
                                                ctx.fill(Circle().path(in: CGRect(x: x + 2, y: y - 3, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.8)))
                                            }
                                        }
                                        ctx.fill(Circle().path(in: CGRect(x: 46, y: 8, width: 2, height: 2)), with: .color(.white))
                                        ctx.fill(Circle().path(in: CGRect(x: 48, y: 12, width: 2, height: 2)), with: .color(.white))
                                    }.frame(width: 42, height: 22).opacity(p ? 1 : 0.3)
                                    if !p { Image(systemName: d >= 1000 ? "lock.open.fill" : "lock.fill").font(.system(size: 12)).foregroundColor(d >= 1000 ? GameColors.neonYellow : .gray) }
                                }
                                Text(p ? "Glow" : (d >= 1000 ? "Unlock 1K💎" : "\(d)/1K💎"))
                                    .font(.system(size: p ? 8 : 7, design: .monospaced))
                                    .foregroundColor(p ? .white : (d >= 1000 ? GameColors.neonYellow : .gray))
                            }
                            .padding(8)
                            .background(useWormySnake ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(useWormySnake ? GameColors.neonGreen : Color.gray.opacity(0.3), lineWidth: useWormySnake ? 2 : 1)
                            )
                        }
                        // Star snake — costs 1000 diamonds to unlock
                        Button {
                            let purchased = UserDefaults.standard.bool(forKey: "starSnakePurchased")
                            if purchased {
                                useStarSnake = true; useRainbowSnake = false; useWormySnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false
                            } else if UserDefaults.standard.integer(forKey: "diamondsCollected") >= 1000 {
                                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "diamondsCollected") - 1000, forKey: "diamondsCollected")
                                UserDefaults.standard.set(true, forKey: "starSnakePurchased")
                                useStarSnake = true; useRainbowSnake = false; useWormySnake = false; useBlazeSnake = false; useCosmosSnake = false; useEmberSnake = false
                            }
                        } label: {
                            let purchased = UserDefaults.standard.bool(forKey: "starSnakePurchased")
                            let dCount = UserDefaults.standard.integer(forKey: "diamondsCollected")
                            let canBuy = dCount >= 1000
                            VStack(spacing: 4) {
                                ZStack {
                                    Canvas { ctx, sz in
                                        for i in 0..<7 {
                                            let x = CGFloat(i) * 7 + 4
                                            let y = sz.height / 2 + sin(CGFloat(i) * 0.8) * 3
                                            let s: CGFloat = i == 6 ? 5 : 3.5
                                            let isBlue = i < 3
                                            let c = isBlue ? Color(red: 0.1, green: 0.3, blue: 0.85) : Color(red: 0.95, green: 0.8, blue: 0.1)
                                            // Glow
                                            ctx.fill(Circle().path(in: CGRect(x: x - s * 1.5, y: y - s * 1.5, width: s * 3, height: s * 3)), with: .color(c.opacity(0.15)))
                                            ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(c))
                                            if i < 6 {
                                                let nx = CGFloat(i + 1) * 7 + 4
                                                let ny = sz.height / 2 + sin(CGFloat(i + 1) * 0.8) * 3
                                                var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: nx, y: ny))
                                                ctx.stroke(p, with: .color(c), lineWidth: 3)
                                            }
                                            // Sparkle
                                            if i % 2 == 0 { ctx.fill(Circle().path(in: CGRect(x: x, y: y - 4, width: 1.5, height: 1.5)), with: .color(.white)) }
                                        }
                                        ctx.fill(Circle().path(in: CGRect(x: 46, y: 8, width: 2, height: 2)), with: .color(.white))
                                        ctx.fill(Circle().path(in: CGRect(x: 48, y: 12, width: 2, height: 2)), with: .color(.white))
                                    }.frame(width: 42, height: 22).opacity(purchased ? 1 : 0.3)
                                    if !purchased {
                                        Image(systemName: canBuy ? "lock.open.fill" : "lock.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(canBuy ? GameColors.neonYellow : .gray)
                                    }
                                }
                                Text(purchased ? "Star" : (canBuy ? "Unlock 1K💎" : "\(dCount)/1K💎"))
                                    .font(.system(size: purchased ? 8 : 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(purchased ? .white : (canBuy ? GameColors.neonYellow : .gray))
                            }
                            .padding(8)
                            .background(useStarSnake ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(useStarSnake ? GameColors.neonGreen : Color.gray.opacity(0.3), lineWidth: useStarSnake ? 2 : 1)
                            )
                        }
                        // Blaze snake
                        Button {
                            let p = UserDefaults.standard.bool(forKey: "blazeSnakePurchased")
                            if p { useBlazeSnake = true; useRainbowSnake = false; useWormySnake = false; useStarSnake = false; useCosmosSnake = false; useEmberSnake = false }
                            else if UserDefaults.standard.integer(forKey: "diamondsCollected") >= 1000 {
                                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "diamondsCollected") - 1000, forKey: "diamondsCollected")
                                UserDefaults.standard.set(true, forKey: "blazeSnakePurchased")
                                useBlazeSnake = true; useRainbowSnake = false; useWormySnake = false; useStarSnake = false; useCosmosSnake = false; useEmberSnake = false
                            }
                        } label: {
                            let p = UserDefaults.standard.bool(forKey: "blazeSnakePurchased")
                            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
                            VStack(spacing: 4) {
                                ZStack {
                                    Canvas { ctx, sz in
                                        for i in 0..<7 {
                                            let x = CGFloat(i) * 7 + 4
                                            let y = sz.height / 2 + sin(CGFloat(i) * 0.8) * 3
                                            let s: CGFloat = i == 6 ? 5 : 3.5
                                            let isBlue = (i / 2) % 2 == 0
                                            let c = isBlue ? Color(red: 0.1, green: 0.2, blue: 0.9) : Color(red: 0.9, green: 0.1, blue: 0.1)
                                            // Glow
                                            ctx.fill(Circle().path(in: CGRect(x: x - s * 1.5, y: y - s * 1.5, width: s * 3, height: s * 3)), with: .color(c.opacity(0.12)))
                                            ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(c))
                                            // Shine highlight
                                            ctx.fill(Circle().path(in: CGRect(x: x - 1, y: y - s * 0.7, width: 2, height: 1.5)), with: .color(.white.opacity(0.3)))
                                            if i < 6 {
                                                let nx = CGFloat(i + 1) * 7 + 4
                                                let ny = sz.height / 2 + sin(CGFloat(i + 1) * 0.8) * 3
                                                var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: nx, y: ny))
                                                ctx.stroke(p, with: .color(c), lineWidth: 3)
                                            }
                                        }
                                        // Purple head
                                        ctx.fill(Circle().path(in: CGRect(x: 42, y: 7, width: 10, height: 10)), with: .color(Color(red: 0.5, green: 0.1, blue: 0.5)))
                                        ctx.fill(Circle().path(in: CGRect(x: 44, y: 9, width: 2, height: 2)), with: .color(.white))
                                        ctx.fill(Circle().path(in: CGRect(x: 48, y: 9, width: 2, height: 2)), with: .color(.white))
                                    }.frame(width: 42, height: 22).opacity(p ? 1 : 0.3)
                                    if !p { Image(systemName: d >= 1000 ? "lock.open.fill" : "lock.fill").font(.system(size: 12)).foregroundColor(d >= 1000 ? GameColors.neonYellow : .gray) }
                                }
                                Text(p ? "Blaze" : (d >= 1000 ? "Unlock 1K💎" : "\(d)/1K💎"))
                                    .font(.system(size: p ? 8 : 7, design: .monospaced))
                                    .foregroundColor(p ? .white : (d >= 1000 ? GameColors.neonYellow : .gray))
                            }
                            .padding(8)
                            .background(useBlazeSnake ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(useBlazeSnake ? GameColors.neonGreen : Color.gray.opacity(0.3), lineWidth: useBlazeSnake ? 2 : 1)
                            )
                        }

                        dnaChooserButton
                        emberChooserButton
                    }
                    } // ScrollView
                }

                // Snake speed slider
                VStack(spacing: 4) {
                    Text("SNAKE SPEED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
                        Text("🐌")
                            .font(.system(size: 12))
                        Slider(value: $snakeSpeedMultiplier, in: 0.3...1.0, step: 0.1)
                            .accentColor(GameColors.neonGreen)
                            .frame(width: 150)
                        Text("🐇")
                            .font(.system(size: 12))
                    }
                    Text("\(Int(snakeSpeedMultiplier * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(snakeSpeedMultiplier < 0.5 ? GameColors.neonGreen : snakeSpeedMultiplier < 0.8 ? GameColors.neonYellow : GameColors.neonPink)
                }

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

                Button(action: onStartHardcore) {
                        VStack(spacing: 4) {
                            Text("HARDCORE MODE")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                            Text("You can't restart at any point")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.black.opacity(0.7))
                            Text("Risk of losing diamonds – watch ad to keep them!")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.black.opacity(0.85))
                                .multilineTextAlignment(.center)
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

                #if DEBUG
                Button(action: onDebugTestEmber) {
                    Text("DEBUG: Test Ember Snake")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.6, green: 0.15, blue: 0.05))
                        .cornerRadius(8)
                }
                Button(action: onStartLevel4) {
                    Text("DEBUG: Skip to Level 4")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.4, green: 0.05, blue: 0.5))
                        .cornerRadius(8)
                }
                #endif
            }
            .padding(30)
    }

    // MARK: - Snake chooser sub-views (extracted to keep the body type-checker happy)

    @ViewBuilder
    private var dnaChooserButton: some View {
        Button {
            let p = UserDefaults.standard.bool(forKey: "dnaSnakePurchased")
            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
            let a = UserDefaults.standard.integer(forKey: "rewardedAdsWatched")
            if p {
                useCosmosSnake = true
                useRainbowSnake = false; useWormySnake = false
                useStarSnake = false; useBlazeSnake = false; useEmberSnake = false
            } else if d >= 5000 && a >= 10 {
                UserDefaults.standard.set(d - 5000, forKey: "diamondsCollected")
                UserDefaults.standard.set(true, forKey: "dnaSnakePurchased")
                useCosmosSnake = true
                useRainbowSnake = false; useWormySnake = false
                useStarSnake = false; useBlazeSnake = false; useEmberSnake = false
            }
        } label: {
            let p = UserDefaults.standard.bool(forKey: "dnaSnakePurchased")
            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
            let a = UserDefaults.standard.integer(forKey: "rewardedAdsWatched")
            let ready: Bool = d >= 5000 && a >= 10
            VStack(spacing: 4) {
                ZStack {
                    Canvas { ctx, _ in
                        let palette: [Color] = [
                            Color(red: 0.85, green: 0.95, blue: 1.0),
                            Color(red: 1.0, green: 0.45, blue: 0.85),
                            Color(red: 1.0, green: 0.85, blue: 0.30),
                            Color(red: 0.30, green: 1.0, blue: 0.85),
                            Color(red: 0.85, green: 0.50, blue: 1.0),
                        ]
                        let positions: [(CGFloat, CGFloat)] = [
                            (8, 11), (16, 7), (22, 13), (30, 8),
                            (35, 14), (12, 16), (26, 17)
                        ]
                        for (idx, pos) in positions.enumerated() {
                            let c = palette[idx % palette.count]
                            ctx.fill(Circle().path(in: CGRect(x: pos.0 - 2.5, y: pos.1 - 2.5, width: 5, height: 5)),
                                     with: .color(c.opacity(0.35)))
                            ctx.fill(Circle().path(in: CGRect(x: pos.0 - 1, y: pos.1 - 1, width: 2, height: 2)),
                                     with: .color(c))
                            var spike = Path()
                            spike.move(to: CGPoint(x: pos.0 - 4, y: pos.1))
                            spike.addLine(to: CGPoint(x: pos.0 + 4, y: pos.1))
                            spike.move(to: CGPoint(x: pos.0, y: pos.1 - 4))
                            spike.addLine(to: CGPoint(x: pos.0, y: pos.1 + 4))
                            ctx.stroke(spike, with: .color(c.opacity(0.7)), lineWidth: 0.4)
                        }
                    }
                    .frame(width: 42, height: 22)
                    .opacity(p ? 1 : 0.3)
                    if !p {
                        Image(systemName: ready ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ready ? GameColors.neonYellow : .gray)
                    }
                }
                if p {
                    Text("DNA")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                } else if ready {
                    Text("Unlock 5K💎")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(GameColors.neonYellow)
                } else {
                    Text("\(d)/5K💎")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(a)/10📺")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
            .background(useCosmosSnake ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(useCosmosSnake ? GameColors.neonGreen : Color.gray.opacity(0.3),
                            lineWidth: useCosmosSnake ? 2 : 1)
            )
        }
    }

    @ViewBuilder
    private var emberChooserButton: some View {
        Button {
            let p = UserDefaults.standard.bool(forKey: "emberSnakePurchased")
            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
            let a = UserDefaults.standard.integer(forKey: "rewardedAdsWatched")
            if p {
                useEmberSnake = true
                useRainbowSnake = false; useWormySnake = false
                useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false
            } else if d >= 10000 && a >= 20 {
                UserDefaults.standard.set(d - 10000, forKey: "diamondsCollected")
                UserDefaults.standard.set(true, forKey: "emberSnakePurchased")
                useEmberSnake = true
                useRainbowSnake = false; useWormySnake = false
                useStarSnake = false; useBlazeSnake = false; useCosmosSnake = false
            }
        } label: {
            let p = UserDefaults.standard.bool(forKey: "emberSnakePurchased")
            let d = UserDefaults.standard.integer(forKey: "diamondsCollected")
            let a = UserDefaults.standard.integer(forKey: "rewardedAdsWatched")
            let ready: Bool = d >= 10000 && a >= 20
            VStack(spacing: 4) {
                ZStack {
                    Canvas { ctx, _ in
                        for i in 0..<7 {
                            let x = CGFloat(i) * 7 + 4
                            let y = 11 + sin(CGFloat(i) * 0.7) * 3
                            let s: CGFloat = i == 6 ? 5 : 3.5
                            ctx.fill(Circle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                                     with: .color(Color(red: 0.18, green: 0.05, blue: 0.04)))
                            ctx.fill(Circle().path(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                                     with: .color(Color(red: 0.55, green: 0.10, blue: 0.05).opacity(0.8)))
                            if i < 6 {
                                let nx = CGFloat(i + 1) * 7 + 4
                                let ny = 11 + sin(CGFloat(i + 1) * 0.7) * 3
                                var pth = Path()
                                pth.move(to: CGPoint(x: x, y: y))
                                pth.addLine(to: CGPoint(x: nx, y: ny))
                                ctx.stroke(pth, with: .color(Color(red: 0.18, green: 0.05, blue: 0.04)), lineWidth: 3)
                            }
                        }
                        // Two fire orbs above body
                        let orbXs: [CGFloat] = [10, 28]
                        for (idx, cx) in orbXs.enumerated() {
                            let cy: CGFloat = idx == 0 ? 6 : 16
                            ctx.fill(Circle().path(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10)),
                                     with: .color(Color(red: 1.0, green: 0.3, blue: 0.0).opacity(0.4)))
                            ctx.fill(Circle().path(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)),
                                     with: .color(Color(red: 1.0, green: 0.55, blue: 0.05)))
                            ctx.fill(Circle().path(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3)),
                                     with: .color(Color(red: 1.0, green: 0.95, blue: 0.55)))
                        }
                        // Eyes
                        ctx.fill(Circle().path(in: CGRect(x: 46, y: 8, width: 2, height: 2)), with: .color(.white))
                        ctx.fill(Circle().path(in: CGRect(x: 48, y: 12, width: 2, height: 2)), with: .color(.white))
                    }
                    .frame(width: 42, height: 22)
                    .opacity(p ? 1 : 0.3)
                    if !p {
                        Image(systemName: ready ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ready ? GameColors.neonYellow : .gray)
                    }
                }
                if p {
                    Text("Ember")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                } else if ready {
                    Text("Unlock 10K💎")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(GameColors.neonYellow)
                } else {
                    Text("\(d)/10K💎")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(a)/20📺")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
            .background(useEmberSnake ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(useEmberSnake ? GameColors.neonGreen : Color.gray.opacity(0.3),
                            lineWidth: useEmberSnake ? 2 : 1)
            )
        }
    }
}

struct RuleRow: View {
    let icon: String
    let text: String
    let color: Color

    private var iconIsEmoji: Bool {
        guard let scalar = icon.unicodeScalars.first else { return false }
        return !scalar.isASCII
    }

    var body: some View {
        HStack(spacing: 12) {
            if iconIsEmoji {
                Text(icon)
                    .font(.system(size: 20))
            } else {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
            }
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 16, design: .monospaced))
        }
    }
}


// MARK: - Win Overlay
struct WinOverlay: View {
    let message: String
    let color: Color
    let levelText: String
    let hardcoreMode: Bool
    let snakeWon: Bool
    let onRestart: () -> Void
    let onRestartLevel: () -> Void
    let onContinueWithAd: (@escaping (Bool) -> Void) -> Void

    @State private var titleScale: CGFloat = 1.0
    @State private var buttonGlow: CGFloat = 8.0
    @State private var goldPulse: CGFloat = 8.0
    @State private var isLoadingAd: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 25) {
                HStack(spacing: 14) {
                    Text(message)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                        .shadow(color: color, radius: 15)
                        .scaleEffect(titleScale)

                    if snakeWon {
                        Button(action: {
                            guard !isLoadingAd else { return }
                            isLoadingAd = true
                            onContinueWithAd { _ in
                                isLoadingAd = false
                            }
                        }) {
                            ZStack {
                                VStack(spacing: 2) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("WATCH AD")
                                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    Text(hardcoreMode ? "KEEP 💎" : "KEEP SCORE")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                }
                                .opacity(isLoadingAd ? 0 : 1)

                                if isLoadingAd {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                }
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.92, blue: 0.4), Color(red: 0.95, green: 0.75, blue: 0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.2), radius: goldPulse)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 1.0, green: 0.95, blue: 0.5), lineWidth: 2)
                            )
                        }
                        .disabled(isLoadingAd)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        titleScale = 1.1
                    }
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        buttonGlow = 20.0
                    }
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        goldPulse = 22.0
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
                    if game.currentLevel >= 4 {
                        Level4SpaceScene(size: geometry.size)
                    } else if game.currentLevel >= 3 {
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
                    ShapeView(shape: shape, isLevel4: game.currentLevel >= 4)
                        .position(x: shape.x, y: shape.y)
                        .opacity(shape.isVisible ? 1 : 0)
                        .id("\(shape.id)-\(game.updateTrigger)")
                }

                // Snake
                if let snake = game.snake {
                    SnakeView(snake: snake, useRainbow: game.useRainbowSnake, useWormy: game.useWormySnake, useStar: game.useStarSnake, useBlaze: game.useBlazeSnake, useCosmos: game.useCosmosSnake, useEmber: game.useEmberSnake)
                        .id(game.updateTrigger)
                }

                // Second snake (Level 4) — with glow
                if let snake2 = game.snake2 {
                    SnakeView(snake: snake2, useRainbow: game.useRainbowSnake, useWormy: game.useWormySnake, useStar: game.useStarSnake, useBlaze: game.useBlazeSnake, useCosmos: game.useCosmosSnake, useEmber: game.useEmberSnake)
                        .id(game.updateTrigger)
                }

                // Power-up
                if let powerUp = game.powerUp, powerUp.isActive {
                    PowerUpView(powerUp: powerUp)
                        .id(game.updateTrigger)
                }

                // Diamonds — 3D depth of field
                ForEach(game.diamonds) { diamond in
                    if diamond.isActive {
                        let floatY = sin(diamond.floatPhase) * 4
                        let sparkle = (sin(diamond.sparklePhase) + 1) / 2

                        ZStack {
                            // 3D shadow on ground
                            Ellipse()
                                .fill(Color.black.opacity(0.25))
                                .frame(width: diamond.size * 0.8, height: diamond.size * 0.3)
                                .offset(y: diamond.size * 0.7)

                            // Diamond image
                            if let dImg = UIImage(named: "diamond") ?? (Bundle.main.path(forResource: "diamond", ofType: "png").flatMap { UIImage(contentsOfFile: $0) }) {
                                Image(uiImage: dImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: diamond.size, height: diamond.size)
                            }

                            // 3D sparkle highlight
                            Circle()
                                .fill(Color.white.opacity(sparkle * 0.6))
                                .frame(width: diamond.size * 0.2, height: diamond.size * 0.2)
                                .offset(x: -diamond.size * 0.15, y: -diamond.size * 0.2)

                            // Colour glow
                            Circle()
                                .fill(Color.cyan.opacity(sparkle * 0.2))
                                .frame(width: diamond.size * 1.5, height: diamond.size * 1.5)
                        }
                        .opacity(Double(diamond.life))
                        .scaleEffect(diamond.life < 0.3 ? CGFloat(diamond.life / 0.3) : 1.0)
                        .position(x: diamond.x, y: diamond.y + floatY)
                        .id("\(diamond.id)-\(game.updateTrigger)")
                    }
                }

                // Lightning bolts (Level 4)
                ForEach(game.lightningBolts) { bolt in
                    if bolt.isActive {
                        LightningBoltView(bolt: bolt)
                            .position(x: bolt.x, y: bolt.y)
                            .id("\(bolt.id)-\(game.updateTrigger)")
                    }
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

                    if game.currentLevel >= 4 {
                        // Level 4 — compact score bar all in one row
                        VStack(spacing: 4) {
                            HStack(spacing: 10) {
                                // Snake score — pink box
                                VStack(spacing: 2) {
                                    Text("SNAKES")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonPink.opacity(0.7))
                                    Text("\(game.snakeScore)")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonPink)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameColors.neonPink, lineWidth: 1.5))

                                // Target — yellow
                                VStack(spacing: 2) {
                                    Text("TARGET")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonYellow.opacity(0.7))
                                    Text("\(game.winningScore)")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonYellow)
                                }

                                // Player score — green box
                                VStack(spacing: 2) {
                                    Text("YOU")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonGreen.opacity(0.7))
                                    Text("\(game.score)")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(GameColors.neonGreen)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameColors.neonGreen, lineWidth: 1.5))
                            }
                            .allowsHitTesting(false)

                            // Sound toggle
                            Button(action: { game.tapSoundEnabled.toggle() }) {
                                Image(systemName: game.tapSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(game.tapSoundEnabled ? GameColors.neonCyan : .gray)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.top, 5)
                    } else {
                        // Levels 1-3 — normal layout
                        HStack {
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
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameColors.neonPink, lineWidth: 2))
                                .allowsHitTesting(false)

                                Button(action: { game.tapSoundEnabled.toggle() }) {
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
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(game.tapSoundEnabled ? GameColors.neonCyan : .gray, lineWidth: 1))
                                }
                            }

                            Spacer().allowsHitTesting(false)

                            VStack {
                                Text("Target").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                Text("\(game.winningScore)").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(GameColors.neonYellow)
                            }.allowsHitTesting(false)

                            Spacer().allowsHitTesting(false)

                            VStack(alignment: .trailing) {
                                Text("You").font(.system(size: 14, weight: .medium, design: .monospaced))
                                Text("\(game.score)").font(.system(size: 28, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(GameColors.neonGreen)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameColors.neonGreen, lineWidth: 2))
                            .allowsHitTesting(false)
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                    }

                    Spacer()
                        .allowsHitTesting(false)

                    // Diamond counter
                    if true {
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.cyan)
                            Text(game.diamondsCollected >= 1000 ? "\(game.diamondsCollected / 1000)K" : "\(game.diamondsCollected)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .allowsHitTesting(false)
                        .padding(.bottom, 4)
                    }

                    // Level 4 sequence challenge display
                    if game.currentLevel >= 4, !game.shapeSequence.isEmpty {
                        VStack(spacing: 4) {
                            if game.lightningRainActive {
                                Text("LIGHTNING RAIN!")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(GameColors.neonCyan)
                                    .opacity(sin(Double(game.updateTrigger ? 1 : 0) * 3) > 0 ? 1 : 0.4)
                            } else {
                                Text("TAP IN ORDER")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                HStack(spacing: 6) {
                                    ForEach(0..<game.shapeSequence.count, id: \.self) { idx in
                                        let done = idx < game.sequenceProgress
                                        SequenceShapeIcon(shapeType: game.shapeSequence[idx])
                                            .opacity(done ? 0.3 : 1)
                                            .overlay(
                                                done ? AnyView(
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(GameColors.neonGreen)
                                                ) : AnyView(EmptyView())
                                            )
                                            .scaleEffect(game.sequenceProgress == idx ? 1.2 : 1.0)
                                        if idx < game.shapeSequence.count - 1 {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(game.lightningRainActive ? GameColors.neonCyan : Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .allowsHitTesting(false)
                        .padding(.bottom, 5)
                    }

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
                    }, onDebugTestEmber: {
                        game.debugTestEmberSnake()
                    }, useRainbowSnake: $game.useRainbowSnake, useWormySnake: $game.useWormySnake, useStarSnake: $game.useStarSnake, useBlazeSnake: $game.useBlazeSnake, useCosmosSnake: $game.useCosmosSnake, useEmberSnake: $game.useEmberSnake, snakeSpeedMultiplier: $game.snakeSpeedMultiplier)
                    .onAppear {
                        // Wait one extra runloop so all the snake-icon Canvases have
                        // finished their first render before dismissing the splash.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            AppDelegate.launchGate.introReady = true
                        }
                    }
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


                // Win overlay
                if game.gameOver {
                    WinOverlay(
                        message: game.winMessage,
                        color: game.winColor,
                        levelText: "LEVEL \(game.currentLevel)",
                        hardcoreMode: game.hardcoreMode,
                        snakeWon: game.winMessage.uppercased().contains("SNAKE WINS"),
                        onRestart: {
                            game.restartGame()
                        },
                        onRestartLevel: {
                            game.restartCurrentLevel()
                        },
                        onContinueWithAd: { completion in
                            RewardedAdManager.shared.show { earned in
                                // Always resume gameplay once the user has
                                // tapped Watch Ad — they committed, honor it.
                                if game.hardcoreMode {
                                    game.restoreHardcoreDiamondsAndRestart()
                                } else {
                                    game.continueWithSameScore()
                                }
                                completion(earned)
                            }
                        }
                    )
                }
            }
            .onAppear {
                game.setupGame(bounds: geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                game.updateBounds(newSize)
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
/// Procedural 3D space scene for Level 4+. Hundreds of small twinkling
/// stars drift radially outward from the centre at speeds proportional
/// to their "depth", giving a parallax / flying-through-space feel.
/// Stars are coloured from a cosmic palette and the brightest get
/// classic 4-point cross spikes. Two pulsing nebula clouds add depth.
struct Level4SpaceScene: View {
    let size: CGSize

    @State private var t: Double = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    /// 240 deterministic seeds — angle, depth, palette index, twinkle phase.
    /// Generated once at first render so the scene is stable.
    private static let stars: [SpaceStar] = (0..<240).map { _ in SpaceStar.random() }

    /// 600 particles arranged on logarithmic spirals to form a 2-armed
    /// spiral galaxy. Generated once at first render.
    static let galaxyParticles: [GalaxyParticle] = GalaxyParticle.makeGalaxy(count: 1100)

    /// 6 glowing comets that streak across the page on independent timing
    /// loops and explode at the end of their journey. Re-used each cycle.
    static let comets: [Comet] = (0..<6).map { _ in Comet.random() }

    /// Realistic stellar colour palette — used by background stars only.
    static let palette: [(Color, Color)] = [
        (Color(red: 1.00, green: 1.00, blue: 1.00), Color(red: 0.85, green: 0.92, blue: 1.00)),  // white
        (Color(red: 0.85, green: 0.92, blue: 1.00), Color(red: 0.55, green: 0.78, blue: 1.00)),  // blue-white
        (Color(red: 0.78, green: 0.88, blue: 1.00), Color(red: 0.45, green: 0.65, blue: 1.00)),  // pale blue
        (Color(red: 1.00, green: 0.96, blue: 0.85), Color(red: 1.00, green: 0.85, blue: 0.55)),  // yellow-white
        (Color(red: 1.00, green: 0.78, blue: 0.55), Color(red: 0.95, green: 0.55, blue: 0.30)),  // warm orange
        (Color(red: 1.00, green: 0.55, blue: 0.40), Color(red: 0.85, green: 0.30, blue: 0.20)),  // deep red
    ]

    /// Maximally vibrant galaxy palette — saturated nebula colours so the
    /// spiral galaxy is unmistakably a colourful deep-space object.
    static let galaxyPalette: [Color] = [
        Color(red: 1.00, green: 1.00, blue: 1.00),                    // bright white
        Color(red: 0.30, green: 0.70, blue: 1.00),                    // electric blue
        Color(red: 1.00, green: 0.30, blue: 0.85),                    // hot pink
        Color(red: 1.00, green: 0.92, blue: 0.30),                    // bright gold
        Color(red: 1.00, green: 0.50, blue: 0.10),                    // hot orange
        Color(red: 0.65, green: 0.20, blue: 1.00),                    // electric violet
        Color(red: 0.10, green: 1.00, blue: 0.95),                    // neon cyan
        Color(red: 1.00, green: 0.10, blue: 0.40),                    // magenta-red
        Color(red: 0.30, green: 1.00, blue: 0.50),                    // neon green
        Color(red: 1.00, green: 0.40, blue: 0.40),                    // vivid red
        Color(red: 0.95, green: 0.60, blue: 1.00),                    // pink-lavender
        Color(red: 1.00, green: 0.85, blue: 0.10),                    // pure yellow
    ]

    var body: some View {
        Canvas { ctx, sz in
            // Pure black background — galaxies pop against it.
            ctx.fill(
                Path(CGRect(origin: .zero, size: sz)),
                with: .color(.black)
            )

            // Faint vignette toward edges for depth.
            ctx.fill(
                Path(CGRect(origin: .zero, size: sz)),
                with: .radialGradient(
                    Gradient(colors: [
                        .clear,
                        Color.black.opacity(0.45)
                    ]),
                    center: CGPoint(x: sz.width / 2, y: sz.height / 2),
                    startRadius: min(sz.width, sz.height) * 0.30,
                    endRadius: max(sz.width, sz.height) * 0.75
                )
            )

            // Three spiral galaxies spread across the scene, each with its
            // own colour family (palette offset) so they read as distinct
            // distant galaxies — pinks/blues, greens/cyans, golds/violets.
            drawSpiralGalaxy(ctx: &ctx,
                             centre: CGPoint(x: sz.width * 0.78, y: sz.height * 0.25),
                             radius: sz.width * 0.22,
                             colorOffset: 0)
            drawSpiralGalaxy(ctx: &ctx,
                             centre: CGPoint(x: sz.width * 0.18, y: sz.height * 0.62),
                             radius: sz.width * 0.16,
                             colorOffset: 4)
            drawSpiralGalaxy(ctx: &ctx,
                             centre: CGPoint(x: sz.width * 0.62, y: sz.height * 0.85),
                             radius: sz.width * 0.13,
                             colorOffset: 8)

            // Stars — radial parallax drift out from screen centre.
            let centerX: CGFloat = sz.width / 2
            let centerY: CGFloat = sz.height / 2
            let maxR: CGFloat = hypot(sz.width, sz.height) * 0.55

            for star in Level4SpaceScene.stars {
                drawStar(ctx: &ctx, star: star,
                         centerX: centerX, centerY: centerY, maxR: maxR)
            }

            // Glowing shooting stars — zoom across the page then explode.
            for comet in Level4SpaceScene.comets {
                drawComet(ctx: &ctx, comet: comet, size: sz)
            }
        }
        .onReceive(timer) { _ in
            t += 0.085
            if t > 100000 { t -= 100000 }
        }
    }

    private func drawStar(ctx: inout GraphicsContext,
                          star: SpaceStar,
                          centerX: CGFloat,
                          centerY: CGFloat,
                          maxR: CGFloat) {
        let raw: Double = star.startPhase + t * star.speed
        let phase: Double = raw - floor(raw)
        let dist: CGFloat = CGFloat(phase) * maxR
        // Counter-clockwise scene rotation — background stars sweep around
        // screen centre opposite to the galaxy's clockwise spin.
        let starAngle: Double = star.angle - t * 0.30
        let cx: CGFloat = centerX + CGFloat(cos(starAngle)) * dist
        let cy: CGFloat = centerY + CGFloat(sin(starAngle)) * dist

        let appear: Double = phase * (1.0 - phase) * 4.0
        // Subtle twinkle (real-photo range, 0.85–1.0).
        let twinkleArg: Double = t * 0.55 + star.twinkleSeed
        let twinkle: Double = sin(twinkleArg) * 0.075 + 0.925
        // Depth-of-field: stars that are "far" (low depth) are heavily dimmed
        // so they recede into the black. Only nearer stars (depth > 0.55)
        // retain full brightness — same effect as a long lens with shallow DoF.
        let depthDim: Double = 0.18 + pow(star.depth, 1.4) * 0.82
        let alpha: Double = appear * twinkle * depthDim

        guard alpha > 0.02 else { return }

        let (core, halo) = Level4SpaceScene.palette[star.paletteIdx % Level4SpaceScene.palette.count]

        // Halo only on closer (brighter) stars — keeps the dim ones as
        // pinpoints, like a real long-exposure photo.
        if star.depth > 0.55 {
            let haloR: CGFloat = CGFloat(1.2 + star.depth * 2.6)
            ctx.fill(
                Circle().path(in: CGRect(x: cx - haloR, y: cy - haloR,
                                         width: haloR * 2, height: haloR * 2)),
                with: .color(halo.opacity(alpha * 0.22))
            )
        }

        let coreR: CGFloat = CGFloat(0.5 + star.depth * 1.3)
        ctx.fill(
            Circle().path(in: CGRect(x: cx - coreR, y: cy - coreR,
                                     width: coreR * 2, height: coreR * 2)),
            with: .color(core.opacity(min(1.0, alpha * 1.3)))
        )

        // Diffraction spike — brightest 12% only, small and thin.
        if star.depth > 0.88 {
            let spikeLen: CGFloat = CGFloat(1.5 + star.depth * 2.5)
            var spike = Path()
            spike.move(to: CGPoint(x: cx - spikeLen, y: cy))
            spike.addLine(to: CGPoint(x: cx + spikeLen, y: cy))
            spike.move(to: CGPoint(x: cx, y: cy - spikeLen))
            spike.addLine(to: CGPoint(x: cx, y: cy + spikeLen))
            ctx.stroke(spike, with: .color(core.opacity(alpha * 0.5)), lineWidth: 0.35)
        }
    }

    /// Draw a 3D-feeling spiral galaxy at `centre` with given disk `radius`.
    /// The disk is squashed vertically (tilt) to suggest depth, and rotates
    /// slowly. Particle positions are pre-baked; rotation is applied here.
    private func drawSpiralGalaxy(ctx: inout GraphicsContext,
                                  centre: CGPoint,
                                  radius: CGFloat,
                                  colorOffset: Int = 0) {
        // Galaxy spins clockwise — full revolution roughly every 7 seconds.
        let rotation: Double = t * 0.60
        let tiltY: CGFloat = 0.45  // 0 = face-on, 1 = edge-on; 0.45 looks 3D.

        var c = ctx
        c.translateBy(x: centre.x, y: centre.y)

        // No background ellipses — the galaxy is made entirely from the
        // colourful particles, no beige halo or yellow core disk behind them.

        // Particles along spiral arms — half spin clockwise, half counter-
        // clockwise. They weave through each other producing a shimmering,
        // multidirectional motion within the galaxy itself.
        for p in Level4SpaceScene.galaxyParticles {
            let theta: Double = p.angle + rotation * p.spinDir
            let r: Double = p.radius
            let baseX: Double = cos(theta) * r
            let baseY: Double = sin(theta) * r
            let x: CGFloat = (CGFloat(baseX) + CGFloat(p.jitterX)) * radius
            let y: CGFloat = (CGFloat(baseY) + CGFloat(p.jitterY)) * radius * tiltY

            let twinkle: Double = sin(t * 0.8 + p.twinkleSeed) * 0.18 + 0.82
            // Brighter near centre, gentler fade toward edge so colour pops.
            let alpha: Double = (1.0 - r * 0.30) * twinkle * p.brightness
            guard alpha > 0.02 else { continue }

            // Shift palette by `colorOffset` so each galaxy reads in its
            // own colour family.
            let palCount: Int = Level4SpaceScene.galaxyPalette.count
            let col: Color = Level4SpaceScene.galaxyPalette[(p.paletteIdx + colorOffset) % palCount]
            // Small glowing particles — tight bright core + wider soft halo.
            let psize: CGFloat = CGFloat(p.size)
            let haloS: CGFloat = psize * 4.0
            // Wide outer halo (very dim, just colour).
            c.fill(
                Circle().path(in: CGRect(x: x - haloS / 2, y: y - haloS / 2,
                                         width: haloS, height: haloS)),
                with: .color(col.opacity(min(1.0, alpha * 0.30)))
            )
            // Mid halo.
            let midS: CGFloat = psize * 2.0
            c.fill(
                Circle().path(in: CGRect(x: x - midS / 2, y: y - midS / 2,
                                         width: midS, height: midS)),
                with: .color(col.opacity(min(1.0, alpha * 0.6)))
            )
            // Tight bright core.
            c.fill(
                Circle().path(in: CGRect(x: x - psize / 2, y: y - psize / 2,
                                         width: psize, height: psize)),
                with: .color(col.opacity(min(1.0, alpha * 1.6)))
            )
        }
    }

    /// Draw a single shooting star — travels in a straight line then bursts
    /// into a 14-particle explosion ring at the end of its journey before
    /// looping. Each comet has its own staggered timing.
    private func drawComet(ctx: inout GraphicsContext, comet: Comet, size sz: CGSize) {
        let raw: Double = comet.startPhase + t * comet.speed
        let phase: Double = raw - floor(raw)
        let dx: Double = cos(comet.angle)
        let dy: Double = sin(comet.angle)
        let totalLen: Double = Double(hypot(sz.width, sz.height)) * 0.95
        // Origin offset behind the visible edge so comets enter naturally.
        let originX: Double = Double(sz.width) * comet.startX - dx * 120
        let originY: Double = Double(sz.height) * comet.startY - dy * 120
        let endX: CGFloat = CGFloat(originX + dx * totalLen)
        let endY: CGFloat = CGFloat(originY + dy * totalLen)
        let cometColor = Level4SpaceScene.galaxyPalette[comet.paletteIdx % Level4SpaceScene.galaxyPalette.count]

        if phase < 0.65 {
            // Travel phase — fanning multi-filament tail full of sparkles.
            let progress: Double = phase / 0.65
            let headDist: Double = progress * totalLen
            let hx: CGFloat = CGFloat(originX + dx * headDist)
            let hy: CGFloat = CGFloat(originY + dy * headDist)
            // Brightness ramps up early, peaks mid-flight, fades near end.
            let appear: Double = min(1.0, progress * 4.0) * min(1.0, (1.0 - progress) * 3.0)
            let tailLen: CGFloat = CGFloat(180.0 * appear)

            // 5 fanning filament tails at slightly different angles.
            let filamentCount: Int = 5
            for f in 0..<filamentCount {
                let fOff: Double = (Double(f) - Double(filamentCount - 1) / 2.0) * 0.05
                let fdx: Double = cos(comet.angle + fOff)
                let fdy: Double = sin(comet.angle + fOff)
                let lenScale: CGFloat = CGFloat(0.65 + Double((f * 7) % 5) * 0.10)
                let fLen: CGFloat = tailLen * lenScale
                let ftx: CGFloat = hx - CGFloat(fdx) * fLen
                let fty: CGFloat = hy - CGFloat(fdy) * fLen
                var path = Path()
                path.move(to: CGPoint(x: ftx, y: fty))
                path.addLine(to: CGPoint(x: hx, y: hy))
                let fAlpha: Double = appear * (f == filamentCount / 2 ? 0.55 : 0.30)
                let fLine: CGFloat = f == filamentCount / 2 ? 1.6 : 0.9
                ctx.stroke(path, with: .color(cometColor.opacity(fAlpha)), lineWidth: fLine)
            }

            // White-hot inner streak right behind the head.
            var inner = Path()
            let innerLen: CGFloat = tailLen * 0.55
            inner.move(to: CGPoint(x: hx - CGFloat(dx) * innerLen, y: hy - CGFloat(dy) * innerLen))
            inner.addLine(to: CGPoint(x: hx, y: hy))
            ctx.stroke(inner, with: .color(.white.opacity(appear * 0.65)), lineWidth: 1.2)

            // Sparkle particles — twinkling dust scattered along + around the
            // tail. Per-sparkle deterministic offsets (seed-based) + per-frame
            // twinkle keeps them coherent but lively.
            let sparkleCount: Int = 28
            // Perpendicular unit vector (for jitter).
            let pdx: Double = -dy
            let pdy: Double = dx
            for s in 0..<sparkleCount {
                let sd: Double = Double(s)
                // Position along tail (0 = at head, 1 = end of tail).
                let along: Double = (sd / Double(sparkleCount)) * 0.95 + 0.02
                // Small along-direction jitter that drifts with t.
                let alongJit: Double = sin(sd * 7.31 + t * 0.6) * 6.0
                // Perpendicular spread — sparkles fan out wider near end of tail.
                let perpSpread: Double = 4.0 + along * 18.0
                let perpJit: Double = sin(sd * 13.7 + comet.startPhase * 100) * perpSpread
                let alongPx: Double = -dx * Double(tailLen) * along + dx * alongJit
                let perpPx: Double = pdx * perpJit
                let alongPy: Double = -dy * Double(tailLen) * along + dy * alongJit
                let perpPy: Double = pdy * perpJit
                let sx: CGFloat = hx + CGFloat(alongPx + perpPx)
                let sy: CGFloat = hy + CGFloat(alongPy + perpPy)

                // Twinkle — independent phase per sparkle.
                let twk: Double = sin(t * 2.4 + sd * 3.17) * 0.5 + 0.5
                let lifeFade: Double = 1.0 - along * 0.55
                let sparkleAlpha: Double = appear * lifeFade * twk
                guard sparkleAlpha > 0.05 else { continue }
                let sparkleSize: CGFloat = CGFloat(0.7 + twk * 1.6)

                // Coloured halo glow.
                let haloS: CGFloat = sparkleSize * 3.5
                ctx.fill(
                    Circle().path(in: CGRect(x: sx - haloS / 2, y: sy - haloS / 2,
                                             width: haloS, height: haloS)),
                    with: .color(cometColor.opacity(sparkleAlpha * 0.32))
                )
                // White-hot core.
                ctx.fill(
                    Circle().path(in: CGRect(x: sx - sparkleSize / 2, y: sy - sparkleSize / 2,
                                             width: sparkleSize, height: sparkleSize)),
                    with: .color(.white.opacity(min(1.0, sparkleAlpha * 1.4)))
                )
            }

            // Glowing head — bigger and more dramatic.
            let outerR: CGFloat = 18.0
            ctx.fill(
                Circle().path(in: CGRect(x: hx - outerR, y: hy - outerR,
                                         width: outerR * 2, height: outerR * 2)),
                with: .color(cometColor.opacity(appear * 0.30))
            )
            let haloR: CGFloat = 9.0
            ctx.fill(
                Circle().path(in: CGRect(x: hx - haloR, y: hy - haloR,
                                         width: haloR * 2, height: haloR * 2)),
                with: .color(cometColor.opacity(appear * 0.65))
            )
            let midR: CGFloat = 4.5
            ctx.fill(
                Circle().path(in: CGRect(x: hx - midR, y: hy - midR,
                                         width: midR * 2, height: midR * 2)),
                with: .color(.white.opacity(min(1.0, appear * 1.3)))
            )
            let coreR: CGFloat = 2.2
            ctx.fill(
                Circle().path(in: CGRect(x: hx - coreR, y: hy - coreR,
                                         width: coreR * 2, height: coreR * 2)),
                with: .color(.white.opacity(min(1.0, appear * 1.6)))
            )
        } else if phase < 0.92 {
            // Explosion phase — expanding ring of particles + central flash.
            let explProgress: Double = (phase - 0.65) / 0.27
            let fade: Double = 1.0 - explProgress
            let radius: CGFloat = CGFloat(70.0 * explProgress)

            // Central white flash.
            let flashR: CGFloat = CGFloat(30.0 * fade)
            ctx.fill(
                Circle().path(in: CGRect(x: endX - flashR, y: endY - flashR,
                                         width: flashR * 2, height: flashR * 2)),
                with: .color(cometColor.opacity(fade * 0.45))
            )
            let coreR: CGFloat = CGFloat(12.0 * fade)
            ctx.fill(
                Circle().path(in: CGRect(x: endX - coreR, y: endY - coreR,
                                         width: coreR * 2, height: coreR * 2)),
                with: .color(.white.opacity(fade * 0.85))
            )

            // 14 expanding particles in a ring.
            let particleCount: Int = 14
            for i in 0..<particleCount {
                let pAngle: Double = Double(i) / Double(particleCount) * .pi * 2
                let px: CGFloat = endX + CGFloat(cos(pAngle)) * radius
                let py: CGFloat = endY + CGFloat(sin(pAngle)) * radius
                let psize: CGFloat = CGFloat(4.0 * fade)
                // Halo
                let phaloR: CGFloat = psize * 2.5
                ctx.fill(
                    Circle().path(in: CGRect(x: px - phaloR, y: py - phaloR,
                                             width: phaloR * 2, height: phaloR * 2)),
                    with: .color(cometColor.opacity(fade * 0.40))
                )
                // Core
                ctx.fill(
                    Circle().path(in: CGRect(x: px - psize / 2, y: py - psize / 2,
                                             width: psize, height: psize)),
                    with: .color(cometColor.opacity(min(1.0, fade * 1.2)))
                )
            }
        }
        // Phase 0.92...1.0 → dormant (waiting to loop).
    }
}

/// A single procedural comet — direction, origin, speed, colour.
struct Comet {
    let angle: Double          // direction of travel (radians)
    let startX: Double         // origin X as fraction of screen width
    let startY: Double         // origin Y as fraction of screen height
    let speed: Double          // lifecycle speed
    let startPhase: Double     // 0...1 — staggers when each comet appears
    let paletteIdx: Int        // colour from galaxyPalette

    static func random() -> Comet {
        Comet(
            angle: Double.random(in: 0...(.pi * 2)),
            startX: Double.random(in: -0.05...1.05),
            startY: Double.random(in: -0.05...1.05),
            speed: Double.random(in: 0.030...0.060),
            startPhase: Double.random(in: 0...1),
            paletteIdx: Int.random(in: 0..<12)
        )
    }
}

/// One particle in the spiral-galaxy distribution.
struct GalaxyParticle {
    let angle: Double          // baked angle around centre (rotation added at draw time)
    let radius: Double         // 0 (centre) ... 1 (edge)
    let jitterX: Double        // small per-particle offset
    let jitterY: Double
    let size: Double           // pixel size
    let brightness: Double     // 0.4 ... 1.0 — varies particle-to-particle
    let paletteIdx: Int        // colour from Level4SpaceScene.galaxyPalette
    let twinkleSeed: Double
    /// +1 = clockwise, -1 = counter-clockwise. Each particle picks one,
    /// roughly half each, so the galaxy has two interleaved counter-
    /// rotating systems woven through it.
    let spinDir: Double

    /// Build a galaxy: bulge of yellow stars in the centre + 2 spiral arms
    /// of mostly white/blue stars trailing outward.
    static func makeGalaxy(count: Int) -> [GalaxyParticle] {
        var out: [GalaxyParticle] = []
        let arms: Int = 2
        let twist: Double = 4.5  // radians per radius unit — tighter = more wound

        // Bulge: ~30% of particles, concentrated near centre, yellow palette
        let bulgeCount: Int = count * 30 / 100
        for _ in 0..<bulgeCount {
            let r0: Double = Double.random(in: 0...1)
            let r: Double = r0 * r0 * 0.30  // squared bias toward centre
            let a: Double = Double.random(in: 0...(.pi * 2))
            // Bulge palette: bias toward yellow-white (idx 3) and orange (4)
            // Bulge palette → gold/orange/white-bright dominates.
            // Indices map to galaxyPalette: 0=white, 3=gold, 4=orange.
            let pIdx: Int = [3, 3, 3, 3, 4, 4, 0].randomElement()!
            out.append(GalaxyParticle(
                angle: a,
                radius: r,
                jitterX: Double.random(in: -0.01...0.01),
                jitterY: Double.random(in: -0.01...0.01),
                size: 0.6 + Double.random(in: 0...0.7),
                brightness: 0.7 + Double.random(in: 0...0.3),
                paletteIdx: pIdx,
                twinkleSeed: Double.random(in: 0...100),
                spinDir: Bool.random() ? 1.0 : -1.0
            ))
        }

        // Arm particles: ~70%, on logarithmic spirals.
        let armCount: Int = count - bulgeCount
        for _ in 0..<armCount {
            let arm: Int = Int.random(in: 0..<arms)
            let armBase: Double = Double(arm) * (.pi * 2.0 / Double(arms))
            let t: Double = Double.random(in: 0.10...1.0)
            // Logarithmic-spiral parametrisation: angle = base + t * twist
            let theta: Double = armBase + t * twist
            // Radial position bias toward inner-mid arm (more density)
            let r: Double = pow(t, 0.85)
            // Perpendicular jitter (arm thickness)
            let armWidth: Double = 0.05 + (1.0 - t) * 0.04
            let jit: Double = Double.random(in: -armWidth...armWidth)
            // Tangent direction → perpendicular = (-sin, cos)
            let jx: Double = -sin(theta) * jit
            let jy: Double = cos(theta) * jit

            // Arm palette: mostly white/blue-white, some yellow, rare red
            // Arm palette → vibrant mix of every nebula colour.
            // Indices 0…11 of galaxyPalette. White (0) appears less often
            // so the colour pops; the vivid hues dominate.
            let pIdx: Int = [1, 2, 2, 3, 4, 5, 5, 6, 6, 7, 8, 9, 10, 11, 0].randomElement()!
            out.append(GalaxyParticle(
                angle: theta,
                radius: r,
                jitterX: jx,
                jitterY: jy,
                size: 0.4 + Double.random(in: 0...0.7),
                brightness: 0.5 + Double.random(in: 0...0.5),
                paletteIdx: pIdx,
                twinkleSeed: Double.random(in: 0...100),
                spinDir: Bool.random() ? 1.0 : -1.0
            ))
        }

        return out
    }
}

/// Immutable seed values for a single procedural star.
struct SpaceStar {
    let angle: Double          // radians around screen centre
    let depth: Double          // 0 = far, 1 = close
    let startPhase: Double     // 0...1, current position along radial path
    let speed: Double          // how fast it drifts outward (depth-related)
    let twinkleSeed: Double
    let paletteIdx: Int

    static func random() -> SpaceStar {
        // Weighted palette: 40% white, 24% blue-white, 14% pale-blue,
        // 13% yellow-white, 7% orange, 2% red — matches real distribution.
        let weights: [Int] = [40, 24, 14, 13, 7, 2]
        let total: Int = weights.reduce(0, +)
        var roll: Int = Int.random(in: 0..<total)
        var idx: Int = 0
        for (i, w) in weights.enumerated() {
            if roll < w { idx = i; break }
            roll -= w
        }

        // Cubic depth — most stars far/dim/tiny, few bright.
        let raw: Double = Double.random(in: 0...1)
        let depth: Double = raw * raw * raw

        return SpaceStar(
            angle: Double.random(in: 0...(.pi * 2)),
            depth: depth,
            startPhase: Double.random(in: 0...1),
            // Very slow drift — real space is essentially still at this scale.
            speed: 0.002 + depth * 0.006,
            twinkleSeed: Double.random(in: 0...100),
            paletteIdx: idx
        )
    }
}

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

            // Draw nebula dust (Level 4) — soft glowing particles with depth
            if game.currentLevel >= 4 {
                for dust in game.nebulaDust {
                    let pulse = (sin(dust.phase * 2) + 1) / 2 * 0.3 + 0.7
                    let drawSize = dust.size * pulse
                    let drawOpacity = dust.opacity * pulse
                    let color = Color(red: dust.colorR, green: dust.colorG, blue: dust.colorB)

                    // Outer glow
                    let glowSize = drawSize * 3
                    context.fill(
                        Circle().path(in: CGRect(
                            x: dust.x - glowSize / 2,
                            y: dust.y - glowSize / 2,
                            width: glowSize,
                            height: glowSize
                        )),
                        with: .color(color.opacity(drawOpacity * 0.3))
                    )

                    // Core
                    context.fill(
                        Circle().path(in: CGRect(
                            x: dust.x - drawSize / 2,
                            y: dust.y - drawSize / 2,
                            width: drawSize,
                            height: drawSize
                        )),
                        with: .color(color.opacity(drawOpacity))
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

