import SpriteKit
import AppKit

// MARK: - December present

/// A wrapped present sitting on the snow. Click it to unwrap.
final class PresentNode: SKNode {
    let day: Int
    private let lid = SKNode()
    private let box = SKNode()
    private(set) var opening = false

    private static let wraps: [(NSColor, NSColor)] = [
        (Palette.c(0.86, 0.14, 0.19), Palette.c(0.98, 0.80, 0.25)),
        (Palette.c(0.14, 0.56, 0.30), Palette.c(0.95, 0.95, 0.98)),
        (Palette.c(0.24, 0.48, 0.92), Palette.c(0.98, 0.80, 0.25)),
        (Palette.c(0.60, 0.33, 0.85), Palette.c(0.95, 0.95, 0.98)),
        (Palette.c(0.97, 0.45, 0.64), Palette.c(0.98, 0.98, 1.00)),
    ]

    init(day: Int) {
        self.day = day
        super.init()
        let (wrap, ribbon) = PresentNode.wraps[abs(day) % PresentNode.wraps.count]
        let dark = Palette.mix(wrap, .black, 0.3)
        let shadow = Art.sprite(Tex.shadow, 76, 16, at: CGPoint(x: 0, y: 2))
        shadow.zPosition = -1
        addChild(shadow)
        box.addChild(Art.fill(Art.rect(-22, 0, 44, 32, radius: 3), wrap, stroke: dark, width: 1.2))
        box.addChild(Art.fill(Art.rect(-3.5, 0, 7, 32), ribbon))
        addChild(box)
        lid.position = CGPoint(x: 0, y: 32)
        lid.addChild(Art.fill(Art.rect(-25, 0, 50, 10, radius: 3), wrap, stroke: dark, width: 1.2))
        lid.addChild(Art.fill(Art.rect(-3.5, 0, 7, 10), ribbon))
        for s: CGFloat in [-1, 1] {
            let loop = Art.ellipse(16, 10, ribbon, at: CGPoint(x: 7 * s, y: 14))
            loop.zRotation = 0.45 * s
            loop.strokeColor = Palette.mix(ribbon, .black, 0.2)
            loop.lineWidth = 1
            lid.addChild(loop)
        }
        lid.addChild(Art.circle(3.5, ribbon, at: CGPoint(x: 0, y: 12)))
        addChild(lid)
        if day > 0 {
            let tag = Art.fill(Art.rect(10, 14, 18, 13, radius: 3), .white, stroke: Palette.rim, width: 1)
            tag.zPosition = 0.5
            addChild(tag)
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "\(day)"
            label.fontSize = 10
            label.fontColor = Palette.ink
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 19, y: 20.5)
            label.zPosition = 0.6
            addChild(label)
        }
        // A little wiggle every few seconds: "open me!"
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 2.5...4.5)),
            SKAction.rotate(toAngle: 0.08, duration: 0.08),
            SKAction.rotate(toAngle: -0.08, duration: 0.12),
            SKAction.rotate(toAngle: 0.05, duration: 0.1),
            SKAction.rotate(toAngle: 0, duration: 0.08),
        ])), withKey: "wiggle")
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ p: CGPoint) -> Bool {
        !opening && abs(p.x - position.x) < 32 && p.y > position.y - 6 && p.y < position.y + 62
    }

    func unwrap() {
        opening = true
        removeAction(forKey: "wiggle")
        zRotation = 0
        let pop = SKAction.group([
            SKAction.moveBy(x: 30, y: 70, duration: 0.45),
            SKAction.rotate(byAngle: -1.4, duration: 0.45),
            SKAction.fadeOut(withDuration: 0.6),
        ])
        pop.timingMode = .easeOut
        lid.run(pop)
        box.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.fadeOut(withDuration: 0.4)]))
    }
}

// MARK: - closet

/// The wooden trunk on the snow. Click it to open the closet.
final class TrunkNode: SKNode {
    private let lid = SKNode()

    override init() {
        super.init()
        let wood = Palette.c(0.55, 0.33, 0.18), dark = Palette.c(0.36, 0.20, 0.10)
        let shadow = Art.sprite(Tex.shadow, 80, 16, at: CGPoint(x: 0, y: 2))
        shadow.zPosition = -1
        addChild(shadow)
        addChild(Art.fill(Art.rect(-24, 0, 48, 26, radius: 4), wood, stroke: dark, width: 1.4))
        for x: CGFloat in [-15, 11] { addChild(Art.fill(Art.rect(x, 0, 4, 26), ItemArt.goldDark)) }
        lid.position = CGPoint(x: -26, y: 25)
        lid.addChild(Art.fill(Art.rect(0, 0, 52, 11, radius: 5), Palette.mix(wood, .white, 0.08), stroke: dark, width: 1.4))
        for x: CGFloat in [11, 37] { lid.addChild(Art.fill(Art.rect(x, 0, 4, 11), ItemArt.goldDark)) }
        lid.addChild(Art.fill(Art.rect(22, 1, 8, 8, radius: 2), ItemArt.gold))
        let snow = Art.fill(Art.rect(2, 10, 48, 5, radius: 2.5), .white, stroke: Palette.rim, width: 0.8)
        snow.zPosition = 0.5
        lid.addChild(snow)
        addChild(lid)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ p: CGPoint) -> Bool { abs(p.x - position.x) < 32 && p.y > position.y - 4 && p.y < position.y + 46 }

    func setOpen(_ open: Bool) {
        lid.run(SKAction.rotate(toAngle: open ? 0.9 : 0, duration: 0.2))
    }
}

/// The closet: a shelf of everything she has unlocked. Drag from it onto a
/// snowman (or onto the snow, for decorations).
final class ClosetTray: SKNode {
    private(set) var cells: [(item: Item, center: CGPoint)] = []
    private var frameRect = CGRect.zero
    private let cell: CGFloat = 54
    private let columns = 9

    func reload(_ items: [Item]) {
        removeAllChildren()
        cells = []
        let rows = max(1, Int(ceil(Double(max(items.count, 1)) / Double(columns))))
        let cols = min(columns, max(items.count, 1))
        let w = CGFloat(cols) * cell + 20, h = CGFloat(rows) * cell + 40
        frameRect = CGRect(x: 0, y: 0, width: w, height: h)
        let panel = Art.fill(Art.rect(0, 0, w, h, radius: 16), Palette.c(0.97, 0.98, 1.0, 0.93), stroke: Palette.rim, width: 1.5)
        addChild(panel)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = items.isEmpty ? "Your closet is empty" : "Closet: drag onto a snowman"
        title.fontSize = 13
        title.fontColor = Palette.ink
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 14, y: h - 18)
        addChild(title)
        for (i, item) in items.enumerated() {
            let col = i % columns, row = i / columns
            let center = CGPoint(x: 10 + cell * (CGFloat(col) + 0.5), y: h - 36 - cell * (CGFloat(row) + 0.5))
            let bg = Art.fill(Art.rect(center.x - 24, center.y - 24, 48, 48, radius: 10), Palette.c(0.88, 0.92, 0.99), stroke: nil)
            addChild(bg)
            let icon = ItemArt.icon(item, fit: 38)
            icon.position = center
            icon.zPosition = 0.5
            addChild(icon)
            cells.append((item: item, center: center))
        }
    }

    /// The closet's frame in its parent's coordinates.
    var bounds: CGRect { frameRect.offsetBy(dx: position.x, dy: position.y) }

    func item(at p: CGPoint) -> Item? {
        let local = CGPoint(x: p.x - position.x, y: p.y - position.y)
        for c in cells where abs(local.x - c.center.x) < 26 && abs(local.y - c.center.y) < 26 { return c.item }
        return nil
    }
}

/// A decoration standing on the snow (tree, sled, igloo...). Draggable.
final class DecorNode: SKNode {
    let item: Item
    init(item: Item) {
        self.item = item
        super.init()
        addChild(ItemArt.decor(item))
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ p: CGPoint) -> Bool {
        let f = calculateAccumulatedFrame().insetBy(dx: -6, dy: -6)
        return f.contains(p)
    }
}

// MARK: - birthday balloon

final class BalloonNode: SKNode {
    var speedUp: CGFloat = CGFloat.random(in: 45...70)
    var phase = CGFloat.random(in: 0...6)
    let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init()
        let string = CGMutablePath()
        string.move(to: CGPoint(x: 0, y: -22))
        string.addCurve(to: CGPoint(x: 0, y: -74), control1: CGPoint(x: 8, y: -38), control2: CGPoint(x: -8, y: -56))
        addChild(Art.line(string, Palette.c(0.85, 0.87, 0.92), width: 1.2))
        let knot = CGMutablePath()
        knot.addLines(between: [CGPoint(x: -3, y: -24), CGPoint(x: 0, y: -19), CGPoint(x: 3, y: -24)])
        knot.closeSubpath()
        addChild(Art.fill(knot, Palette.mix(color, .black, 0.2)))
        addChild(Art.ellipse(36, 44, color, at: .zero))
        let shine = Art.ellipse(8, 13, NSColor(white: 1, alpha: 0.5), at: CGPoint(x: -8, y: 9))
        shine.zRotation = 0.4
        addChild(shine)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ p: CGPoint) -> Bool {
        let dx = (p.x - position.x) / 22, dy = (p.y - position.y) / 27
        return dx * dx + dy * dy <= 1
    }
}

// MARK: - Santa's sleigh

/// Santa, his sleigh and four reindeer (the first one has a shiny nose).
/// Drawn facing right; flipped to fly left.
final class SleighNode: SKNode {
    private var deer: [SKNode] = []
    private var clock: CGFloat = 0

    override init() {
        super.init()
        let red = ItemArt.red, gold = ItemArt.gold
        let brown = Palette.c(0.55, 0.38, 0.24), dark = Palette.c(0.36, 0.24, 0.14)

        // Harness first (behind everything).
        let harness = CGMutablePath()
        harness.move(to: CGPoint(x: 12, y: 16))
        harness.addLine(to: CGPoint(x: 150, y: 22))
        addChild(Art.line(harness, gold, width: 1.6))

        // Sleigh.
        let runner = CGMutablePath()
        runner.move(to: CGPoint(x: -42, y: -4))
        runner.addLine(to: CGPoint(x: 10, y: -4))
        runner.addQuadCurve(to: CGPoint(x: 18, y: 8), control: CGPoint(x: 22, y: -4))
        addChild(Art.line(runner, gold, width: 2.6))
        let sack = Art.ellipse(20, 22, Palette.c(0.55, 0.40, 0.25), at: CGPoint(x: -32, y: 30))
        addChild(sack)
        // Santa.
        addChild(Art.circle(10, red, at: CGPoint(x: -14, y: 26)))
        addChild(Art.circle(6.5, Palette.c(1, 0.84, 0.74), at: CGPoint(x: -12, y: 40)))
        addChild(Art.ellipse(10, 9, .white, at: CGPoint(x: -9, y: 35)))
        let hat = CGMutablePath()
        hat.addLines(between: [CGPoint(x: -19, y: 44), CGPoint(x: -5, y: 44), CGPoint(x: -18, y: 56)])
        hat.closeSubpath()
        addChild(Art.fill(hat, red))
        addChild(Art.circle(2.6, .white, at: CGPoint(x: -18, y: 56)))
        addChild(Art.fill(Art.rect(-20, 42, 16, 4, radius: 2), .white))
        // Sleigh body in front of Santa's legs.
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -40, y: 2))
        body.addLine(to: CGPoint(x: 6, y: 2))
        body.addQuadCurve(to: CGPoint(x: 14, y: 22), control: CGPoint(x: 18, y: 4))
        body.addLine(to: CGPoint(x: -2, y: 18))
        body.addLine(to: CGPoint(x: -36, y: 22))
        body.addQuadCurve(to: CGPoint(x: -40, y: 2), control: CGPoint(x: -46, y: 10))
        body.closeSubpath()
        let sleigh = Art.fill(body, red, stroke: gold, width: 1.6)
        sleigh.zPosition = 1
        addChild(sleigh)

        // Reindeer.
        for i in 0..<4 {
            let d = SKNode()
            d.position = CGPoint(x: 52 + CGFloat(i) * 32, y: 16)
            d.zPosition = 2
            let legs = CGMutablePath()
            for x: CGFloat in [-7, -3, 5, 9] {
                legs.move(to: CGPoint(x: x, y: -2))
                legs.addLine(to: CGPoint(x: x + 3, y: -11))
            }
            d.addChild(Art.line(legs, dark, width: 1.8))
            d.addChild(Art.ellipse(24, 11, brown, at: .zero))
            d.addChild(Art.ellipse(10, 7, brown, at: CGPoint(x: 13, y: 8)))
            let antler = CGMutablePath()
            antler.move(to: CGPoint(x: 11, y: 11))
            antler.addLine(to: CGPoint(x: 9, y: 19))
            antler.move(to: CGPoint(x: 10, y: 15))
            antler.addLine(to: CGPoint(x: 6, y: 17))
            d.addChild(Art.line(antler, dark, width: 1.4))
            if i == 3 {
                let glow = Art.sprite(Tex.softDot, 18, 18, at: CGPoint(x: 19, y: 8), tint: Palette.c(1, 0.2, 0.2), alpha: 0.85)
                glow.blendMode = .add
                d.addChild(glow)
                d.addChild(Art.circle(2.2, Palette.c(1, 0.15, 0.15), at: CGPoint(x: 19, y: 8)))
            }
            addChild(d)
            deer.append(d)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func animate(dt: CGFloat) {
        clock += dt
        for (i, d) in deer.enumerated() {
            d.position.y = 16 + sin(clock * 9 + CGFloat(i) * 0.9) * 3
        }
    }
}

// MARK: - badge celebration

/// "New badge!" card that drops in from the top of the screen.
final class BadgeToast: SKNode {
    init(_ badge: Badge) {
        super.init()
        let w: CGFloat = 320, h: CGFloat = 66
        addChild(Art.fill(Art.rect(-w / 2, -h / 2, w, h, radius: 18), Palette.c(0.10, 0.17, 0.36, 0.92),
                          stroke: ItemArt.gold, width: 2))
        let medal = Art.circle(22, ItemArt.gold, at: CGPoint(x: -w / 2 + 38, y: 0))
        medal.strokeColor = ItemArt.goldDark
        medal.lineWidth = 2
        addChild(medal)
        if let tex = BadgeToast.symbolTexture(badge.symbol) {
            let icon = SKSpriteNode(texture: tex)
            let s = 24 / max(tex.size().width, tex.size().height)
            icon.size = CGSize(width: tex.size().width * s, height: tex.size().height * s)
            icon.position = CGPoint(x: -w / 2 + 38, y: 0)
            icon.zPosition = 0.2
            addChild(icon)
        } else {
            let star = Art.fill(ItemArt.star(13, inner: 6), .white)
            star.position = CGPoint(x: -w / 2 + 38, y: 0)
            addChild(star)
        }
        let top = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        top.text = "New badge!"
        top.fontSize = 12
        top.fontColor = ItemArt.gold
        top.horizontalAlignmentMode = .left
        top.verticalAlignmentMode = .center
        top.position = CGPoint(x: -w / 2 + 72, y: 12)
        addChild(top)
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = badge.title
        title.fontSize = 18
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -w / 2 + 72, y: -9)
        addChild(title)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func symbolTexture(_ name: String) -> SKTexture? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 30, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let img = base.withSymbolConfiguration(config) else { return nil }
        return SKTexture(image: img)
    }
}

// MARK: - snowball fight scoreboard

final class Scoreboard: SKNode {
    private let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let timer = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    override init() {
        super.init()
        addChild(Art.fill(Art.rect(-150, -26, 300, 52, radius: 26), Palette.c(0.10, 0.17, 0.36, 0.9),
                          stroke: Palette.c(0.6, 0.75, 1.0), width: 1.5))
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 5)
        addChild(label)
        timer.fontSize = 11
        timer.fontColor = Palette.c(0.75, 0.85, 1.0)
        timer.verticalAlignmentMode = .center
        timer.position = CGPoint(x: 0, y: -14)
        addChild(timer)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(name: String, her: Int, yeti: Int, secondsLeft: Int) {
        label.text = "\(name.isEmpty ? "You" : name)  \(her) : \(yeti)  Yeti"
        timer.text = secondsLeft > 0 ? "SNOWBALL FIGHT  \(secondsLeft)s" : "FINAL"
    }
}
