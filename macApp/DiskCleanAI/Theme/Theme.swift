import SwiftUI

/// Identifier of every built-in theme. `system` follows the macOS appearance and
/// resolves to `daylight` or `midnight`.
enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case system, daylight, midnight, graphite, nord, solar, dusk, ocean, forest, sakura

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Match System"
        case .daylight: return "Daylight"
        case .midnight: return "Midnight"
        case .graphite: return "Graphite"
        case .nord: return "Nord"
        case .solar: return "Solar"
        case .dusk: return "Dusk"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sakura: return "Sakura"
        }
    }
}

/// A complete colour system for the app. Every view reads colours from the theme
/// in the environment instead of hard-coding them, so switching themes restyles
/// the whole window, including the sunburst and every chart.
struct Theme: Identifiable, Hashable {
    let id: ThemeID
    let name: String
    let tagline: String
    let isDark: Bool

    /// Window ground.
    let background: Color
    /// Sidebar and secondary panels.
    let surface: Color
    /// Cards that float on the ground.
    let card: Color
    /// Hairlines and dividers.
    let line: Color
    /// Primary text.
    let ink: Color
    /// Body copy.
    let body: Color
    /// Captions and secondary labels.
    let muted: Color
    /// Accent.
    let brand: Color
    let brandDeep: Color
    let brandSoft: Color
    /// Eight chart colours: video, photos, audio, documents, apps, archives, developer, caches.
    let chart: [Color]
    let success: Color
    let warning: Color
    let danger: Color

    var colorScheme: ColorScheme { isDark ? .dark : .light }

    func chartColor(_ index: Int) -> Color {
        let n = chart.count
        return chart[((index % n) + n) % n]
    }

    func color(for category: FileCategory) -> Color {
        category == .other ? muted : chartColor(category.chartIndex)
    }

    /// Card shadow only makes sense on light grounds.
    var cardShadow: Color { isDark ? .clear : Color.black.opacity(0.06) }
}

extension Theme {
    init(id: ThemeID, name: String, tagline: String, isDark: Bool,
         background: UInt32, surface: UInt32, card: UInt32, line: UInt32,
         ink: UInt32, body: UInt32, muted: UInt32,
         brand: UInt32, brandDeep: UInt32, brandSoft: UInt32,
         chart: [UInt32], success: UInt32, warning: UInt32, danger: UInt32) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.isDark = isDark
        self.background = Color(hex: background)
        self.surface = Color(hex: surface)
        self.card = Color(hex: card)
        self.line = Color(hex: line)
        self.ink = Color(hex: ink)
        self.body = Color(hex: body)
        self.muted = Color(hex: muted)
        self.brand = Color(hex: brand)
        self.brandDeep = Color(hex: brandDeep)
        self.brandSoft = Color(hex: brandSoft)
        self.chart = chart.map { Color(hex: $0) }
        self.success = Color(hex: success)
        self.warning = Color(hex: warning)
        self.danger = Color(hex: danger)
    }

    // MARK: Built-in themes

    /// The landing-page palette: white ground, near-black ink, one blue.
    static let daylight = Theme(
        id: .daylight, name: "Daylight", tagline: "White ground, near-black ink, one blue.", isDark: false,
        background: 0xFFFFFF, surface: 0xF6F7FB, card: 0xFFFFFF, line: 0xE7E8EE,
        ink: 0x0B0B0F, body: 0x55565F, muted: 0x8B8D98,
        brand: 0x2563EB, brandDeep: 0x1D4ED8, brandSoft: 0xEEF3FF,
        chart: [0x2F6BFF, 0x8B5CF6, 0x22B8E6, 0x14B8A6, 0xFB8A3C, 0xFF6B8A, 0xF5B53A, 0x4ADE80],
        success: 0x16A34A, warning: 0xD97706, danger: 0xDC2626)

    static let midnight = Theme(
        id: .midnight, name: "Midnight", tagline: "Deep navy with the same electric blue.", isDark: true,
        background: 0x0B0F1A, surface: 0x111827, card: 0x161E2E, line: 0x243049,
        ink: 0xF3F4F6, body: 0xB7BDCB, muted: 0x7C8496,
        brand: 0x4F82FF, brandDeep: 0x3B6EF5, brandSoft: 0x1A2A4D,
        chart: [0x5B8CFF, 0xA78BFA, 0x38BDF8, 0x2DD4BF, 0xFB923C, 0xFB7185, 0xFBBF24, 0x4ADE80],
        success: 0x34D399, warning: 0xFBBF24, danger: 0xF87171)

    static let graphite = Theme(
        id: .graphite, name: "Graphite", tagline: "Neutral charcoal with a warm amber accent.", isDark: true,
        background: 0x121212, surface: 0x1A1A1A, card: 0x212121, line: 0x303030,
        ink: 0xF2F2F2, body: 0xB5B5B5, muted: 0x7A7A7A,
        brand: 0xF59E0B, brandDeep: 0xD97706, brandSoft: 0x2E2413,
        chart: [0xF59E0B, 0xA3A3A3, 0xFBBF24, 0x737373, 0xFCD34D, 0xD4D4D4, 0xB45309, 0x8A8A8A],
        success: 0x4ADE80, warning: 0xFBBF24, danger: 0xF87171)

    static let nord = Theme(
        id: .nord, name: "Nord", tagline: "The arctic, north-bluish palette.", isDark: true,
        background: 0x2E3440, surface: 0x3B4252, card: 0x434C5E, line: 0x4C566A,
        ink: 0xECEFF4, body: 0xD8DEE9, muted: 0x9AA5B8,
        brand: 0x88C0D0, brandDeep: 0x81A1C1, brandSoft: 0x3E4A5E,
        chart: [0x88C0D0, 0xB48EAD, 0x81A1C1, 0x8FBCBB, 0xD08770, 0xBF616A, 0xEBCB8B, 0xA3BE8C],
        success: 0xA3BE8C, warning: 0xEBCB8B, danger: 0xBF616A)

    static let solar = Theme(
        id: .solar, name: "Solar", tagline: "Solarized light: warm paper and calm accents.", isDark: false,
        background: 0xFDF6E3, surface: 0xEEE8D5, card: 0xFFFCF0, line: 0xE1DBC6,
        ink: 0x073642, body: 0x586E75, muted: 0x93A1A1,
        brand: 0x268BD2, brandDeep: 0x1E6FA8, brandSoft: 0xE3EEF5,
        chart: [0x268BD2, 0x6C71C4, 0x2AA198, 0x859900, 0xCB4B16, 0xD33682, 0xB58900, 0xDC322F],
        success: 0x859900, warning: 0xB58900, danger: 0xDC322F)

    static let dusk = Theme(
        id: .dusk, name: "Dusk", tagline: "Solarized dark: deep teal and soft cream.", isDark: true,
        background: 0x002B36, surface: 0x073642, card: 0x0B3D49, line: 0x1B4E5A,
        ink: 0xFDF6E3, body: 0xCBD3CE, muted: 0x839496,
        brand: 0x2AA198, brandDeep: 0x23887F, brandSoft: 0x0F4A50,
        chart: [0x268BD2, 0x6C71C4, 0x2AA198, 0x859900, 0xCB4B16, 0xD33682, 0xB58900, 0xDC322F],
        success: 0x859900, warning: 0xB58900, danger: 0xDC322F)

    static let ocean = Theme(
        id: .ocean, name: "Ocean", tagline: "Light blue-green ground with a teal accent (default).", isDark: false,
        background: 0xF4FBFB, surface: 0xE6F4F5, card: 0xFFFFFF, line: 0xD3E7E9,
        ink: 0x0F2B33, body: 0x4A6670, muted: 0x7F98A0,
        brand: 0x0E9AA7, brandDeep: 0x0B7F8A, brandSoft: 0xDCF3F5,
        chart: [0x0E9AA7, 0x3A86FF, 0x2EC4B6, 0x8AC926, 0xFF9F1C, 0xFF6B6B, 0xFFCA3A, 0x6A4C93],
        success: 0x2A9D8F, warning: 0xE9A23B, danger: 0xE76F51)

    static let forest = Theme(
        id: .forest, name: "Forest", tagline: "Dark evergreen with a bright leaf accent.", isDark: true,
        background: 0x0E1512, surface: 0x152019, card: 0x1B2A21, line: 0x2A3E31,
        ink: 0xEDF5EF, body: 0xB3C7B8, muted: 0x7E937F,
        brand: 0x4ADE80, brandDeep: 0x22C55E, brandSoft: 0x173225,
        chart: [0x4ADE80, 0x2DD4BF, 0xA3E635, 0x38BDF8, 0xFB923C, 0xF472B6, 0xFACC15, 0xC084FC],
        success: 0x4ADE80, warning: 0xFACC15, danger: 0xFB7185)

    static let sakura = Theme(
        id: .sakura, name: "Sakura", tagline: "Blossom pink on soft white.", isDark: false,
        background: 0xFFF8FA, surface: 0xFDECF1, card: 0xFFFFFF, line: 0xF5D9E1,
        ink: 0x2B1420, body: 0x6B4A57, muted: 0x9E8390,
        brand: 0xE0457B, brandDeep: 0xC7336A, brandSoft: 0xFDE7EE,
        chart: [0xE0457B, 0x9B5DE5, 0xF15BB5, 0x00BBF9, 0xF7B801, 0x00C2A8, 0xFF9F1C, 0x7B8CDE],
        success: 0x22A06B, warning: 0xE39B12, danger: 0xD63B5E)

    static let all: [Theme] = [.ocean, .daylight, .midnight, .graphite, .nord, .solar, .dusk, .forest, .sakura]

    static func named(_ id: ThemeID) -> Theme? {
        all.first { $0.id == id }
    }
}

// MARK: - Environment plumbing

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .daylight
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Linear blend towards another colour. Used to shade deeper sunburst rings.
    func mixed(with other: Color, amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        let t = min(max(amount, 0), 1)
        return Color(.sRGB,
                     red: Double(a.redComponent) * (1 - t) + Double(b.redComponent) * t,
                     green: Double(a.greenComponent) * (1 - t) + Double(b.greenComponent) * t,
                     blue: Double(a.blueComponent) * (1 - t) + Double(b.blueComponent) * t,
                     opacity: 1)
    }
}
