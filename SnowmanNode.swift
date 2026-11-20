import SpriteKit
import AppKit

/// What a snowman wears. Snowmen Stella builds get a random one, so every
/// snowman she makes is a little different.
struct SnowmanOutfit: Codable, Equatable {
    enum Hat: Int { case topHat = 0, beanie = 1, earmuffs = 2 }
    var scarf: Int
    var hat: Int
    /// Closet items she has dressed him in (nil = his own).
    var hatItem: Item? = nil
    var faceItem: Item? = nil
    var neckItem: Item? = nil

    var effectiveHat: Item {
        if let h = hatItem { return h }
        switch Hat(rawValue: hat) ?? .topHat {
        case .topHat: return .topHat
        case .beanie: return .beanie
        case .earmuffs: return .earmuffs
        }
    }

    static let classic = SnowmanOutfit(scarf: 0, hat: 0)
    static func random() -> SnowmanOutfit {
        SnowmanOutfit(scarf: Int.random(in: 0..<Palette.scarves.count), hat: Int.random(in: 0...2))
    }
}

/// A snowman made of four real parts (three snowballs and a hat) on a rig.
///
/// Idle, the rig breathes, blinks, waves, and his eyes and carrot follow
/// the pointer. Poked, he squashes and wobbles (three quick pokes and he
/// sneezes). Knocked by the yeti, the parts fly apart and roll along the
/// snow, then hop back onto each other one at a time, hat last.
final class SnowmanNode: SKNode {
    enum Mode { case idle, scattered, reassembling }

    private(set) var outfit: SnowmanOutfit
    private(set) var mode: Mode = .idle
    private(set) var figureScale: CGFloat = 1
    private weak var host: SnowScene?

    private final class Part {
        let node: SKNode
        var home: CGPoint
        var r: CGFloat
        var v = CGVector.zero
        var spin: CGFloat = 0
        var from = CGPoint.zero
        var fromRot: CGFloat = 0
        init(node: SKNode, home: CGPoint, r: CGFloat) {
            self.node = node
            self.home = home
            self.r = r
        }
    }

    private let rig = SKNode()
    private let shadowSprite = Art.sprite(Tex.shadow, 132, 30, at: CGPoint(x: 0, y: 3))
    private var parts: [Part] = []
    private let eyes = SKNode()
    private let nose = SKNode()
    private let mouth = SKNode()
    private let oMouth = Art.circle(4.2, Palette.coal, at: CGPoint(x: 0, y: -10))
    private let waveArm = SKNode()
    private let scarfTail = SKNode()
    private let hatArt = SKNode()
    private let faceArt = SKNode()
    private let neckArt = SKNode()
    private var partyHat = false
    private var hatOffset: CGFloat = 18
    private let hatTilt: CGFloat = 0.07

    private var clock: CGFloat = 0
    private var wobble: CGFloat = 0
    private var wobbleVel: CGFloat = 0
    private var squash: CGFloat = 0
    private var squashVel: CGFloat = 0
    private var blinkTimer: CGFloat = 2.5
    private var blink: CGFloat = 0
    private var waveTimer: CGFloat = 9
    private var wave: CGFloat = 0
    private var pokes = 0
    private var lastPoke: CGFloat = -10
    private var surprised: CGFloat = 0
    private var scatterTimer: CGFloat = 0
    private var reassembleT: CGFloat = 0
    private var look = CGPoint.zero
    private var noseDir: CGFloat = 1

    init(host: SnowScene, outfit: SnowmanOutfit, scale: CGFloat = 1) {
        self.host = host
        self.outfit = outfit
        super.init()
        shadowSprite.zPosition = -1
        addChild(shadowSprite)
        addChild(rig)
        build()
        figureScale = scale
        setScale(scale)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - building the figure

    private var scarfColor: NSColor { Palette.scarves[outfit.scarf % Palette.scarves.count] }

    private func ball(_ r: CGFloat, at p: CGPoint, z: CGFloat) -> SKNode {
        let n = SKNode()
        n.position = p
        n.zPosition = z
        n.addChild(Art.sprite(Tex.snowball, r * 2, r * 2))
        rig.addChild(n)
        return n
    }

    private func stickArm(sign: CGFloat) -> SKNode {
        let path = CGMutablePath()
        let tip = CGPoint(x: 40 * sign, y: 13)
        path.move(to: .zero)
        path.addQuadCurve(to: tip, control: CGPoint(x: 20 * sign, y: 2))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: 51 * sign, y: 23))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: 52 * sign, y: 8))
        path.move(to: CGPoint(x: 24 * sign, y: 5))
        path.addLine(to: CGPoint(x: 28 * sign, y: 15))
        return Art.line(path, Palette.stick, width: 3.4)
    }

    private func build() {
        let bottom = ball(46, at: CGPoint(x: 0, y: 46), z: 0)
        let mid = ball(34, at: CGPoint(x: 0, y: 102), z: 1)
        let head = ball(25, at: CGPoint(x: 0, y: 142), z: 2)

        // Middle: coal buttons, stick arms, scarf.
        for dy: CGFloat in [-19, -6, 7] {
            mid.addChild(Art.circle(3.3, Palette.coal, at: CGPoint(x: 0, y: dy)))
        }
        let leftArm = stickArm(sign: -1)
        leftArm.position = CGPoint(x: -29, y: 6)
        leftArm.zRotation = -0.12
        leftArm.zPosition = -0.5
        mid.addChild(leftArm)
        waveArm.position = CGPoint(x: 29, y: 6)
        waveArm.zPosition = -0.5
        waveArm.addChild(stickArm(sign: 1))
        mid.addChild(waveArm)

        let wrap = CGMutablePath()
        wrap.addArc(center: CGPoint(x: 0, y: 73), radius: 56,
                    startAngle: .pi * 4 / 3, endAngle: .pi * 5 / 3, clockwise: false)
        let scarf = Art.line(wrap, scarfColor, width: 12)
        scarf.zPosition = 2.5
        mid.addChild(scarf)
        let stripes = Art.line(wrap.copy(dashingWithPhase: 2, lengths: [5, 9]),
                                 Palette.mix(scarfColor, .white, 0.5), width: 12, round: false)
        stripes.zPosition = 2.6
        mid.addChild(stripes)

        scarfTail.position = CGPoint(x: 12, y: 16)
        scarfTail.zPosition = 2.7
        let tail = Art.fill(Art.rect(-6, -32, 12, 32, radius: 3), scarfColor)
        scarfTail.addChild(tail)
        for y: CGFloat in [-12, -22] {
            scarfTail.addChild(Art.fill(Art.rect(-6, y, 12, 4), Palette.mix(scarfColor, .white, 0.5)))
        }
        let fringe = CGMutablePath()
        for x: CGFloat in [-4, 0, 4] {
            fringe.move(to: CGPoint(x: x, y: -32))
            fringe.addLine(to: CGPoint(x: x, y: -38))
        }
        scarfTail.addChild(Art.line(fringe, scarfColor, width: 2))
        mid.addChild(scarfTail)

        // Head: eyes that follow you, rosy cheeks, carrot, coal smile.
        eyes.position = CGPoint(x: 0, y: 6)
        eyes.zPosition = 1
        for x: CGFloat in [-8.5, 8.5] {
            let e = Art.circle(3.7, Palette.coal, at: CGPoint(x: x, y: 0))
            e.addChild(Art.circle(1.1, .white, at: CGPoint(x: 1.1, y: 1.3)))
            eyes.addChild(e)
        }
        head.addChild(eyes)
        for x: CGFloat in [-15, 15] {
            let cheek = Art.sprite(Tex.softDot, 12, 9, at: CGPoint(x: x, y: -5), tint: Palette.cheek, alpha: 0.55)
            cheek.zPosition = 0.5
            head.addChild(cheek)
        }
        let carrot = CGMutablePath()
        carrot.move(to: CGPoint(x: 0, y: 3.8))
        carrot.addQuadCurve(to: CGPoint(x: 25, y: -1), control: CGPoint(x: 14, y: 3))
        carrot.addQuadCurve(to: CGPoint(x: 0, y: -3.8), control: CGPoint(x: 13, y: -2.6))
        carrot.closeSubpath()
        nose.addChild(Art.fill(carrot, Palette.carrot, stroke: Palette.carrotDark, width: 0.8))
        let ridges = CGMutablePath()
        for x: CGFloat in [7, 13] {
            ridges.move(to: CGPoint(x: x, y: 2.4 - x * 0.08))
            ridges.addLine(to: CGPoint(x: x + 1, y: 0.6))
        }
        nose.addChild(Art.line(ridges, Palette.carrotDark, width: 1))
        nose.position = CGPoint(x: 1, y: -1)
        nose.zPosition = 2
        head.addChild(nose)
        for deg: CGFloat in [215, 242, 270, 298, 325] {
            let a = deg * .pi / 180
            mouth.addChild(Art.circle(1.8, Palette.coal, at: CGPoint(x: cos(a) * 11, y: -1 + sin(a) * 11)))
        }
        mouth.zPosition = 1
        head.addChild(mouth)
        oMouth.isHidden = true
        oMouth.zPosition = 1
        head.addChild(oMouth)

        // Hat, its own part so it can fly off. Face and neck items ride on
        // the head and middle ball.
        let hat = SKNode()
        hat.zPosition = 3
        hat.addChild(hatArt)
        rig.addChild(hat)
        faceArt.position = CGPoint(x: 0, y: 6)
        faceArt.zPosition = 2.5
        head.addChild(faceArt)
        neckArt.position = CGPoint(x: 0, y: 14)
        neckArt.zPosition = 3
        mid.addChild(neckArt)

        parts = [
            Part(node: bottom, home: bottom.position, r: 46),
            Part(node: mid, home: mid.position, r: 34),
            Part(node: head, home: head.position, r: 25),
            Part(node: hat, home: CGPoint(x: 0, y: 142 + hatOffset), r: 6),
        ]
        refreshOutfit()
    }

    /// Redraws the hat, glasses and neck pieces from the outfit.
    private func refreshOutfit() {
        hatArt.removeAllChildren()
        let wanted = partyHat && outfit.hatItem == nil ? Item.partyHat : outfit.effectiveHat
        let h = ItemArt.hat(wanted, scarf: scarfColor)
        hatArt.addChild(h.node)
        hatOffset = h.offset
        parts[3].home = CGPoint(x: 0, y: 142 + hatOffset)
        parts[3].r = h.radius
        faceArt.removeAllChildren()
        if let f = outfit.faceItem { faceArt.addChild(ItemArt.face(f)) }
        nose.isHidden = outfit.faceItem == .rudolphNose
        neckArt.removeAllChildren()
        if let n = outfit.neckItem { neckArt.addChild(ItemArt.neck(n)) }
        if mode == .idle { attachHat() }
    }

    // MARK: - dress-up

    /// Puts a closet item on him. Returns what it replaced, if anything.
    @discardableResult
    func wear(_ item: Item) -> Item? {
        var old: Item?
        switch item.slot {
        case .hat:
            old = outfit.hatItem
            outfit.hatItem = item
        case .face:
            old = outfit.faceItem
            outfit.faceItem = item
        case .neck:
            old = outfit.neckItem
            outfit.neckItem = item
        case .decor:
            return nil
        }
        refreshOutfit()
        squashVel += 6
        return old
    }

    /// Takes off whatever closet item is under the pointer, if any.
    func takeOff(at p: CGPoint) -> Item? {
        guard mode == .idle, let host = host else { return nil }
        let checks: [(Item?, SKNode, Item.Slot)] = [
            (outfit.faceItem, faceArt, .face), (outfit.neckItem, neckArt, .neck), (outfit.hatItem, hatArt, .hat),
        ]
        for (item, node, slot) in checks {
            guard let item = item, let parent = node.parent else { continue }
            let f = node.calculateAccumulatedFrame().insetBy(dx: -8, dy: -8)
            let a = host.convert(CGPoint(x: f.minX, y: f.minY), from: parent)
            let b = host.convert(CGPoint(x: f.maxX, y: f.maxY), from: parent)
            let r = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
            if r.contains(p) {
                switch slot {
                case .hat: outfit.hatItem = nil
                case .face: outfit.faceItem = nil
                case .neck: outfit.neckItem = nil
                case .decor: break
                }
                refreshOutfit()
                return item
            }
        }
        return nil
    }

    /// Where a dropped item should land to count as "on" him.
    func catches(_ p: CGPoint) -> Bool {
        guard mode == .idle, !isHidden else { return false }
        let s = figureScale
        let dx = (p.x - position.x) / (70 * s), dy = (p.y - (position.y + 110 * s)) / (110 * s)
        return dx * dx + dy * dy <= 1
    }

    /// Birthday: a party hat for the day (unless she picked another).
    func setPartyHat(_ on: Bool) {
        guard partyHat != on else { return }
        partyHat = on
        refreshOutfit()
    }

    private func attachHat() {
        let head = parts[2].node, hat = parts[3].node
        let off = rotated(CGPoint(x: 0, y: hatOffset), by: head.zRotation)
        hat.position = CGPoint(x: head.position.x + off.x, y: head.position.y + off.y)
        hat.zRotation = head.zRotation + hatTilt
    }

    // MARK: - interaction

    /// Generous hit area around the whole figure (bigger than the art, so
    /// small hands land it every time).
    func hit(_ p: CGPoint) -> Bool {
        guard mode == .idle, !isHidden else { return false }
        let s = figureScale
        let dx = (p.x - position.x) / (58 * s)
        let dy = (p.y - (position.y + 95 * s)) / (102 * s)
        return dx * dx + dy * dy <= 1
    }

    private var headInScene: CGPoint {
        guard let host = host else { return position }
        return host.convert(parts[2].node.position, from: rig)
    }

    private func say(_ text: String) {
        host?.say(text, at: CGPoint(x: position.x + 26 * figureScale, y: position.y + 192 * figureScale))
    }

    func greet(_ name: String) {
        wave = 2.2
        say(name.isEmpty ? "Hi!" : "Hi \(name)!")
    }

    func poke() {
        guard mode == .idle else { return }
        wobbleVel += CGFloat.random(in: 2.2...3.2) * (Bool.random() ? 1 : -1)
        squashVel += 7
        if clock - lastPoke < 0.9 { pokes += 1 } else { pokes = 1 }
        lastPoke = clock
        if pokes >= 3 {
            pokes = 0
            surprised = 0.6
            if let host = host {
                let tip = host.convert(CGPoint(x: 25, y: -1), from: nose)
                host.burst(at: tip, count: 28, spread: 200)
            }
            say("Achoo!")
            SnowProgress.shared.bump(.sneezes)
        } else if pokes == 1 && Int.random(in: 0..<3) == 0 {
            say(["Hee hee!", "That tickles!", "Brrr!"].randomElement() ?? "Hee hee!")
        }
    }

    /// The yeti's shove. Parts fly away from the side the push came from.
    func knock(fromLeft: Bool) {
        guard mode == .idle else { return }
        mode = .scattered
        scatterTimer = 3.4
        rig.zRotation = 0
        rig.xScale = 1
        rig.yScale = 1
        wobble = 0
        wobbleVel = 0
        squash = 0
        squashVel = 0
        surprised = 99
        wave = 0
        waveArm.zRotation = 0
        let s: CGFloat = fromLeft ? 1 : -1
        let launch: [(CGFloat, CGFloat)] = [(85, 150), (165, 240), (245, 340), (150, 440)]
        for (i, p) in parts.enumerated() {
            p.v = CGVector(dx: s * launch[i].0 * CGFloat.random(in: 0.8...1.2),
                           dy: launch[i].1 * CGFloat.random(in: 0.85...1.15))
            p.spin = i == 3 ? -s * CGFloat.random(in: 6...10) : 0
        }
        host?.burst(at: headInScene, count: 20, spread: 170)
    }

    // MARK: - frame

    func update(dt: CGFloat, pointer: CGPoint?, wind: CGFloat) {
        clock += dt
        switch mode {
        case .idle: animateIdle(dt: dt, pointer: pointer)
        case .scattered: simulateScatter(dt: dt)
        case .reassembling: animateReassemble(dt: dt)
        }
        let swing = sin(clock * 2.3) * 0.06 + wind * 0.006 + wobble * 0.25
        scarfTail.zRotation = clamp(swing, -0.7, 0.7)
        surprised -= dt
        oMouth.isHidden = surprised <= 0
        mouth.isHidden = surprised > 0
    }

    private func animateIdle(dt: CGFloat, pointer: CGPoint?) {
        wobbleVel += (-90 * wobble - 7 * wobbleVel) * dt
        wobble += wobbleVel * dt
        squashVel += (-170 * squash - 11 * squashVel) * dt
        squash += squashVel * dt
        let breathe = sin(clock * 1.6) * 0.012
        rig.zRotation = wobble * 0.12
        rig.yScale = 1 + breathe - squash * 0.10
        rig.xScale = 1 - breathe * 0.5 + squash * 0.07

        blinkTimer -= dt
        if blinkTimer <= 0 {
            blink = 0.14
            blinkTimer = CGFloat.random(in: 2.2...5.5)
        }
        blink -= dt
        eyes.yScale = blink > 0 ? 0.15 : 1

        waveTimer -= dt
        if waveTimer <= 0 {
            wave = 1.6
            waveTimer = CGFloat.random(in: 9...18)
        }
        if wave > 0 {
            wave -= dt
            waveArm.zRotation = 0.55 + sin(clock * 11) * 0.38
        } else {
            waveArm.zRotation += (0 - waveArm.zRotation) * min(1, 8 * dt)
        }

        // Eyes, head tilt and carrot follow the pointer.
        var target = CGPoint.zero
        var tilt: CGFloat = 0
        if let p = pointer {
            let hc = headInScene
            let dx = p.x - hc.x, dy = p.y - hc.y
            let d = max(1, hypot(dx, dy))
            let k = min(1, d / 90) * 2.6
            target = CGPoint(x: dx / d * k, y: dy / d * k * 0.8)
            tilt = clamp(-dx / 2600, -0.08, 0.08)
            if abs(dx) > 40 { noseDir += ((dx > 0 ? 1 : -1) - noseDir) * min(1, 5 * dt) }
        }
        look.x += (target.x - look.x) * min(1, 9 * dt)
        look.y += (target.y - look.y) * min(1, 9 * dt)
        eyes.position = CGPoint(x: look.x, y: 6 + look.y)
        let head = parts[2].node
        head.zRotation += (tilt - head.zRotation) * min(1, 4 * dt)
        nose.xScale = abs(noseDir) < 0.12 ? (noseDir < 0 ? -0.12 : 0.12) : noseDir
        attachHat()
    }

    private func localGround(_ x: CGFloat) -> CGFloat {
        guard let host = host else { return 0 }
        return (host.driftAt(position.x + x * figureScale) - position.y) / figureScale
    }

    private func simulateScatter(dt: CGFloat) {
        let width = host?.size.width ?? 2000
        for (i, p) in parts.enumerated() {
            p.v.dy -= 980 * dt
            var pos = p.node.position
            pos.x += p.v.dx * dt
            pos.y += p.v.dy * dt
            let g = localGround(pos.x)
            if pos.y - p.r <= g {
                pos.y = g + p.r
                if p.v.dy < -90 {
                    p.v.dy = -p.v.dy * 0.32
                    p.v.dx *= 0.8
                } else {
                    p.v.dy = 0
                }
                p.v.dx *= max(0, 1 - 2.4 * dt)
                if i < 3 {
                    p.node.zRotation -= p.v.dx * dt / p.r
                } else {
                    let flat = (p.node.zRotation / .pi).rounded() * .pi
                    p.node.zRotation += (flat - p.node.zRotation) * min(1, 7 * dt)
                }
            } else if i == 3 {
                p.node.zRotation += p.spin * dt
            }
            let s = figureScale
            let lo = (p.r * s - position.x) / s, hi = (width - p.r * s - position.x) / s
            if pos.x < lo { pos.x = lo; p.v.dx = abs(p.v.dx) * 0.4 }
            if pos.x > hi { pos.x = hi; p.v.dx = -abs(p.v.dx) * 0.4 }
            p.node.position = pos
        }
        scatterTimer -= dt
        if scatterTimer <= 0 {
            mode = .reassembling
            reassembleT = 0
            for p in parts {
                p.from = p.node.position
                p.fromRot = p.node.zRotation
            }
        }
    }

    private func animateReassemble(dt: CGFloat) {
        reassembleT += dt
        let delays: [CGFloat] = [0, 0.24, 0.48, 0.84]
        let dur: CGFloat = 0.5
        var done = true
        for (i, p) in parts.enumerated() {
            let u = clamp((reassembleT - delays[i]) / dur, 0, 1)
            if u < 1 { done = false }
            let e = easeInOut(u)
            let target = p.home
            let targetRot: CGFloat = i == 3 ? hatTilt : (p.fromRot / (2 * .pi)).rounded() * 2 * .pi
            let hop = 46 + hypot(target.x - p.from.x, target.y - p.from.y) * 0.25
            p.node.position = CGPoint(x: lerp(p.from.x, target.x, e),
                                      y: lerp(p.from.y, target.y, e) + hop * 4 * u * (1 - u))
            p.node.zRotation = lerp(p.fromRot, targetRot, e)
        }
        if done {
            mode = .idle
            for p in parts.prefix(3) { p.node.zRotation = 0 }
            attachHat()
            squashVel += 9
            surprised = 0
            host?.burst(at: CGPoint(x: position.x, y: position.y + 10), count: 14, spread: 120)
            say(["Hey!", "Hmph!", "Not again!"].randomElement() ?? "Hey!")
        }
    }
}
