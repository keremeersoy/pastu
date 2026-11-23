import Foundation
import SQLite3

/// Everything stored about one clip, kept in memory so a delete in the panel can be undone (⌘Z).
/// Holds clip text and pictures, so the panel drops it as soon as it hides.
public struct ClipSnapshot: Sendable {
    public let text: String
    public let sourceBundleIdentifier: String?
    public let firstCopiedAt: Date
    public let lastCopiedAt: Date
    public let copyCount: Int
    public let isPinned: Bool
    let isImage: Bool
    let imagePNG: Data?
}

extension ClipStore {
    /// Reads one clip completely (picture bytes included), or nil when it does not exist.
    public func snapshot(id: Int64) throws -> ClipSnapshot? {
        let stmt = try prepare("""
            SELECT text, source_bundle_id, first_copied_at, last_copied_at, copy_count, pinned, kind, image
            FROM clips WHERE id = ?1
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        func string(_ column: Int32) -> String? {
            sqlite3_column_text(stmt, column).map { String(cString: $0) }
        }
        let image: Data? = sqlite3_column_blob(stmt, 7).map { Data(bytes: $0, count: Int(sqlite3_column_bytes(stmt, 7))) }
        return ClipSnapshot(
            text: string(0) ?? "",
            sourceBundleIdentifier: string(1),
            firstCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            lastCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
            copyCount: Int(sqlite3_column_int64(stmt, 4)),
            isPinned: sqlite3_column_int64(stmt, 5) != 0,
            isImage: string(6) == "image",
            imagePNG: image
        )
    }

    /// Puts a deleted clip back exactly as it was. If the same text was copied again in the meantime, that row
    /// stays as it is (one row per text) and its id is returned.
    @discardableResult
    public func restore(_ clip: ClipSnapshot) throws -> Int64 {
        let insert = try prepare("""
            INSERT OR IGNORE INTO clips
                (text, source_bundle_id, first_copied_at, last_copied_at, copy_count, pinned, kind, image)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
            """)
        defer { sqlite3_finalize(insert) }
        bind(clip.text, at: 1, in: insert)
        bind(clip.sourceBundleIdentifier, at: 2, in: insert)
        sqlite3_bind_double(insert, 3, clip.firstCopiedAt.timeIntervalSince1970)
        sqlite3_bind_double(insert, 4, clip.lastCopiedAt.timeIntervalSince1970)
        sqlite3_bind_int64(insert, 5, Int64(clip.copyCount))
        sqlite3_bind_int64(insert, 6, clip.isPinned ? 1 : 0)
        bind(clip.isImage ? "image" : "text", at: 7, in: insert)
        bind(blob: clip.imagePNG, at: 8, in: insert)
        guard sqlite3_step(insert) == SQLITE_DONE else { throw lastError() }

        let select = try prepare("SELECT id FROM clips WHERE text = ?1")
        defer { sqlite3_finalize(select) }
        bind(clip.text, at: 1, in: select)
        guard sqlite3_step(select) == SQLITE_ROW else { throw lastError() }
        return sqlite3_column_int64(select, 0)
    }
}
