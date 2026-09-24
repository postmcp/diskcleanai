import Foundation
import SwiftUI
import Observation
import AppKit
import CryptoKit

/// The subset of GitHub's release JSON the updater reads
/// (`GET /repos/{owner}/{repo}/releases/latest`).
struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int64
        /// `"sha256:<hex>"`, computed by GitHub for every uploaded asset.
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let publishedAt: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case body, draft, prerelease, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }
}

/// A published release of the app, taken from a GitHub release on `AppConfig.updateRepo`.
struct AppRelease: Equatable {
    /// Marketing version from the tag, without the leading "v" (`v1.2.0` → `1.2.0`).
    let version: String
    let tag: String
    /// The zip to install. `nil` when the release has no zip attached; the sheet then links to `pageURL`.
    let url: URL?
    let pageURL: URL
    let sha256: String?
    let size: Int64?
    let notes: String

    var isNewerThanRunning: Bool { AppVersion.compare(version, AppConfig.version) == .orderedDescending }

    init(version: String, tag: String, url: URL?, pageURL: URL, sha256: String?, size: Int64?, notes: String) {
        self.version = version
        self.tag = tag
        self.url = url
        self.pageURL = pageURL
        self.sha256 = sha256
        self.size = size
        self.notes = notes
    }

    /// `nil` for drafts, pre-releases and tags that are not a version number.
    init?(github release: GitHubRelease) {
        guard !release.draft, !release.prerelease else { return nil }
        let version = AppVersion.normalized(release.tagName)
        guard !AppVersion.components(version).isEmpty else { return nil }
        let zips = release.assets.filter { $0.name.lowercased().hasSuffix(".zip") }
        let asset = zips.first(where: { $0.name.hasPrefix("DiskCleanAI") }) ?? zips.first
        self.init(
            version: version,
            tag: release.tagName,
            url: asset?.browserDownloadURL,
            pageURL: release.htmlURL,
            sha256: asset?.digest.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)) : nil },
            size: asset?.size,
            notes: (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

/// Dotted version numbers as used in tags and `CFBundleShortVersionString`.
enum AppVersion {
    /// `"v1.2.0"` → `"1.2.0"`.
    static func normalized(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        return trimmed.first == "v" || trimmed.first == "V" ? String(trimmed.dropFirst()) : trimmed
    }

    /// `"1.2.0-beta.1"` → `[1, 2, 0]`. Anything after `-`, `+` or a space is ignored.
    static func components(_ version: String) -> [Int] {
        let core = normalized(version).split(whereSeparator: { $0 == "-" || $0 == "+" || $0 == " " }).first ?? ""
        let parts = core.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return [] }
        return parts.compactMap { $0 }
    }

    /// Compares numerically, padding the shorter version with zeros (`1.2` == `1.2.0`).
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = components(lhs), b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

/// Checks the newest GitHub release, downloads its zip, verifies it and swaps the running bundle.
///
/// The installer is deliberately small: unpack next to the download, confirm the new
/// bundle is really Disk Clean AI with the advertised version, move the old app
/// aside, move the new one in, then relaunch. If the app lives somewhere it cannot
/// write (or was started from Xcode) it falls back to revealing the download.
@MainActor
@Observable
final class UpdateChecker {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case downloading(AppRelease, fraction: Double)
        case installing(AppRelease)
        case readyToRelaunch(AppRelease)
        case failed(String)
    }

    private static let automaticInterval: TimeInterval = 24 * 3600

    var phase: Phase = .idle
    var showSheet = false
    @ObservationIgnored private var task: Task<Void, Never>?

    var availableRelease: AppRelease? {
        switch phase {
        case .available(let r), .downloading(let r, _), .installing(let r), .readyToRelaunch(let r): return r
        default: return nil
        }
    }

    var isWorking: Bool {
        switch phase {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    // MARK: - Checking

    /// Runs on launch when the user has automatic checks on and a day has passed.
    func checkAutomaticallyIfDue() {
        guard UserDefaults.standard.bool(forKey: Pref.autoCheckUpdates) else { return }
        let last = UserDefaults.standard.double(forKey: Pref.lastUpdateCheck)
        guard Date().timeIntervalSince1970 - last > Self.automaticInterval else { return }
        check(userInitiated: false)
    }

    func check(userInitiated: Bool) {
        guard !isWorking else { if userInitiated { showSheet = true }; return }
        phase = .checking
        if userInitiated { showSheet = true }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await fetchLatest()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Pref.lastUpdateCheck)
                guard let release, release.isNewerThanRunning else {
                    phase = .upToDate
                    return
                }
                let skipped = UserDefaults.standard.string(forKey: Pref.skippedVersion)
                if !userInitiated && skipped == release.version { phase = .idle; return }
                phase = .available(release)
                showSheet = true
            } catch {
                phase = .failed(error.localizedDescription)
                if !userInitiated { showSheet = false }
            }
        }
    }

    /// The newest published, non-prerelease GitHub release, or `nil` when there is none yet.
    private func fetchLatest() async throws -> AppRelease? {
        var request = URLRequest(url: AppConfig.latestReleaseAPI)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("DiskCleanAI/\(AppConfig.versionString) macOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }   // no release published yet
        if status == 403 || status == 429 { throw UpdateError.rateLimited }
        guard status == 200 else { throw UpdateError.http(status) }
        return AppRelease(github: try JSONDecoder().decode(GitHubRelease.self, from: data))
    }

    func skip(_ release: AppRelease) {
        UserDefaults.standard.set(release.version, forKey: Pref.skippedVersion)
        showSheet = false
        phase = .idle
    }

    func cancel() {
        task?.cancel()
        task = nil
        if isWorking { phase = availableRelease.map { .available($0) } ?? .idle }
    }

    // MARK: - Installing

    func downloadAndInstall(_ release: AppRelease) {
        guard !isWorking else { return }
        guard release.url != nil else { NSWorkspace.shared.open(release.pageURL); return }
        phase = .downloading(release, fraction: 0)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let zip = try await download(release)
                try Task.checkCancellation()
                phase = .installing(release)
                let installed = try await Task.detached(priority: .userInitiated) { try Self.install(zip: zip, release: release) }.value
                switch installed {
                case .replaced(let url):
                    phase = .readyToRelaunch(release)
                    relaunch(at: url)
                case .revealed:
                    phase = .failed("Disk Clean AI could not replace itself here. The new version was downloaded and shown in Finder — drag it into Applications to finish.")
                }
            } catch is CancellationError {
                phase = .available(release)
            } catch let error as URLError where error.code == .cancelled {
                phase = .available(release)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func download(_ release: AppRelease) async throws -> URL {
        let dir = try Self.updatesDirectory()
        let destination = dir.appendingPathComponent("DiskCleanAI-\(release.version).zip")
        try? FileManager.default.removeItem(at: destination)
        guard let url = release.url else { throw UpdateError.invalidArchive("This release has no zip to install.") }

        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        let downloaded = try await FileDownloader.download(request, expectedSize: release.size) { [weak self] fraction in
            Task { @MainActor in
                guard let self, case .downloading = self.phase else { return }
                self.phase = .downloading(release, fraction: fraction)
            }
        }
        try FileManager.default.moveItem(at: downloaded, to: destination)
        phase = .downloading(release, fraction: 1)

        if let sha = release.sha256, !sha.isEmpty {
            let digest = try await Task.detached(priority: .userInitiated) { try Self.sha256(of: destination) }.value
            guard digest.caseInsensitiveCompare(sha) == .orderedSame else {
                try? FileManager.default.removeItem(at: destination)
                throw UpdateError.checksumMismatch
            }
        }
        return destination
    }

    nonisolated private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private enum InstallOutcome { case replaced(URL), revealed }

    /// Runs off the main actor. Unpacks, validates and swaps bundles.
    nonisolated private static func install(zip: URL, release: AppRelease) throws -> InstallOutcome {
        let fm = FileManager.default
        let staging = zip.deletingLastPathComponent().appendingPathComponent("unpacked-\(release.version)", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        try run("/usr/bin/ditto", ["-xk", zip.path, staging.path])

        guard let newApp = try fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.invalidArchive("The download did not contain an application.")
        }
        guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let identifier = info["CFBundleIdentifier"] as? String,
              identifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.invalidArchive("The downloaded app is not Disk Clean AI.")
        }
        if let version = info["CFBundleShortVersionString"] as? String, AppVersion.compare(version, release.version) != .orderedSame {
            throw UpdateError.invalidArchive("The downloaded app is version \(version), but the release is tagged \(release.tag).")
        }
        if let minimum = info["LSMinimumSystemVersion"] as? String {
            let parts = AppVersion.components(minimum)
            let required = OperatingSystemVersion(majorVersion: parts.first ?? 0, minorVersion: parts.count > 1 ? parts[1] : 0, patchVersion: parts.count > 2 ? parts[2] : 0)
            guard ProcessInfo.processInfo.isOperatingSystemAtLeast(required) else {
                try? fm.removeItem(at: staging)
                throw UpdateError.invalidArchive("Disk Clean AI \(release.version) requires macOS \(minimum) or later.")
            }
        }
        // Downloads made by the app itself are not quarantined, but be explicit.
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

        let current = Bundle.main.bundleURL
        let parent = current.deletingLastPathComponent()
        let inDerivedData = current.path.contains("/DerivedData/") || current.path.contains("/Xcode/")
        guard !inDerivedData, fm.isWritableFile(atPath: parent.path), fm.isWritableFile(atPath: current.path) else {
            DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([newApp]) }
            return .revealed
        }

        let backup = parent.appendingPathComponent(".\(current.lastPathComponent).old-\(Int(Date().timeIntervalSince1970))")
        try fm.moveItem(at: current, to: backup)
        do {
            try fm.moveItem(at: newApp, to: current)
        } catch {
            try? fm.moveItem(at: backup, to: current)
            throw error
        }
        // The running process keeps its mapped binary alive, so the old bundle can go now.
        try? fm.removeItem(at: backup)
        try? fm.removeItem(at: staging)
        try? fm.removeItem(at: zip)
        return .replaced(current)
    }

    private func relaunch(at url: URL) {
        // A detached shell survives our exit and reopens the new bundle once we are gone.
        let script = "sleep 1; /usr/bin/open -n \"\(url.path)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
            // SwiftUI can defer termination indefinitely while a sheet is up; nothing here
            // needs saving, so make sure we are gone before the new copy comes up.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { exit(0) }
        }
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw UpdateError.tool("\(tool) failed: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    nonisolated private static func updatesDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "ai.diskclean.app", isDirectory: true).appendingPathComponent("updates", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

enum UpdateError: LocalizedError {
    case http(Int)
    case rateLimited
    case checksumMismatch
    case invalidArchive(String)
    case tool(String)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "GitHub returned HTTP \(code) while checking for updates."
        case .rateLimited: return "GitHub is limiting update checks from this network right now. Please try again later."
        case .checksumMismatch: return "The download was corrupted (checksum mismatch). Please try again."
        case .invalidArchive(let why): return why
        case .tool(let why): return why
        }
    }
}

/// Download task with progress, bridged to async/await. The temporary file URL it
/// resolves with must be moved before the completion handler returns, which the
/// continuation guarantees by resuming synchronously inside the delegate callback.
final class FileDownloader: NSObject, URLSessionDownloadDelegate {
    private let progress: (Double) -> Void
    private let expectedSize: Int64?
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?

    private init(expectedSize: Int64?, progress: @escaping (Double) -> Void) {
        self.expectedSize = expectedSize
        self.progress = progress
    }

    static func download(_ request: URLRequest, expectedSize: Int64?, progress: @escaping (Double) -> Void) async throws -> URL {
        let downloader = FileDownloader(expectedSize: expectedSize, progress: progress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                downloader.continuation = continuation
                let session = URLSession(configuration: .ephemeral, delegate: downloader, delegateQueue: nil)
                downloader.session = session
                session.downloadTask(with: request).resume()
            }
        } onCancel: {
            downloader.session?.invalidateAndCancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (expectedSize ?? 0)
        guard total > 0 else { return }
        progress(min(Double(totalBytesWritten) / Double(total), 0.99))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(UpdateError.http(http.statusCode)))
            return
        }
        // `location` is deleted when this method returns, so claim it immediately.
        let kept = location.deletingLastPathComponent().appendingPathComponent("DiskCleanAI-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: kept)
            finish(.success(kept))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
        session.finishTasksAndInvalidate()
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
