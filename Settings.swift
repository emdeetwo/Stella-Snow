import SwiftUI
import AppKit
import ServiceManagement

/// Shared settings. Plain @Published properties saved to UserDefaults by
/// hand: @AppStorage inside an ObservableObject does not publish changes,
/// which left the old menu's sliders and labels stuck.
final class SnowSettings: ObservableObject {
    static let shared = SnowSettings()
    private let d = UserDefaults.standard

    @Published var name: String { didSet { d.set(name, forKey: "name") } }
    @Published var snowfall: Double { didSet { d.set(snowfall, forKey: "snowfall") } }
    @Published var wind: Double { didSet { d.set(wind, forKey: "wind") } }
    @Published var flakeSize: Double { didSet { d.set(flakeSize, forKey: "flakeSize") } }
    @Published var showSnowman: Bool { didSet { d.set(showSnowman, forKey: "showSnowman") } }
    @Published var yetiEnabled: Bool { didSet { d.set(yetiEnabled, forKey: "yetiEnabled") } }
    @Published var clickSnowballs: Bool { didSet { d.set(clickSnowballs, forKey: "clickSnowballs") } }
    @Published var houseWallpaper: Bool {
        didSet {
            d.set(houseWallpaper, forKey: "houseWallpaper")
            if houseWallpaper != oldValue { HouseWallpaper.apply(houseWallpaper) }
        }
    }
    /// The looping video of the house, playing behind the desktop icons.
    @Published var animatedHouse: Bool { didSet { d.set(animatedHouse, forKey: "animatedHouse") } }
    /// Not saved: a fresh launch always starts snowing.
    @Published var paused = false

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "" : n
    }

    init() {
        d.register(defaults: [
            "name": "Stella",
            "snowfall": 260.0,
            "wind": 1.0,
            "flakeSize": 1.0,
            "showSnowman": true,
            "yetiEnabled": true,
            "clickSnowballs": true,
            "houseWallpaper": true,
            "animatedHouse": true,
        ])
        name = d.string(forKey: "name") ?? "Stella"
        snowfall = d.double(forKey: "snowfall")
        wind = d.double(forKey: "wind")
        flakeSize = d.double(forKey: "flakeSize")
        showSnowman = d.bool(forKey: "showSnowman")
        yetiEnabled = d.bool(forKey: "yetiEnabled")
        clickSnowballs = d.bool(forKey: "clickSnowballs")
        houseWallpaper = d.bool(forKey: "houseWallpaper")
        animatedHouse = d.bool(forKey: "animatedHouse")
    }
}

/// Tiny bridge so the menu bar popover can poke the live scene.
final class SnowController {
    static let shared = SnowController()
    weak var scene: SnowScene?

    func plough() { scene?.startPlough() }
    func summonYeti() { scene?.summonYeti() }
    func starterBall() { scene?.spawnStarterBall() }
    func blizzard() { scene?.startBlizzard() }
}

/// The house picture (the video's first frame) becomes the real macOS
/// wallpaper on every display, so the Mac still looks right when the app is
/// quit. Switching it off puts back whatever was there before.
enum HouseWallpaper {
    private static let previousKey = "previousWallpapers"

    /// The bundled picture is copied out of the app first, so the wallpaper
    /// survives the app being moved or deleted.
    private static func houseURL() -> URL? {
        let fm = FileManager.default
        guard let src = Bundle.main.url(forResource: "Wallpaper", withExtension: "jpg"),
              let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("StellaSnow", isDirectory: true)
        let dst = dir.appendingPathComponent("House.jpg")
        if !fm.fileExists(atPath: dst.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? fm.copyItem(at: src, to: dst)
        }
        return fm.fileExists(atPath: dst.path) ? dst : nil
    }

    static func apply(_ on: Bool) {
        let ws = NSWorkspace.shared
        let d = UserDefaults.standard
        if on {
            guard let house = houseURL() else { return }
            var previous: [String] = []
            for screen in NSScreen.screens {
                let current = ws.desktopImageURL(for: screen)
                if let current = current, current.lastPathComponent != "House.jpg" {
                    previous.append(current.absoluteString)
                } else {
                    previous.append("")
                }
                let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                    .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
                    .allowClipping: NSNumber(value: true),
                ]
                try? ws.setDesktopImageURL(house, for: screen, options: options)
            }
            if previous.contains(where: { !$0.isEmpty }) { d.set(previous, forKey: previousKey) }
        } else {
            let previous = d.stringArray(forKey: previousKey) ?? []
            for (i, screen) in NSScreen.screens.enumerated() {
                guard i < previous.count, let url = URL(string: previous[i]), !previous[i].isEmpty else { continue }
                try? ws.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }
}

/// "Open at login", the modern way (macOS 13+), no manual System Settings trip.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }
}
