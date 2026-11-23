import Foundation
import SQLite3

// Text recognised in pictures, so a screenshot can be found by the words in it.
extension ClipStore {
    /// Stores the text found in a picture clip. An empty string means "looked at, nothing there", so the picture is
    /// not queued again. Ignores ids that do not exist or are not pictures.
    public func setOCRText(id: Int64, _ text: String) throws {
        let stmt = try prepare("UPDATE clips SET ocr_text = ?2 WHERE id = ?1 AND kind = 'image'")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        bind(text, at: 2, in: stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError() }
    }

    /// The recognised text of a picture, nil while it has not been looked at.
    public func recognisedText(id: Int64) throws -> String? {
        let stmt = try prepare("SELECT ocr_text FROM clips WHERE id = ?1")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW, let pointer = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: pointer)
    }

    /// Pictures nobody has looked at yet, newest first: the one just copied is the one to find next.
    public func picturesWithoutRecognisedText(limit: Int) throws -> [Int64] {
        let stmt = try prepare("""
            SELECT id FROM clips WHERE kind = 'image' AND ocr_text IS NULL
            ORDER BY last_copied_at DESC, id DESC LIMIT ?1
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(max(limit, 0)))
        var ids: [Int64] = []
        while sqlite3_step(stmt) == SQLITE_ROW { ids.append(sqlite3_column_int64(stmt, 0)) }
        return ids
    }
}
