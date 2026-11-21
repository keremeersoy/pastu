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
    public let isPinned: Bool
    /// `.image` for pictures; for text clips computed from the text (text or link).
    public let kind: ClipKind
}

/// How much history to keep. `nil` means "no limit" for that dimension.
public struct RetentionPolicy: Equatable, Sendable {
    public var maxCount: Int?
    public var maxAge: TimeInterval?
    /// Cap on the estimated database size (see `ClipStore.estimatedSizeInBytes()`). Default 200 MB.
    public var maxTotalBytes: Int?

    public init(
        maxCount: Int? = 5_000,
        maxAge: TimeInterval? = 90 * 24 * 3600,
        maxTotalBytes: Int? = 200 * 1024 * 1024
    ) {
        self.maxCount = maxCount
        self.maxAge = maxAge
        self.maxTotalBytes = maxTotalBytes
    }
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
        if let path { try Self.secureFile(at: path) }
        let rc = sqlite3_open_v2(path ?? ":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard rc == SQLITE_OK else {
            let error = ClipStoreError(code: rc, message: db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed")
            sqlite3_close(db)
            throw error
        }
        try registerFunctions()
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: Public API

    /// Inserts a clip, or merges it into the existing row when the same text was copied before.
    @discardableResult
    public func insert(_ clip: CapturedClip) throws -> Int64 {
        let stmt = try prepare("""
            INSERT INTO clips (text, source_bundle_id, first_copied_at, last_copied_at, kind, image)
            VALUES (?1, ?2, ?3, ?3, ?4, ?5)
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
        bind(clip.imagePNG == nil ? "text" : "image", at: 4, in: stmt)
        bind(blob: clip.imagePNG, at: 5, in: stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw lastError() }
        let id = sqlite3_column_int64(stmt, 0)
        // Drain so the statement completes before finalize.
        while sqlite3_step(stmt) == SQLITE_ROW {}
        return id
    }

    /// Pinned first, then newest. `kind` restricts the result to text or links; it applies before `limit`.
    /// The PNG bytes of an image clip, or nil for text clips and unknown ids.
    /// Kept out of the list queries on purpose: pictures can be megabytes and the list only needs metadata.
    public func imageData(id: Int64) throws -> Data? {
        let stmt = try prepare("SELECT image FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
    }

    public func recent(limit: Int = 50, kind: ClipKind? = nil) throws -> [StoredClip] {
        try query("""
            SELECT c.id, c.text, c.source_bundle_id, c.first_copied_at, c.last_copied_at, c.copy_count, c.pinned, c.kind
            FROM clips c
            WHERE \(Self.kindCondition(kind))
            ORDER BY c.pinned DESC, c.last_copied_at DESC, c.id DESC LIMIT ?1
            """, limit: limit)
    }

    /// SQL for the kind filter. Text and links use `pastu_is_link`, which calls `ClipKind.detect`, so the
    /// filter and the Swift-side `StoredClip.kind` can never disagree; images are marked by the `kind` column.
    private static func kindCondition(_ kind: ClipKind?) -> String {
        switch kind {
        case nil: "1"
        case .link?: "c.kind = 'text' AND pastu_is_link(c.text) = 1"
        case .text?: "c.kind = 'text' AND pastu_is_link(c.text) = 0"
        case .image?: "c.kind = 'image'"
        }
    }

    /// Substring search: every term must appear somewhere in the text (any position, any case,
    /// accents ignored). Pinned clips first, then newest. Punctuation is searchable too ("://").
    ///
    /// Terms of 3+ characters use the trigram index. Shorter terms cannot (a trigram needs 3 characters),
    /// so they are checked with `instr`, which is only case-insensitive for ASCII letters.
    public func search(_ query: String, limit: Int = 50, kind: ClipKind? = nil) throws -> [StoredClip] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        if terms.isEmpty { return try recent(limit: limit, kind: kind) }

        let indexed = terms.filter { $0.count >= 3 }
        let short = terms.filter { $0.count < 3 }

        var conditions: [String] = [Self.kindCondition(kind)]
        var binds: [String] = []
        let source: String
        if indexed.isEmpty {
            source = "clips c"
        } else {
            source = "clips_fts f JOIN clips c ON c.id = f.rowid"
            conditions.append("clips_fts MATCH ?\(binds.count + 2)")
            binds.append(Self.ftsMatchExpression(for: indexed))
        }
        for term in short {
            conditions.append("instr(lower(c.text), lower(?\(binds.count + 2))) > 0")
            binds.append(term)
        }

        return try self.query("""
            SELECT c.id, c.text, c.source_bundle_id, c.first_copied_at, c.last_copied_at, c.copy_count, c.pinned, c.kind
            FROM \(source)
            WHERE \(conditions.joined(separator: " AND "))
            ORDER BY c.pinned DESC, c.last_copied_at DESC, c.id DESC LIMIT ?1
            """, limit: limit, binds: binds)
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

    /// Deletes clips outside the policy: first the ones older than `maxAge`, then everything beyond
    /// the newest `maxCount`. Pinned clips are never deleted and do not count against `maxCount`.
    /// Returns how many were deleted.
    @discardableResult
    public func prune(_ policy: RetentionPolicy, now: Date = Date()) throws -> Int {
        try exec("BEGIN")
        do {
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
            try exec("COMMIT")
            return removed
        } catch {
            try? exec("ROLLBACK")
            throw error
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
            SELECT COALESCE(SUM(LENGTH(CAST(text AS BLOB))), 0), COALESCE(SUM(LENGTH(image)), 0) FROM clips
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
            SELECT id, LENGTH(CAST(text AS BLOB)), COALESCE(LENGTH(image), 0)
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

    /// Pinned clips stay on top of the list and are never pruned. Pinning is not a copy: it changes nothing else.
    public func setPinned(id: Int64, _ pinned: Bool) throws {
        let stmt = try prepare("UPDATE clips SET pinned = ?2 WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_bind_int64(stmt, 2, pinned ? 1 : 0)
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

    /// The history may contain sensitive text, so the database file is readable by the owner only.
    /// Created (or tightened) before SQLite opens it; SQLite gives its -wal/-shm files the same mode.
    private static func secureFile(at path: String) throws {
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: path),
               !fm.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o600]) {
                throw ClipStoreError(code: -1, message: "could not create \(path)")
            }
            // Also tighten sidecars left over from an older, looser run: SQLite never changes their mode.
            for file in [path, path + "-wal", path + "-shm"] where fm.fileExists(atPath: file) {
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file)
            }
        } catch let error as ClipStoreError {
            throw error
        } catch {
            throw ClipStoreError(code: -1, message: "could not restrict permissions of \(path): \(error.localizedDescription)")
        }
    }

    // MARK: Search query building

    /// Turns search terms into a safe FTS5 expression: each term becomes a quoted phrase, so characters
    /// like `"`, `(` or `*` can never cause a syntax error. With the trigram index a phrase is a substring.
    static func ftsMatchExpression(for terms: [String]) -> String {
        terms.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: " ")
    }

    // MARK: SQL functions

    /// `pastu_is_link(text)`: 1 when `ClipKind.detect(text)` is `.link`, else 0.
    private func registerFunctions() throws {
        let rc = sqlite3_create_function_v2(
            db, "pastu_is_link", 1, SQLITE_UTF8 | SQLITE_DETERMINISTIC, nil,
            { context, argc, argv in
                guard argc == 1, let argv, let raw = sqlite3_value_text(argv[0]) else {
                    sqlite3_result_int(context, 0)
                    return
                }
                sqlite3_result_int(context, ClipKind.detect(String(cString: raw)) == .link ? 1 : 0)
            },
            nil, nil, nil
        )
        guard rc == SQLITE_OK else { throw lastError() }
    }

    // MARK: Schema

    private func migrate() throws {
        // Deleted clips must not linger in free pages: overwrite them (the system SQLite only does so by
        // default on some builds, so ask for it explicitly).
        try exec("PRAGMA secure_delete = ON")
        // `text` is never updated in place, so the FTS index needs only insert/delete triggers.
        try exec("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL UNIQUE,
                source_bundle_id TEXT,
                first_copied_at REAL NOT NULL,
                last_copied_at REAL NOT NULL,
                copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0,
                kind TEXT NOT NULL DEFAULT 'text',
                image BLOB
            );
            CREATE INDEX IF NOT EXISTS clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts USING fts5(
                text, content='clips', content_rowid='id',
                tokenize='trigram remove_diacritics 1'
            );
            CREATE TRIGGER IF NOT EXISTS clips_ai AFTER INSERT ON clips BEGIN
                INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text);
            END;
            CREATE TRIGGER IF NOT EXISTS clips_ad AFTER DELETE ON clips BEGIN
                INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text);
            END;
            """)

        // Versioned upgrades for databases created by older builds. Each step must be safe to re-run.
        if try userVersion() < 1 {
            // v1: pins. Databases from before pins have no `pinned` column.
            if !(try columnExists("pinned", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
            }
            try exec("PRAGMA user_version = 1")
        }
        if try userVersion() < 2 {
            // v2: substring search. Databases with the old word-based index get a trigram index,
            // rebuilt from the clips table (the text itself is untouched).
            if try ftsUsesWordTokenizer() {
                try exec("""
                    BEGIN;
                    DROP TABLE clips_fts;
                    CREATE VIRTUAL TABLE clips_fts USING fts5(
                        text, content='clips', content_rowid='id',
                        tokenize='trigram remove_diacritics 1'
                    );
                    INSERT INTO clips_fts (clips_fts) VALUES ('rebuild');
                    COMMIT;
                    """)
            }
            try exec("PRAGMA user_version = 2")
        }
        if try userVersion() < 3 {
            // v3: images. Existing rows are text; the PNG bytes live in the same row but are never selected by the list queries.
            if !(try columnExists("kind", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'")
            }
            if !(try columnExists("image", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN image BLOB")
            }
            try exec("PRAGMA user_version = 3")
        }
    }

    private func ftsUsesWordTokenizer() throws -> Bool {
        let stmt = try prepare("SELECT sql FROM sqlite_master WHERE name = 'clips_fts'")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let sql = sqlite3_column_text(stmt, 0) else { return false }
        return String(cString: sql).contains("unicode61")
    }

    private func userVersion() throws -> Int {
        let stmt = try prepare("PRAGMA user_version")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw lastError() }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func columnExists(_ column: String, in table: String) throws -> Bool {
        let stmt = try prepare("SELECT 1 FROM pragma_table_info(?1) WHERE name = ?2")
        defer { sqlite3_finalize(stmt) }
        bind(table, at: 1, in: stmt)
        bind(column, at: 2, in: stmt)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    // MARK: SQLite helpers

    /// Runs a clip query. `?1` is the limit; `binds` fill `?2`, `?3`, … in order.
    private func query(_ sql: String, limit: Int, binds: [String] = []) throws -> [StoredClip] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        for (offset, value) in binds.enumerated() { bind(value, at: Int32(offset + 2), in: stmt) }

        var clips: [StoredClip] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw lastError() }
            let text = Self.columnString(stmt, 1) ?? ""
            let kind: ClipKind = Self.columnString(stmt, 7) == "image" ? .image : ClipKind.detect(text)
            clips.append(StoredClip(
                id: sqlite3_column_int64(stmt, 0),
                text: text,
                sourceBundleIdentifier: Self.columnString(stmt, 2),
                firstCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                lastCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                copyCount: Int(sqlite3_column_int64(stmt, 5)),
                isPinned: sqlite3_column_int64(stmt, 6) != 0,
                kind: kind
            ))
        }
        return clips
    }

    /// Reads a text column by byte length, so embedded NULs survive. `nil` for SQL NULL.
    private static func columnString(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(stmt, index) else { return nil }
        let count = Int(sqlite3_column_bytes(stmt, index))
        return String(decoding: UnsafeBufferPointer(start: pointer, count: count), as: UTF8.self)
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
            // Explicit byte length: with -1 SQLite stops at the first NUL and would silently truncate the text.
            sqlite3_bind_text(stmt, index, value, Int32(value.utf8.count), Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bind(blob: Data?, at index: Int32, in stmt: OpaquePointer) {
        guard let blob else { sqlite3_bind_null(stmt, index); return }
        blob.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(stmt, index, raw.baseAddress, Int32(blob.count), Self.transient)
        }
    }

    private func lastError() -> ClipStoreError {
        ClipStoreError(code: sqlite3_errcode(db), message: String(cString: sqlite3_errmsg(db)))
    }
}
