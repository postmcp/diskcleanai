import Foundation

/// The links the app shows and the GitHub repository whose releases feed the updater.
/// Any build can be pointed at another repository (a fork, a test repo) with
/// `defaults write ai.diskclean.app updates.repo owner/name`.
enum AppConfig {
    static let githubRepo = "postmcp/diskcleanai"

    static var updateRepo: String {
        if let override = UserDefaults.standard.string(forKey: Pref.updateRepo),
           override.split(separator: "/").count == 2 {
            return override
        }
        return githubRepo
    }

    /// Newest published release that is neither a draft nor a pre-release.
    static var latestReleaseAPI: URL { URL(string: "https://api.github.com/repos/\(updateRepo)/releases/latest")! }

    static let supportEmail = "hello@diskcleanai.com"
    static let websiteURL = URL(string: "https://diskcleanai.com")!
    static let sourceURL = URL(string: "https://github.com/\(githubRepo)")!
    static let issuesURL = URL(string: "https://github.com/\(githubRepo)/issues")!
    static let releasesURL = URL(string: "https://github.com/\(githubRepo)/releases")!

    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    static var build: Int { Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 1 }
    static var versionString: String { "\(version) (\(build))" }
}
