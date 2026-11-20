import AppKit
import SpriteKit
import AVFoundation

/// Borderless, transparent panel that sits just above the desktop icons and
/// below every app window.
///
/// The first version sat BELOW the Finder's desktop-icon layer, so Finder
/// swallowed every click and none of the snow play worked. This one sits
/// above the icons but lets clicks fall straight through to the desktop,
/// except at the exact spots where there is something to grab (the
/// snowman, the yeti, a snowball, the snow on the ground, a splat). The
/// scene flips that on and off every frame as the pointer moves.
///
/// It is a non-activating panel, so playing with the snow never steals focus
/// from whatever app is in front.
final class OverlayPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isFloatingPanel = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SpriteKit view that takes the very first click even though the app is
/// in the background, so a single click grabs a snowball.
final class SnowView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The animated house: a looping video in a window that sits just above the
/// real wallpaper and below the desktop icons, so the icons still show and
/// still click. macOS has no public way to make a video the real wallpaper;
/// this is how wallpaper apps do it. Hardware video decoding keeps it cheap.
final class BackdropWindow: NSWindow {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init?(frame: NSRect) {
        guard let url = Bundle.main.url(forResource: "HouseLoop", withExtension: "mp4") else { return nil }
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        contentView = view

        player.isMuted = true
        // Without this the Mac would never let the screen go to sleep.
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setPlaying(_ on: Bool) {
        if on { player.play() } else { player.pause() }
    }
}
