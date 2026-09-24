import Foundation

enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func bytes(_ n: Int64) -> String {
        byteFormatter.string(fromByteCount: n)
    }

    static func count(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        if abs(date.timeIntervalSinceNow) < 60 { return "just now" }
        return relative.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return short.string(from: date)
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(fraction < 0.01 && fraction > 0 ? 1 : 0)))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return String(format: "%.0f s", seconds) }
        let m = Int(seconds) / 60, s = Int(seconds) % 60
        return "\(m) min \(s) s"
    }

    static func usd(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value < 0.01 && value > 0 { return "<$0.01" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    static func tokens(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    /// Abbreviate a path under the home folder with `~`.
    static func tildePath(_ path: String) -> String {
        let home = SafetyPolicy.home
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    static func daysAgo(_ date: Date?) -> String {
        guard let date else { return "Never opened" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case ..<30: return "\(days) days ago"
        case ..<365: return "\(days / 30) months ago"
        default: return "\(days / 365) year\(days / 365 == 1 ? "" : "s") ago"
        }
    }
}
