import SwiftUI
import AppKit

/// The menu bar popover.
struct ControlsView: View {
    @EnvironmentObject var settings: SnowSettings
    @State private var loginOn = LoginItem.isEnabled
    @State private var loginFailed = false
    @State private var showHelp = false

    private var title: String {
        settings.displayName.isEmpty ? "Snow Day" : "\(settings.displayName)'s Snow"
    }

    private var snowWord: String {
        if settings.paused { return "Paused" }
        switch settings.snowfall {
        case ..<1: return "No snow right now"
        case ..<140: return "Light snow"
        case ..<340: return "Steady snow"
        default: return "Blizzard!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            MenuSection("Weather") {
                SliderRow(icon: "cloud.snow", title: "Snowfall", value: $settings.snowfall, range: 0...600, step: 10,
                          note: settings.snowfall < 1 ? "off" : settings.snowfall < 140 ? "light"
                              : settings.snowfall < 340 ? "steady" : "blizzard")
                SliderRow(icon: "wind", title: "Wind", value: $settings.wind, range: 0...2.5, step: 0.05,
                          note: settings.wind < 0.05 ? "calm" : settings.wind < 0.8 ? "breeze"
                              : settings.wind < 1.6 ? "windy" : "gale")
                SliderRow(icon: "sparkles", title: "Flake size", value: $settings.flakeSize, range: 0.6...1.8, step: 0.05,
                          note: settings.flakeSize < 0.85 ? "tiny" : settings.flakeSize < 1.25 ? "normal" : "big")
                ActionButton(icon: "cloud.snow.fill", title: "Let it snow!") { SnowController.shared.blizzard() }
            }

            MenuSection("Play") {
                HStack(spacing: 8) {
                    ActionButton(icon: "circle.fill", title: "Snowball") { SnowController.shared.starterBall() }
                    ActionButton(icon: "car.fill", title: "Snowplough") { SnowController.shared.plough() }
                }
                SwitchRow(icon: "hand.tap", title: "Click the desktop to throw", isOn: $settings.clickSnowballs)
            }

            MenuSection("Friends") {
                SwitchRow(icon: "face.smiling", title: "Snowman", isOn: $settings.showSnowman)
                HStack {
                    SwitchRow(icon: "pawprint", title: "Yeti visits", isOn: $settings.yetiEnabled)
                    Button("Call him") { SnowController.shared.summonYeti() }
                        .controlSize(.small)
                        .disabled(!settings.yetiEnabled)
                }
            }

            MenuSection("This Mac") {
                SwitchRow(icon: "play.rectangle", title: "Animated house", isOn: $settings.animatedHouse)
                SwitchRow(icon: "photo", title: "House wallpaper", isOn: $settings.houseWallpaper)
                SwitchRow(icon: "power", title: "Open at login", isOn: Binding(
                    get: { loginOn },
                    set: { on in
                        if LoginItem.set(on) {
                            loginOn = on
                            loginFailed = false
                        } else {
                            loginOn = LoginItem.isEnabled
                            loginFailed = true
                        }
                    }))
                if loginFailed {
                    Text("macOS said no. Add Stella's Snow in System Settings, General, Login Items.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                    Text("Snowman says hi to")
                    TextField("Name", text: $settings.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 110)
                }
            }

            DisclosureGroup(isExpanded: $showHelp) {
                VStack(alignment: .leading, spacing: 5) {
                    HelpLine("Press on the snow at the bottom and drag to roll a snowball. It grows where there's snow.")
                    HelpLine("Drop one snowball on another to stack. Three makes a snowman, and he stays.")
                    HelpLine("Drag a snowman off the edge of the screen to say goodbye.")
                    HelpLine("Click the snowman to say hi. Click him three times fast.")
                    HelpLine("Snow piles up on your windows. Close one and watch.")
                    HelpLine("Click the yeti to get him back. Click a splat to wipe it off.")
                }
                .padding(.top, 6)
            } label: {
                Label("How to play", systemImage: "questionmark.circle").font(.callout)
            }

            Divider()
            HStack {
                Button(settings.paused ? "Resume" : "Pause") { settings.paused.toggle() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
        .padding(16)
        .toggleStyle(.switch)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.14, green: 0.25, blue: 0.55),
                                                      Color(red: 0.36, green: 0.62, blue: 0.94)],
                                             startPoint: .bottomLeading, endPoint: .topTrailing))
                Image(systemName: "snowflake")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                Text(snowWord).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                settings.paused.toggle()
            } label: {
                Image(systemName: settings.paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(settings.paused ? "Resume" : "Pause")
        }
    }
}

private struct MenuSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(.secondary)
                Text(title)
                Spacer()
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .padding(.leading, 26)
        }
    }
}

private struct SwitchRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .controlSize(.mini)
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

private struct HelpLine: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
