import Foundation
import AppKit
import Combine

// MARK: - Calendar

/// The dates that matter. Everything special keys off the Mac's own clock.
enum Holiday {
    static let birthdayMonth = 12
    static let birthdayDay = 26

    private static var parts: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
    }
    static var year: Int { parts.year ?? 2026 }
    static var month: Int { parts.month ?? 1 }
    static var day: Int { parts.day ?? 1 }
    static var hour: Int { parts.hour ?? 12 }

    /// Advent days 1...25 that have arrived (catch-up allowed through Dec 31).
    static var adventDaysAvailable: ClosedRange<Int>? {
        guard month == 12 else { return nil }
        return 1...min(day, 25)
    }
    /// Christmas Eve night (and the small hours of Christmas morning).
    static var isSleighTime: Bool {
        (month == 12 && day == 24 && hour >= 17) || (month == 12 && day == 25 && hour < 7)
    }
    static var isNewYearsEve: Bool { month == 12 && day == 31 && hour >= 18 }
    static var isNewYearsMidnight: Bool { month == 1 && day == 1 && hour == 0 }
    static var isBirthday: Bool { month == birthdayMonth && day == birthdayDay }

    static func daysUntil(month m: Int, day d: Int) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = DateComponents(year: year, month: m, day: d)
        guard var target = cal.date(from: comps) else { return 0 }
        if target < today {
            comps.year = year + 1
            target = cal.date(from: comps) ?? target
        }
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// One line for the menu: what's coming up.
    static func countdownLine(name: String) -> String {
        let who = name.isEmpty ? "" : ", \(name)"
        if isBirthday { return "Happy birthday\(who)!" }
        if month == 12 && day == 24 { return "Christmas Eve! Watch the sky tonight." }
        if month == 12 && day == 25 { return "Merry Christmas\(who)!" }
        if month == 12 && day == 31 { return "New Year's Eve! Fireworks tonight." }
        let christmas = daysUntil(month: 12, day: 25)
        if christmas <= 45 { return christmas == 1 ? "1 day until Christmas" : "\(christmas) days until Christmas" }
        let bday = daysUntil(month: birthdayMonth, day: birthdayDay)
        return bday == 1 ? "Birthday tomorrow!" : "\(bday) days until your birthday"
    }
}

// MARK: - Closet items

/// Everything that can be worn by a snowman or set out on the snow.
enum Item: String, Codable, CaseIterable {
    // hats
    case topHat, beanie, earmuffs, santaHat, elfHat, partyHat, crown, antlers, tiara
    // face
    case sunglasses, heartGlasses, starGlasses, roundGlasses, rudolphNose
    // neck
    case bowtieRed, bowtieGreen, bowtieGold, sleighBell
    // things to set out on the snow
    case miniTree, candyCane, gingerbread, lantern, sled, presents, hotCocoa, igloo, snowDog, goldenStar, birthdayCake

    enum Slot { case hat, face, neck, decor }

    var slot: Slot {
        switch self {
        case .topHat, .beanie, .earmuffs, .santaHat, .elfHat, .partyHat, .crown, .antlers, .tiara: return .hat
        case .sunglasses, .heartGlasses, .starGlasses, .roundGlasses, .rudolphNose: return .face
        case .bowtieRed, .bowtieGreen, .bowtieGold, .sleighBell: return .neck
        default: return .decor
        }
    }

    var title: String {
        switch self {
        case .topHat: return "Top hat"
        case .beanie: return "Beanie"
        case .earmuffs: return "Earmuffs"
        case .santaHat: return "Santa hat"
        case .elfHat: return "Elf hat"
        case .partyHat: return "Party hat"
        case .crown: return "Gold crown"
        case .antlers: return "Reindeer antlers"
        case .tiara: return "Sparkly tiara"
        case .sunglasses: return "Cool sunglasses"
        case .heartGlasses: return "Heart glasses"
        case .starGlasses: return "Star glasses"
        case .roundGlasses: return "Round glasses"
        case .rudolphNose: return "Shiny red nose"
        case .bowtieRed: return "Red bow tie"
        case .bowtieGreen: return "Green bow tie"
        case .bowtieGold: return "Gold bow tie"
        case .sleighBell: return "Sleigh bell"
        case .miniTree: return "Little Christmas tree"
        case .candyCane: return "Giant candy cane"
        case .gingerbread: return "Gingerbread friend"
        case .lantern: return "Glowing lantern"
        case .sled: return "Red sled"
        case .presents: return "Stack of presents"
        case .hotCocoa: return "Hot cocoa"
        case .igloo: return "Igloo"
        case .snowDog: return "Snow puppy"
        case .goldenStar: return "Golden star"
        case .birthdayCake: return "Birthday cake"
        }
    }

    /// Hats a snowman can have from the start.
    static let starters: [Item] = [.topHat, .beanie, .earmuffs]

    /// What each day of December unwraps.
    static let advent: [Int: Item] = [
        1: .santaHat, 2: .sunglasses, 3: .miniTree, 4: .bowtieRed, 5: .candyCane,
        6: .heartGlasses, 7: .antlers, 8: .gingerbread, 9: .elfHat, 10: .starGlasses,
        11: .lantern, 12: .crown, 13: .roundGlasses, 14: .sled, 15: .bowtieGreen,
        16: .partyHat, 17: .presents, 18: .bowtieGold, 19: .hotCocoa, 20: .igloo,
        21: .tiara, 22: .snowDog, 23: .rudolphNose, 24: .sleighBell, 25: .goldenStar,
    ]
}

// MARK: - Badges and progress

enum Stat: String, CaseIterable {
    case snowmenBuilt, yetiHits, snowballsThrown, splatsWiped, blizzards, ploughs, sneezes
    case presentsOpened, globes, penguins, cardinals, fightsWon, frostDrawings, outfits
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let stat: Stat
    let goal: Int

    static let all: [Badge] = [
        Badge(id: "firstSnowman", title: "First Snowman", detail: "Build a snowman", symbol: "snowflake", stat: .snowmenBuilt, goal: 1),
        Badge(id: "snowFamily", title: "Snow Family", detail: "Build 5 snowmen", symbol: "person.3.fill", stat: .snowmenBuilt, goal: 5),
        Badge(id: "snowVillage", title: "Snow Village", detail: "Build 15 snowmen", symbol: "house.fill", stat: .snowmenBuilt, goal: 15),
        Badge(id: "yetiHunter", title: "Yeti Hunter", detail: "Hit the yeti", symbol: "scope", stat: .yetiHits, goal: 1),
        Badge(id: "yetiBoss", title: "Yeti Boss", detail: "Hit the yeti 25 times", symbol: "bolt.fill", stat: .yetiHits, goal: 25),
        Badge(id: "fightWinner", title: "Snowball Champion", detail: "Win a snowball fight", symbol: "trophy.fill", stat: .fightsWon, goal: 1),
        Badge(id: "bigArm", title: "Big Arm", detail: "Throw 100 snowballs", symbol: "figure.softball", stat: .snowballsThrown, goal: 100),
        Badge(id: "windowWasher", title: "Window Washer", detail: "Wipe 10 splats", symbol: "hand.raised.fill", stat: .splatsWiped, goal: 10),
        Badge(id: "blizzardMaker", title: "Blizzard Maker", detail: "Make it snow 3 times", symbol: "cloud.snow.fill", stat: .blizzards, goal: 3),
        Badge(id: "ploughDriver", title: "Plough Driver", detail: "Drive the plough 3 times", symbol: "car.fill", stat: .ploughs, goal: 3),
        Badge(id: "blessYou", title: "Bless You!", detail: "Make the snowman sneeze 3 times", symbol: "wind", stat: .sneezes, goal: 3),
        Badge(id: "giftOpener", title: "Gift Opener", detail: "Open a present", symbol: "gift.fill", stat: .presentsOpened, goal: 1),
        Badge(id: "allGifts", title: "All 25 Gifts", detail: "Open every December present", symbol: "star.fill", stat: .presentsOpened, goal: 25),
        Badge(id: "snowGlobe", title: "Snow Globe", detail: "Shake up a snow globe", symbol: "globe.americas.fill", stat: .globes, goal: 1),
        Badge(id: "penguinPal", title: "Penguin Pal", detail: "See the penguin slide 3 times", symbol: "figure.skiing.downhill", stat: .penguins, goal: 3),
        Badge(id: "birdWatcher", title: "Bird Watcher", detail: "Spot the cardinal 3 times", symbol: "bird.fill", stat: .cardinals, goal: 3),
        Badge(id: "frostArtist", title: "Frost Artist", detail: "Draw in the frost", symbol: "paintbrush.pointed.fill", stat: .frostDrawings, goal: 1),
        Badge(id: "fashionista", title: "Snow Stylist", detail: "Dress up a snowman 10 times", symbol: "tshirt.fill", stat: .outfits, goal: 10),
    ]
}

/// Saved progress: stats, badges earned, presents opened, closet contents.
final class SnowProgress: ObservableObject {
    static let shared = SnowProgress()
    private let d = UserDefaults.standard

    @Published private(set) var counts: [String: Int]
    @Published private(set) var earned: Set<String>
    @Published private(set) var unlocked: [Item]
    @Published private(set) var openedDays: Set<Int>

    /// The scene listens here to celebrate a new badge.
    var onBadge: ((Badge) -> Void)?

    private var openedKey: String { "openedDays-\(Holiday.year)" }

    init() {
        counts = (d.dictionary(forKey: "stats") as? [String: Int]) ?? [:]
        earned = Set(d.stringArray(forKey: "badges") ?? [])
        let saved = (d.stringArray(forKey: "closet") ?? []).compactMap { Item(rawValue: $0) }
        unlocked = saved.isEmpty ? Item.starters : saved
        openedDays = Set((d.array(forKey: "openedDays-\(Holiday.year)") as? [Int]) ?? [])
    }

    func count(_ s: Stat) -> Int { counts[s.rawValue] ?? 0 }

    func bump(_ s: Stat, by n: Int = 1) {
        counts[s.rawValue, default: 0] += n
        d.set(counts, forKey: "stats")
        for b in Badge.all where b.stat == s && !earned.contains(b.id) && count(s) >= b.goal {
            earned.insert(b.id)
            d.set(Array(earned), forKey: "badges")
            onBadge?(b)
        }
    }

    func unlock(_ item: Item) {
        guard !unlocked.contains(item) else { return }
        unlocked.append(item)
        d.set(unlocked.map { $0.rawValue }, forKey: "closet")
    }

    /// Opens one December day's present. Returns what was inside.
    @discardableResult
    func open(day: Int) -> Item? {
        guard let item = Item.advent[day], !openedDays.contains(day) else { return nil }
        openedDays.insert(day)
        d.set(Array(openedDays), forKey: openedKey)
        unlock(item)
        bump(.presentsOpened)
        return item
    }

    var unopenedDays: [Int] {
        guard let days = Holiday.adventDaysAvailable else { return [] }
        return days.filter { !openedDays.contains($0) }
    }
}
