import Foundation

/// Builds the metadata-only payload sent to the model and turns the answer into
/// `AISuggestion`s that point at real paths. File contents are never read here.
struct AIAdvisor {
    static let systemPrompt = """
    You are a careful macOS storage advisor built into an open-source disk cleaner.
    You receive metadata only: paths, sizes in bytes, kinds and dates. You never see file contents.
    Recommend what the user can safely move to the Trash to free space, and explain why in one plain sentence each.

    Rules:
    - Only reference paths that appear in the input. Never invent paths.
    - Copy every path character for character from the input. Never shorten, abbreviate or rebuild a path.
    - Prefer caches, logs, installers (.dmg/.pkg/.zip) that were already used, old downloads, duplicate copies, unused apps and their leftovers, build artefacts (node_modules, DerivedData) that can be regenerated.
    - Never suggest documents, photos, videos, music, projects or anything inside ~/Documents, ~/Desktop, ~/Pictures unless it is an exact duplicate or an obvious export/render that is clearly redundant (mark those "review").
    - Never suggest system paths, application bundles under /System, keychains, preferences, or iCloud data.
    - Never suggest individual files inside a project (.git objects, source, assets); a whole regenerable folder such as node_modules is fine.
    - Anything that cannot be regenerated — chat or session histories, databases, saved app state, virtual machine disks — is at most "review", never "trash".
    - Use "trash" only when you are confident. Use "review" when the user should look first. Do not list items to "keep".
    - confidence is "high", "medium" or "low".

    Respond with JSON only, matching exactly:
    {"summary": "two sentences for the user", "suggestions": [{"path": "/absolute/path", "action": "trash"|"review", "reason": "...", "confidence": "high"|"medium"|"low", "category": "caches"|"installers"|"downloads"|"duplicates"|"apps"|"developer"|"other"}]}
    """

    struct Payload: Encodable {
        struct Entry: Encodable {
            let path: String
            let bytes: Int64
            let kind: String
            let modified: String?
            let lastOpened: String?
        }
        struct AppEntry: Encodable {
            let name: String
            let path: String
            let bytes: Int64
            let lastUsed: String?
            let leftoverBytes: Int64
            let leftoverPaths: [String]
        }
        struct DuplicateEntry: Encodable {
            let bytesEach: Int64
            let copies: Int
            let paths: [String]
        }
        let volumeName: String
        let totalBytes: Int64
        let freeBytes: Int64
        let scannedRoot: String
        let largeFiles: [Entry]
        let downloads: [Entry]
        let caches: [Entry]
        let unusedApps: [AppEntry]
        let duplicates: [DuplicateEntry]

        /// Every path the model was shown; suggestions are only accepted from this set.
        /// Built step by step: as one `+` chain it exceeds Xcode 16's type-checking time limit.
        var allPaths: [String] {
            var paths: [String] = []
            for entries in [largeFiles, downloads, caches] {
                paths.append(contentsOf: entries.map(\.path))
            }
            for app in unusedApps {
                paths.append(app.path)
                paths.append(contentsOf: app.leftoverPaths)
            }
            for group in duplicates {
                paths.append(contentsOf: group.paths)
            }
            return paths
        }
    }

    static func buildPayload(snapshot: ScanSnapshot?, downloads: [FileNode], apps: [InstalledApp], duplicates: [DuplicateGroup]) -> Payload {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        func entry(_ node: FileNode) -> Payload.Entry {
            Payload.Entry(path: node.path, bytes: node.size, kind: node.isContainer ? "folder" : node.fileExtension,
                          modified: node.modified.map(iso.string), lastOpened: node.accessed.map(iso.string))
        }
        let large = (snapshot?.largeFiles ?? [])
            .filter { SafetyPolicy.assess(path: $0.path, insidePackage: $0.isInsidePackage) != .protected && !isRepositoryInternal($0.path) }
            .prefix(60).map(entry)
        let caches = cacheCandidates(snapshot: snapshot).prefix(40).map(entry)
        let unused = apps.filter { $0.isUnused(days: 60) && $0.isRemovable }.prefix(25).map {
            Payload.AppEntry(name: $0.name, path: $0.url.path, bytes: $0.size, lastUsed: $0.lastUsed.map(iso.string),
                             leftoverBytes: $0.leftoverBytes, leftoverPaths: $0.leftovers.prefix(6).map(\.url.path))
        }
        let dupes = duplicates.prefix(25).map { Payload.DuplicateEntry(bytesEach: $0.size, copies: $0.files.count, paths: $0.files.prefix(4).map(\.path)) }
        return Payload(volumeName: snapshot?.volume.name ?? "Macintosh HD",
                       totalBytes: snapshot?.volume.totalCapacity ?? 0,
                       freeBytes: snapshot?.volume.availableCapacity ?? 0,
                       scannedRoot: snapshot?.rootURL.path ?? "",
                       largeFiles: Array(large), downloads: downloads.prefix(60).map(entry), caches: Array(caches),
                       unusedApps: Array(unused), duplicates: Array(dupes))
    }

    /// Files inside a `.git`/`.hg`/`.svn` folder. Removing one (e.g. a pack file) corrupts the
    /// repository, so they are never shown to the model and so can never come back as suggestions.
    static func isRepositoryInternal(_ path: String) -> Bool {
        ["/.git/", "/.hg/", "/.svn/"].contains { path.contains($0) }
    }

    /// Well-known disposable folders inside the scan, largest first.
    static func cacheCandidates(snapshot: ScanSnapshot?) -> [FileNode] {
        guard let root = snapshot?.root else { return [] }
        let home = SafetyPolicy.home
        let wellKnown = [
            home + "/Library/Caches", home + "/Library/Logs", home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/Developer/Xcode/Archives", home + "/Library/Developer/Xcode/iOS DeviceSupport",
            home + "/Library/Developer/CoreSimulator/Caches", home + "/Library/Application Support/CrashReporter",
            home + "/.npm/_cacache", home + "/.cache", home + "/Library/Caches/Homebrew", home + "/.gradle/caches",
            home + "/.cocoapods/repos", home + "/Library/Containers/com.docker.docker/Data",
        ]
        var out: [FileNode] = []
        for path in wellKnown {
            if let node = root.node(atPath: path), node.size > 0 {
                if path.hasSuffix("/Library/Caches") || path.hasSuffix("/Library/Logs") || path.hasSuffix("/DerivedData") {
                    out.append(contentsOf: node.children.filter { $0.isContainer && $0.size > 5_000_000 })
                } else {
                    out.append(node)
                }
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    static func encode(_ payload: Payload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func analyze(client: OpenRouterClient, model: String, payload: Payload, snapshot: ScanSnapshot?) async throws -> AIAnalysis {
        let user = "Here is the scan metadata. Reply with the JSON object only.\n\n" + (try encode(payload))
        let result = try await client.complete(model: model, system: systemPrompt, user: user)
        let parsed = try parse(result.content)
        let resolved = constrain(parsed.suggestions, to: payload.allPaths).map { resolve($0, snapshot: snapshot) }
        return AIAnalysis(summary: parsed.summary, suggestions: resolved, model: model,
                          promptTokens: result.usage?.promptTokens ?? 0, completionTokens: result.usage?.completionTokens ?? 0,
                          cost: result.usage?.cost, createdAt: Date())
    }

    private struct RawResponse: Decodable {
        struct RawSuggestion: Decodable {
            let path: String
            let action: String?
            let reason: String?
            let confidence: String?
            let category: String?
        }
        let summary: String?
        let suggestions: [RawSuggestion]?
    }

    static func parse(_ text: String) throws -> (summary: String, suggestions: [AISuggestion]) {
        var body = text
        // Some reasoning models inline their thinking, which can itself contain braces.
        while let open = body.range(of: "<think>"), let close = body.range(of: "</think>", range: open.upperBound..<body.endIndex) {
            body.removeSubrange(open.lowerBound..<close.upperBound)
        }
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```") {
            body = body.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        }
        if let start = body.firstIndex(of: "{"), let end = body.lastIndex(of: "}") {
            body = String(body[start...end])
        }
        guard let data = body.data(using: .utf8), let raw = try? JSONDecoder().decode(RawResponse.self, from: data) else {
            throw OpenRouterError.invalidJSON(text)
        }
        let suggestions = (raw.suggestions ?? []).compactMap { s -> AISuggestion? in
            guard s.path.hasPrefix("/") else { return nil }
            let action = AISuggestion.Action(rawValue: s.action?.lowercased() ?? "review") ?? .review
            if action == .keep { return nil }
            let confidence = AISuggestion.Confidence(rawValue: s.confidence?.lowercased() ?? "medium") ?? .medium
            return AISuggestion(path: s.path, action: action, reason: s.reason ?? "", confidence: confidence, category: s.category,
                                size: 0, exists: false, isDirectory: false)
        }
        return (raw.summary ?? "", suggestions)
    }

    /// Keep only suggestions for paths that were actually sent, once each. Models sometimes
    /// shorten a path (e.g. drop `/Downloads`); when the file name matches exactly one sent
    /// path the suggestion is repaired, otherwise it is discarded rather than shown as "Not found".
    static func constrain(_ suggestions: [AISuggestion], to sentPaths: [String]) -> [AISuggestion] {
        let sent = Set(sentPaths)
        let byName = Dictionary(grouping: sent, by: { ($0 as NSString).lastPathComponent })
        var seen = Set<String>()
        return suggestions.compactMap { s in
            var path = s.path.hasSuffix("/") && s.path.count > 1 ? String(s.path.dropLast()) : s.path
            if !sent.contains(path) {
                guard let matches = byName[(path as NSString).lastPathComponent], matches.count == 1 else { return nil }
                path = matches[0]
            }
            guard seen.insert(path).inserted else { return nil }
            return AISuggestion(path: path, action: s.action, reason: s.reason, confidence: s.confidence, category: s.category,
                                size: s.size, exists: s.exists, isDirectory: s.isDirectory)
        }
    }

    /// Attach the real size and existence to a suggestion; the model's word is never trusted for sizes.
    static func resolve(_ suggestion: AISuggestion, snapshot: ScanSnapshot?) -> AISuggestion {
        var s = suggestion
        if let node = snapshot?.root.node(atPath: s.path) {
            s.size = node.size
            s.exists = true
            s.isDirectory = node.isContainer
            return s
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: s.path, isDirectory: &isDir) {
            s.exists = true
            s.isDirectory = isDir.boolValue
            s.size = isDir.boolValue ? AppInventory.directorySize(URL(fileURLWithPath: s.path))
                : Int64((try? URL(fileURLWithPath: s.path).resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return s
    }
}
