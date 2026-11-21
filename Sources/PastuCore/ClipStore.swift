import Foundation
import SQLite3

/// A clip as persisted in the database.
public struct StoredClip: Equatable, Sendable {
    public let id: Int64
    public let text: String
    public let sourceBundleIdentifier: String?
    public let firstCopiedAt: Date
    public let lastCopiedAt: Date
    public let copyCount: Int
}

public struct ClipStoreError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String
    public var description: String { "SQLite error \(code): \(message)" }
}

/// Local history storage: SQLite with an FTS5 full-text index. Everything stays on disk, no network.
///
/// Not thread-safe; use it from a single actor/queue (the app uses the main actor for now).
public final class ClipStore {
    private var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// - Parameter path: database file path, or `nil` for an in-memory database (tests).
    public init(path: String? = nil) throws {
        let rc = sqlite3_open_v2(path ?? ":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard rc == SQLITE_OK else {
            let error = ClipStoreError(code: rc, message: db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed")
            sqlite3_close(db)
            throw error
        }
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: Public API

    /// Inserts a clip, or merges it into the existing row when the same text was copied before.
    @discardableResult
    public func insert(_ clip: CapturedClip) throws -> Int64 {
        let stmt = try prepare("""
            INSERT INTO clips (text, source_bundle_id, first_copied_at, last_copied_at)
            VALUES (?1, ?2, ?3, ?3)
            ON CONFLICT(text) DO UPDATE SET
                last_copied_at = excluded.last_copied_at,
                copy_count = copy_count + 1,
                source_bundle_id = COALESCE(excluded.source_bundle_id, source_bundle_id)
            RETURNING id
            """)
        defer { sqlite3_finalize(stmt) }
        bind(clip.text, at: 1, in: stmt)
        bind(clip.sourceBundleIdentifier, at: 2, in: stmt)
        sqlite3_bind_double(stmt, 3, clip.date.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw lastError() }
        let id = sqlite3_column_int64(stmt, 0)
        // Drain so the statement completes before finalize.
        while sqlite3_step(stmt) == SQLITE_ROW {}
        return id
    }

    public func recent(limit: Int = 50) throws -> [StoredClip] {
        try query("""
            SELECT id, text, source_bundle_id, first_copied_at, last_copied_at, copy_count
            FROM clips ORDER BY last_copied_at DESC, id DESC LIMIT ?1
            """, limit: limit)
    }

    /// Full-text search: every word must match as a prefix. Newest matches first.
    public func search(_ query: String, limit: Int = 50) throws -> [StoredClip] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return try recent(limit: limit) }

        guard let match = Self.ftsMatchExpression(for: trimmed) else { return [] }
        return try self.query("""
            SELECT c.id, c.text, c.source_bundle_id, c.first_copied_at, c.last_copied_at, c.copy_count
            FROM clips_fts f JOIN clips c ON c.id = f.rowid
            WHERE clips_fts MATCH ?2
            ORDER BY c.last_copied_at DESC, c.id DESC LIMIT ?1
            """, limit: limit, match: match)
    }

    /// Marks a clip as just used (e.g. pasted from the panel): moves it to the top
    /// without counting as a new copy.
    public func markUsed(id: Int64, at date: Date = Date()) throws {
        let stmt = try prepare("UPDATE clips SET last_copied_at = ?2 WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_bind_double(stmt, 2, date.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
    }

    public func delete(id: Int64) throws {
        let stmt = try prepare("DELETE FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
    }

    /// Throws if the full-text index is out of sync with the `clips` table (rank = 1 also compares the content table).
    public func verifyIntegrity() throws {
        try exec("INSERT INTO clips_fts (clips_fts, rank) VALUES ('integrity-check', 1)")
    }

    // MARK: Search query building

    /// Turns user input into a safe FTS5 expression: each word becomes a quoted prefix term,
    /// so characters like `"`, `(` or `*` can never cause a syntax error.
    /// Returns nil when the input contains no searchable words.
    static func ftsMatchExpression(for input: String) -> String? {
        let terms = input
            .split(whereSeparator: \.isWhitespace)
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
        return terms.isEmpty ? nil : terms.joined(separator: " ")
    }

    // MARK: Schema

    private func migrate() throws {
        // `text` is never updated in place, so the FTS index needs only insert/delete triggers.
        try exec("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL UNIQUE,
                source_bundle_id TEXT,
                first_copied_at REAL NOT NULL,
                last_copied_at REAL NOT NULL,
                copy_count INTEGER NOT NULL DEFAULT 1
            );
            CREATE INDEX IF NOT EXISTS clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts USING fts5(
                text, content='clips', content_rowid='id',
                tokenize='unicode61 remove_diacritics 2'
            );
            CREATE TRIGGER IF NOT EXISTS clips_ai AFTER INSERT ON clips BEGIN
                INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text);
            END;
            CREATE TRIGGER IF NOT EXISTS clips_ad AFTER DELETE ON clips BEGIN
                INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text);
            END;
            """)
    }

    // MARK: SQLite helpers

    private func query(_ sql: String, limit: Int, match: String? = nil) throws -> [StoredClip] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        if let match { bind(match, at: 2, in: stmt) }

        var clips: [StoredClip] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw lastError() }
            clips.append(StoredClip(
                id: sqlite3_column_int64(stmt, 0),
                text: String(cString: sqlite3_column_text(stmt, 1)),
                sourceBundleIdentifier: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                firstCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                lastCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                copyCount: Int(sqlite3_column_int64(stmt, 5))
            ))
        }
        return clips
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw lastError() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw lastError() }
        return stmt
    }

    private func bind(_ value: String?, at index: Int32, in stmt: OpaquePointer) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func lastError() -> ClipStoreError {
        ClipStoreError(code: sqlite3_errcode(db), message: String(cString: sqlite3_errmsg(db)))
    }
}
