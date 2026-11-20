import SpriteKit
import AppKit

/// Every texture in the app is painted in code once, the first time it is
/// used. No image files to ship besides the wallpaper, and everything stays
/// crisp on Retina because each texture is painted larger than it is drawn.
enum Tex {

    // MARK: - painting helpers

    static let space: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: space, components: [r, g, b, a]) ?? CGColor(gray: 1, alpha: a)
    }

    private static func paint(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> SKTexture {
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return SKTexture()
        }
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        draw(ctx)
        guard let image = ctx.makeImage() else { return SKTexture() }
        let t = SKTexture(cgImage: image)
        t.filteringMode = .linear
        return t
    }

    private static func radial(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat,
                               _ colors: [CGColor], _ stops: [CGFloat], extend: Bool = false) {
        guard let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops) else { return }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                               options: extend ? [.drawsAfterEndLocation] : [])
    }

    private static func linear(_ ctx: CGContext, from a: CGPoint, to b: CGPoint,
                               _ colors: [CGColor], _ stops: [CGFloat]) {
        guard let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops) else { return }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    /// Small deterministic random so the hand-painted textures look the
    /// same on every launch.
    struct Seeded {
        private var s: UInt64
        init(_ seed: UInt64) { s = seed &* 2654435761 &+ 1013904223 }
        mutating func next() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) % 1_000_000) / 1_000_000
        }
        mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * next() }
    }

    // MARK: - snowflakes

    /// Soft round flake, the bulk of the snowfall.
    static let softDot: SKTexture = paint(32, 32) { ctx in
        radial(ctx, CGPoint(x: 16, y: 16), 16,
               [rgba(1, 1, 1, 1), rgba(1, 1, 1, 0.85), rgba(1, 1, 1, 0)], [0, 0.38, 1])
    }

    /// Out-of-focus flake drifting right past the "lens".
    static let bokeh: SKTexture = paint(64, 64) { ctx in
        radial(ctx, CGPoint(x: 32, y: 32), 32,
               [rgba(1, 1, 1, 0.20), rgba(1, 1, 1, 0.28), rgba(1, 1, 1, 0.45), rgba(1, 1, 1, 0)],
               [0, 0.68, 0.88, 1])
    }

    /// A real six-armed crystal with a soft glow, used for a few big flakes.
    static let crystal: SKTexture = paint(64, 64) { ctx in
        let c = CGPoint(x: 32, y: 32)
        ctx.setShadow(offset: .zero, blur: 3, color: rgba(1, 1, 1, 0.9))
        ctx.setStrokeColor(rgba(1, 1, 1, 1))
        ctx.setLineCap(.round)
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3 + .pi / 6
            let dx = cos(a), dy = sin(a)
            ctx.setLineWidth(2.6)
            ctx.move(to: c)
            ctx.addLine(to: CGPoint(x: c.x + dx * 27, y: c.y + dy * 27))
            ctx.strokePath()
            ctx.setLineWidth(2.0)
            for (d, len) in [(CGFloat(11), CGFloat(7)), (CGFloat(19), CGFloat(5))] {
                let m = CGPoint(x: c.x + dx * d, y: c.y + dy * d)
                for side: CGFloat in [-1, 1] {
                    let b = a + side * .pi / 3.2
                    ctx.move(to: m)
                    ctx.addLine(to: CGPoint(x: m.x + cos(b) * len, y: m.y + sin(b) * len))
                }
            }
            ctx.strokePath()
        }
        ctx.fillEllipse(in: circle(c, 3))
    }

    // MARK: - snow objects

    /// A shaded snowball: lit from the upper left, cool blue in the shade,
    /// a little snow grain, and a faint rim so it reads on white windows.
    static let snowball: SKTexture = paint(128, 128) { ctx in
        let rect = CGRect(x: 3, y: 3, width: 122, height: 122)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        radial(ctx, CGPoint(x: 48, y: 84), 104,
               [rgba(1, 1, 1), rgba(0.97, 0.98, 1), rgba(0.78, 0.85, 0.95)], [0, 0.42, 1], extend: true)
        radial(ctx, CGPoint(x: 78, y: -16), 64,
               [rgba(0.92, 0.95, 1, 0.55), rgba(0.92, 0.95, 1, 0)], [0, 1])
        var r = Seeded(7)
        for _ in 0..<260 {
            let s = r.range(0.8, 2.4)
            ctx.setFillColor(rgba(0.55, 0.66, 0.84, r.range(0.05, 0.13)))
            ctx.fillEllipse(in: CGRect(x: r.range(0, 128), y: r.range(0, 128), width: s, height: s))
        }
        ctx.restoreGState()
        ctx.setStrokeColor(rgba(0.55, 0.65, 0.83, 0.55))
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
    }

    /// Tufted fur ball, the building block of the yeti and the pom-pom.
    static let fluff: SKTexture = paint(128, 128) { ctx in
        let c = CGPoint(x: 64, y: 64)
        let path = CGMutablePath()
        let n = 96
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let rr = 55 + 4.5 * sin(a * 11) + 2.2 * sin(a * 7 + 1.3)
            let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        radial(ctx, CGPoint(x: 50, y: 82), 92,
               [rgba(1, 1, 1), rgba(0.96, 0.97, 1), rgba(0.79, 0.85, 0.95)], [0, 0.5, 1], extend: true)
        var r = Seeded(31)
        ctx.setLineCap(.round)
        for _ in 0..<70 {
            let a = r.range(0, 2 * .pi), d = r.range(14, 50)
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
            ctx.setStrokeColor(rgba(0.62, 0.71, 0.87, r.range(0.10, 0.22)))
            ctx.setLineWidth(r.range(1.2, 2.2))
            ctx.move(to: p)
            ctx.addLine(to: CGPoint(x: p.x + cos(a) * 7, y: p.y + sin(a) * 7))
            ctx.strokePath()
        }
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(rgba(0.60, 0.69, 0.86, 0.5))
        ctx.setLineWidth(2.4)
        ctx.strokePath()
    }

    /// Snowball splats that hit the "glass" of the screen. Three variants.
    static let splats: [SKTexture] = (0..<3).map { variant in
        paint(256, 256) { ctx in
            var r = Seeded(UInt64(variant * 97 + 13))
            let c = CGPoint(x: 128, y: 140)
            let path = CGMutablePath()
            path.addEllipse(in: circle(c, 52))
            let lobes = 9 + Int(r.next() * 4)
            for i in 0..<lobes {
                let a = CGFloat(i) / CGFloat(lobes) * 2 * .pi + r.range(0, 0.5)
                let d = r.range(40, 74)
                path.addEllipse(in: circle(CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), r.range(13, 30)))
            }
            for _ in 0..<8 {
                let a = r.range(0, 2 * .pi), d = r.range(88, 114)
                path.addEllipse(in: circle(CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), r.range(3, 8)))
            }
            let drips = 2 + Int(r.next() * 2)
            for _ in 0..<drips {
                let x = c.x + r.range(-36, 36), w = r.range(9, 15), len = r.range(34, 70)
                path.addRoundedRect(in: CGRect(x: x - w / 2, y: c.y - 30 - len, width: w, height: len + 30),
                                    cornerWidth: w / 2, cornerHeight: w / 2)
                path.addEllipse(in: circle(CGPoint(x: x, y: c.y - 30 - len + w * 0.35), w * 0.72))
            }
            // Drop shadow of the whole union gives it a crisp edge on any wallpaper.
            ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 7, color: rgba(0.20, 0.30, 0.50, 0.45))
            ctx.setFillColor(rgba(1, 1, 1))
            ctx.addPath(path)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            radial(ctx, c, 140, [rgba(1, 1, 1), rgba(0.95, 0.97, 1), rgba(0.80, 0.87, 0.97)], [0, 0.5, 1], extend: true)
            var g = Seeded(UInt64(variant + 3))
            for _ in 0..<500 {
                let s = g.range(1, 3)
                ctx.setFillColor(rgba(0.55, 0.66, 0.85, g.range(0.05, 0.12)))
                ctx.fillEllipse(in: CGRect(x: g.range(20, 236), y: g.range(20, 236), width: s, height: s))
            }
            // Wet highlight.
            radial(ctx, CGPoint(x: c.x - 18, y: c.y + 20), 26, [rgba(1, 1, 1, 0.9), rgba(1, 1, 1, 0)], [0, 1])
            ctx.restoreGState()
        }
    }

    // MARK: - ground details

    /// Vertical fill for the drifts: bright on top, cool blue underneath.
    static let driftFill: SKTexture = paint(4, 128) { ctx in
        linear(ctx, from: CGPoint(x: 0, y: 128), to: CGPoint(x: 0, y: 0),
               [rgba(1, 1, 1), rgba(0.95, 0.97, 1), rgba(0.80, 0.87, 0.96)], [0, 0.35, 1])
    }

    /// Soft contact shadow under characters so they sit in the snow.
    static let shadow: SKTexture = paint(128, 40) { ctx in
        ctx.translateBy(x: 64, y: 20)
        ctx.scaleBy(x: 1, y: 0.3125)
        radial(ctx, .zero, 64, [rgba(0.22, 0.32, 0.52, 0.38), rgba(0.22, 0.32, 0.52, 0)], [0, 1])
    }

    static let footprint: SKTexture = paint(32, 20) { ctx in
        ctx.translateBy(x: 16, y: 10)
        ctx.scaleBy(x: 1, y: 0.62)
        radial(ctx, .zero, 16, [rgba(0.50, 0.62, 0.82, 0.55), rgba(0.50, 0.62, 0.82, 0.35), rgba(0.50, 0.62, 0.82, 0)],
               [0, 0.6, 1])
    }

    /// Four-point glint for sparkles on the snow.
    static let sparkle: SKTexture = paint(48, 48) { ctx in
        let c = CGPoint(x: 24, y: 24)
        radial(ctx, c, 10, [rgba(1, 1, 1, 0.9), rgba(1, 1, 1, 0)], [0, 1])
        ctx.setFillColor(rgba(1, 1, 1, 1))
        for (w, h) in [(CGFloat(3), CGFloat(44)), (CGFloat(44), CGFloat(3))] {
            ctx.fillEllipse(in: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
        }
    }
}
