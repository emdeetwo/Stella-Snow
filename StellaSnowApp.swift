import SwiftUI
import AppKit
import SpriteKit
import Combine

@main
struct StellaSnowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var settings = SnowSettings.shared

    var body: some Scene {
        MenuBarExtra("Stella's Snow", systemImage: "snowflake") {
            ControlsView()
                .environmentObject(settings)
                .frame(width: 300)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var backdrop: BackdropWindow?
    private var view: SnowView?
    private var scene: SnowScene?
    private var clickMonitor: Any?
    private var bag = Set<AnyCancellable>()
    private var occluded = false
    private var asleep = false

    /// The display with the menu bar. NSScreen.main is the screen with the
    /// key window, which for a menu bar app can be any of them.
    private static func primaryFrame() -> CGRect {
        (NSScreen.screens.first ?? NSScreen.main)?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SnowSettings.shared
        let frame = Self.primaryFrame()

        let scene = SnowScene(size: frame.size, settings: settings)
        scene.scaleMode = .resizeFill
        scene.screenFrame = frame

        let view = SnowView(frame: NSRect(origin: .zero, size: frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)

        // The animated house goes in first, underneath everything.
        let backdrop = BackdropWindow(frame: frame)
        backdrop?.orderFrontRegardless()
        self.backdrop = backdrop

        let panel = OverlayPanel(frame: frame)
        panel.contentView = view
        panel.orderFrontRegardless()
        scene.overlay = panel

        self.scene = scene
        self.view = view
        self.panel = panel
        SnowController.shared.scene = scene

        // Desktop clicks pass through the overlay, so watch for them here.
        // Mouse clicks need no Accessibility permission (only keys would).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.scene?.desktopClick(global: NSEvent.mouseLocation)
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Nothing visible (a full-screen app, a maximized window): stop
        // drawing entirely. Big battery saver on a MacBook Air.
        nc.addObserver(self, selector: #selector(occlusionChanged),
                       name: NSWindow.didChangeOcclusionStateNotification, object: panel)
        nc.addObserver(self, selector: #selector(powerChanged),
                       name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(didSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(didSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        wnc.addObserver(self, selector: #selector(didWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        settings.$paused
            .receive(on: RunLoop.main)
            .sink { [weak self] paused in self?.refreshRunning(userPaused: paused) }
            .store(in: &bag)
        settings.$animatedHouse
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshRunning(userPaused: SnowSettings.shared.paused) }
            .store(in: &bag)

        applyPower()
        refreshRunning(userPaused: settings.paused)

        // First launch: put up the house wallpaper (switching it off in the
        // menu restores the old one).
        let d = UserDefaults.standard
        if settings.houseWallpaper && !d.bool(forKey: "houseApplied") {
            HouseWallpaper.apply(true)
            d.set(true, forKey: "houseApplied")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
    }

    @objc private func screensChanged() {
        let frame = Self.primaryFrame()
        panel?.setFrame(frame, display: true)
        backdrop?.setFrame(frame, display: true)
        view?.frame = NSRect(origin: .zero, size: frame.size)
        scene?.screenFrame = frame
        scene?.size = frame.size
    }

    @objc private func occlusionChanged() {
        guard let panel = panel else { return }
        occluded = !panel.occlusionState.contains(.visible)
        refreshRunning(userPaused: SnowSettings.shared.paused)
    }

    @objc private func didSleep() {
        asleep = true
        refreshRunning(userPaused: SnowSettings.shared.paused)
    }

    @objc private func didWake() {
        asleep = false
        refreshRunning(userPaused: SnowSettings.shared.paused)
    }

    @objc private func powerChanged() {
        DispatchQueue.main.async { self.applyPower() }
    }

    private func applyPower() {
        let low = ProcessInfo.processInfo.isLowPowerModeEnabled
        scene?.powerScale = low ? 0.5 : 1
        view?.preferredFramesPerSecond = low ? 30 : 60
    }

    private func refreshRunning(userPaused: Bool) {
        let run = !userPaused && !occluded && !asleep
        view?.isPaused = !run
        if !run { scene?.releaseMouse() }
        let showHouse = SnowSettings.shared.animatedHouse
        if showHouse { backdrop?.orderFrontRegardless() } else { backdrop?.orderOut(nil) }
        backdrop?.setPlaying(run && showHouse)
    }
}
