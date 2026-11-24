import Foundation
import SQLite3

// Keeping the history within its limits: age, count and estimated size.
extension ClipStore {
    /// Deletes clips outside the policy: first the ones older than `maxAge`, then everything beyond
    /// the newest `maxCount`. Pinned clips are never deleted and do not count against `maxCount`.
    /// Returns how many were deleted.
    @discardableResult
    public func prune(_ policy: RetentionPolicy, now: Date = Date()) throws -> Int {
        try inTransaction {
            var removed = 0
            if let maxAge = policy.maxAge {
                let stmt = try prepare("DELETE FROM clips WHERE last_copied_at < ?1 AND pinned = 0")
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_double(stmt, 1, now.addingTimeInterval(-maxAge).timeIntervalSince1970)
                guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
                removed += Int(sqlite3_changes(db))
            }
            if let maxCount = policy.maxCount {
                let stmt = try prepare("""
                    DELETE FROM clips WHERE id IN (
                        SELECT id FROM clips WHERE pinned = 0 ORDER BY last_copied_at DESC, id DESC LIMIT -1 OFFSET ?1
                    )
                    """)
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, Int64(max(maxCount, 0)))
                guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
                removed += Int(sqlite3_changes(db))
            }
            if let cap = policy.maxTotalBytes {
                removed += try pruneToSize(cap)
            }
            return removed
        }
    }

    /// The text is stored once in the table and again, as overlapping 3-character pieces, in the trigram index.
    /// Measured overhead is roughly 3.5x the text size on top of the text itself, hence 4.5x in total.
    /// An estimate from the text length (not `page_count * page_size`) so it is deterministic and shrinks
    /// immediately after deletes, without waiting for a VACUUM.
    static let indexOverheadFactor = 4.5

    /// Estimated on-disk size of the history: UTF-8 bytes of all clip text times `indexOverheadFactor`
    /// (the trigram index), plus the bytes of every image (stored once, not indexed).
    public func estimatedSizeInBytes() throws -> Int {
        let stmt = try prepare("""
            SELECT COALESCE(SUM(LENGTH(CAST(text AS BLOB)) + COALESCE(LENGTH(CAST(ocr_text AS BLOB)), 0)), 0),
                   COALESCE(SUM(LENGTH(image)), 0) FROM clips
            """)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw lastError() }
        return Int(Double(sqlite3_column_int64(stmt, 0)) * Self.indexOverheadFactor) + Int(sqlite3_column_int64(stmt, 1))
    }

    /// Deletes the oldest unpinned clips until the estimate is within `cap`. Runs inside `prune`'s transaction.
    private func pruneToSize(_ cap: Int) throws -> Int {
        var excess = try estimatedSizeInBytes() - cap
        guard excess > 0 else { return 0 }
        let select = try prepare("""
            SELECT id, LENGTH(CAST(text AS BLOB)) + COALESCE(LENGTH(CAST(ocr_text AS BLOB)), 0), COALESCE(LENGTH(image), 0)
            FROM clips WHERE pinned = 0 ORDER BY last_copied_at ASC, id ASC
            """)
        defer { sqlite3_finalize(select) }
        var ids: [Int64] = []
        while excess > 0, sqlite3_step(select) == SQLITE_ROW {
            ids.append(sqlite3_column_int64(select, 0))
            excess -= Int((Double(sqlite3_column_int64(select, 1)) * Self.indexOverheadFactor).rounded(.up))
                + Int(sqlite3_column_int64(select, 2))
        }
        let delete = try prepare("DELETE FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(delete) }
        for id in ids {
            sqlite3_reset(delete)
            sqlite3_bind_int64(delete, 1, id)
            guard sqlite3_step(delete) == SQLITE_DONE else { throw lastError() }
        }
        return ids.count
    }

    /// Deletes the whole history, or everything except pinned clips. Returns how many clips were deleted.
    @discardableResult
    public func clear(keepPinned: Bool) throws -> Int {
        let stmt = try prepare(keepPinned ? "DELETE FROM clips WHERE pinned = 0" : "DELETE FROM clips")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
        return Int(sqlite3_changes(db))
    }
}
