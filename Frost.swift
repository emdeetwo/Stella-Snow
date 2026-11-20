import SpriteKit
import AppKit

/// Frost on the glass. When the Mac sits untouched, frost creeps in from the
/// screen edges. Moving the pointer wipes it away like a finger on a cold
/// window, so she can draw in it. It slowly melts once she's back.
///
/// Kept as a coarse grid (one cell per 6 points) painted into a small image
/// and stretched over the screen, so it's cheap.
final class FrostLayer: SKSpriteNode {
    private let cellSize: CGFloat = 6
    private var gw = 0
    private var gh = 0
    private var density: [Float] = []
    private var pattern: [Float] = []
    private var edge: [Float] = []
    private var ctx: CGContext?
    private var dirty = false
    private var texClock: CGFloat = 0
    private(set) var coverage: Float = 0

    func setup(size: CGSize) {
        self.size = size
        anchorPoint = .zero
        position = .zero
        gw = max(8, Int(size.width / cellSize))
        gh = max(8, Int(size.height / cellSize))
        density = [Float](repeating: 0, count: gw * gh)
        pattern = [Float](repeating: 0, count: gw * gh)
        edge = [Float](repeating: 0, count: gw * gh)
        let half = Float(min(gw, gh)) / 2
        for gy in 0..<gh {
            for gx in 0..<gw {
                let x = Float(gx), y = Float(gy)
                let soft = 0.55 * FrostLayer.noise(x * 0.07, y * 0.07) + 0.3 * FrostLayer.noise(x * 0.19 + 7, y * 0.19 + 3)
                let ridge = 1 - abs(2 * FrostLayer.noise(x * 0.33 + 11, y * 0.33 + 5) - 1)
                pattern[gy * gw + gx] = min(1, soft + 0.35 * ridge * ridge)
                let e = Float(min(min(gx, gw - 1 - gx), min(gy, gh - 1 - gy)))
                edge[gy * gw + gx] = e / half
            }
        }
        ctx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: gw * 4,
                        space: Tex.space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        coverage = 0
        isHidden = true
    }

    private static func cellHash(_ x: Int, _ y: Int) -> Float {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263)
        h = (h ^ (h >> 13)) &* 1274126177
        return Float(h & 0xffff) / 65535
    }

    private static func noise(_ x: Float, _ y: Float) -> Float {
        let x0 = floor(x), y0 = floor(y)
        let fx = x - x0, fy = y - y0
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let xi = Int(x0), yi = Int(y0)
        let a = cellHash(xi, yi), b = cellHash(xi + 1, yi), c = cellHash(xi, yi + 1), d = cellHash(xi + 1, yi + 1)
        return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy
    }

    /// Covers the edges in frost right away (sneak peek).
    func frostNow() {
        for i in density.indices where edge[i] + (pattern[i] - 0.5) * 0.18 < 0.5 { density[i] = 1 }
        dirty = true
        coverage = 0.3
    }

    /// Returns true when she drew through real frost this frame.
    func update(dt: CGFloat, idle: CGFloat, wipeAt: CGPoint?) -> Bool {
        guard gw > 0 else { return false }
        var changed = false
        var drew = false
        let progress = Float(clamp((idle - 60) / 80, 0, 1))
        if progress > 0 {
            let front = progress * 0.62
            let grow = Float(dt) * 0.6
            for i in density.indices where density[i] < 1 && edge[i] + (pattern[i] - 0.5) * 0.18 < front {
                density[i] = min(1, density[i] + grow)
                changed = true
            }
        } else if coverage > 0 {
            let melt = Float(dt) * 0.004
            for i in density.indices where density[i] > 0 { density[i] = max(0, density[i] - melt) }
            changed = true
        }
        if let p = wipeAt, coverage > 0.0005 {
            let r: CGFloat = 30
            let cx = Int(p.x / cellSize), cy = Int(p.y / cellSize), cr = Int(r / cellSize) + 1
            let y0 = max(0, cy - cr), y1 = min(gh - 1, cy + cr)
            let x0 = max(0, cx - cr), x1 = min(gw - 1, cx + cr)
            if y0 <= y1 && x0 <= x1 {
            for gy in y0...y1 {
                for gx in x0...x1 {
                    let dx = (CGFloat(gx) + 0.5) * cellSize - p.x, dy = (CGFloat(gy) + 0.5) * cellSize - p.y
                    let d = sqrt(dx * dx + dy * dy) / r
                    guard d < 1 else { continue }
                    let keep = Float(clamp((d - 0.55) / 0.45, 0, 1))
                    let i = gy * gw + gx
                    if density[i] > keep {
                        if density[i] > 0.3 { drew = true }
                        density[i] = keep
                        changed = true
                    }
                }
            }
            }
        }
        if changed { dirty = true }
        texClock += dt
        if dirty && texClock > 0.08 {
            texClock = 0
            dirty = false
            redraw()
        }
        return drew
    }

    private func redraw() {
        guard let ctx = ctx, let base = ctx.data else { return }
        let px = base.bindMemory(to: UInt8.self, capacity: gw * gh * 4)
        var total: Float = 0
        for gy in 0..<gh {
            let row = (gh - 1 - gy) * gw   // bitmap rows run top to bottom
            for gx in 0..<gw {
                let i = gy * gw + gx
                let d = density[i]
                total += d
                let a = min(1, d * (0.30 + 0.62 * pattern[i]))
                let o = (row + gx) * 4
                px[o] = UInt8(232 * a)
                px[o + 1] = UInt8(242 * a)
                px[o + 2] = UInt8(255 * a)
                px[o + 3] = UInt8(255 * a)
            }
        }
        coverage = total / Float(max(1, density.count))
        isHidden = coverage < 0.0005
        if !isHidden, let img = ctx.makeImage() {
            let t = SKTexture(cgImage: img)
            t.filteringMode = .linear
            texture = t
        }
    }
}
