import Foundation
import Darwin

/// Point-in-time readings of memory, CPU, swap and network for the menu bar and
/// the Tools screen. Everything here is cheap enough to sample every few seconds.
enum SystemStats {
    struct Memory: Equatable {
        var used: UInt64
        var total: UInt64
        var compressed: UInt64
        var swapUsed: UInt64

        var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    /// Raw CPU tick counters. Usage is the change between two samples.
    struct CPUTicks: Equatable {
        var busy: UInt64
        var total: UInt64

        func usage(since previous: CPUTicks?) -> Double? {
            guard let previous, total > previous.total else { return nil }
            return Double(busy - previous.busy) / Double(total - previous.total)
        }
    }

    /// "Memory Used" the way Activity Monitor adds it up: app memory + wired + compressed.
    static func memory() -> Memory {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else { return Memory(used: 0, total: total, compressed: 0, swapUsed: swapUsed()) }
        let page = UInt64(vm_kernel_page_size)
        let appPages = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
        let compressed = UInt64(stats.compressor_page_count) * page
        let used = (appPages + UInt64(stats.wire_count)) * page + compressed
        return Memory(used: min(used, total), total: total, compressed: compressed, swapUsed: swapUsed())
    }

    static func swapUsed() -> UInt64 {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 else { return 0 }
        return swap.xsu_used
    }

    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return CPUTicks(busy: user + system + nice, total: user + system + nice + idle)
    }

    /// The first IPv4 address on a real interface (Wi-Fi or Ethernet), for sharing a dev server on the LAN.
    static func localIPAddress() -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var candidates: [(name: String, address: String)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            candidates.append((String(cString: entry.ifa_name), String(cString: host)))
        }
        return (candidates.first { $0.name.hasPrefix("en") } ?? candidates.first)?.address
    }

    // MARK: - Processes

    struct ProcessUsage: Identifiable, Hashable {
        let pid: Int32
        let uid: Int32
        let name: String
        let memory: UInt64
        let cpu: Double

        var id: Int32 { pid }
        var isOwnedByUser: Bool { uid == getuid() }
    }

    static func topProcesses() async -> [ProcessUsage] {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-Aco", "pid=,uid=,rss=,pcpu=,comm="]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return parsePS(String(decoding: data, as: UTF8.self))
        }.value
    }

    /// Parses `ps -Aco pid=,uid=,rss=,pcpu=,comm=`. The command is last so it may contain spaces.
    static func parsePS(_ output: String) -> [ProcessUsage] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count == 5,
                  let pid = Int32(fields[0]), let uid = Int32(fields[1]),
                  let rss = UInt64(fields[2]), let cpu = Double(fields[3].replacingOccurrences(of: ",", with: "."))
            else { return nil }
            return ProcessUsage(pid: pid, uid: uid, name: String(fields[4]), memory: rss * 1024, cpu: cpu)
        }
    }
}
