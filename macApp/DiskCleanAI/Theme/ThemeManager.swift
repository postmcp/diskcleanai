import SwiftUI
import Observation

/// Owns the user's theme selection and persists it. The root view resolves the
/// selection against the system appearance so `Match System` keeps working.
@Observable
final class ThemeManager {
    private static let key = "appearance.theme"
    /// Ocean is the out-of-the-box look: a light blue-green ground with a teal accent.
    static let defaultTheme: ThemeID = .ocean

    var selection: ThemeID {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: Self.key) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? ""
        selection = ThemeID(rawValue: stored) ?? ThemeManager.defaultTheme
    }

    func resolved(for systemScheme: ColorScheme) -> Theme {
        if selection == .system {
            return systemScheme == .dark ? .midnight : .daylight
        }
        return Theme.named(selection) ?? .daylight
    }

    /// `nil` lets the window follow the system; otherwise force the scheme the theme was designed for.
    var preferredColorScheme: ColorScheme? {
        selection == .system ? nil : Theme.named(selection)?.colorScheme
    }
}
