import SpriteKit
import AppKit

/// Drawings for every closet item. Conventions (snowman head radius is 25):
/// - hats: bottom of the hat at the origin; `hatOffset` is how far above the
///   head's center that origin sits.
/// - face items: origin at the eye line.
/// - neck items: origin at the front of the scarf.
/// - decorations: origin at the bottom center, standing on the snow.
enum ItemArt {
    private static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { Palette.c(r, g, b, a) }

    static let gold = Palette.c(0.98, 0.78, 0.20)
    static let goldDark = Palette.c(0.72, 0.50, 0.05)
    static let red = Palette.c(0.86, 0.14, 0.19)
    static let green = Palette.c(0.14, 0.58, 0.30)

    static func star(_ r: CGFloat, inner: CGFloat, at p: CGPoint = .zero) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<10 {
            let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rr = i % 2 == 0 ? r : inner
            let pt = CGPoint(x: p.x + cos(a) * rr, y: p.y + sin(a) * rr)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    static func heart(_ s: CGFloat, at p: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: p.x, y: p.y - s * 0.45))
        path.addCurve(to: CGPoint(x: p.x - s * 0.5, y: p.y + s * 0.15),
                      control1: CGPoint(x: p.x - s * 0.2, y: p.y - s * 0.25),
                      control2: CGPoint(x: p.x - s * 0.5, y: p.y - s * 0.1))
        path.addArc(center: CGPoint(x: p.x - s * 0.25, y: p.y + s * 0.18), radius: s * 0.25,
                    startAngle: .pi, endAngle: 0, clockwise: true)
        path.addArc(center: CGPoint(x: p.x + s * 0.25, y: p.y + s * 0.18), radius: s * 0.25,
                    startAngle: .pi, endAngle: 0, clockwise: true)
        path.addCurve(to: CGPoint(x: p.x, y: p.y - s * 0.45),
                      control1: CGPoint(x: p.x + s * 0.5, y: p.y - s * 0.1),
                      control2: CGPoint(x: p.x + s * 0.2, y: p.y - s * 0.25))
        path.closeSubpath()
        return path
    }

    private static func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: [a, b, c])
        p.closeSubpath()
        return p
    }

    private static func twinkle(_ n: SKNode, delay: Double) {
        n.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.35, duration: 0.5),
                SKAction.fadeAlpha(to: 1, duration: 0.5),
            ])),
        ]))
    }

    // MARK: - hats

    /// Hat art, plus how high above the head's center it sits and how big it
    /// is when it tumbles on the ground.
    static func hat(_ item: Item, scarf: NSColor) -> (node: SKNode, offset: CGFloat, radius: CGFloat) {
        let n = SKNode()
        switch item {
        case .beanie:
            let dome = CGMutablePath()
            dome.addArc(center: CGPoint(x: 0, y: 6), radius: 26, startAngle: 0, endAngle: .pi, clockwise: false)
            dome.closeSubpath()
            n.addChild(Art.fill(dome, scarf))
            n.addChild(Art.fill(Art.rect(-28, -3, 56, 13, radius: 6), Palette.mix(scarf, .black, 0.18)))
            let ribs = CGMutablePath()
            for i in 0..<9 {
                let x = -22 + CGFloat(i) * 5.5
                ribs.move(to: CGPoint(x: x, y: -1))
                ribs.addLine(to: CGPoint(x: x, y: 8))
            }
            n.addChild(Art.line(ribs, Palette.mix(scarf, .black, 0.32), width: 1.2))
            n.addChild(Art.sprite(Tex.fluff, 22, 22, at: CGPoint(x: 0, y: 34)))
            return (n, 9, 9)
        case .earmuffs:
            let band = CGMutablePath()
            band.addArc(center: CGPoint(x: 0, y: 2), radius: 28, startAngle: .pi * 0.1, endAngle: .pi * 0.9, clockwise: false)
            n.addChild(Art.line(band, Palette.mix(Palette.hatBlack, .white, 0.25), width: 3.6))
            for x: CGFloat in [-27, 27] {
                n.addChild(Art.sprite(Tex.fluff, 21, 21, at: CGPoint(x: x, y: -2), tint: scarf))
            }
            return (n, 0, 10)
        case .santaHat:
            let cone = CGMutablePath()
            cone.move(to: CGPoint(x: -23, y: 4))
            cone.addQuadCurve(to: CGPoint(x: 6, y: 46), control: CGPoint(x: -20, y: 40))
            cone.addQuadCurve(to: CGPoint(x: 31, y: 22), control: CGPoint(x: 26, y: 50))
            cone.addQuadCurve(to: CGPoint(x: 23, y: 4), control: CGPoint(x: 22, y: 22))
            cone.closeSubpath()
            n.addChild(Art.fill(cone, red, stroke: Palette.mix(red, .black, 0.3), width: 1))
            n.addChild(Art.fill(Art.rect(-27, -3, 54, 12, radius: 6), .white, stroke: Palette.rim, width: 1))
            n.addChild(Art.sprite(Tex.fluff, 17, 17, at: CGPoint(x: 31, y: 20)))
            return (n, 15, 9)
        case .elfHat:
            let cone = CGMutablePath()
            cone.move(to: CGPoint(x: -21, y: 4))
            cone.addQuadCurve(to: CGPoint(x: 20, y: 58), control: CGPoint(x: -8, y: 46))
            cone.addQuadCurve(to: CGPoint(x: 21, y: 4), control: CGPoint(x: 14, y: 28))
            cone.closeSubpath()
            n.addChild(Art.fill(cone, green, stroke: Palette.mix(green, .black, 0.3), width: 1))
            n.addChild(Art.fill(Art.rect(-24, -2, 48, 10, radius: 4), red))
            for x: CGFloat in [-15, -5, 5, 15] { n.addChild(Art.circle(1.8, gold, at: CGPoint(x: x, y: 3))) }
            let bell = Art.circle(5, gold, at: CGPoint(x: 21, y: 58))
            bell.strokeColor = goldDark
            bell.lineWidth = 1
            n.addChild(bell)
            return (n, 14, 9)
        case .partyHat:
            n.addChild(Art.fill(tri(CGPoint(x: -15, y: 0), CGPoint(x: 0, y: 42), CGPoint(x: 15, y: 0)),
                                Palette.c(0.97, 0.45, 0.64), stroke: Palette.c(0.80, 0.25, 0.45), width: 1))
            for (p, col) in [(CGPoint(x: -5, y: 10), Palette.c(0.25, 0.55, 0.95)), (CGPoint(x: 5, y: 18), gold),
                             (CGPoint(x: -2, y: 27), Palette.c(0.25, 0.75, 0.45)), (CGPoint(x: 6, y: 6), .white)] {
                n.addChild(Art.circle(2.4, col, at: p))
            }
            n.addChild(Art.sprite(Tex.fluff, 15, 15, at: CGPoint(x: 0, y: 44), tint: gold))
            return (n, 16, 6)
        case .crown:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -20, y: 0), CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 18), CGPoint(x: 12, y: 10),
                                 CGPoint(x: 6, y: 24), CGPoint(x: 0, y: 12), CGPoint(x: -6, y: 24), CGPoint(x: -12, y: 10),
                                 CGPoint(x: -20, y: 18)])
            p.closeSubpath()
            n.addChild(Art.fill(p, gold, stroke: goldDark, width: 1.2))
            for (x, col) in [(CGFloat(-11), Palette.c(0.2, 0.45, 0.95)), (0, red), (11, Palette.c(0.2, 0.7, 0.4))] {
                n.addChild(Art.circle(x == 0 ? 3 : 2.4, col, at: CGPoint(x: x, y: 5)))
            }
            for pt in [CGPoint(x: -20, y: 18), CGPoint(x: -6, y: 24), CGPoint(x: 6, y: 24), CGPoint(x: 20, y: 18)] {
                n.addChild(Art.circle(2.2, gold, at: pt))
            }
            return (n, 19, 5)
        case .tiara:
            let band = CGMutablePath()
            band.addArc(center: CGPoint(x: 0, y: -14), radius: 24, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            n.addChild(Art.line(band, Palette.c(0.86, 0.89, 0.96), width: 3))
            let peak = CGMutablePath()
            peak.addLines(between: [CGPoint(x: -9, y: 8), CGPoint(x: 0, y: 20), CGPoint(x: 9, y: 8)])
            n.addChild(Art.line(peak, Palette.c(0.86, 0.89, 0.96), width: 2.4))
            n.addChild(Art.circle(4, Palette.c(0.98, 0.45, 0.70), at: CGPoint(x: 0, y: 13)))
            for x: CGFloat in [-14, 14] { n.addChild(Art.circle(2.4, Palette.c(0.6, 0.85, 1.0), at: CGPoint(x: x, y: 7))) }
            let glint = Art.sprite(Tex.sparkle, 16, 16, at: CGPoint(x: 0, y: 14))
            glint.blendMode = .add
            twinkle(glint, delay: 0)
            n.addChild(glint)
            return (n, 21, 4)
        case .antlers:
            let brown = Palette.c(0.55, 0.36, 0.20)
            let band = CGMutablePath()
            band.addArc(center: CGPoint(x: 0, y: 2), radius: 27, startAngle: .pi * 0.12, endAngle: .pi * 0.88, clockwise: false)
            n.addChild(Art.line(band, brown, width: 3.4))
            let horns = CGMutablePath()
            for s: CGFloat in [-1, 1] {
                horns.move(to: CGPoint(x: 13 * s, y: 26))
                horns.addLine(to: CGPoint(x: 21 * s, y: 50))
                horns.move(to: CGPoint(x: 17 * s, y: 38))
                horns.addLine(to: CGPoint(x: 29 * s, y: 42))
                horns.move(to: CGPoint(x: 19.5 * s, y: 45))
                horns.addLine(to: CGPoint(x: 13 * s, y: 54))
            }
            n.addChild(Art.line(horns, brown, width: 3.6))
            for s: CGFloat in [-1, 1] {
                let ear = Art.ellipse(8, 14, Palette.c(0.66, 0.46, 0.30), at: CGPoint(x: 22 * s, y: 20))
                ear.zRotation = -0.6 * s
                n.addChild(ear)
            }
            return (n, 0, 10)
        default: // top hat
            n.addChild(Art.fill(Art.rect(-15, 0, 30, 31, radius: 2), Palette.hatBlack))
            n.addChild(Art.fill(Art.rect(-15, 2, 30, 6), scarf))
            n.addChild(Art.fill(Art.rect(-11, 10, 3, 18, radius: 1.5), NSColor(white: 1, alpha: 0.18)))
            n.addChild(Art.ellipse(54, 10, Palette.hatBlack, at: CGPoint(x: 0, y: 1)))
            return (n, 18, 5)
        }
    }

    // MARK: - face

    static func face(_ item: Item) -> SKNode {
        let n = SKNode()
        let bridge = CGMutablePath()
        bridge.move(to: CGPoint(x: -3, y: 1))
        bridge.addLine(to: CGPoint(x: 3, y: 1))
        switch item {
        case .sunglasses:
            for x: CGFloat in [-17, 3] {
                n.addChild(Art.fill(Art.rect(x, -4.5, 14, 9.5, radius: 3), Palette.c(0.08, 0.08, 0.12)))
                let shine = CGMutablePath()
                shine.move(to: CGPoint(x: x + 3, y: 2.5))
                shine.addLine(to: CGPoint(x: x + 7, y: 2.5))
                n.addChild(Art.line(shine, NSColor(white: 1, alpha: 0.6), width: 1.2))
            }
            n.addChild(Art.line(bridge, Palette.c(0.08, 0.08, 0.12), width: 1.8))
        case .heartGlasses:
            for x: CGFloat in [-10, 10] {
                n.addChild(Art.fill(heart(15, at: CGPoint(x: x, y: 0)), Palette.c(0.98, 0.33, 0.55, 0.95),
                                    stroke: Palette.c(0.75, 0.12, 0.35), width: 1))
            }
            n.addChild(Art.line(bridge, Palette.c(0.75, 0.12, 0.35), width: 1.6))
        case .starGlasses:
            for x: CGFloat in [-10, 10] {
                n.addChild(Art.fill(star(9, inner: 4.2, at: CGPoint(x: x, y: 0)), gold, stroke: goldDark, width: 1))
            }
            n.addChild(Art.line(bridge, goldDark, width: 1.6))
        case .roundGlasses:
            for x: CGFloat in [-9.5, 9.5] {
                let lens = Art.circle(6.8, NSColor(white: 1, alpha: 0.15), at: CGPoint(x: x, y: 0))
                lens.strokeColor = Palette.c(0.25, 0.18, 0.12)
                lens.lineWidth = 1.6
                n.addChild(lens)
            }
            n.addChild(Art.line(bridge, Palette.c(0.25, 0.18, 0.12), width: 1.6))
        default: // shiny red nose (replaces the carrot)
            let glow = Art.sprite(Tex.softDot, 26, 26, at: CGPoint(x: 1, y: -7), tint: Palette.c(1, 0.2, 0.2), alpha: 0.7)
            glow.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.7), SKAction.fadeAlpha(to: 0.8, duration: 0.7),
            ])))
            n.addChild(glow)
            n.addChild(Art.circle(5.2, Palette.c(0.92, 0.10, 0.12), at: CGPoint(x: 1, y: -7)))
            n.addChild(Art.circle(1.6, NSColor(white: 1, alpha: 0.8), at: CGPoint(x: 2.6, y: -5.4)))
        }
        return n
    }

    // MARK: - neck

    static func neck(_ item: Item) -> SKNode {
        let n = SKNode()
        if item == .sleighBell {
            n.addChild(Art.fill(Art.rect(-3, -2, 6, 8, radius: 2), red))
            let bell = Art.circle(6.5, gold, at: CGPoint(x: 0, y: -7))
            bell.strokeColor = goldDark
            bell.lineWidth = 1
            n.addChild(bell)
            let slit = CGMutablePath()
            slit.move(to: CGPoint(x: -3, y: -9))
            slit.addLine(to: CGPoint(x: 3, y: -9))
            n.addChild(Art.line(slit, goldDark, width: 1.4))
            n.addChild(Art.circle(1.6, NSColor(white: 1, alpha: 0.75), at: CGPoint(x: -2, y: -4.5)))
            return n
        }
        let color: NSColor = item == .bowtieGreen ? green : item == .bowtieGold ? gold : red
        let dark = Palette.mix(color, .black, 0.3)
        n.addChild(Art.fill(tri(CGPoint(x: 0, y: 0), CGPoint(x: -14, y: 7.5), CGPoint(x: -14, y: -7.5)), color, stroke: dark, width: 1))
        n.addChild(Art.fill(tri(CGPoint(x: 0, y: 0), CGPoint(x: 14, y: 7.5), CGPoint(x: 14, y: -7.5)), color, stroke: dark, width: 1))
        n.addChild(Art.circle(3.6, Palette.mix(color, .black, 0.15), at: .zero))
        return n
    }

    // MARK: - decorations

    static func decor(_ item: Item) -> SKNode {
        let n = SKNode()
        let shadow = Art.sprite(Tex.shadow, 80, 16, at: CGPoint(x: 0, y: 2))
        shadow.zPosition = -1
        n.addChild(shadow)
        switch item {
        case .miniTree:
            n.addChild(Art.fill(Art.rect(-4, 0, 8, 9), Palette.c(0.45, 0.28, 0.15)))
            let tiers: [(CGFloat, CGFloat, CGFloat)] = [(24, 6, 30), (19, 22, 44), (14, 37, 58)]
            for (w, y0, y1) in tiers {
                n.addChild(Art.fill(tri(CGPoint(x: -w, y: y0), CGPoint(x: 0, y: y1), CGPoint(x: w, y: y0)),
                                    Palette.c(0.10, 0.48, 0.25), stroke: Palette.c(0.05, 0.32, 0.15), width: 1))
                n.addChild(Art.fill(Art.rect(-w * 0.8, y0, w * 1.6, 2.5, radius: 1.2), NSColor(white: 1, alpha: 0.85)))
            }
            let bulbs: [CGPoint] = [CGPoint(x: -14, y: 12), CGPoint(x: 0, y: 15), CGPoint(x: 14, y: 11), CGPoint(x: -9, y: 27),
                                    CGPoint(x: 8, y: 29), CGPoint(x: -5, y: 42), CGPoint(x: 6, y: 44), CGPoint(x: 0, y: 51)]
            let colors = [red, gold, Palette.c(0.3, 0.6, 1), Palette.c(0.98, 0.45, 0.7)]
            for (i, p) in bulbs.enumerated() {
                let b = Art.circle(2.3, colors[i % colors.count], at: p)
                twinkle(b, delay: Double(i) * 0.13)
                n.addChild(b)
            }
            n.addChild(Art.fill(star(7, inner: 3.2, at: CGPoint(x: 0, y: 61)), gold, stroke: goldDark, width: 1))
        case .candyCane:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 0, y: 40))
            p.addArc(center: CGPoint(x: -9, y: 40), radius: 9, startAngle: 0, endAngle: .pi, clockwise: false)
            p.addLine(to: CGPoint(x: -18, y: 34))
            n.addChild(Art.line(p, .white, width: 8))
            n.addChild(Art.line(p.copy(dashingWithPhase: 0, lengths: [5, 5]), red, width: 8, round: false))
        case .gingerbread:
            let dough = Palette.c(0.72, 0.45, 0.22)
            n.addChild(Art.fill(Art.rect(-9, 0, 7, 15, radius: 3.5), dough))
            n.addChild(Art.fill(Art.rect(2, 0, 7, 15, radius: 3.5), dough))
            n.addChild(Art.fill(Art.rect(-18, 22, 36, 7, radius: 3.5), dough))
            n.addChild(Art.fill(Art.rect(-9, 9, 18, 22, radius: 7), dough))
            n.addChild(Art.circle(9.5, dough, at: CGPoint(x: 0, y: 37)))
            for x: CGFloat in [-3.5, 3.5] { n.addChild(Art.circle(1.4, .white, at: CGPoint(x: x, y: 39))) }
            let smile = CGMutablePath()
            smile.addArc(center: CGPoint(x: 0, y: 36), radius: 4, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
            n.addChild(Art.line(smile, .white, width: 1.2))
            n.addChild(Art.circle(1.8, red, at: CGPoint(x: 0, y: 23)))
            n.addChild(Art.circle(1.8, green, at: CGPoint(x: 0, y: 16)))
            let icing = CGMutablePath()
            for x: CGFloat in [-15, 15] {
                icing.move(to: CGPoint(x: x, y: 23))
                icing.addLine(to: CGPoint(x: x, y: 28))
            }
            n.addChild(Art.line(icing, .white, width: 1.4))
        case .lantern:
            let glow = Art.sprite(Tex.softDot, 80, 80, at: CGPoint(x: 0, y: 16), tint: Palette.c(1, 0.75, 0.35), alpha: 0.6)
            glow.zPosition = -0.5
            glow.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.45, duration: 0.25), SKAction.fadeAlpha(to: 0.65, duration: 0.35),
            ])))
            n.addChild(glow)
            let frame = Palette.c(0.20, 0.22, 0.28)
            n.addChild(Art.fill(Art.rect(-11, 0, 22, 4, radius: 1), frame))
            n.addChild(Art.fill(Art.rect(-9, 4, 18, 24), Palette.c(1, 0.84, 0.48), stroke: frame, width: 2))
            n.addChild(Art.fill(tri(CGPoint(x: -12, y: 28), CGPoint(x: 0, y: 36), CGPoint(x: 12, y: 28)), frame))
            let handle = CGMutablePath()
            handle.addArc(center: CGPoint(x: 0, y: 37), radius: 5, startAngle: 0, endAngle: .pi, clockwise: false)
            n.addChild(Art.line(handle, frame, width: 1.8))
            n.addChild(Art.ellipse(5, 9, Palette.c(1, 0.6, 0.15), at: CGPoint(x: 0, y: 14)))
        case .sled:
            let wood = Palette.c(0.80, 0.22, 0.20)
            n.addChild(Art.fill(Art.rect(-30, 10, 58, 8, radius: 3), wood, stroke: Palette.mix(wood, .black, 0.3), width: 1))
            let runner = CGMutablePath()
            runner.move(to: CGPoint(x: -34, y: 4))
            runner.addLine(to: CGPoint(x: 26, y: 4))
            runner.addQuadCurve(to: CGPoint(x: 36, y: 20), control: CGPoint(x: 40, y: 4))
            let struts = CGMutablePath()
            for x: CGFloat in [-22, 0, 20] {
                struts.move(to: CGPoint(x: x, y: 4))
                struts.addLine(to: CGPoint(x: x, y: 10))
            }
            n.addChild(Art.line(struts, Palette.c(0.35, 0.36, 0.42), width: 2))
            n.addChild(Art.line(runner, Palette.c(0.35, 0.36, 0.42), width: 3))
        case .presents:
            let boxes: [(CGRect, NSColor, NSColor)] = [
                (CGRect(x: -26, y: 0, width: 26, height: 22), red, .white),
                (CGRect(x: 2, y: 0, width: 22, height: 18), green, gold),
                (CGRect(x: -17, y: 22, width: 21, height: 16), Palette.c(0.25, 0.5, 0.92), Palette.c(0.9, 0.92, 0.97)),
            ]
            for (r, col, ribbon) in boxes {
                n.addChild(Art.fill(Art.rect(r.minX, r.minY, r.width, r.height, radius: 2), col,
                                    stroke: Palette.mix(col, .black, 0.3), width: 1))
                n.addChild(Art.fill(Art.rect(r.midX - 2, r.minY, 4, r.height), ribbon))
                n.addChild(Art.fill(Art.rect(r.minX, r.midY - 2, r.width, 4), ribbon))
            }
            for s: CGFloat in [-1, 1] {
                let loop = Art.ellipse(9, 6, Palette.c(0.9, 0.92, 0.97), at: CGPoint(x: -6.5 + 4 * s, y: 40))
                loop.zRotation = 0.5 * s
                n.addChild(loop)
            }
        case .hotCocoa:
            let mug = Palette.c(0.85, 0.18, 0.22)
            let handle = CGMutablePath()
            handle.addArc(center: CGPoint(x: 11, y: 11), radius: 6, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
            n.addChild(Art.line(handle, mug, width: 3.5))
            n.addChild(Art.fill(Art.rect(-11, 0, 22, 23, radius: 4), mug, stroke: Palette.mix(mug, .black, 0.3), width: 1))
            n.addChild(Art.ellipse(20, 6, Palette.c(0.42, 0.25, 0.15), at: CGPoint(x: 0, y: 22)))
            for p in [CGPoint(x: -4, y: 23), CGPoint(x: 3, y: 24), CGPoint(x: 1, y: 21.5)] {
                n.addChild(Art.fill(Art.rect(p.x - 2.5, p.y - 2, 5, 4, radius: 1.2), .white))
            }
            for i in 0..<2 {
                let steam = Art.sprite(Tex.softDot, 12, 12, at: CGPoint(x: -3 + CGFloat(i) * 6, y: 28), alpha: 0)
                steam.run(SKAction.sequence([
                    SKAction.wait(forDuration: Double(i) * 0.9),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.group([SKAction.moveBy(x: 0, y: 18, duration: 1.8),
                                        SKAction.sequence([SKAction.fadeAlpha(to: 0.6, duration: 0.5),
                                                           SKAction.fadeAlpha(to: 0, duration: 1.3)])]),
                        SKAction.moveBy(x: 0, y: -18, duration: 0),
                    ])),
                ]))
                n.addChild(steam)
            }
        case .igloo:
            let dome = CGMutablePath()
            dome.addArc(center: .zero, radius: 40, startAngle: 0, endAngle: .pi, clockwise: false)
            dome.closeSubpath()
            let d = Art.fill(dome, .white, stroke: Palette.rim, width: 1.2)
            d.fillTexture = Tex.snowball
            n.addChild(d)
            let blocks = CGMutablePath()
            for y: CGFloat in [12, 24, 33] {
                let half = sqrt(max(0, 40 * 40 - y * y))
                blocks.move(to: CGPoint(x: -half, y: y))
                blocks.addLine(to: CGPoint(x: half, y: y))
            }
            for (x, y) in [(CGFloat(-20), CGFloat(0)), (0, 0), (-28, 12), (-8, 12), (24, 12), (-14, 24), (10, 24)] {
                blocks.move(to: CGPoint(x: x, y: y))
                blocks.addLine(to: CGPoint(x: x, y: y + 12))
            }
            n.addChild(Art.line(blocks, Palette.rim, width: 1))
            let door = CGMutablePath()
            door.addArc(center: CGPoint(x: 16, y: 0), radius: 11, startAngle: 0, endAngle: .pi, clockwise: false)
            door.closeSubpath()
            n.addChild(Art.fill(door, Palette.c(0.16, 0.20, 0.32)))
        case .snowDog:
            for x: CGFloat in [-14, -6, 8, 15] { n.addChild(Art.sprite(Tex.snowball, 10, 10, at: CGPoint(x: x, y: 5))) }
            n.addChild(Art.sprite(Tex.snowball, 11, 11, at: CGPoint(x: -24, y: 24)))
            n.addChild(Art.sprite(Tex.snowball, 46, 28, at: CGPoint(x: 0, y: 17)))
            n.addChild(Art.fill(Art.rect(14, 22, 5, 14, radius: 2), red))
            n.addChild(Art.sprite(Tex.snowball, 26, 24, at: CGPoint(x: 24, y: 32)))
            for (x, r) in [(CGFloat(16), CGFloat(0.5)), (30, -0.5)] {
                let ear = Art.ellipse(7, 13, Palette.c(0.45, 0.32, 0.25), at: CGPoint(x: x, y: 41))
                ear.zRotation = r
                n.addChild(ear)
            }
            n.addChild(Art.circle(2.6, Palette.coal, at: CGPoint(x: 36, y: 31)))
            for x: CGFloat in [21, 28] { n.addChild(Art.circle(1.7, Palette.coal, at: CGPoint(x: x, y: 35))) }
        case .goldenStar:
            let glow = Art.sprite(Tex.softDot, 100, 100, at: CGPoint(x: 0, y: 44), tint: gold, alpha: 0.5)
            glow.zPosition = -0.5
            glow.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 1.2), SKAction.scale(to: 0.9, duration: 1.2),
            ])))
            n.addChild(glow)
            n.addChild(Art.fill(Art.rect(-1.6, 0, 3.2, 30, radius: 1.5), Palette.c(0.70, 0.60, 0.42)))
            n.addChild(Art.fill(star(17, inner: 7.5, at: CGPoint(x: 0, y: 44)), gold, stroke: goldDark, width: 1.4))
            let glint = Art.sprite(Tex.sparkle, 26, 26, at: CGPoint(x: 6, y: 52))
            glint.blendMode = .add
            twinkle(glint, delay: 0.3)
            n.addChild(glint)
        case .birthdayCake:
            n.addChild(Art.ellipse(74, 9, .white, at: CGPoint(x: 0, y: 3)))
            n.addChild(Art.fill(Art.rect(-30, 4, 60, 22, radius: 4), Palette.c(0.98, 0.70, 0.80),
                                stroke: Palette.c(0.85, 0.45, 0.6), width: 1))
            n.addChild(Art.fill(Art.rect(-20, 26, 40, 16, radius: 4), .white, stroke: Palette.rim, width: 1))
            let drips = CGMutablePath()
            drips.move(to: CGPoint(x: -30, y: 22))
            for i in 0..<6 {
                let x = -30 + CGFloat(i) * 10
                drips.addQuadCurve(to: CGPoint(x: x + 10, y: 22), control: CGPoint(x: x + 5, y: 15))
            }
            n.addChild(Art.line(drips, .white, width: 3))
            let colors = [red, gold, Palette.c(0.3, 0.6, 1), green, Palette.c(0.6, 0.35, 0.9)]
            for i in 0..<5 {
                let x = -12 + CGFloat(i) * 6
                n.addChild(Art.fill(Art.rect(x - 1.5, 42, 3, 11, radius: 1), colors[i]))
                let flame = Art.ellipse(3.5, 6, Palette.c(1, 0.7, 0.2), at: CGPoint(x: x, y: 56))
                flame.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.scaleY(to: 1.3, duration: 0.15 + Double(i) * 0.02),
                    SKAction.scaleY(to: 0.85, duration: 0.15),
                ])))
                n.addChild(flame)
            }
        default:
            break
        }
        return n
    }

    // MARK: - closet icons

    /// Any item, scaled to fit a closet cell.
    static func icon(_ item: Item, fit: CGFloat) -> SKNode {
        let art: SKNode
        switch item.slot {
        case .hat: art = hat(item, scarf: Palette.scarves[0]).node
        case .face: art = face(item)
        case .neck: art = neck(item)
        case .decor: art = decor(item)
        }
        let holder = SKNode()
        holder.addChild(art)
        let f = art.calculateAccumulatedFrame()
        let s = min(fit / max(f.width, 1), fit / max(f.height, 1), 2.2)
        art.setScale(s)
        art.position = CGPoint(x: -f.midX * s, y: -f.midY * s)
        return holder
    }
}
