import Foundation
import SQLite3

// Creating the schema and upgrading databases written by older builds.
extension ClipStore {
    func migrate() throws {
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
                try inTransaction {
                    try exec("""
                        DROP TABLE clips_fts;
                        CREATE VIRTUAL TABLE clips_fts USING fts5(
                            text, content='clips', content_rowid='id',
                            tokenize='trigram remove_diacritics 1'
                        );
                        INSERT INTO clips_fts (clips_fts) VALUES ('rebuild');
                        """)
                }
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
        if try userVersion() < 4 {
            // v4: text recognised in pictures. The full-text index now covers a second column, so it is rebuilt
            // together with its triggers (the clips themselves are untouched). Pictures already in the history
            // have NULL there, which means "not looked at yet".
            if !(try columnExists("ocr_text", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN ocr_text TEXT")
            }
            try inTransaction {
                try exec("""
                DROP TRIGGER IF EXISTS clips_ai;
                DROP TRIGGER IF EXISTS clips_ad;
                DROP TRIGGER IF EXISTS clips_au;
                DROP TABLE IF EXISTS clips_fts;
                CREATE VIRTUAL TABLE clips_fts USING fts5(
                    text, ocr_text, content='clips', content_rowid='id',
                    tokenize='trigram remove_diacritics 1'
                );
                CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN
                    INSERT INTO clips_fts (rowid, text, ocr_text) VALUES (new.id, new.text, new.ocr_text);
                END;
                CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN
                    INSERT INTO clips_fts (clips_fts, rowid, text, ocr_text) VALUES ('delete', old.id, old.text, old.ocr_text);
                END;
                CREATE TRIGGER clips_au AFTER UPDATE OF ocr_text ON clips BEGIN
                    INSERT INTO clips_fts (clips_fts, rowid, text, ocr_text) VALUES ('delete', old.id, old.text, old.ocr_text);
                    INSERT INTO clips_fts (rowid, text, ocr_text) VALUES (new.id, new.text, new.ocr_text);
                END;
                INSERT INTO clips_fts (clips_fts) VALUES ('rebuild');
                """)
            }
            try exec("PRAGMA user_version = 4")
        }
        if try userVersion() < 5 {
            // v5: formatting. Text clips keep the RTF and HTML flavours they were copied with (NULL when the source
            // offered none), so "paste with formatting" can put them back. Never indexed or searched.
            if !(try columnExists("rtf", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN rtf BLOB")
            }
            if !(try columnExists("html", in: "clips")) {
                try exec("ALTER TABLE clips ADD COLUMN html BLOB")
            }
            try exec("PRAGMA user_version = 5")
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
}
