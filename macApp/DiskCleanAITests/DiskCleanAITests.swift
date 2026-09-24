import Testing
import Foundation
import CoreGraphics
@testable import DiskCleanAI

@Suite("File classification")
struct FileCategoryTests {
    @Test func classifiesByExtension() {
        let ctx = PathContext()
        #expect(FileCategory.classify(name: "clip.MOV", context: ctx) == .video)
        #expect(FileCategory.classify(name: "photo.heic", context: ctx) == .photos)
        #expect(FileCategory.classify(name: "song.flac", context: ctx) == .audio)
        #expect(FileCategory.classify(name: "report.pdf", context: ctx) == .documents)
        #expect(FileCategory.classify(name: "image.dmg", context: ctx) == .archives)
        #expect(FileCategory.classify(name: "main.swift", context: ctx) == .developer)
        #expect(FileCategory.classify(name: "README", context: ctx) == .other)
    }

    @Test func pathContextWins() {
        let caches = PathContext().descending(into: "Caches", isPackage: false)
        #expect(FileCategory.classify(name: "movie.mp4", context: caches) == .caches)
        let app = PathContext().descending(into: "Safari.app", isPackage: true)
        #expect(FileCategory.classify(name: "icon.png", context: app) == .apps)
        let dev = PathContext().descending(into: "node_modules", isPackage: false)
        #expect(FileCategory.classify(name: "package.json", context: dev) == .developer)
        #expect(FileCategory.classify(name: "demo.mp4", context: dev) == .video)
    }
}

@Suite("File tree")
struct FileNodeTests {
    func sampleTree() -> FileNode {
        let root = FileNode(name: "/", kind: .directory)
        let users = FileNode(name: "Users", kind: .directory)
        users.parent = root
        let a = FileNode(name: "a.mov", kind: .file, size: 600, category: .video)
        let b = FileNode(name: "b.pdf", kind: .file, size: 300, category: .documents)
        let c = FileNode(name: "c.txt", kind: .file, size: 100, category: .documents)
        for f in [a, b, c] { f.parent = users }
        users.children = [c, a, b]
        users.finalize()
        root.children = [users]
        root.finalize()
        return root
    }

    @Test func finalizeSumsAndSorts() {
        let root = sampleTree()
        #expect(root.size == 1000)
        #expect(root.fileCount == 3)
        #expect(root.children[0].children.map(\.name) == ["a.mov", "b.pdf", "c.txt"])
        #expect(root.children[0].dominantCategory == .video)
    }

    @Test func pathsAndLookup() {
        let root = sampleTree()
        let users = root.children[0]
        #expect(users.path == "/Users")
        #expect(users.children[1].path == "/Users/b.pdf")
        #expect(root.node(atPath: "/Users/c.txt")?.name == "c.txt")
        #expect(root.node(atPath: "/Nope") == nil)
    }

    @Test func removalRefinalizes() {
        let root = sampleTree()
        let users = root.children[0]
        users.children[0].removed = true
        users.refinalizeAncestors()
        #expect(root.size == 400)
        #expect(users.children.count == 2)
    }
}

@Suite("Volume readout")
struct VolumeInfoTests {
    private let disk = VolumeInfo(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", totalCapacity: 1000, availableCapacity: 200, isRoot: true, isRemovable: false)

    @Test func reclaimingCreditsPendingTrash() {
        let after = disk.reclaiming(300)
        #expect(after.availableCapacity == 500)
        #expect(after.usedCapacity == 500)
        #expect(after.totalCapacity == 1000)
        #expect(after.name == disk.name)
    }

    @Test func reclaimingIsCappedAndIgnoresNothing() {
        #expect(disk.reclaiming(0) == disk)
        #expect(disk.reclaiming(-5) == disk)
        #expect(disk.reclaiming(5000).availableCapacity == 1000)
    }
}

@Suite("Sunburst layout")
struct SunburstLayoutTests {
    @Test func arcsCoverTheCircleProportionally() {
        let root = FileNode(name: "/", kind: .directory)
        let big = FileNode(name: "big", kind: .file, size: 750)
        let small = FileNode(name: "small", kind: .file, size: 250)
        big.parent = root; small.parent = root
        root.children = [big, small]
        root.finalize()
        let arcs = SunburstLayout.arcs(focus: root, rings: 3)
        #expect(arcs.count == 2)
        #expect(abs(arcs[0].span - 1.5 * .pi) < 1e-9)
        #expect(abs(arcs[1].span - 0.5 * .pi) < 1e-9)
        #expect(abs(arcs[1].end - 2 * .pi) < 1e-9)
    }

    @Test func tinySlicesAreDropped() {
        let root = FileNode(name: "/", kind: .directory)
        let big = FileNode(name: "big", kind: .file, size: 1_000_000)
        let dust = FileNode(name: "dust", kind: .file, size: 1)
        big.parent = root; dust.parent = root
        root.children = [big, dust]
        root.finalize()
        #expect(SunburstLayout.arcs(focus: root, rings: 2).count == 1)
    }
}

@Suite("Safety policy")
struct SafetyPolicyTests {
    @Test func systemPathsAreProtected() {
        #expect(SafetyPolicy.assess(path: "/System/Library/CoreServices", insidePackage: false) == .protected)
        #expect(SafetyPolicy.assess(path: "/usr/bin/ls", insidePackage: false) == .protected)
        #expect(SafetyPolicy.assess(path: SafetyPolicy.home + "/Library/Keychains/login.keychain-db", insidePackage: false) == .protected)
        #expect(SafetyPolicy.assess(path: "/Applications/Safari.app/Contents/MacOS/Safari", insidePackage: true) == .protected)
    }

    @Test func userDataIsSafeAndLibraryIsCaution() {
        #expect(SafetyPolicy.assess(path: SafetyPolicy.home + "/Downloads/big.dmg", insidePackage: false) == .safe)
        #expect(SafetyPolicy.assess(path: SafetyPolicy.home + "/Library/Caches/com.example/blob", insidePackage: false) == .safe)
        #expect(SafetyPolicy.assess(path: SafetyPolicy.home + "/Library/Application Support/Example", insidePackage: false) == .caution)
        #expect(SafetyPolicy.assess(path: "/Applications/Example.app", insidePackage: false) == .caution)
    }

    @Test func appLeftoversInPreferencesAndCookiesCanBeRemoved() {
        let home = SafetyPolicy.home
        #expect(SafetyPolicy.assess(path: home + "/Library/Preferences", insidePackage: false) == .protected)
        #expect(SafetyPolicy.assess(path: home + "/Library/Preferences/com.example.app.plist", insidePackage: false) == .caution)
        #expect(SafetyPolicy.assess(path: home + "/Library/Cookies/com.example.app.binarycookies", insidePackage: false) == .caution)
        #expect(SafetyPolicy.assess(path: home + "/.ssh/id_ed25519", insidePackage: false) == .protected)
    }

    @Test func protectedItemsAreNeverApproved() {
        let item = CleanupItem(url: URL(fileURLWithPath: "/System/Library/Kernels/kernel"), size: 10, source: .largeFiles, reason: "test", isDirectory: false)
        #expect(item.safety == .protected)
        #expect(item.approved == false)
    }
}

@Suite("Perceptual hash")
struct PerceptualHashTests {
    private func solidImage(gray: UInt8, width: Int = 32, height: Int = 32, gradient: Bool = false) -> CGImage {
        var pixels = [UInt8](repeating: gray, count: width * height)
        if gradient {
            // Brightest on the left, darkest on the right: every left pixel beats its right neighbour.
            for y in 0..<height { for x in 0..<width { pixels[y * width + x] = UInt8(255 - x * 255 / (width - 1)) } }
        }
        return pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            return ctx.makeImage()!
        }
    }

    @Test func gradientHashIsStableAndDistinctFromFlat() {
        let flat = SimilarPhotoFinder.hash(of: solidImage(gray: 128))
        let gradientA = SimilarPhotoFinder.hash(of: solidImage(gray: 0, gradient: true))
        let gradientB = SimilarPhotoFinder.hash(of: solidImage(gray: 0, width: 64, height: 48, gradient: true))
        #expect(flat == 0)
        // Interpolation at the bitmap edge may flip a couple of bits; a real gradient still lights almost every bit.
        #expect(gradientA.nonzeroBitCount >= 56)
        #expect((gradientA ^ gradientB).nonzeroBitCount <= 4)
        #expect((flat ^ gradientA).nonzeroBitCount >= 56)
    }
}

@Suite("AI response parsing")
struct AIParsingTests {
    @Test func parsesFencedJSON() throws {
        let text = """
        ```json
        {"summary": "Two things.", "suggestions": [
          {"path": "/Users/me/Downloads/old.dmg", "action": "trash", "reason": "Installer", "confidence": "high", "category": "installers"},
          {"path": "relative/path", "action": "trash", "reason": "bad", "confidence": "high"},
          {"path": "/Users/me/Documents/keep.pdf", "action": "keep", "reason": "ignored"}
        ]}
        ```
        """
        let parsed = try AIAdvisor.parse(text)
        #expect(parsed.summary == "Two things.")
        #expect(parsed.suggestions.count == 1)
        #expect(parsed.suggestions[0].confidence == .high)
        #expect(parsed.suggestions[0].action == .trash)
    }

    @Test func rejectsNonJSON() {
        #expect(throws: OpenRouterError.self) { try AIAdvisor.parse("Sorry, I cannot help with that.") }
    }

    @Test func ignoresInlineThinking() throws {
        let text = """
        <think>The user wants {"summary"} JSON. Caches like {DerivedData} are safe.</think>
        {"summary": "One cache.", "suggestions": [{"path": "/Users/me/Library/Caches/x", "action": "trash", "reason": "Cache", "confidence": "high"}]}
        """
        let parsed = try AIAdvisor.parse(text)
        #expect(parsed.summary == "One cache.")
        #expect(parsed.suggestions.count == 1)
    }

    @Test func suggestionsAreLimitedToSentPaths() {
        func s(_ path: String) -> AISuggestion {
            AISuggestion(path: path, action: .trash, reason: "", confidence: .high, category: nil, size: 0, exists: false, isDirectory: false)
        }
        let sent = ["/Users/me/Downloads/Zoom.pkg", "/Users/me/Downloads/a/report.zip", "/Users/me/Desktop/report.zip", "/Users/me/Library/Caches/x"]
        let kept = AIAdvisor.constrain([
            s("/Users/me/Zoom.pkg"),              // shortened: repaired by unique name
            s("/Users/me/report.zip"),            // ambiguous name: dropped
            s("/Users/me/Library/Caches/x/"),     // trailing slash: normalised
            s("/Users/me/Library/Caches/x"),      // duplicate: dropped
            s("/etc/hosts"),                      // never sent: dropped
        ], to: sent).map(\.path)
        #expect(kept == ["/Users/me/Downloads/Zoom.pkg", "/Users/me/Library/Caches/x"])
    }

    @Test func repositoryInternalsAreNeverSent() {
        #expect(AIAdvisor.isRepositoryInternal("/Users/me/code/app/.git/objects/pack/pack-1.pack"))
        #expect(!AIAdvisor.isRepositoryInternal("/Users/me/code/app/node_modules"))
        #expect(!AIAdvisor.isRepositoryInternal("/Users/me/.gitconfig"))
    }

    @Test func errorMessagesAreActionable() {
        #expect(OpenRouterError.http(401, "User not found.").localizedDescription.contains("API key"))
        #expect(OpenRouterError.http(402, "").localizedDescription.contains("credits"))
        #expect(OpenRouterError.http(429, "").localizedDescription.contains("rate-limited"))
        #expect(OpenRouterError.http(503, "").isTransient)
        #expect(!OpenRouterError.http(400, "").isTransient)
    }
}

@Suite("Formatting")
struct FormatTests {
    @Test func tildePath() {
        #expect(Format.tildePath(SafetyPolicy.home + "/Downloads") == "~/Downloads")
        #expect(Format.tildePath("/Applications") == "/Applications")
    }

    @Test func tokensAndCurrency() {
        #expect(Format.tokens(1900) == "1.9k")
        #expect(Format.tokens(42) == "42")
        #expect(Format.usd(0.004) == "<$0.01")
    }
}

@Suite("Port monitor")
struct PortScannerTests {
    @Test func parsesListeningSockets() {
        let output = """
        p448
        cControlCenter
        Lshiva
        f10
        PTCP
        n*:7000
        f11
        PTCP
        n[::1]:7000
        p9120
        cnode
        Lshiva
        f23
        PTCP
        n127.0.0.1:3000
        f24
        PTCP
        n[::1]:3000
        """
        let ports = PortScanner.parse(output)
        #expect(ports.count == 2)
        #expect(ports[0].command == "ControlCenter")
        #expect(ports[0].addresses == ["*", "[::1]"])
        #expect(ports[0].systemHint != nil)
        #expect(ports[1].pid == 9120)
        #expect(ports[1].port == 3000)
        #expect(ports[1].isLoopbackOnly)
        #expect(ports[1].browserURL?.absoluteString == "http://localhost:3000")
    }

    @Test func skipsUnboundAndConnectedEndpoints() {
        #expect(PortScanner.splitEndpoint("*:*") == nil)
        #expect(PortScanner.splitEndpoint("10.0.0.2:5353->10.0.0.9:5353") == nil)
        #expect(PortScanner.splitEndpoint("[fe80::1%lo0]:8080")?.1 == 8080)
        let udp = PortScanner.parse("p1\ncmDNS\nLroot\nf5\nPUDP\nn*:*\nf6\nPUDP\nn*:5353\n")
        #expect(udp.count == 1)
        #expect(udp[0].proto == .udp)
    }

    @Test func parsesProcessList() {
        let rows = SystemStats.parsePS("  123   501  204800   12.5 Google Chrome Helper\n    1     0   8000    0.0 launchd\nbad line\n")
        #expect(rows.count == 2)
        #expect(rows[0].name == "Google Chrome Helper")
        #expect(rows[0].memory == 204800 * 1024)
        #expect(rows[0].cpu == 12.5)
        #expect(rows[1].uid == 0)
    }
}

@Suite("GitHub release updates")
struct UpdateReleaseTests {
    @Test func comparesVersionsNumerically() {
        #expect(AppVersion.compare("1.10.0", "1.9.3") == .orderedDescending)
        #expect(AppVersion.compare("v1.2", "1.2.0") == .orderedSame)
        #expect(AppVersion.compare("1.2.0", "1.2.1") == .orderedAscending)
        #expect(AppVersion.compare("2.0.0-beta.1", "1.9.0") == .orderedDescending)
        #expect(AppVersion.components("release-candidate").isEmpty)
    }

    private func release(tag: String, prerelease: Bool = false, assets: String) throws -> GitHubRelease {
        let json = """
        {"tag_name": "\(tag)", "body": "- Faster scans", "html_url": "https://github.com/postmcp/diskcleanai/releases/tag/\(tag)",
         "published_at": "2026-09-24T10:00:00Z", "draft": false, "prerelease": \(prerelease), "assets": [\(assets)]}
        """
        return try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
    }

    @Test func picksTheAppZipAndGitHubDigest() throws {
        let gh = try release(tag: "v1.2.0", assets: """
        {"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt", "size": 10, "digest": null},
        {"name": "DiskCleanAI.zip", "browser_download_url": "https://github.com/postmcp/diskcleanai/releases/download/v1.2.0/DiskCleanAI.zip", "size": 15000000, "digest": "sha256:abc123"}
        """)
        let r = try #require(AppRelease(github: gh))
        #expect(r.version == "1.2.0")
        #expect(r.url?.lastPathComponent == "DiskCleanAI.zip")
        #expect(r.sha256 == "abc123")
        #expect(r.size == 15_000_000)
        #expect(r.notes == "- Faster scans")
    }

    @Test func releaseWithoutZipFallsBackToThePage() throws {
        let gh = try release(tag: "v1.3.0", assets: "")
        let r = try #require(AppRelease(github: gh))
        #expect(r.url == nil)
        #expect(r.pageURL.absoluteString.hasSuffix("/v1.3.0"))
    }

    @Test func ignoresPrereleasesAndNonVersionTags() throws {
        let beta = try release(tag: "v2.0.0", prerelease: true, assets: "")
        let nightly = try release(tag: "nightly", assets: "")
        #expect(AppRelease(github: beta) == nil)
        #expect(AppRelease(github: nightly) == nil)
    }
}

@Suite("Hard links")
struct HardLinkTests {
    /// A temporary folder holding `original.bin`, a hard link to it and a real copy.
    private func makeFolder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskCleanAITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bytes = Data((0..<300_000).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        try bytes.write(to: dir.appendingPathComponent("original.bin"))
        try FileManager.default.linkItem(at: dir.appendingPathComponent("original.bin"), to: dir.appendingPathComponent("link.bin"))
        try bytes.write(to: dir.appendingPathComponent("copy.bin"))
        return dir
    }

    @Test func duplicateFinderIgnoresHardLinks() async throws {
        let dir = try makeFolder()
        defer { try? FileManager.default.removeItem(at: dir) }

        let root = FileNode(name: dir.path, kind: .directory)
        for name in ["original.bin", "link.bin", "copy.bin"] {
            let file = FileNode(name: name, kind: .file, size: 300_000)
            file.parent = root
            root.children.append(file)
        }
        root.finalize()

        let groups = try await DuplicateFinder().find(in: root, minimumSize: 1)
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        let names = Set(group.files.map(\.name))
        #expect(names.count == 2)
        #expect(names.contains("copy.bin"))
        #expect(names.contains("original.bin") != names.contains("link.bin"))
        #expect(group.wastedBytes == 300_000)
    }

    @Test func scannerCountsHardLinkedBytesOnce() async throws {
        let dir = try makeFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let allocated = Int64(try dir.appendingPathComponent("original.bin").resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0)
        let copy = Int64(try dir.appendingPathComponent("copy.bin").resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0)

        let root = try await DiskScanner().scan(root: dir)
        #expect(root.fileCount == 3)
        #expect(root.size == allocated + copy)
        let linkSizes = root.children.filter { $0.name != "copy.bin" }.map(\.size).sorted()
        #expect(linkSizes == [0, allocated])
    }
}
