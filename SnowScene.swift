import SpriteKit
import AppKit

/// One snowflake (or one puff particle). Each carries its own physics.
final class Flake: SKSpriteNode {
    var radius: CGFloat = 2
    var term: CGFloat = 40
    var phase: CGFloat = 0
    var swayFreq: CGFloat = 1
    var swayAmp: CGFloat = 12
    var spin: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
}

/// The whole desktop: three depths of snow, drifts on the ground and on
/// every window, the snowman, the yeti, snowball play and the plough.
final class SnowScene: SKScene {
    private let settings: SnowSettings
    weak var overlay: NSWindow?
    /// The display the overlay covers, in global Cocoa coordinates.
    var screenFrame: CGRect = .zero
    /// 0.5 in Low Power Mode, set by the app delegate.
    var powerScale: CGFloat = 1

    // MARK: time, wind, pointer

    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0
    private var wind: CGFloat = 0
    private var gust: CGFloat = 0
    private var gustTarget: CGFloat = 0
    private var gustTimer: CGFloat = 4
    private var blizzardT: CGFloat = 0
    private var pointer = CGPoint(x: -999, y: -999)
    private var pointerVel = CGVector.zero
    private var pointerMovedAt: CGFloat = -10
    private var capturing = false
    private var greetIn: CGFloat = 2.5
    private var buttonWasDown = false
    private var lastDesktopThrow: CGFloat = -10

    // MARK: snowfall

    private struct LayerSpec {
        let share: CGFloat, rLo: CGFloat, rHi: CGFloat
        let termBase: CGFloat, termPerR: CGFloat
        let aLo: CGFloat, aHi: CGFloat
        let z: CGFloat, windMul: CGFloat
        let swayLo: CGFloat, swayHi: CGFloat
    }
    /// Far (tiny, slow, dim, behind everything), mid (the snow that lands
    /// and piles up), near (big, soft, out-of-focus, in front of everything).
    /// The parallax between them is what makes it read as real depth.
    private let specs: [LayerSpec] = [
        LayerSpec(share: 0.42, rLo: 0.7, rHi: 1.5, termBase: 14, termPerR: 10, aLo: 0.30, aHi: 0.55,
                  z: 2, windMul: 0.45, swayLo: 4, swayHi: 10),
        LayerSpec(share: 0.48, rLo: 1.5, rHi: 3.4, termBase: 22, termPerR: 11, aLo: 0.72, aHi: 0.95,
                  z: 12, windMul: 1, swayLo: 8, swayHi: 22),
        LayerSpec(share: 0.10, rLo: 5, rHi: 11, termBase: 64, termPerR: 7, aLo: 0.20, aHi: 0.40,
                  z: 40, windMul: 1.7, swayLo: 14, swayHi: 30),
    ]
    private var layers: [[Flake]] = [[], [], []]
    private var particles: [Flake] = []
    private var seeded = false

    // MARK: ground and window drifts

    private let colWidth: CGFloat = 6
    private var drift: [CGFloat] = []
    private let driftNode = SKShapeNode()
    private let driftCap: CGFloat = 64
    private let ledgeCap: CGFloat = 28

    private struct Ledge {
        var topY: CGFloat
        var minX: CGFloat
        var maxX: CGFloat
        var heights: [CGFloat]
    }
    private var ledges: [Int: Ledge] = [:]
    private var ledgeNodes: [Int: SKShapeNode] = [:]
    private var ledgeClock: CGFloat = 0
    private var ledgeInterval: CGFloat = 0.25
    private var dockFrame: CGRect?

    private var sparkles: [(node: SKSpriteNode, t: CGFloat, dur: CGFloat)] = []
    private var footprints: [(node: SKSpriteNode, age: CGFloat)] = []

    // MARK: snowballs

    private struct Clump {
        let node: SKSpriteNode
        var vx: CGFloat
        var vy: CGFloat
        let r: CGFloat
        let spin: CGFloat
    }
    private var clumps: [Clump] = []

    private struct Throw {
        let node: SKSpriteNode
        let p0: CGPoint, p1: CGPoint, p2: CGPoint
        var u: CGFloat
        let dur: CGFloat
        let s0: CGFloat, s1: CGFloat
        let atGlass: Bool
    }
    private var throwsInFlight: [Throw] = []
    private var splats: [SKSpriteNode] = []

    // MARK: characters

    private var snowman: SnowmanNode!
    private var yeti: YetiNode!
    private var plough: PloughNode?
    private var ploughFront: CGFloat = 0
    private var sprayClock: CGFloat = 0

    // MARK: build-your-own snowman

    private final class BuildBall {
        let node: SKSpriteNode
        var r: CGFloat
        init(node: SKSpriteNode, r: CGFloat) {
            self.node = node
            self.r = r
        }
    }
    private final class Stack {
        var balls: [BuildBall]
        init(_ balls: [BuildBall]) { self.balls = balls }
    }
    private var stacks: [Stack] = []
    private var built: [SnowmanNode] = []
    private enum Drag {
        case roll(Stack)
        case slide(Stack, offset: CGFloat)
        case snowman(SnowmanNode, offset: CGFloat)
    }
    private var drag: Drag?

    private struct SavedSnowman: Codable {
        var x: Double
        var scale: Double
        var outfit: SnowmanOutfit
    }

    // MARK: - setup

    init(size: CGSize, settings: SnowSettings) {
        self.settings = settings
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = .zero
        isUserInteractionEnabled = true
        snowman = SnowmanNode(host: self, outfit: .classic)
        yeti = YetiNode(host: self)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        guard driftNode.parent == nil else { return }
        seedDrift()
        driftNode.fillColor = .white
        driftNode.fillTexture = Tex.driftFill
        driftNode.strokeColor = Palette.rim.withAlphaComponent(0.55)
        driftNode.lineWidth = 1.3
        driftNode.isAntialiased = true
        driftNode.zPosition = 4
        addChild(driftNode)

        for _ in 0..<16 {
            let s = Art.sprite(Tex.sparkle, 14, 14)
            s.zPosition = 5
            s.alpha = 0
            s.blendMode = .add
            addChild(s)
            sparkles.append((node: s, t: CGFloat.random(in: -3...0), dur: 1))
        }

        snowman.position = CGPoint(x: homeX(), y: groundUnder(homeX(), half: 40))
        snowman.zPosition = 7
        addChild(snowman)
        yeti.position = CGPoint(x: -150, y: 0)
        yeti.zPosition = 8
        addChild(yeti)

        loadBuilt()
        refreshLedges()
        syncFlakes()
        rebuildDriftPath()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard !drift.isEmpty else { return }
        let n = Int(ceil(size.width / colWidth)) + 2
        drift = (0..<n).map { i in
            let src = Int(CGFloat(i) * CGFloat(drift.count - 1) / CGFloat(max(1, n - 1)))
            return drift[min(max(src, 0), drift.count - 1)]
        }
        snowman?.position.x = homeX()
        rebuildDriftPath()
    }

    private func seedDrift() {
        let n = Int(ceil(size.width / colWidth)) + 2
        let a = CGFloat.random(in: 0...6), b = CGFloat.random(in: 0...6)
        drift = (0..<n).map { i in
            let x = CGFloat(i)
            return max(5, 15 + 6 * sin(x * 0.045 + a) + 4 * sin(x * 0.13 + b) + CGFloat.random(in: 0...1.5))
        }
    }

    // MARK: - coordinates

    private func toScene(_ global: CGPoint) -> CGPoint {
        CGPoint(x: global.x - screenFrame.minX, y: global.y - screenFrame.minY)
    }

    private var inBounds: Bool {
        pointer.x >= 0 && pointer.y >= 0 && pointer.x <= size.width && pointer.y <= size.height
    }

    // MARK: - input: pointer, clicks, drags

    private func pollPointer(_ dt: CGFloat) {
        let p = toScene(NSEvent.mouseLocation)
        let dx = p.x - pointer.x, dy = p.y - pointer.y
        if pointer.x > -900 {
            let k = min(1, 0.5 * dt * 60)
            pointerVel.dx += (dx / max(dt, 0.001) - pointerVel.dx) * k
            pointerVel.dy += (dy / max(dt, 0.001) - pointerVel.dy) * k
        }
        if abs(dx) + abs(dy) > 0.5 { pointerMovedAt = clock }
        pointer = p
    }

    /// Clicks only reach the overlay where there is something to grab.
    /// Everywhere else the click goes straight through to the desktop.
    private func isInteractive(_ p: CGPoint) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x <= size.width, p.y <= size.height else { return false }
        if splatAt(p) != nil { return true }
        if built.contains(where: { $0.hit(p) }) { return true }
        if settings.showSnowman && snowman.hit(p) { return true }
        if yeti.hit(p) { return true }
        if stackAt(p) != nil { return true }
        return p.y <= driftAt(p.x) + 14
    }

    private func updateMouseCapture() {
        let want = drag != nil || isInteractive(pointer)
        if want != capturing {
            capturing = want
            overlay?.ignoresMouseEvents = !want
        }
    }

    func releaseMouse() {
        capturing = false
        drag = nil
        overlay?.ignoresMouseEvents = true
    }

    override func mouseDown(with event: NSEvent) { press(event.location(in: self)) }
    override func mouseDragged(with event: NSEvent) { dragTo(event.location(in: self)) }
    override func mouseUp(with event: NSEvent) { release() }

    private func press(_ p: CGPoint) {
        if let s = splatAt(p) {
            wipe(s)
            return
        }
        if let b = built.last(where: { $0.hit(p) }) {
            b.poke()
            drag = .snowman(b, offset: b.position.x - p.x)
            return
        }
        if settings.showSnowman && snowman.hit(p) {
            snowman.poke()
            return
        }
        if yeti.hit(p) {
            throwIntoScene(target: p)
            return
        }
        if let st = stackAt(p) {
            drag = st.balls.count == 1 ? .roll(st) : .slide(st, offset: st.balls[0].node.position.x - p.x)
            return
        }
        if p.y <= driftAt(p.x) + 16 {
            let st = newStack(x: p.x, r: 9)
            consumeDrift(at: p.x, radius: 9, amount: 2)
            drag = .roll(st)
        }
    }

    private func dragTo(_ p: CGPoint) {
        guard let d = drag else { return }
        switch d {
        case .roll(let st):
            let b = st.balls[0]
            let nx = clamp(p.x, b.r, size.width - b.r)
            let dx = nx - b.node.position.x
            b.node.position.x = nx
            b.node.zRotation -= dx / b.r
            // It only grows where there is snow to pick up, like real snow.
            let snow = driftAt(nx)
            if snow > 2.5 && b.r < 54 {
                let grow = abs(dx) * 0.06 * min(1, snow / 10)
                b.r = min(54, b.r + grow)
                b.node.size = CGSize(width: b.r * 2, height: b.r * 2)
                consumeDrift(at: nx, radius: b.r * 0.7, amount: grow * 1.4)
            }
            layout(st)
        case .slide(let st, let offset):
            let b = st.balls[0]
            b.node.position.x = clamp(p.x + offset, b.r, size.width - b.r)
            layout(st)
        case .snowman(let s, let offset):
            s.position.x = clamp(p.x + offset, -30, size.width + 30)
        }
    }

    private func release() {
        guard let d = drag else { return }
        drag = nil
        switch d {
        case .roll(let st), .slide(let st, _):
            tryMerge(st)
        case .snowman(let s, _):
            if s.position.x < 24 || s.position.x > size.width - 24 {
                burst(at: CGPoint(x: s.position.x, y: s.position.y + 80), count: 30, spread: 220)
                s.removeFromParent()
                built.removeAll { $0 === s }
            }
            saveBuilt()
        }
    }

    /// A click on the bare desktop (seen through a global monitor, since the
    /// overlay lets those clicks through) throws a snowball into the scene.
    func desktopClick(global: CGPoint) {
        guard settings.clickSnowballs, !settings.paused, clock - lastDesktopThrow > 0.12 else { return }
        let p = toScene(global)
        guard p.x >= 0, p.y >= 0, p.x <= size.width, p.y <= size.height,
              WindowTracker.isDesktop(atCocoa: global) else { return }
        lastDesktopThrow = clock
        throwIntoScene(target: p)
    }

    // MARK: - build your own snowman

    private func newStack(x: CGFloat, r: CGFloat) -> Stack {
        let node = Art.sprite(Tex.snowball, r * 2, r * 2)
        node.zPosition = 6
        addChild(node)
        node.position = CGPoint(x: x, y: driftAt(x) * 0.85 + r)
        let st = Stack([BuildBall(node: node, r: r)])
        stacks.append(st)
        if stacks.count > 10, let old = stacks.first(where: { $0.balls.count == 1 && $0 !== st }) {
            removeStack(old, puff: true)
        }
        return st
    }

    private func removeStack(_ st: Stack, puff: Bool) {
        for b in st.balls {
            if puff { burst(at: b.node.position, count: 8, spread: 110) }
            b.node.removeFromParent()
        }
        stacks.removeAll { $0 === st }
    }

    private func layout(_ st: Stack) {
        guard let first = st.balls.first else { return }
        let x = first.node.position.x
        first.node.position.y = driftAt(x) * 0.85 + first.r
        for i in st.balls.indices.dropFirst() {
            let below = st.balls[i - 1], b = st.balls[i]
            b.node.position = CGPoint(x: x, y: below.node.position.y + below.r + b.r - min(b.r, below.r) * 0.3)
            b.node.zPosition = 6 + CGFloat(i) * 0.1
        }
    }

    private func stackAt(_ p: CGPoint) -> Stack? {
        for st in stacks.reversed() {
            for b in st.balls {
                let dx = p.x - b.node.position.x, dy = p.y - b.node.position.y
                if dx * dx + dy * dy <= (b.r + 6) * (b.r + 6) { return st }
            }
        }
        return nil
    }

    /// Drop one stack onto another and they combine. The biggest ball always
    /// goes on the bottom, so it looks right however she stacks them.
    private func tryMerge(_ st: Stack) {
        guard let mine = st.balls.first else { return }
        let x = mine.node.position.x
        guard let other = stacks.first(where: {
            $0 !== st && abs($0.balls[0].node.position.x - x) < 0.62 * ($0.balls[0].r + mine.r)
        }) else { return }
        guard other.balls.count + st.balls.count <= 3 else {
            mine.node.position.x = clamp(x + (x < other.balls[0].node.position.x ? -1 : 1) * (mine.r + 12),
                                         mine.r, size.width - mine.r)
            layout(st)
            return
        }
        let anchorX = other.balls[0].node.position.x
        other.balls = (other.balls + st.balls).sorted { $0.r > $1.r }
        other.balls[0].node.position.x = anchorX
        stacks.removeAll { $0 === st }
        layout(other)
        burst(at: CGPoint(x: anchorX, y: other.balls.last?.node.position.y ?? 0), count: 10, spread: 120)
        if other.balls.count == 3 { completeSnowman(other) }
    }

    private func completeSnowman(_ st: Stack) {
        let bottom = st.balls[0]
        let x = bottom.node.position.x
        let s = SnowmanNode(host: self, outfit: .random(), scale: clamp(bottom.r / 46, 0.5, 1.15))
        s.position = CGPoint(x: x, y: groundUnder(x, half: 30))
        s.zPosition = 7
        addChild(s)
        built.append(s)
        removeStack(st, puff: false)
        burst(at: CGPoint(x: x, y: s.position.y + 90 * s.figureScale), count: 34, spread: 240)
        let name = settings.displayName
        say(name.isEmpty ? "Thank you!" : "Thanks, \(name)!",
            at: CGPoint(x: x + 20, y: s.position.y + 190 * s.figureScale))
        if built.count > 8 {
            let old = built.removeFirst()
            burst(at: CGPoint(x: old.position.x, y: old.position.y + 60), count: 20, spread: 160)
            old.removeFromParent()
        }
        saveBuilt()
    }

    /// "Roll a snowball" from the menu: a starter ball on the snow.
    func spawnStarterBall() {
        let x = clamp(size.width * 0.38 + CGFloat.random(in: -80...80), 40, size.width - 40)
        let st = newStack(x: x, r: 13)
        burst(at: st.balls[0].node.position, count: 10, spread: 100)
    }

    private func saveBuilt() {
        let w = max(1, size.width)
        let saved = built.map { SavedSnowman(x: Double($0.position.x / w), scale: Double($0.figureScale), outfit: $0.outfit) }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: "builtSnowmen")
        }
    }

    private func loadBuilt() {
        guard let data = UserDefaults.standard.data(forKey: "builtSnowmen"),
              let saved = try? JSONDecoder().decode([SavedSnowman].self, from: data) else { return }
        for item in saved.prefix(8) {
            let s = SnowmanNode(host: self, outfit: item.outfit, scale: CGFloat(item.scale))
            let x = CGFloat(item.x) * size.width
            s.position = CGPoint(x: x, y: groundUnder(x, half: 30))
            s.zPosition = 7
            addChild(s)
            built.append(s)
        }
    }

    // MARK: - menu actions

    func summonYeti() { yeti.summon() }

    func startBlizzard() {
        blizzardT = 24
        gustTimer = 0
    }

    func startPlough() {
        guard plough == nil else { return }
        let p = PloughNode()
        p.position = CGPoint(x: -110, y: 0)
        p.zPosition = 15
        addChild(p)
        plough = p
        ploughFront = -200
    }

    // MARK: - hooks for the characters

    var snowmanX: CGFloat? {
        settings.showSnowman && snowman.mode == .idle ? snowman.position.x : nil
    }

    func knockSnowman(fromLeft: Bool) {
        guard settings.showSnowman else { return }
        snowman.knock(fromLeft: fromLeft)
    }

    func say(_ text: String, at p: CGPoint) {
        let b = SpeechBubble(text)
        b.position = CGPoint(x: clamp(p.x, 70, size.width - 70), y: min(p.y, size.height - 70))
        b.zPosition = 30
        addChild(b)
        b.play()
    }

    func addFootprint(x: CGFloat) {
        guard x > -20, x < size.width + 20 else { return }
        let f = Art.sprite(Tex.footprint, 22, 12, at: CGPoint(x: x, y: driftAt(x) * 0.85 + 1))
        f.zPosition = 5
        addChild(f)
        footprints.append((node: f, age: 0))
        consumeDrift(at: x, radius: 6, amount: 1.2)
        if footprints.count > 60 {
            footprints.removeFirst().node.removeFromParent()
        }
    }

    // MARK: - puffs, snowballs, splats

    func burst(at point: CGPoint, count: Int, spread: CGFloat) {
        for _ in 0..<count where particles.count < 600 {
            let f = Flake(texture: Tex.softDot)
            let r = CGFloat.random(in: 1.3...3.4)
            f.size = CGSize(width: r * 3.2, height: r * 3.2)
            f.position = point
            let a = CGFloat.random(in: 0...(2 * .pi))
            let sp = CGFloat.random(in: 20...max(21, spread))
            f.vx = cos(a) * sp
            f.vy = sin(a) * sp + 40
            f.maxLife = CGFloat.random(in: 0.6...1.2)
            f.life = f.maxLife
            f.zPosition = 13
            f.alpha = 0.95
            addChild(f)
            particles.append(f)
        }
    }

    private func dropClump(at p: CGPoint, r: CGFloat, vx: CGFloat, vy: CGFloat) {
        guard clumps.count < 160 else { return }
        let n = Art.sprite(Tex.snowball, r * 2, r * 2, at: p)
        n.zPosition = 14
        addChild(n)
        clumps.append(Clump(node: n, vx: vx, vy: vy, r: r, spin: CGFloat.random(in: -6...6)))
    }

    /// Stella throws: the ball leaves from the bottom of the screen, big
    /// (near her), and shrinks as it flies into the scene.
    func throwIntoScene(target: CGPoint) {
        let start = CGPoint(x: clamp(target.x * 0.7 + size.width * 0.15 + CGFloat.random(in: -40...40), 0, size.width),
                            y: -50)
        let dist = hypot(target.x - start.x, target.y - start.y)
        let mid = CGPoint(x: (start.x + target.x) / 2, y: max(start.y, target.y) + 120 + dist * 0.22)
        let n = Art.sprite(Tex.snowball, 24, 24, at: start)
        n.zPosition = 45
        addChild(n)
        throwsInFlight.append(Throw(node: n, p0: start, p1: mid, p2: target, u: 0, dur: 0.42,
                                    s0: 2.6, s1: 0.55, atGlass: false))
    }

    /// The yeti throws at you: the ball starts small in his paw and grows
    /// as it comes at the screen, then splats on the glass.
    func throwAtGlass(from: CGPoint) {
        let target = CGPoint(x: CGFloat.random(in: size.width * 0.12...size.width * 0.88),
                             y: CGFloat.random(in: size.height * 0.32...size.height * 0.80))
        let mid = CGPoint(x: (from.x + target.x) / 2, y: max(from.y, target.y) + 200)
        let n = Art.sprite(Tex.snowball, 20, 20, at: from)
        n.zPosition = 55
        addChild(n)
        throwsInFlight.append(Throw(node: n, p0: from, p1: mid, p2: target, u: 0, dur: 0.6,
                                    s0: 0.8, s1: 5.5, atGlass: true))
    }

    private func impact(_ p: CGPoint) {
        burst(at: p, count: 16, spread: 150)
        if yeti.hit(p) {
            yeti.bonk()
        } else if let b = built.first(where: { $0.hit(p) }) {
            b.poke()
        } else if settings.showSnowman && snowman.hit(p) {
            snowman.poke()
        } else if p.y < driftAt(p.x) + 40 {
            addSnow(at: p.x, radius: 14, amount: 3)
        }
    }

    private func splat(at p: CGPoint) {
        guard let tex = Tex.splats.randomElement() else { return }
        let s = SKSpriteNode(texture: tex)
        s.size = CGSize(width: 210, height: 210)
        s.position = p
        s.zRotation = CGFloat.random(in: -0.5...0.5)
        s.zPosition = 60
        s.setScale(0.3)
        addChild(s)
        splats.append(s)
        let pop = SKAction.scale(to: 1.1, duration: 0.07)
        pop.timingMode = .easeOut
        let slide = SKAction.moveBy(x: 0, y: -48, duration: 3.2)
        slide.timingMode = .easeIn
        s.run(SKAction.sequence([
            pop,
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 2.6),
            SKAction.group([slide, SKAction.fadeOut(withDuration: 3.2)]),
            SKAction.run { [weak self, weak s] in self?.splats.removeAll { $0 === s } },
            SKAction.removeFromParent(),
        ]))
        for _ in 0..<12 {
            let f = Flake(texture: Tex.softDot)
            let r = CGFloat.random(in: 4...10)
            f.size = CGSize(width: r * 2.4, height: r * 2.4)
            f.position = p
            let a = CGFloat.random(in: 0...(2 * .pi)), sp = CGFloat.random(in: 160...420)
            f.vx = cos(a) * sp
            f.vy = sin(a) * sp
            f.maxLife = CGFloat.random(in: 0.35...0.7)
            f.life = f.maxLife
            f.zPosition = 61
            addChild(f)
            particles.append(f)
        }
    }

    private func splatAt(_ p: CGPoint) -> SKSpriteNode? {
        splats.last(where: { s in
            s.alpha > 0.3 && hypot(p.x - s.position.x, p.y - s.position.y) < 70 * s.xScale
        })
    }

    /// Click a splat to wipe it off the screen.
    private func wipe(_ s: SKSpriteNode) {
        splats.removeAll { $0 === s }
        s.removeAllActions()
        burst(at: s.position, count: 14, spread: 160)
        s.run(SKAction.sequence([
            SKAction.group([SKAction.scaleX(to: 1.35, y: 0.6, duration: 0.18), SKAction.fadeOut(withDuration: 0.18)]),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - snow bookkeeping

    func driftAt(_ x: CGFloat) -> CGFloat {
        guard drift.count > 1 else { return 0 }
        let fx = clamp(x / colWidth, 0, CGFloat(drift.count - 1))
        let i = Int(fx), j = min(i + 1, drift.count - 1)
        return lerp(drift[i], drift[j], fx - CGFloat(i))
    }

    private func groundUnder(_ x: CGFloat, half: CGFloat) -> CGFloat {
        (driftAt(x - half) + driftAt(x) * 2 + driftAt(x + half)) / 4 * 0.8
    }

    private func consumeDrift(at x: CGFloat, radius: CGFloat, amount: CGFloat) {
        guard !drift.isEmpty else { return }
        let c0 = max(0, Int((x - radius) / colWidth)), c1 = min(drift.count - 1, Int((x + radius) / colWidth))
        guard c0 <= c1 else { return }
        for c in c0...c1 { drift[c] = max(0, drift[c] - amount) }
    }

    private func addSnow(at x: CGFloat, radius: CGFloat, amount: CGFloat) {
        guard !drift.isEmpty else { return }
        let c0 = max(0, Int((x - radius) / colWidth)), c1 = min(drift.count - 1, Int((x + radius) / colWidth))
        guard c0 <= c1 else { return }
        for c in c0...c1 {
            let d = abs(CGFloat(c) * colWidth - x) / max(radius, 1)
            drift[c] = min(driftCap, drift[c] + amount * max(0, 1 - d * d))
        }
    }

    private func homeX() -> CGFloat {
        var x = size.width - 170
        if let dock = dockFrame, x + 70 > dock.minX && x - 70 < dock.maxX {
            x = dock.maxX + 90 < size.width - 40 ? dock.maxX + 90 : dock.minX - 110
        }
        return x
    }

    // MARK: - window ledges

    private func refreshLedges() {
        let visible = NSScreen.screens.first?.visibleFrame ?? screenFrame
        let menuBarBottom = visible.maxY - screenFrame.minY
        var seen = Set<Int>()
        var anyMoved = false
        var dock: CGRect?
        for w in WindowTracker.snapshot() {
            let f = w.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            guard f.maxY < menuBarBottom - 2, f.maxY > 0, f.maxX > 0, f.minX < size.width else { continue }
            seen.insert(w.id)
            if upsertLedge(id: w.id, minX: max(f.minX, -8), maxX: min(f.maxX, size.width + 8), topY: f.maxY) {
                anyMoved = true
            }
        }
        // The Dock gets a pile of snow along its top edge, like any window.
        if let d = WindowTracker.dockFrame() {
            let f = d.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            dock = f
            seen.insert(-1)
            upsertLedge(id: -1, minX: f.minX, maxX: f.maxX, topY: f.maxY)
        }
        for id in Array(ledges.keys) where !seen.contains(id) {
            if let l = ledges[id] { shed(l, fraction: 1) }
            ledges.removeValue(forKey: id)
            ledgeNodes[id]?.removeFromParent()
            ledgeNodes.removeValue(forKey: id)
        }
        if dock != dockFrame {
            dockFrame = dock
            if snowman.mode == .idle { snowman.position.x = homeX() }
        }
        // Poll fast while a window is being dragged, so the snow keeps up.
        ledgeInterval = anyMoved ? 0.06 : 0.25
    }

    @discardableResult
    private func upsertLedge(id: Int, minX: CGFloat, maxX: CGFloat, topY: CGFloat) -> Bool {
        let n = max(2, Int(ceil((maxX - minX) / colWidth)))
        guard var l = ledges[id] else {
            ledges[id] = Ledge(topY: topY, minX: minX, maxX: maxX, heights: [CGFloat](repeating: 0, count: n))
            let node = SKShapeNode()
            node.fillColor = .white
            node.fillTexture = Tex.driftFill
            node.strokeColor = Palette.rim.withAlphaComponent(0.55)
            node.lineWidth = 1.2
            node.zPosition = 4
            addChild(node)
            ledgeNodes[id] = node
            return false
        }
        let moved = abs(l.topY - topY) > 0.5 || abs(l.minX - minX) > 0.5 || abs(l.maxX - maxX) > 0.5
        if l.topY - topY > 40 {
            // Window yanked downward: half the snow slides off.
            shed(l, fraction: 0.5)
            for i in l.heights.indices { l.heights[i] *= 0.5 }
        }
        if l.heights.count != n {
            let old = l.heights
            l.heights = (0..<n).map { i in
                old[min(old.count - 1, Int(CGFloat(i) * CGFloat(old.count - 1) / CGFloat(max(1, n - 1))))]
            }
        }
        l.topY = topY
        l.minX = minX
        l.maxX = maxX
        ledges[id] = l
        return moved
    }

    /// Snow on a window that closed, minimized, or got yanked falls off as
    /// clumps, which land in the drifts below (or on a lower window).
    private func shed(_ l: Ledge, fraction: CGFloat) {
        guard l.heights.reduce(0, +) > 3 else { return }
        var x = l.minX + 6
        var made = 0
        while x < l.maxX - 4 && made < 36 {
            let c = min(l.heights.count - 1, max(0, Int((x - l.minX) / colWidth)))
            let h = l.heights[c] * fraction
            if h > 1.2 {
                dropClump(at: CGPoint(x: x, y: l.topY + h * 0.5), r: clamp(2 + h * 0.45, 2.5, 10),
                          vx: CGFloat.random(in: -35...35), vy: CGFloat.random(in: -10...50))
                made += 1
            }
            x += CGFloat.random(in: 11...18)
        }
    }

    /// The highest window top a falling thing crossed this frame.
    private func ledgeHit(prevY: CGFloat, newY: CGFloat, x: CGFloat) -> Int? {
        var best: Int?
        var bestY = -CGFloat.greatestFiniteMagnitude
        for (id, l) in ledges where x >= l.minX && x <= l.maxX && newY <= l.topY && l.topY <= prevY {
            if l.topY > bestY {
                bestY = l.topY
                best = id
            }
        }
        return best
    }

    private func addToLedge(_ id: Int, x: CGFloat, amount: CGFloat) {
        guard var l = ledges[id] else { return }
        let c = min(max(Int((x - l.minX) / colWidth), 0), l.heights.count - 1)
        l.heights[c] = min(ledgeCap, l.heights[c] + amount)
        if c > 0 { l.heights[c - 1] = min(ledgeCap, l.heights[c - 1] + amount * 0.4) }
        if c < l.heights.count - 1 { l.heights[c + 1] = min(ledgeCap, l.heights[c + 1] + amount * 0.4) }
        ledges[id] = l
    }

    // MARK: - snowfall

    private func configure(_ f: Flake, layer: Int, anywhere: Bool) {
        let sp = specs[layer]
        let sizeMul = CGFloat(settings.flakeSize)
        let r = CGFloat.random(in: sp.rLo...sp.rHi) * (layer == 0 ? 0.7 + 0.3 * sizeMul : sizeMul)
        var draw = r * 1.6
        if layer == 2 {
            f.texture = Tex.bokeh
            draw = r * 2
        } else if layer == 1 && r > 2.4 && Int.random(in: 0..<5) == 0 {
            f.texture = Tex.crystal
            draw = r * 2.7
        } else {
            f.texture = Tex.softDot
        }
        f.size = CGSize(width: draw, height: draw)
        f.radius = r
        f.term = (sp.termBase + r * sp.termPerR) * CGFloat.random(in: 0.85...1.15)
        f.phase = CGFloat.random(in: 0...(2 * .pi))
        f.swayFreq = CGFloat.random(in: 0.4...1.6)
        f.swayAmp = CGFloat.random(in: sp.swayLo...sp.swayHi)
        f.spin = CGFloat.random(in: -1.2...1.2)
        f.alpha = CGFloat.random(in: sp.aLo...sp.aHi)
        f.vx = 0
        f.vy = -f.term
        f.zRotation = CGFloat.random(in: 0...(2 * .pi))
        f.zPosition = sp.z
        f.position = CGPoint(x: CGFloat.random(in: 0...max(1, size.width)),
                             y: anywhere ? CGFloat.random(in: 0...max(1, size.height))
                                         : size.height + CGFloat.random(in: 4...60))
    }

    private var blizzardAmount: CGFloat {
        guard blizzardT > 0 else { return 0 }
        let up = clamp((24 - blizzardT) / 3, 0, 1), down = clamp(blizzardT / 5, 0, 1)
        return min(up, down)
    }

    private func syncFlakes() {
        let total = CGFloat(settings.snowfall) * powerScale * (1 + 1.6 * blizzardAmount)
        for layer in 0..<3 {
            let target = Int(total * specs[layer].share)
            while layers[layer].count < target {
                let f = Flake(texture: Tex.softDot)
                configure(f, layer: layer, anywhere: !seeded)
                addChild(f)
                layers[layer].append(f)
            }
            while layers[layer].count > target {
                layers[layer].removeLast().removeFromParent()
            }
        }
        seeded = true
    }

    private func updateFlakes(_ dt: CGFloat) {
        let pushOn = clock - pointerMovedAt < 0.4
        let pSpeed = hypot(pointerVel.dx, pointerVel.dy)
        let damp = max(0, 1 - 1.6 * dt)
        for layer in 0..<3 {
            let sp = specs[layer]
            for f in layers[layer] {
                let prevY = f.position.y
                f.vy += (-f.term - f.vy) * min(1, 2.2 * dt)
                f.position.y += f.vy * dt
                let sway = sin(clock * f.swayFreq + f.phase) * f.swayAmp
                f.position.x += (wind * sp.windMul + sway + f.vx) * dt
                f.vx *= damp
                f.zRotation += f.spin * dt

                // Moving the pointer fast through the snow scatters it.
                if layer > 0 && pushOn && pSpeed > 40 {
                    let dx = f.position.x - pointer.x, dy = f.position.y - pointer.y
                    let d2 = dx * dx + dy * dy
                    if d2 < 130 * 130 && d2 > 1 {
                        let d = sqrt(d2)
                        let push = (1 - d / 130) * min(1, pSpeed / 700) * 320
                        f.vx += dx / d * push * dt * 6
                        f.vy += dy / d * push * dt * 2
                    }
                }

                if f.position.x < -14 { f.position.x = size.width + 12 }
                if f.position.x > size.width + 14 { f.position.x = -12 }

                switch layer {
                case 1:
                    if let id = ledgeHit(prevY: prevY, newY: f.position.y, x: f.position.x) {
                        addToLedge(id, x: f.position.x, amount: f.radius * 0.8)
                        configure(f, layer: 1, anywhere: false)
                    } else if f.position.y <= driftAt(f.position.x) {
                        addSnow(at: f.position.x, radius: colWidth * 1.6, amount: f.radius * 0.22)
                        configure(f, layer: 1, anywhere: false)
                    }
                case 0:
                    if f.position.y < driftAt(f.position.x) - 2 { configure(f, layer: 0, anywhere: false) }
                default:
                    if f.position.y < -30 { configure(f, layer: 2, anywhere: false) }
                }
            }
        }
    }

    private func updateParticles(_ dt: CGFloat) {
        var i = 0
        while i < particles.count {
            let f = particles[i]
            f.vy -= 420 * dt
            f.vx *= max(0, 1 - 1.8 * dt)
            f.position.x += (f.vx + wind * 0.5) * dt
            f.position.y += f.vy * dt
            f.life -= dt
            f.alpha = max(0, f.life / f.maxLife) * 0.95
            if f.life <= 0 || f.position.y < -20 {
                f.removeFromParent()
                particles.remove(at: i)
                continue
            }
            i += 1
        }
    }

    private func updateClumps(_ dt: CGFloat) {
        var i = 0
        while i < clumps.count {
            var c = clumps[i]
            let prevY = c.node.position.y - c.r
            c.vy -= 900 * dt
            c.node.position.x += c.vx * dt
            c.node.position.y += c.vy * dt
            c.node.zRotation += c.spin * dt
            let bottom = c.node.position.y - c.r
            if let id = ledgeHit(prevY: prevY, newY: bottom, x: c.node.position.x) {
                addToLedge(id, x: c.node.position.x, amount: c.r * 0.8)
                burst(at: c.node.position, count: 3, spread: 60)
                c.node.removeFromParent()
                clumps.remove(at: i)
                continue
            }
            if bottom <= driftAt(c.node.position.x) {
                addSnow(at: c.node.position.x, radius: c.r * 1.6, amount: c.r * 0.7)
                burst(at: c.node.position, count: 4, spread: 70)
                c.node.removeFromParent()
                clumps.remove(at: i)
                continue
            }
            clumps[i] = c
            i += 1
        }
    }

    private func updateThrows(_ dt: CGFloat) {
        var i = 0
        while i < throwsInFlight.count {
            var t = throwsInFlight[i]
            t.u = min(1, t.u + dt / t.dur)
            let u = t.u, v = 1 - u
            t.node.position = CGPoint(x: v * v * t.p0.x + 2 * v * u * t.p1.x + u * u * t.p2.x,
                                      y: v * v * t.p0.y + 2 * v * u * t.p1.y + u * u * t.p2.y)
            let k = t.atGlass ? pow(u, 1.7) : 1 - (1 - u) * (1 - u)
            t.node.setScale(lerp(t.s0, t.s1, k))
            t.node.zRotation += (t.atGlass ? 5 : -8) * dt
            if u >= 1 {
                t.node.removeFromParent()
                throwsInFlight.remove(at: i)
                if t.atGlass { splat(at: t.p2) } else { impact(t.p2) }
                continue
            }
            throwsInFlight[i] = t
            i += 1
        }
    }

    private func updateDrifts(_ dt: CGFloat) {
        // Slow melt, plus a little settling so piles keep a natural slope.
        let melt = max(0, 1 - 0.0006 * dt)
        let settle = min(1, dt * 8) * 0.5
        for i in drift.indices {
            drift[i] *= melt
            if i > 0 {
                let d = drift[i] - drift[i - 1]
                if abs(d) > 5 {
                    let m = (abs(d) - 5) * settle
                    if d > 0 { drift[i] -= m; drift[i - 1] += m } else { drift[i] += m; drift[i - 1] -= m }
                }
            }
        }
        let ledgeMelt = max(0, 1 - 0.0015 * dt)
        for (id, var l) in ledges {
            for i in l.heights.indices {
                l.heights[i] *= ledgeMelt
                if i > 0 {
                    let d = l.heights[i] - l.heights[i - 1]
                    if abs(d) > 4 {
                        let m = (abs(d) - 4) * settle
                        if d > 0 { l.heights[i] -= m; l.heights[i - 1] += m } else { l.heights[i] += m; l.heights[i - 1] -= m }
                    }
                }
            }
            ledges[id] = l
        }
    }

    private func updateSparkles(_ dt: CGFloat) {
        for i in sparkles.indices {
            var s = sparkles[i]
            s.t += dt
            if s.t >= s.dur {
                s.dur = CGFloat.random(in: 0.6...1.2)
                s.t = -CGFloat.random(in: 0.5...3)
                for _ in 0..<5 {
                    let x = CGFloat.random(in: 10...max(11, size.width - 10))
                    let h = driftAt(x)
                    if h > 9 {
                        s.node.position = CGPoint(x: x, y: h - CGFloat.random(in: 2...max(3, h * 0.45)))
                        break
                    }
                }
            }
            let k = s.t < 0 ? 0 : sin(.pi * s.t / s.dur)
            s.node.alpha = k * 0.95
            s.node.setScale(0.4 + k * 0.8)
            s.node.zRotation = s.t * 0.8
            sparkles[i] = s
        }
    }

    private func updateFootprints(_ dt: CGFloat) {
        var i = 0
        while i < footprints.count {
            footprints[i].age += dt
            let fp = footprints[i]
            fp.node.alpha = max(0, 1 - fp.age / 16)
            fp.node.position.y = driftAt(fp.node.position.x) * 0.85 + 1
            if fp.age > 16 {
                fp.node.removeFromParent()
                footprints.remove(at: i)
                continue
            }
            i += 1
        }
    }

    private func updatePlough(_ dt: CGFloat) {
        guard let p = plough else { return }
        let speed: CGFloat = 380
        p.position.x += speed * dt
        let lastFront = ploughFront
        ploughFront = p.position.x + PloughNode.bladeReach
        p.position.y = groundUnder(p.position.x, half: 50) * 0.35
        for i in drift.indices {
            let x = CGFloat(i) * colWidth
            if x < ploughFront && drift[i] > 2.5 {
                let take = (drift[i] - 2.5) * min(1, 12 * dt)
                drift[i] -= take
                if x > ploughFront - 60 { p.collected += take }
            }
        }
        // Snow on the windows shakes loose as the plough rumbles past.
        for (id, l) in ledges where (l.minX + l.maxX) / 2 > lastFront && (l.minX + l.maxX) / 2 <= ploughFront {
            shed(l, fraction: 1)
            var cleared = l
            cleared.heights = [CGFloat](repeating: 0, count: l.heights.count)
            ledges[id] = cleared
        }
        for st in stacks where st.balls[0].node.position.x < ploughFront {
            p.collected += st.balls.reduce(0) { $0 + $1.r }
            removeStack(st, puff: true)
        }
        if yeti.hit(CGPoint(x: ploughFront, y: yeti.position.y + 60)) { yeti.bonk() }
        sprayClock += dt
        if sprayClock > 0.05 {
            sprayClock = 0
            for _ in 0..<2 where particles.count < 600 {
                let f = Flake(texture: Tex.softDot)
                let r = CGFloat.random(in: 1.5...3.5)
                f.size = CGSize(width: r * 3, height: r * 3)
                f.position = CGPoint(x: ploughFront + 14, y: p.position.y + 30)
                f.vx = CGFloat.random(in: 60...220)
                f.vy = CGFloat.random(in: 120...320)
                f.maxLife = CGFloat.random(in: 0.6...1.0)
                f.life = f.maxLife
                f.zPosition = 16
                addChild(f)
                particles.append(f)
            }
        }
        p.update(dt: dt, speed: speed)
        if p.position.x > size.width + 180 {
            p.removeFromParent()
            plough = nil
        }
    }

    private func updateCharacters(_ dt: CGFloat) {
        let look: CGPoint? = inBounds ? pointer : nil
        snowman.isHidden = !settings.showSnowman
        if settings.showSnowman {
            if snowman.mode == .idle {
                let g = groundUnder(snowman.position.x, half: 40)
                snowman.position.y += (g - snowman.position.y) * min(1, 2 * dt)
            }
            snowman.update(dt: dt, pointer: look, wind: wind)
            if greetIn > 0 {
                greetIn -= dt
                if greetIn <= 0 { snowman.greet(settings.displayName) }
            }
        }
        for s in built {
            if s.mode == .idle {
                let g = groundUnder(s.position.x, half: 40 * s.figureScale)
                s.position.y += (g - s.position.y) * min(1, 2 * dt)
            }
            s.update(dt: dt, pointer: look, wind: wind)
        }
        yeti.position.y = groundUnder(yeti.position.x, half: 30)
        yeti.update(dt: dt, enabled: settings.yetiEnabled, snowmanX: snowmanX, pointer: look)
    }

    // MARK: - drawing the drifts

    private func rebuildDriftPath() {
        guard drift.count > 2 else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -4, y: -4))
        path.addLine(to: CGPoint(x: -4, y: drift[0]))
        for i in 1..<drift.count - 1 {
            let xc = (CGFloat(i) + 0.5) * colWidth
            let yc = (drift[i] + drift[i + 1]) / 2
            path.addQuadCurve(to: CGPoint(x: xc, y: yc), control: CGPoint(x: CGFloat(i) * colWidth, y: drift[i]))
        }
        path.addLine(to: CGPoint(x: size.width + 4, y: drift[drift.count - 1]))
        path.addLine(to: CGPoint(x: size.width + 4, y: -4))
        path.closeSubpath()
        driftNode.path = path
    }

    private func rebuildLedgePaths() {
        for (id, l) in ledges {
            guard let node = ledgeNodes[id] else { continue }
            let n = l.heights.count
            guard n > 2, l.heights.reduce(0, +) > 0.5 else {
                node.path = nil
                continue
            }
            // Taper the ends so piles look rounded, not cut off.
            func h(_ i: Int) -> CGFloat {
                let edge = CGFloat(min(i, n - 1 - i))
                return l.heights[i] * min(1, (edge + 0.6) / 3.5)
            }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: l.minX, y: l.topY))
            path.addLine(to: CGPoint(x: l.minX, y: l.topY + h(0)))
            for i in 1..<n - 1 {
                let xc = l.minX + (CGFloat(i) + 0.5) * colWidth
                let yc = l.topY + (h(i) + h(i + 1)) / 2
                path.addQuadCurve(to: CGPoint(x: min(xc, l.maxX), y: yc),
                                  control: CGPoint(x: min(l.minX + CGFloat(i) * colWidth, l.maxX), y: l.topY + h(i)))
            }
            path.addLine(to: CGPoint(x: l.maxX, y: l.topY + h(n - 1)))
            path.addLine(to: CGPoint(x: l.maxX, y: l.topY))
            path.closeSubpath()
            node.path = path
        }
    }

    // MARK: - frame

    override func update(_ currentTime: TimeInterval) {
        var dt = lastTime > 0 ? CGFloat(currentTime - lastTime) : 1.0 / 60
        lastTime = currentTime
        dt = clamp(dt, 0, 1.0 / 20)
        clock += dt

        pollPointer(dt)

        // Backup for desktop clicks: watch the mouse button directly (no
        // permission needed), in case macOS doesn't pass the app the click.
        let buttonDown = (NSEvent.pressedMouseButtons & 1) != 0
        if buttonDown && !buttonWasDown && !capturing && drag == nil {
            desktopClick(global: NSEvent.mouseLocation)
        }
        buttonWasDown = buttonDown

        gustTimer -= dt
        if gustTimer <= 0 {
            gustTarget = CGFloat.random(in: -34...34) * (1 + 1.2 * blizzardAmount)
            gustTimer = CGFloat.random(in: 5...11)
        }
        gust += (gustTarget - gust) * min(1, 0.8 * dt)
        let base = 14 * sin(clock * 0.11) + 8 * sin(clock * 0.043 + 2)
        wind = (base + gust) * CGFloat(settings.wind)
        if blizzardT > 0 { blizzardT -= dt }

        ledgeClock += dt
        if ledgeClock >= ledgeInterval {
            ledgeClock = 0
            refreshLedges()
        }

        syncFlakes()
        updateFlakes(dt)
        updateParticles(dt)
        updateClumps(dt)
        updateThrows(dt)
        updateDrifts(dt)
        updateSparkles(dt)
        updateFootprints(dt)
        updatePlough(dt)
        updateCharacters(dt)
        rebuildDriftPath()
        rebuildLedgePaths()
        updateMouseCapture()
    }
}
