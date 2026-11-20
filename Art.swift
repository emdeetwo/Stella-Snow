import SpriteKit
import AppKit

enum Palette {
    static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    /// Scarf and hat colors. Index 0 is the original snowman's red.
    static let scarves: [NSColor] = [
        c(0.85, 0.16, 0.24), c(0.05, 0.62, 0.66), c(0.55, 0.33, 0.83), c(0.97, 0.45, 0.64),
        c(0.98, 0.73, 0.16), c(0.20, 0.63, 0.36), c(0.23, 0.48, 0.90),
    ]
    static let coal = c(0.10, 0.10, 0.14)
    static let hatBlack = c(0.13, 0.13, 0.18)
    static let stick = c(0.40, 0.27, 0.16)
    static let carrot = c(0.97, 0.52, 0.13)
    static let carrotDark = c(0.80, 0.36, 0.06)
    static let cheek = c(0.98, 0.55, 0.62)
    static let yetiSkin = c(0.70, 0.80, 0.94)
    static let yetiSkinDark = c(0.52, 0.63, 0.82)
    static let yetiScarf = c(0.23, 0.48, 0.90)
    static let ink = c(0.13, 0.20, 0.36)
    static let rim = c(0.60, 0.70, 0.87)

    static func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        a.blended(withFraction: t, of: b) ?? a
    }
}

/// Small helpers so the character code reads like a description of the
/// character instead of a pile of SKShapeNode setup.
enum Art {
    static func circle(_ r: CGFloat, _ color: NSColor, at p: CGPoint = .zero) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: r)
        n.fillColor = color
        n.strokeColor = .clear
        n.position = p
        return n
    }

    static func ellipse(_ w: CGFloat, _ h: CGFloat, _ color: NSColor, at p: CGPoint = .zero) -> SKShapeNode {
        let n = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        n.fillColor = color
        n.strokeColor = .clear
        n.position = p
        return n
    }

    static func fill(_ path: CGPath, _ color: NSColor, stroke: NSColor? = nil, width: CGFloat = 1) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = color
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        return n
    }

    static func line(_ path: CGPath, _ color: NSColor, width: CGFloat, round: Bool = true) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = .clear
        n.strokeColor = color
        n.lineWidth = width
        n.lineCap = round ? .round : .butt
        return n
    }

    static func sprite(_ tex: SKTexture, _ w: CGFloat, _ h: CGFloat, at p: CGPoint = .zero,
                       tint: NSColor? = nil, alpha: CGFloat = 1) -> SKSpriteNode {
        let s = SKSpriteNode(texture: tex)
        s.size = CGSize(width: w, height: h)
        s.position = p
        s.alpha = alpha
        if let tint = tint {
            s.color = tint
            s.colorBlendFactor = 1
        }
        return s
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0) -> CGPath {
        let r = CGRect(x: x, y: y, width: w, height: h)
        if radius <= 0 { return CGPath(rect: r, transform: nil) }
        return CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}

/// Comic speech bubble. Pops in, holds, floats up and fades.
final class SpeechBubble: SKNode {
    init(_ text: String) {
        super.init()
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 15
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        let w = max(56, label.frame.width + 28), h: CGFloat = 32, rr: CGFloat = 13
        let L = -w / 2, R = w / 2, B: CGFloat = 0, T = h
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 4, y: B))
        p.addArc(tangent1End: CGPoint(x: R, y: B), tangent2End: CGPoint(x: R, y: T), radius: rr)
        p.addArc(tangent1End: CGPoint(x: R, y: T), tangent2End: CGPoint(x: L, y: T), radius: rr)
        p.addArc(tangent1End: CGPoint(x: L, y: T), tangent2End: CGPoint(x: L, y: B), radius: rr)
        p.addArc(tangent1End: CGPoint(x: L, y: B), tangent2End: CGPoint(x: R, y: B), radius: rr)
        p.addLine(to: CGPoint(x: -10, y: B))
        p.addLine(to: CGPoint(x: -15, y: B - 11))
        p.closeSubpath()
        let bg = Art.fill(p, .white, stroke: Palette.rim, width: 1.6)
        label.position = CGPoint(x: 0, y: h / 2)
        label.zPosition = 0.1
        addChild(bg)
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func play() {
        setScale(0.2)
        alpha = 0
        let pop = SKAction.group([SKAction.scale(to: 1.08, duration: 0.14), SKAction.fadeIn(withDuration: 0.1)])
        pop.timingMode = .easeOut
        run(SKAction.sequence([
            pop,
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 1.7),
            SKAction.group([SKAction.fadeOut(withDuration: 0.35), SKAction.moveBy(x: 0, y: 10, duration: 0.35)]),
            SKAction.removeFromParent(),
        ]))
    }
}

@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
@inline(__always) func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
func easeInOut(_ t: CGFloat) -> CGFloat { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
func easeOutBack(_ t: CGFloat) -> CGFloat {
    let c1: CGFloat = 1.70158, c3 = c1 + 1
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
}
func rotated(_ p: CGPoint, by a: CGFloat) -> CGPoint {
    CGPoint(x: p.x * cos(a) - p.y * sin(a), y: p.x * sin(a) + p.y * cos(a))
}
