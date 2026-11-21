import Foundation
import PastuCore

/// Where Pastu keeps its files on disk. One place, so the location (and its permissions) is easy to audit.
enum AppPaths {
    /// ~/Library/Application Support/Pastu/history.sqlite (created on first launch).
    /// The folder is owner-only (`0700`) because the history may contain sensitive text.
    static func databasePath() throws -> String {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent(PastuInfo.name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // createDirectory leaves an existing folder untouched, so tighten it explicitly.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir.appendingPathComponent("history.sqlite").path
    }
}
