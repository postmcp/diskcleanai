import Foundation

/// Device and inode of a file: the same for every hard link to it. The device matters
/// because a scan of `/` spans the System and Data volumes, which can reuse inode numbers.
struct FileIdentity: Hashable, Sendable {
    let device: Int32
    let inode: UInt64

    /// `nil` when the path cannot be `lstat`ed.
    init?(path: String) {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        device = info.st_dev
        inode = info.st_ino
    }
}
