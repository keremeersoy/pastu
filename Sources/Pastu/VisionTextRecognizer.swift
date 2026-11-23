import Foundation
import PastuCore
import Vision

/// Apple's on-device text recognition. Runs off the main thread at low priority; nothing leaves the Mac.
struct VisionTextRecognizer: TextRecognizer {
    func recognizeText(in png: Data) async -> String? {
        await Task.detached(priority: .utility) { () -> String? in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            do {
                try VNImageRequestHandler(data: png).perform([request])
            } catch {
                return nil
            }
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }
}
