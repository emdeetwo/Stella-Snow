import SpriteKit
import AppKit

/// A little red snowplough truck: spinning wheels, blinking amber beacon,
/// yellow blade, and a wave of snow that grows in front of the blade as it
/// scrapes the ground clean.
final class PloughNode: SKNode {
    private var wheels: [SKNode] = []
    private let beaconGlow = Art.sprite(Tex.softDot, 34, 34, at: CGPoint(x: -21, y: 70),
                                          tint: Palette.c(1, 0.68, 0.10), alpha: 0.8)
    private let wave = Art.sprite(Tex.snowball, 20, 20, at: CGPoint(x: 84, y: 12))
    private var clock: CGFloat = 0
    var collected: CGFloat = 0

    override init() {
        super.init()
        let red = Palette.c(0.86, 0.17, 0.18), redDark = Palette.c(0.58, 0.08, 0.10)

        let shadowSprite = Art.sprite(Tex.shadow, 170, 24, at: CGPoint(x: 6, y: 2))
        shadowSprite.zPosition = -1
        addChild(shadowSprite)

        let chassis = Art.fill(Art.rect(-52, 10, 104, 24, radius: 6), red, stroke: redDark, width: 1.2)
        addChild(chassis)
        addChild(Art.fill(Art.rect(-52, 19, 104, 4), NSColor(white: 1, alpha: 0.75)))
        let hood = Art.fill(Art.rect(-2, 30, 40, 12, radius: 5), red, stroke: redDark, width: 1.2)
        addChild(hood)
        let cab = Art.fill(Art.rect(-48, 30, 48, 36, radius: 7), red, stroke: redDark, width: 1.2)
        addChild(cab)
        let window = Art.fill(Art.rect(-41, 42, 33, 18, radius: 4), Palette.c(0.74, 0.88, 0.99),
                                stroke: redDark, width: 1)
        window.zPosition = 0.1
        addChild(window)
        let glare = CGMutablePath()
        glare.move(to: CGPoint(x: -36, y: 46))
        glare.addLine(to: CGPoint(x: -28, y: 57))
        let glareLine = Art.line(glare, NSColor(white: 1, alpha: 0.7), width: 2.5)
        glareLine.zPosition = 0.2
        addChild(glareLine)
        addChild(Art.fill(Art.rect(-8, 36, 5, 26, radius: 2), Palette.c(0.45, 0.47, 0.52)))
        let beacon = Art.fill(Art.rect(-27, 66, 12, 7, radius: 2.5), Palette.c(1, 0.70, 0.12))
        addChild(beacon)
        beaconGlow.zPosition = 0.3
        addChild(beaconGlow)

        // Blade on an arm, out front.
        addChild(Art.fill(Art.rect(44, 17, 14, 7, radius: 2), Palette.c(0.42, 0.44, 0.50)))
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 56, y: 2))
        blade.addLine(to: CGPoint(x: 68, y: 2))
        blade.addQuadCurve(to: CGPoint(x: 74, y: 46), control: CGPoint(x: 62, y: 24))
        blade.addLine(to: CGPoint(x: 62, y: 46))
        blade.addQuadCurve(to: CGPoint(x: 56, y: 2), control: CGPoint(x: 52, y: 24))
        blade.closeSubpath()
        let bladeNode = Art.fill(blade, Palette.c(0.99, 0.77, 0.14), stroke: Palette.c(0.60, 0.42, 0.05), width: 1.2)
        bladeNode.zPosition = 0.5
        addChild(bladeNode)
        wave.zPosition = 0.6
        addChild(wave)

        for x: CGFloat in [-30, 30] {
            let w = SKNode()
            w.position = CGPoint(x: x, y: 12)
            w.zPosition = 0.4
            w.addChild(Art.circle(13, Palette.c(0.15, 0.15, 0.18)))
            w.addChild(Art.circle(5.5, Palette.c(0.72, 0.74, 0.78)))
            w.addChild(Art.fill(Art.rect(-1.5, -11, 3, 7), Palette.c(0.32, 0.33, 0.38)))
            addChild(w)
            wheels.append(w)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Where the blade meets the ground, relative to the truck.
    static let bladeReach: CGFloat = 70

    func update(dt: CGFloat, speed: CGFloat) {
        clock += dt
        for w in wheels { w.zRotation -= speed * dt / 13 }
        beaconGlow.alpha = sin(clock * 9) > 0 ? 0.95 : 0.15
        let r = min(34, 9 + sqrt(collected) * 2.2)
        wave.size = CGSize(width: r * 2, height: r * 2)
        wave.position = CGPoint(x: 70 + r * 0.7, y: r * 0.85)
        wave.zRotation -= speed * dt / max(r, 1) * 0.4
    }
}
