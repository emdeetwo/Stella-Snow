import AppKit

/// One window that snow can pile on, in Cocoa coordinates (origin at the
/// bottom-left of the main display, y going up), same as the overlay.
struct TrackedWindow {
    let id: Int
    let frame: CGRect
    let isDock: Bool
}

/// Reads window frames from the window server. Frames only, never pixels,
/// so no Screen Recording permission is needed.
///
/// The window server reports bounds with the origin at the TOP-left of the
/// main display and y going DOWN. The first version treated them as Cocoa
/// coordinates, which put every pile of snow at the wrong height. Everything
/// is flipped here, in one place.
enum WindowTracker {
    private static let myPID = Int(ProcessInfo.processInfo.processIdentifier)
    private static let dockLevel = Int(CGWindowLevelForKey(.dockWindow))

    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
    }

    private static func cocoaRect(_ quartz: CGRect) -> CGRect {
        CGRect(x: quartz.minX, y: primaryHeight - quartz.maxY, width: quartz.width, height: quartz.height)
    }

    private static func list() -> [[String: Any]] {
        (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]) ?? []
    }

    private static func bounds(_ dict: [String: Any]) -> CGRect? {
        guard let raw = dict[kCGWindowBounds as String] else { return nil }
        if let b = raw as? CGRect { return b }
        if let b = raw as? [String: Any] { return CGRect(dictionaryRepresentation: b as CFDictionary) }
        return nil
    }

    /// Normal app windows, front to back. (The Dock is found by dockFrame.)
    static func snapshot() -> [TrackedWindow] {
        var out: [TrackedWindow] = []
        for dict in list() {
            guard let id = dict[kCGWindowNumber as String] as? Int,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int,
                  pid != myPID,
                  let b = bounds(dict) else { continue }
            let alpha = (dict[kCGWindowAlpha as String] as? Double) ?? 1
            guard alpha > 0.05 else { continue }
            if layer == 0 && b.width >= 120 && b.height >= 60 {
                out.append(TrackedWindow(id: id, frame: cocoaRect(b), isDock: false))
            }
            if out.count >= 40 { break }
        }
        return out
    }

    /// The Dock's bar on the main display, in Cocoa coordinates, or nil when
    /// it is hidden or sits on the side of the screen.
    ///
    /// Its height comes from the screen's visible area (exact). Its width is
    /// read from a Dock window when one looks like the bar itself; on recent
    /// macOS the Dock's window covers the whole screen instead, so the width
    /// is worked out from the Dock's own settings: icon size, pinned apps,
    /// running apps, recents, folders.
    static func dockFrame() -> CGRect? {
        guard let screen = NSScreen.screens.first else { return nil }
        let f = screen.frame, v = screen.visibleFrame
        let top = v.minY - f.minY
        guard top > 24, v.minX - f.minX < 2, f.maxX - v.maxX < 2 else { return nil }
        for dict in list() {
            guard (dict[kCGWindowOwnerName as String] as? String) == "Dock",
                  (dict[kCGWindowLayer as String] as? Int) == dockLevel,
                  let b = bounds(dict) else { continue }
            let c = cocoaRect(b)
            if c.width > 80 && c.width < f.width * 0.97 && c.height < 300 && c.minY <= f.minY + 6 {
                return CGRect(x: c.minX + 4, y: f.minY, width: c.width - 8, height: top - 3)
            }
        }
        let w = min(f.width - 24, estimatedDockWidth(height: top))
        return CGRect(x: f.midX - w / 2, y: f.minY, width: w, height: top - 3)
    }

    private static func dockPref(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }

    private static func estimatedDockWidth(height: CGFloat) -> CGFloat {
        let tileSize = (dockPref("tilesize") as? Double).map { CGFloat($0) } ?? max(32, height - 22)
        let pinned = (dockPref("persistent-apps") as? [Any]) ?? []
        var pinnedIDs = Set<String>()
        for case let item as [String: Any] in pinned {
            if let tile = item["tile-data"] as? [String: Any], let id = tile["bundle-identifier"] as? String {
                pinnedIDs.insert(id)
            }
        }
        let others = ((dockPref("persistent-others") as? [Any]) ?? []).count
        let running = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier else { return false }
            return id != "com.apple.finder" && !pinnedIDs.contains(id)
        }.count
        let showRecents = (dockPref("show-recents") as? Bool) ?? true
        let recents = min(3, ((dockPref("recent-apps") as? [Any]) ?? []).count)
        let extra = showRecents ? max(running, recents) : running
        let tiles = 1 + pinned.count + extra + others + 1          // Finder ... Trash
        let separators = 1 + (extra > 0 ? 1 : 0)
        // A little under the real width, so snow never hangs past the ends.
        return (CGFloat(tiles) * (tileSize + 6) + CGFloat(separators) * 14 + 14) * 0.97
    }

    /// True when a click at this point landed on the bare desktop (or a
    /// desktop icon), not on an app window, the Dock, or the menu bar.
    ///
    /// The menu bar and Dock are ruled out by the screen's visible area. The
    /// Dock and some system services also own invisible windows stretched
    /// over the whole screen, which would block every click, so full-screen
    /// windows above the normal layer are ignored.
    static func isDesktop(atCocoa p: CGPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { return false }
        if !screen.visibleFrame.contains(p) { return false }
        let screenArea = screen.frame.width * screen.frame.height
        let q = CGPoint(x: p.x, y: primaryHeight - p.y)
        for dict in list() {
            guard let pid = dict[kCGWindowOwnerPID as String] as? Int, pid != myPID,
                  let layer = dict[kCGWindowLayer as String] as? Int, layer >= 0,
                  let b = bounds(dict), b.contains(q) else { continue }
            let alpha = (dict[kCGWindowAlpha as String] as? Double) ?? 1
            if alpha <= 0.05 { continue }
            if layer > 0 && b.width * b.height > screenArea * 0.9 { continue }
            return false
        }
        return true
    }
}
