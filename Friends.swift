import SpriteKit
import AppKit

/// A window top (or the Dock) that a small friend can stand on.
struct Perch {
    let id: Int
    let minX: CGFloat
    let maxX: CGFloat
    let topY: CGFloat
}

// MARK: - penguin

/// Pops up from behind a window, waddles along the top, then belly-slides
/// off the edge into the snow below. With no windows open he slides along
/// the ground instead. Click him and he goes for it right away.
final class PenguinNode: SKNode {
    enum State { case peek, waddle, slide, fall, land, leave, done }
    private(set) var state: State = .peek
    private weak var host: SnowScene?
    private let rig = SKNode()
    private let flipperBack = SKNode()
    private let flipperFront = SKNode()
    private var perchID: Int?
    private var t: CGFloat = 0
    private var stateT: CGFloat = 0
    private var dir: CGFloat = 1
    private var vx: CGFloat = 0
    private var vy: CGFloat = 0
    private var walked: CGFloat = 0
    private var walkGoal: CGFloat = 100
    private var peekY: CGFloat = 0

    init(host: SnowScene) {
        self.host = host
        super.init()
        let black = Palette.c(0.10, 0.11, 0.15), orange = Palette.c(0.98, 0.60, 0.15)
        flipperBack.position = CGPoint(x: -4, y: 28)
        flipperBack.zPosition = -0.5
        flipperBack.addChild(Art.ellipse(7, 18, black, at: CGPoint(x: 0, y: -8)))
        rig.addChild(flipperBack)
        for x: CGFloat in [-5, 6] { rig.addChild(Art.ellipse(11, 4.5, orange, at: CGPoint(x: x, y: 1.5))) }
        rig.addChild(Art.ellipse(30, 40, black, at: CGPoint(x: 0, y: 22)))
        rig.addChild(Art.ellipse(20, 30, .white, at: CGPoint(x: 4, y: 19)))
        rig.addChild(Art.fill(Art.rect(-11, 26, 24, 5, radius: 2.5), ItemArt.red))
        rig.addChild(Art.circle(3.4, .white, at: CGPoint(x: 6, y: 35)))
        rig.addChild(Art.circle(1.8, black, at: CGPoint(x: 7, y: 35)))
        let beak = CGMutablePath()
        beak.addLines(between: [CGPoint(x: 11, y: 33), CGPoint(x: 20, y: 31), CGPoint(x: 11, y: 29)])
        beak.closeSubpath()
        rig.addChild(Art.fill(beak, orange))
        flipperFront.position = CGPoint(x: 2, y: 27)
        flipperFront.zPosition = 0.5
        flipperFront.addChild(Art.ellipse(7, 17, black, at: CGPoint(x: 0, y: -8)))
        rig.addChild(flipperFront)
        addChild(rig)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start(on perch: Perch?) {
        guard let host = host else { return }
        if let p = perch {
            perchID = p.id
            let room = p.maxX - p.minX
            position.x = p.minX + room * CGFloat.random(in: 0.3...0.7)
            dir = Bool.random() ? 1 : -1
            walkGoal = CGFloat.random(in: 40...min(120, room * 0.3))
            peekY = p.topY - 46
            position.y = peekY
            state = .peek
        } else {
            perchID = nil
            dir = 1
            position.x = -40
            position.y = host.groundLevel(at: -40)
            walkGoal = 110
            state = .waddle
        }
        xScale = dir
    }

    func hit(_ p: CGPoint) -> Bool {
        guard state == .peek || state == .waddle else { return false }
        return abs(p.x - position.x) < 22 && p.y > position.y - 4 && p.y < position.y + 46
    }

    func tickle() {
        guard state == .peek || state == .waddle else { return }
        beginSlide()
    }

    private func set(_ s: State) {
        state = s
        stateT = 0
    }

    private func beginSlide() {
        set(.slide)
        vx = 150 * dir
        host?.say("Wheee!", at: CGPoint(x: position.x, y: position.y + 70))
        SnowProgress.shared.bump(.penguins)
    }

    /// The top of the snow under him, wherever he is.
    private func surface() -> CGFloat? {
        guard let host = host else { return nil }
        if let id = perchID {
            guard let p = host.perch(id: id) else { return nil }
            if position.x < p.minX - 4 || position.x > p.maxX + 4 { return nil }
            return p.topY + host.perchSnow(id: id, x: position.x) * 0.8
        }
        return host.groundLevel(at: position.x)
    }

    func update(dt: CGFloat) {
        guard let host = host else { return }
        t += dt
        stateT += dt
        switch state {
        case .peek:
            guard let top = surface() else { set(.fall); return }
            position.y = lerp(peekY, top, easeInOut(min(1, stateT / 0.6)))
            if stateT > 1.0 { set(.waddle) }
        case .waddle:
            guard let top = surface() else { set(.fall); return }
            position.y = top
            position.x += 45 * dir * dt
            walked += 45 * dt
            rig.zRotation = sin(t * 12) * 0.12
            flipperFront.zRotation = sin(t * 12) * 0.3
            if walked >= walkGoal { beginSlide() }
        case .slide:
            rig.zRotation += (-.pi / 2 - rig.zRotation) * min(1, 10 * dt)
            vx += 60 * dir * dt
            position.x += vx * dt
            flipperFront.zRotation = 1.2
            flipperBack.zRotation = 1.2
            if let top = surface() {
                position.y = top - 8
                if perchID == nil, Int(t * 20) % 2 == 0 {
                    host.burst(at: CGPoint(x: position.x - 14 * dir, y: position.y + 6), count: 1, spread: 60)
                }
            } else {
                set(.fall)
                vy = 60
            }
            if position.x < -60 || position.x > host.size.width + 60 { set(.done) }
        case .fall:
            vy -= 900 * dt
            position.x += vx * dt
            position.y += vy * dt
            rig.zRotation += 2.5 * dt
            let g = host.groundLevel(at: position.x)
            if position.y <= g {
                position.y = g
                host.burst(at: CGPoint(x: position.x, y: g + 10), count: 18, spread: 160)
                set(.land)
            }
            if position.x < -60 || position.x > host.size.width + 60 { set(.done) }
        case .land:
            rig.zRotation += (0 - rig.zRotation) * min(1, 6 * dt)
            flipperFront.zRotation = sin(t * 20) * 0.6
            flipperBack.zRotation = 0
            position.y = host.groundLevel(at: position.x)
            if stateT > 0.9 {
                dir = position.x < host.size.width / 2 ? -1 : 1
                xScale = dir
                set(.leave)
            }
        case .leave:
            position.x += 60 * dir * dt
            position.y = host.groundLevel(at: position.x)
            rig.zRotation = sin(t * 12) * 0.12
            if position.x < -60 || position.x > host.size.width + 60 { set(.done) }
        case .done:
            break
        }
    }
}

// MARK: - cardinal

/// A red cardinal flies in, lands on a snowy window top (or the drift),
/// hops and pecks, and flies off if the pointer gets close.
final class CardinalNode: SKNode {
    enum State { case flyIn, perched, flyAway, done }
    private(set) var state: State = .flyIn
    private weak var host: SnowScene?
    private let rig = SKNode()
    private let wing = SKNode()
    private let head = SKNode()
    private var perchID: Int?
    private var perchX: CGFloat = 0
    private var p0 = CGPoint.zero, p1 = CGPoint.zero, p2 = CGPoint.zero
    private var u: CGFloat = 0
    private var dur: CGFloat = 1.6
    private var t: CGFloat = 0
    private var stateT: CGFloat = 0
    private var nextMove: CGFloat = 1.5
    private var hopT: CGFloat = -1
    private var hopFrom: CGFloat = 0
    private var hopTo: CGFloat = 0

    init(host: SnowScene) {
        self.host = host
        super.init()
        let red = Palette.c(0.85, 0.12, 0.14), dark = Palette.c(0.62, 0.07, 0.09)
        let tail = Art.fill(Art.rect(-22, 4, 16, 6, radius: 3), dark)
        tail.zRotation = -0.35
        rig.addChild(tail)
        let legs = CGMutablePath()
        for x: CGFloat in [-2, 3] {
            legs.move(to: CGPoint(x: x, y: 5))
            legs.addLine(to: CGPoint(x: x - 1, y: 0))
        }
        rig.addChild(Art.line(legs, Palette.c(0.35, 0.25, 0.20), width: 1.3))
        let body = Art.ellipse(24, 16, red, at: CGPoint(x: 0, y: 11))
        body.zRotation = 0.25
        rig.addChild(body)
        head.position = CGPoint(x: 9, y: 18)
        let crest = CGMutablePath()
        crest.addLines(between: [CGPoint(x: -4, y: 4), CGPoint(x: 0, y: 14), CGPoint(x: 4, y: 3)])
        crest.closeSubpath()
        head.addChild(Art.fill(crest, red))
        head.addChild(Art.circle(7.5, red, at: .zero))
        head.addChild(Art.ellipse(9, 7, Palette.c(0.08, 0.06, 0.06), at: CGPoint(x: 4.5, y: -1)))
        let beak = CGMutablePath()
        beak.addLines(between: [CGPoint(x: 6, y: 1.5), CGPoint(x: 12, y: -0.5), CGPoint(x: 6, y: -2.5)])
        beak.closeSubpath()
        head.addChild(Art.fill(beak, Palette.c(0.98, 0.55, 0.20)))
        head.addChild(Art.circle(1.3, .white, at: CGPoint(x: 3, y: 2)))
        rig.addChild(head)
        wing.position = CGPoint(x: -2, y: 13)
        wing.addChild(Art.ellipse(14, 9, dark, at: CGPoint(x: -3, y: 0)))
        wing.zPosition = 0.5
        rig.addChild(wing)
        addChild(rig)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start(on perch: Perch?) {
        guard let host = host else { return }
        let w = host.size.width
        perchID = perch?.id
        if let p = perch {
            perchX = p.minX + (p.maxX - p.minX) * CGFloat.random(in: 0.2...0.8)
        } else {
            perchX = w * CGFloat.random(in: 0.15...0.85)
        }
        let fromLeft = Bool.random()
        p0 = CGPoint(x: fromLeft ? -40 : w + 40, y: host.size.height * CGFloat.random(in: 0.6...0.85))
        p2 = CGPoint(x: perchX, y: landingY() ?? 100)
        p1 = CGPoint(x: (p0.x + p2.x) / 2, y: max(p0.y, p2.y) + 80)
        position = p0
        xScale = fromLeft ? 1 : -1
        state = .flyIn
        u = 0
        dur = max(1.4, hypot(p2.x - p0.x, p2.y - p0.y) / 320)
    }

    private func landingY() -> CGFloat? {
        guard let host = host else { return nil }
        if let id = perchID {
            guard let p = host.perch(id: id), perchX >= p.minX, perchX <= p.maxX else { return nil }
            return p.topY + host.perchSnow(id: id, x: perchX) * 0.85
        }
        return host.groundLevel(at: perchX)
    }

    private func flyAway() {
        guard let host = host else { return }
        state = .flyAway
        u = 0
        let toRight = Bool.random()
        p0 = position
        p2 = CGPoint(x: toRight ? host.size.width + 60 : -60, y: host.size.height * CGFloat.random(in: 0.7...0.95))
        p1 = CGPoint(x: (p0.x + p2.x) / 2, y: p0.y + 160)
        xScale = toRight ? 1 : -1
        dur = 1.6
    }

    private func flap() {
        wing.yScale = sin(t * 34) * 1.1
        wing.zRotation = 0.3
    }

    func update(dt: CGFloat, pointer: CGPoint?) {
        t += dt
        stateT += dt
        switch state {
        case .flyIn, .flyAway:
            u = min(1, u + dt / dur)
            let e = state == .flyIn ? 1 - (1 - u) * (1 - u) : u * u
            let v = 1 - e
            if state == .flyIn, let y = landingY() { p2.y = y } else if state == .flyIn { flyAway(); return }
            position = CGPoint(x: v * v * p0.x + 2 * v * e * p1.x + e * e * p2.x,
                               y: v * v * p0.y + 2 * v * e * p1.y + e * e * p2.y)
            flap()
            rig.zRotation = 0.15
            if u >= 1 {
                if state == .flyIn {
                    state = .perched
                    stateT = 0
                    wing.yScale = 1
                    wing.zRotation = 0
                    rig.zRotation = 0
                    SnowProgress.shared.bump(.cardinals)
                } else {
                    state = .done
                }
            }
        case .perched:
            guard let y = landingY() else { flyAway(); return }
            if let p = pointer, hypot(p.x - position.x, p.y - position.y) < 150 { flyAway(); return }
            if stateT > 40 { flyAway(); return }
            nextMove -= dt
            if hopT >= 0 {
                hopT += dt
                let k = min(1, hopT / 0.25)
                perchX = lerp(hopFrom, hopTo, k)
                position.y = y + sin(.pi * k) * 9
                if k >= 1 { hopT = -1 }
            } else {
                position.y = y
            }
            position.x = perchX
            head.zRotation += (0 - head.zRotation) * min(1, 8 * dt)
            if nextMove <= 0 {
                nextMove = CGFloat.random(in: 1.0...2.6)
                switch Int.random(in: 0..<3) {
                case 0:
                    hopT = 0
                    hopFrom = perchX
                    hopTo = perchX + xScale * CGFloat.random(in: 6...14)
                case 1:
                    head.zRotation = -0.55
                default:
                    xScale = -xScale
                }
            }
        case .done:
            break
        }
    }
}
