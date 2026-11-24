import Foundation

/// Finds the text in a picture. The app uses Apple Vision; tests use a fake. Never touches the network.
public protocol TextRecognizer: Sendable {
    /// The text in the picture, an empty string when there is none, nil when recognition itself failed.
    func recognizeText(in png: Data) async -> String?
}

/// Reads the text in picture clips, one at a time in the background, and stores it so the pictures can be found by
/// their words. The database is read and written here, on the main actor; only the recognition runs elsewhere.
@MainActor
public final class PictureIndexer {
    /// Recognised text is cut here, so a screenshot of a whole document cannot bloat the database.
    public static let maxCharacters = 20_000

    private let store: ClipStore
    private let recognizer: TextRecognizer
    private let isEnabled: () -> Bool
    private let onIndexed: @MainActor () -> Void

    private var queue: [Int64] = []
    private var queued: Set<Int64> = []
    private var worker: Task<Void, Never>?

    /// - Parameter isEnabled: read before every picture; false leaves pictures waiting.
    /// - Parameter onIndexed: called after a picture's text was stored (the panel refreshes its list).
    public init(
        store: ClipStore, recognizer: TextRecognizer, isEnabled: @escaping () -> Bool,
        onIndexed: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.recognizer = recognizer
        self.isEnabled = isEnabled
        self.onIndexed = onIndexed
    }

    /// A picture was just copied.
    public func enqueue(_ clipID: Int64) {
        guard queued.insert(clipID).inserted else { return }
        queue.append(clipID)
        startWorkerIfNeeded()
    }

    /// Queues every picture nobody has looked at yet, newest first (those from before this feature, or from a time
    /// it was switched off).
    public func catchUp(limit: Int = 500) {
        for id in (try? store.picturesWithoutRecognisedText(limit: limit)) ?? [] { enqueue(id) }
    }

    /// Returns once everything queued so far has been handled; for tests.
    public func waitUntilIdle() async {
        while let worker { await worker.value }
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { @MainActor [weak self] in
            await self?.work()
            self?.worker = nil
        }
    }

    private func work() async {
        while !queue.isEmpty {
            let id = queue.removeFirst()
            queued.remove(id)
            await index(id)
        }
    }

    private func index(_ id: Int64) async {
        guard isEnabled() else { return }
        // Skipped when it was handled already (the same picture queued by a catch-up and by a new copy) or is gone.
        guard (try? store.recognisedText(id: id)) == nil, let png = (try? store.imageData(id: id)) ?? nil else { return }
        guard let text = await recognizer.recognizeText(in: png) else { return }   // failed: stays pending
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxCharacters))
        do {
            try store.setOCRText(id: id, trimmed)
            onIndexed()
        } catch {
            NSLog("Pastu could not store the text of a picture: \(error)")
        }
    }
}
