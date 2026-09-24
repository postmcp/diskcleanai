import Foundation
import AppKit

/// One process listening on one port. IPv4 and IPv6 sockets for the same
/// process, protocol and port are merged into a single row.
struct ListeningPort: Identifiable, Hashable {
    enum Proto: String, Hashable { case tcp = "TCP", udp = "UDP" }

    let pid: Int32
    let command: String
    let user: String
    let proto: Proto
    let port: Int
    var addresses: [String]

    var id: String { "\(proto.rawValue)-\(port)-\(pid)" }

    /// Only reachable from this Mac (every socket is bound to a loopback address).
    var isLoopbackOnly: Bool {
        !addresses.isEmpty && addresses.allSatisfy { $0.hasPrefix("127.") || $0 == "[::1]" || $0 == "localhost" }
    }

    var bindingLabel: String { isLoopbackOnly ? "localhost" : (addresses.contains("*") ? "all interfaces" : addresses.joined(separator: ", ")) }

    /// Ports that macOS itself hands out to system services developers often trip over.
    var systemHint: String? {
        switch (command, port) {
        case ("ControlCenter", 5000), ("ControlCenter", 7000):
            return "AirPlay Receiver. Turn it off in System Settings → General → AirDrop & Handoff instead of killing it."
        case ("rapportd", _): return "Continuity / Handoff service. macOS restarts it automatically."
        default: return nil
        }
    }

    var browserURL: URL? { proto == .tcp ? URL(string: "http://localhost:\(port)") : nil }
}

/// Lists listening sockets with `lsof` and signals the processes that own them.
/// Without root, `lsof` only sees the current user's processes, which covers dev
/// servers, databases started from a terminal and most apps.
enum PortScanner {
    static func list(includeUDP: Bool) async -> [ListeningPort] {
        await Task.detached(priority: .userInitiated) {
            var ports = parse(run(["-nP", "+c", "0", "-iTCP", "-sTCP:LISTEN", "-F", "pcLPn"]))
            if includeUDP {
                ports += parse(run(["-nP", "+c", "0", "-iUDP", "-F", "pcLPn"]))
            }
            return ports.sorted { ($0.port, $0.proto.rawValue, $0.pid) < ($1.port, $1.proto.rawValue, $1.pid) }
        }.value
    }

    /// Parses `lsof -F pcLPn` output: `p` starts a process, `f` a file, and the
    /// other fields belong to whichever of the two came last.
    static func parse(_ output: String) -> [ListeningPort] {
        var result: [String: ListeningPort] = [:]
        var order: [String] = []
        var pid: Int32 = 0
        var command = ""
        var user = ""
        var proto: ListeningPort.Proto?

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p":
                pid = Int32(value) ?? 0
                command = ""
                user = ""
                proto = nil
            case "c": command = value
            case "L": user = value
            case "f": proto = nil
            case "P": proto = ListeningPort.Proto(rawValue: value.uppercased())
            case "n":
                guard let proto, pid > 0, let (address, port) = splitEndpoint(value) else { continue }
                let key = "\(proto.rawValue)-\(port)-\(pid)"
                if var existing = result[key] {
                    if !existing.addresses.contains(address) { existing.addresses.append(address) }
                    result[key] = existing
                } else {
                    result[key] = ListeningPort(pid: pid, command: command, user: user, proto: proto, port: port, addresses: [address])
                    order.append(key)
                }
            default: continue
            }
        }
        return order.compactMap { result[$0] }
    }

    /// `*:3000`, `127.0.0.1:5432`, `[::1]:8080`. Connected UDP sockets
    /// (`a:1->b:2`) and unbound ones (`*:*`) are skipped.
    static func splitEndpoint(_ name: String) -> (String, Int)? {
        guard !name.contains("->"), let colon = name.lastIndex(of: ":") else { return nil }
        guard let port = Int(name[name.index(after: colon)...]), port > 0 else { return nil }
        return (String(name[..<colon]), port)
    }

    private static func run(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Signals

    enum KillResult: Equatable {
        case terminated
        case forced
        case notPermitted
        case alreadyGone
        case failed(String)
    }

    /// Sends SIGTERM and, unless `graceful` is set, escalates to SIGKILL when the
    /// process is still alive after a short grace period (what `kill-port` does).
    static func terminate(pid: Int32, graceful: Bool = false) async -> KillResult {
        guard pid > 1, pid != getpid() else { return .failed("Refusing to signal this process.") }
        if kill(pid, SIGTERM) != 0 { return result(for: errno) }
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(100))
            if !isAlive(pid) { return .terminated }
        }
        if graceful { return .failed("It is still running. Try Force Kill.") }
        return forceKill(pid: pid)
    }

    static func forceKill(pid: Int32) -> KillResult {
        guard pid > 1, pid != getpid() else { return .failed("Refusing to signal this process.") }
        if kill(pid, SIGKILL) != 0 { return result(for: errno) }
        return .forced
    }

    /// Asks macOS for an administrator password and kills a process owned by
    /// another user (root daemons, other accounts). The password goes straight
    /// to the system prompt; the app never sees it.
    static func killAsAdministrator(pid: Int32) -> KillResult {
        guard pid > 1 else { return .failed("Refusing to signal launchd.") }
        switch SystemTools.runAsAdministrator("/bin/kill -9 \(pid)") {
        case .success: return .forced
        case .failure(let error): return .failed(error.message)
        }
    }

    static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private static func result(for code: Int32) -> KillResult {
        switch code {
        case EPERM: return .notPermitted
        case ESRCH: return .alreadyGone
        default: return .failed(String(cString: strerror(code)))
        }
    }
}
