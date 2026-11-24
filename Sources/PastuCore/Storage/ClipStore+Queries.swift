import Foundation
import SQLite3

// Reading clips: the list, search and picture bytes.
extension ClipStore {
    /// The PNG bytes of an image clip, or nil for text clips and unknown ids.
    /// Kept out of the list queries on purpose: pictures can be megabytes and the list only needs metadata.
    public func imageData(id: Int64) throws -> Data? {
        let stmt = try prepare("SELECT image FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
    }

    /// The RTF/HTML stored with a text clip, or nil when it has none. Kept out of the list queries like picture bytes.
    public func richContent(id: Int64) throws -> RichContent? {
        let stmt = try prepare("SELECT rtf, html FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        func blob(_ column: Int32) -> Data? {
            guard let bytes = sqlite3_column_blob(stmt, column) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, column)))
        }
        let rich = RichContent(rtf: blob(0), html: blob(1))
        return rich.rtf == nil && rich.html == nil ? nil : rich
    }

    /// Pinned first, then newest. `kind` restricts the result to text, links or images; it applies before `limit`.
    /// `offset` skips that many rows so the panel can load the list in pages.
    public func recent(limit: Int = 50, offset: Int = 0, kind: ClipKind? = nil) throws -> [StoredClip] {
        try query("""
            SELECT c.id, c.text, c.source_bundle_id, c.first_copied_at, c.last_copied_at, c.copy_count, c.pinned, c.kind,
                   (c.rtf IS NOT NULL OR c.html IS NOT NULL)
            FROM clips c
            WHERE \(Self.kindCondition(kind))
            ORDER BY c.pinned DESC, c.last_copied_at DESC, c.id DESC LIMIT ?1 OFFSET ?2
            """, limit: limit, offset: offset)
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
    public func search(_ query: String, limit: Int = 50, offset: Int = 0, kind: ClipKind? = nil) throws -> [StoredClip] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        if terms.isEmpty { return try recent(limit: limit, offset: offset, kind: kind) }

        let indexed = terms.filter { $0.count >= 3 }
        let short = terms.filter { $0.count < 3 }

        var conditions: [String] = [Self.kindCondition(kind)]
        var binds: [String] = []
        let source: String
        if indexed.isEmpty {
            source = "clips c"
        } else {
            source = "clips_fts f JOIN clips c ON c.id = f.rowid"
            conditions.append("clips_fts MATCH ?\(binds.count + 3)")
            binds.append(Self.ftsMatchExpression(for: indexed))
        }
        for term in short {
            // Pictures also match on the text recognised in them.
            let slot = binds.count + 3
            conditions.append("(instr(lower(c.text), lower(?\(slot))) > 0 OR instr(lower(COALESCE(c.ocr_text, '')), lower(?\(slot))) > 0)")
            binds.append(term)
        }

        return try self.query("""
            SELECT c.id, c.text, c.source_bundle_id, c.first_copied_at, c.last_copied_at, c.copy_count, c.pinned, c.kind,
                   (c.rtf IS NOT NULL OR c.html IS NOT NULL)
            FROM \(source)
            WHERE \(conditions.joined(separator: " AND "))
            ORDER BY c.pinned DESC, c.last_copied_at DESC, c.id DESC LIMIT ?1 OFFSET ?2
            """, limit: limit, offset: offset, binds: binds)
    }

    /// Turns search terms into a safe FTS5 expression: each term becomes a quoted phrase, so characters
    /// like `"`, `(` or `*` can never cause a syntax error. With the trigram index a phrase is a substring.
    static func ftsMatchExpression(for terms: [String]) -> String {
        terms.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: " ")
    }

    /// Runs a clip query. `?1` is the limit, `?2` the offset (negative values count as 0); `binds` fill `?3`, `?4`, … in order.
    private func query(_ sql: String, limit: Int, offset: Int, binds: [String] = []) throws -> [StoredClip] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))
        sqlite3_bind_int64(stmt, 2, Int64(max(0, offset)))
        for (index, value) in binds.enumerated() { bind(value, at: Int32(index + 3), in: stmt) }

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
                kind: kind,
                hasFormatting: sqlite3_column_int64(stmt, 8) != 0
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
}
