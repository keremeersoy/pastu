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
    /// The full paths of a file clip, in the order they were copied; empty for every other kind.
    public internal(set) var files: [String] = []
    /// True when the clip was copied with RTF or HTML formatting that can be pasted back.
    public internal(set) var hasFormatting: Bool = false
}

extension StoredClip {
    /// What the panel shows for a file clip: the file names, without their folders.
    public var fileNames: [String] { files.map { ($0 as NSString).lastPathComponent } }
}

/// The formatting stored with a text clip.
public struct RichContent: Equatable, Sendable {
    public let rtf: Data?
    public let html: Data?
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

/// A failed SQLite call. Carries SQLite's own message, which never includes clip text, so it is safe to log.
public struct ClipStoreError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String
    public var description: String { "SQLite error \(code): \(message)" }
}

/// Local history storage: SQLite with an FTS5 full-text index. Everything stays on disk, no network.
///
/// Not thread-safe; use it from a single actor/queue (the app uses the main actor for now).
public final class ClipStore {
    // `private(set)` rather than `private`: the extensions in ClipStore+*.swift read it.
    private(set) var db: OpaquePointer?
    static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
            INSERT INTO clips (text, source_bundle_id, first_copied_at, last_copied_at, kind, image, rtf, html, files, ocr_text)
            VALUES (?1, ?2, ?3, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            ON CONFLICT(text) DO UPDATE SET
                last_copied_at = excluded.last_copied_at,
                copy_count = copy_count + 1,
                source_bundle_id = COALESCE(excluded.source_bundle_id, source_bundle_id),
                rtf = CASE WHEN excluded.rtf IS NOT NULL OR excluded.html IS NOT NULL THEN excluded.rtf ELSE rtf END,
                html = CASE WHEN excluded.rtf IS NOT NULL OR excluded.html IS NOT NULL THEN excluded.html ELSE html END
            RETURNING id
            """)
        defer { sqlite3_finalize(stmt) }
        bind(clip.text, at: 1, in: stmt)
        bind(clip.sourceBundleIdentifier, at: 2, in: stmt)
        sqlite3_bind_double(stmt, 3, clip.date.timeIntervalSince1970)
        bind(clip.files != nil ? "file" : (clip.imagePNG == nil ? "text" : "image"), at: 4, in: stmt)
        bind(blob: clip.imagePNG, at: 5, in: stmt)
        bind(blob: clip.rtf, at: 6, in: stmt)
        bind(blob: clip.html, at: 7, in: stmt)
        // The paths, so the files can be put back; and the names, which is what search looks at.
        bind(clip.files.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }, at: 8, in: stmt)
        bind(clip.files.map { $0.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ") }, at: 9, in: stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw lastError() }
        let id = sqlite3_column_int64(stmt, 0)
        // Drain so the statement completes before finalize.
        while sqlite3_step(stmt) == SQLITE_ROW {}
        return id
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

    /// Pinned clips stay on top of the list and are never pruned. Pinning is not a copy: it changes nothing else.
    public func setPinned(id: Int64, _ pinned: Bool) throws {
        let stmt = try prepare("UPDATE clips SET pinned = ?2 WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_bind_int64(stmt, 2, pinned ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
    }

    /// Removes one clip (⌘⌫ in the panel). With `secure_delete` on, its text is overwritten on disk.
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

    // MARK: SQLite helpers

    func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw lastError() }
    }

    /// Runs `body` in one transaction: all of it happens, or (if it throws) none of it. Used by every multi-statement
    /// change, so a failure never leaves a transaction open or the database half changed.
    @discardableResult
    func inTransaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN")
        do {
            let result = try body()
            try exec("COMMIT")
            return result
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw lastError() }
        return stmt
    }

    func bind(_ value: String?, at index: Int32, in stmt: OpaquePointer) {
        if let value {
            // Explicit byte length: with -1 SQLite stops at the first NUL and would silently truncate the text.
            sqlite3_bind_text(stmt, index, value, Int32(value.utf8.count), Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    func bind(blob: Data?, at index: Int32, in stmt: OpaquePointer) {
        guard let blob else { sqlite3_bind_null(stmt, index); return }
        blob.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(stmt, index, raw.baseAddress, Int32(blob.count), Self.transient)
        }
    }

    func lastError() -> ClipStoreError {
        ClipStoreError(code: sqlite3_errcode(db), message: String(cString: sqlite3_errmsg(db)))
    }
}
