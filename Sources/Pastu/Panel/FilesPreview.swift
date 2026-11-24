import PastuCore
import SwiftUI

/// The preview of a file clip: each file with Finder's icon, its name, and the folder it is in. A file that has been
/// moved or deleted since is marked, because pasting it will leave it out.
struct FilesPreview: View {
    /// A long selection is cut here (the clip itself keeps every path); the rest is a count.
    static let visibleLimit = 50

    let clip: StoredClip

    var body: some View {
        let shown = Array(clip.files.prefix(Self.visibleLimit))
        ScrollView {
            // At most `visibleLimit` rows, so there is no need for a lazy stack (which would also hide the count below).
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, path in
                    FileEntryRow(path: path)
                }
                if clip.files.count > shown.count {
                    Text("… and \(clip.files.count - shown.count) more")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FileEntryRow: View {
    let path: String
    private let exists: Bool

    init(path: String) {
        self.path = path
        exists = FileManager.default.fileExists(atPath: path)
    }

    private var name: String { (path as NSString).lastPathComponent }
    private var folder: String { ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: FileIcons.icon(forPath: path))
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(exists ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.body)
                    .strikethrough(!exists)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(exists ? folder : "Missing · \(folder)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exists ? "\(name), \(folder)" : "\(name), missing, \(folder)")
    }
}
