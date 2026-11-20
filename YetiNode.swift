import SpriteKit
import AppKit

/// The friendly, sneaky yeti.
///
/// Every few minutes he walks in leaving footprints, tiptoes up to the
/// snowman, looks right at you, winds up and shoves him apart, laughs,
/// then scoops three snowballs and throws them AT THE SCREEN (they splat on
/// the glass). Then he waves and wanders off. Click him to bonk him with a
/// snowball and he runs away.
///
/// Every move has anticipation (lean back), action, and follow-through, so
/// he reads like a cartoon instead of a sliding sticker.
final class YetiNode: SKNode {
    enum Beat {
        case away, walkIn, sneak, windup, shove, laugh, scoop, aim, release, wave, walkOut, bonked
        case fightReady, ouch, hide, cower, giveCake
    }

    private weak var host: SnowScene?
    private(set) var beat: Beat = .away
    private var beatT: CGFloat = 0
    private var awayTimer: CGFloat = CGFloat.random(in: 50...80)
    private var throwsLeft = 0
    private var walkPhase: CGFloat = 0
    private var lastStep = 0
    private var facing: CGFloat = 1
    private var clock: CGFloat = 0
    private var blinkTimer: CGFloat = 3
    private var walkSpeed: CGFloat = 70

    private let rig = SKNode()
    private let shadowSprite = Art.sprite(Tex.shadow, 120, 26, at: CGPoint(x: 0, y: 3))
    private let legL = SKNode()
    private let legR = SKNode()
    private let armBack = SKNode()
    private let armFront = SKNode()
    private let headNode = SKNode()
    private let eyes = SKNode()
    private let smile = SKNode()
    private let grin = SKNode()
    private let held = Art.sprite(Tex.snowball, 20, 20, at: CGPoint(x: 0, y: -50))
    private let brows = SKNode()

    var isAway: Bool { beat == .away }
    /// In a snowball fight with her right now.
    private(set) var fighting = false
    private var foughtThisVisit = false
    /// Sneak peek: start a fight the moment he arrives.
    var fightOnArrival = false
    /// Her birthday: he brings a cake instead of causing trouble.
    var birthdayVisit = false
    private var hideX: CGFloat = 0
    private let cake = SKNode()

    init(host: SnowScene) {
        self.host = host
        super.init()
        shadowSprite.zPosition = -1
        addChild(shadowSprite)
        addChild(rig)
        build()
        let cakeArt = ItemArt.decor(.birthdayCake)
        cakeArt.setScale(0.75)
        cake.addChild(cakeArt)
        cake.position = CGPoint(x: 44, y: 66)
        cake.zPosition = 5.5
        cake.isHidden = true
        rig.addChild(cake)
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - drawing

    private func fur(_ size: CGFloat, at p: CGPoint, z: CGFloat = 0, into parent: SKNode) {
        let s = Art.sprite(Tex.fluff, size, size, at: p)
        s.zPosition = z
        parent.addChild(s)
    }

    private func makeArm(_ arm: SKNode) {
        fur(30, at: CGPoint(x: 0, y: -4), into: arm)
        fur(28, at: CGPoint(x: 0, y: -19), z: 0.1, into: arm)
        fur(29, at: CGPoint(x: 0, y: -34), z: 0.2, into: arm)
        let paw = Art.ellipse(22, 19, Palette.yetiSkin, at: CGPoint(x: 1, y: -48))
        paw.strokeColor = Palette.yetiSkinDark
        paw.lineWidth = 1.2
        paw.zPosition = 0.3
        arm.addChild(paw)
    }

    private func build() {
        // Legs and big pale-blue feet.
        for (leg, x) in [(legL, CGFloat(-14)), (legR, CGFloat(14))] {
            leg.position = CGPoint(x: x, y: 22)
            fur(40, at: .zero, into: leg)
            let foot = Art.ellipse(32, 14, Palette.yetiSkin, at: CGPoint(x: 5, y: -15))
            foot.strokeColor = Palette.yetiSkinDark
            foot.lineWidth = 1.2
            foot.zPosition = 0.2
            leg.addChild(foot)
            leg.zPosition = 1
            rig.addChild(leg)
        }

        armBack.position = CGPoint(x: -24, y: 88)
        armBack.zPosition = 0.5
        makeArm(armBack)
        rig.addChild(armBack)

        let torso = SKNode()
        torso.zPosition = 2
        fur(98, at: CGPoint(x: 0, y: 62), into: torso)
        fur(64, at: CGPoint(x: -14, y: 86), z: 0.1, into: torso)
        fur(64, at: CGPoint(x: 14, y: 86), z: 0.1, into: torso)
        rig.addChild(torso)

        // His blue scarf (the snowman's is red, so you can tell them apart).
        let wrap = CGMutablePath()
        wrap.addArc(center: CGPoint(x: 4, y: 132), radius: 46,
                    startAngle: .pi * 1.32, endAngle: .pi * 1.68, clockwise: false)
        let scarf = Art.line(wrap, Palette.yetiScarf, width: 11)
        scarf.zPosition = 3
        rig.addChild(scarf)
        let stripes = Art.line(wrap.copy(dashingWithPhase: 0, lengths: [5, 8]),
                                 Palette.mix(Palette.yetiScarf, .white, 0.55), width: 11, round: false)
        stripes.zPosition = 3.1
        rig.addChild(stripes)

        // Head.
        headNode.position = CGPoint(x: 4, y: 118)
        headNode.zPosition = 4
        fur(78, at: .zero, into: headNode)
        fur(28, at: CGPoint(x: -18, y: 32), z: -0.1, into: headNode)
        fur(30, at: CGPoint(x: 2, y: 38), z: -0.1, into: headNode)
        fur(26, at: CGPoint(x: 21, y: 30), z: -0.1, into: headNode)
        let face = Art.ellipse(48, 37, Palette.yetiSkin, at: CGPoint(x: 8, y: -4))
        face.strokeColor = Palette.yetiSkinDark
        face.lineWidth = 1
        face.zPosition = 0.2
        headNode.addChild(face)

        eyes.position = CGPoint(x: 8, y: 2)
        eyes.zPosition = 0.4
        for x: CGFloat in [-8, 8] {
            let e = Art.ellipse(7, 9, Palette.coal, at: CGPoint(x: x, y: 0))
            e.addChild(Art.circle(1.3, .white, at: CGPoint(x: 1.2, y: 1.8)))
            eyes.addChild(e)
        }
        headNode.addChild(eyes)

        brows.position = CGPoint(x: 8, y: 11)
        brows.zPosition = 0.45
        for x: CGFloat in [-9, 9] {
            let b = Art.ellipse(15, 6, .white, at: CGPoint(x: x, y: 0))
            b.strokeColor = Palette.yetiSkinDark
            b.lineWidth = 0.8
            b.zRotation = x < 0 ? 0.28 : -0.28
            brows.addChild(b)
        }
        headNode.addChild(brows)

        headNode.addChild({
            let n = Art.ellipse(9, 6, Palette.yetiSkinDark, at: CGPoint(x: 9, y: -5))
            n.zPosition = 0.5
            return n
        }())

        let smilePath = CGMutablePath()
        smilePath.addArc(center: CGPoint(x: 8, y: -7), radius: 8,
                         startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
        smile.addChild(Art.line(smilePath, Palette.coal, width: 2))
        smile.zPosition = 0.5
        headNode.addChild(smile)

        let grinPath = CGMutablePath()
        grinPath.move(to: CGPoint(x: -3, y: -9))
        grinPath.addLine(to: CGPoint(x: 19, y: -9))
        grinPath.addArc(center: CGPoint(x: 8, y: -9), radius: 11, startAngle: 0, endAngle: .pi, clockwise: true)
        grinPath.closeSubpath()
        grin.addChild(Art.fill(grinPath, Palette.c(0.22, 0.12, 0.22)))
        grin.addChild(Art.ellipse(11, 6, Palette.c(0.95, 0.45, 0.55), at: CGPoint(x: 8, y: -17)))
        grin.addChild(Art.fill(Art.rect(1, -12, 14, 3, radius: 1), .white))
        grin.zPosition = 0.5
        grin.isHidden = true
        headNode.addChild(grin)
        rig.addChild(headNode)

        armFront.position = CGPoint(x: 26, y: 88)
        armFront.zPosition = 6
        makeArm(armFront)
        held.zPosition = 0.4
        held.isHidden = true
        armFront.addChild(held)
        rig.addChild(armFront)
    }

    // MARK: - control

    func summon() {
        if beat == .away { awayTimer = 0.3 }
    }

    /// Hiding behind a snowman, he can't be hit (the snowman takes it).
    func hit(_ p: CGPoint) -> Bool {
        guard !isHidden, beat != .away, beat != .bonked, beat != .cower, beat != .hide else { return false }
        return abs(p.x - position.x) < 52 && p.y > position.y - 6 && p.y < position.y + 172
    }

    /// She got him with a snowball. The first hit of a visit starts a
    /// snowball fight; hits during the fight score; after that he runs.
    func bonk() {
        guard beat != .away, beat != .bonked else { return }
        SnowProgress.shared.bump(.yetiHits)
        if fighting {
            held.isHidden = true
            host?.yetiWasHit()
            host?.burst(at: CGPoint(x: position.x, y: position.y + 120), count: 16, spread: 170)
            setBeat(.ouch)
            return
        }
        if beat != .walkOut && beat != .giveCake && !foughtThisVisit, host?.startFight() == true {
            fighting = true
            foughtThisVisit = true
            held.isHidden = true
            host?.burst(at: CGPoint(x: position.x, y: position.y + 120), count: 16, spread: 170)
            host?.say("Oh, it's ON!", at: CGPoint(x: position.x + 20, y: position.y + 182))
            setBeat(.ouch)
            return
        }
        held.isHidden = true
        setBeat(.bonked)
        host?.burst(at: CGPoint(x: position.x, y: position.y + 120), count: 22, spread: 200)
        host?.say(["Eep!", "No fair!", "You got me!"].randomElement() ?? "Eep!",
                  at: CGPoint(x: position.x + 20, y: position.y + 182))
    }

    /// The scene calls this when the fight's time is up.
    func endFight() {
        guard fighting else { return }
        fighting = false
        held.isHidden = true
        setBeat(.wave)
    }

    private func setBeat(_ b: Beat) {
        beat = b
        beatT = 0
    }

    private var handInScene: CGPoint {
        guard let host = host else { return position }
        return host.convert(CGPoint(x: 0, y: -50), from: armFront)
    }

    // MARK: - frame

    func update(dt: CGFloat, enabled: Bool, snowmanX: CGFloat?, pointer: CGPoint?) {
        clock += dt
        beatT += dt
        guard enabled || beat != .away else {
            isHidden = true
            return
        }
        if !enabled && beat != .walkOut && beat != .bonked && beat != .away {
            held.isHidden = true
            cake.isHidden = true
            if fighting { fighting = false; host?.forfeitFight() }
            setBeat(.walkOut)
        }

        blinkTimer -= dt
        if blinkTimer <= 0 { blinkTimer = CGFloat.random(in: 2...5) }
        eyes.yScale = blinkTimer < 0.13 ? 0.15 : 1

        var lean: CGFloat = 0
        var crouch: CGFloat = 1
        var bob: CGFloat = 0
        var front: CGFloat = 0
        var back: CGFloat = 0
        var happy = false

        switch beat {
        case .away:
            isHidden = true
            awayTimer -= dt
            if awayTimer <= 0 {
                isHidden = false
                facing = 1
                position.x = -150
                walkSpeed = 70
                foughtThisVisit = false
                cake.isHidden = !birthdayVisit
                setBeat(.walkIn)
            }
            return

        case .walkIn:
            walk(dt, dir: 1)
            bob = abs(sin(walkPhase)) * 5
            front = -sin(walkPhase) * 0.5
            back = sin(walkPhase) * 0.5
            let stopX = (snowmanX ?? (host?.size.width ?? 1000) * 0.6) - 125
            if position.x >= stopX { setBeat(.sneak) }

        case .sneak:
            // Freezes, turns to the camera, sly grin.
            crouch = 0.95 + sin(beatT * 9) * 0.01
            happy = true
            bob = sin(beatT * 9) * 1.2
            if beatT > 1.0 {
                if birthdayVisit {
                    setBeat(.giveCake)
                } else if fightOnArrival, host?.startFight() == true {
                    fightOnArrival = false
                    fighting = true
                    foughtThisVisit = true
                    host?.say("Snowball fight!", at: CGPoint(x: position.x + 20, y: position.y + 182))
                    setBeat(.fightReady)
                } else {
                    setBeat(snowmanX == nil ? .scoop : .windup)
                }
            }

        case .windup:
            let u = min(1, beatT / 0.45)
            lean = 0.17 * easeInOut(u)
            front = -0.5 * u
            back = -0.6 * u
            crouch = 1 - 0.05 * u
            if beatT > 0.45 { setBeat(.shove) }

        case .shove:
            let u = min(1, beatT / 0.12)
            lean = lerp(0.17, -0.2, u)
            front = lerp(-0.5, 1.55, u)
            back = lerp(-0.6, 1.45, u)
            if beatT >= 0.08 && beatT - dt < 0.08 { host?.knockSnowman(fromLeft: true) }
            if beatT > 0.38 { setBeat(.laugh) }

        case .laugh:
            happy = true
            bob = abs(sin(beatT * 16)) * 5
            lean = -0.05 + sin(beatT * 16) * 0.03
            front = 0.3
            back = 0.2
            if beatT > 0.95 {
                throwsLeft = 3
                setBeat(.scoop)
            }

        case .scoop:
            let u = min(1, beatT / 0.3)
            crouch = 1 - 0.12 * sin(.pi * min(1, beatT / 0.55))
            lean = -0.12 * u
            front = 0.55 * u
            if beatT > 0.3 && held.isHidden {
                held.isHidden = false
                host?.burst(at: handInScene, count: 8, spread: 90)
            }
            if beatT > 0.55 {
                if throwsLeft <= 0 { throwsLeft = 3 }
                setBeat(.aim)
            }

        case .aim:
            let u = easeInOut(min(1, beatT / 0.42))
            lean = 0.12 * u
            front = lerp(0.55, 3.7, u)
            back = -0.4 * u
            happy = true
            if beatT > 0.45 { setBeat(.release) }

        case .release:
            let u = min(1, beatT / 0.1)
            lean = lerp(0.12, -0.14, u)
            front = lerp(3.7, 1.25, u)
            back = 0.4
            if !held.isHidden && beatT > 0.04 {
                held.isHidden = true
                host?.throwAtGlass(from: handInScene, target: fighting ? host?.fightThrowTarget() : nil)
                throwsLeft -= 1
            }
            if beatT > 0.3 { setBeat(fighting ? .fightReady : (throwsLeft > 0 ? .scoop : .wave)) }

        case .fightReady:
            happy = true
            bob = abs(sin(beatT * 10)) * 4
            front = 0.4
            back = 0.3
            if beatT > 0.55 + CGFloat(Int(clock * 7) % 5) * 0.12 { setBeat(.scoop) }

        case .ouch:
            lean = 0.26
            crouch = 0.92
            front = 2.2
            back = -0.8
            eyes.yScale = 0.3
            if beatT > 0.5 {
                if Bool.random(), let x = host?.coverX(near: position.x) {
                    hideX = x
                    walkSpeed = 150
                    setBeat(.hide)
                } else {
                    setBeat(.fightReady)
                }
            }

        case .hide:
            let dx = hideX - position.x
            if abs(dx) < 6 {
                setBeat(.cower)
            } else {
                walk(dt, dir: dx > 0 ? 1 : -1)
                bob = abs(sin(walkPhase)) * 6
                front = -sin(walkPhase) * 0.8
                back = sin(walkPhase) * 0.8
            }

        case .cower:
            crouch = 0.68
            bob = sin(beatT * 30) * 0.8
            front = 2.7
            back = 2.5
            if beatT > 1.6 {
                facing = 1
                setBeat(.fightReady)
            }

        case .giveCake:
            front = 1.45
            back = 1.35
            happy = true
            if beatT > 1.3 && !cake.isHidden {
                cake.isHidden = true
                host?.placeCake(x: position.x + 72 * facing)
            }
            if beatT > 2.0 {
                birthdayVisit = false
                host?.say("Happy birthday!", at: CGPoint(x: position.x + 20, y: position.y + 182))
                setBeat(.wave)
            }

        case .wave:
            happy = true
            front = 2.85 + sin(beatT * 12) * 0.35
            bob = sin(beatT * 6) * 1.5
            if beatT > 1.3 {
                walkSpeed = 82
                setBeat(.walkOut)
            }

        case .walkOut, .bonked:
            if beat == .bonked {
                walkSpeed = 240
                happy = false
            }
            walk(dt, dir: -1)
            bob = abs(sin(walkPhase)) * (beat == .bonked ? 9 : 5)
            front = -sin(walkPhase) * (beat == .bonked ? 1.0 : 0.5)
            back = sin(walkPhase) * (beat == .bonked ? 1.0 : 0.5)
            if position.x < -160 {
                isHidden = true
                awayTimer = CGFloat.random(in: 170...330)
                setBeat(.away)
                return
            }
        }

        zPosition = (beat == .hide || beat == .cower) ? 6.5 : 8
        if beat != .walkIn && beat != .walkOut && beat != .bonked && beat != .hide {
            legL.position.y += (22 - legL.position.y) * min(1, 12 * dt)
            legR.position.y += (22 - legR.position.y) * min(1, 12 * dt)
        }

        rig.xScale = facing
        rig.zRotation = lean * facing
        rig.yScale = crouch
        rig.position.y = bob
        armFront.zRotation += (front - armFront.zRotation) * min(1, (beat == .release || beat == .shove ? 40 : 14) * dt)
        armBack.zRotation += (back - armBack.zRotation) * min(1, 14 * dt)
        smile.isHidden = happy
        grin.isHidden = !happy
        brows.position.y = happy ? 13 : 11

        // Eyes look at you (the camera) while scheming, otherwise ahead.
        let lookCamera = beat == .sneak || beat == .aim || beat == .wave || beat == .laugh || beat == .fightReady || beat == .giveCake
        var ex: CGFloat = lookCamera ? 0 : 3
        if let p = pointer, beat == .walkIn {
            ex = clamp((p.x - position.x) / 300, -3, 3) * facing
        }
        eyes.position.x += ((8 + ex) - eyes.position.x) * min(1, 8 * dt)
    }

    private func walk(_ dt: CGFloat, dir: CGFloat) {
        facing = dir
        position.x += walkSpeed * dir * dt
        walkPhase += dt * walkSpeed / 10
        legL.position.y = 22 + max(0, sin(walkPhase)) * 8
        legR.position.y = 22 + max(0, -sin(walkPhase)) * 8
        let step = Int(walkPhase / .pi)
        if step != lastStep {
            lastStep = step
            let foot: CGFloat = step % 2 == 0 ? -14 : 14
            host?.addFootprint(x: position.x + (foot + 6) * facing)
        }
    }
}
