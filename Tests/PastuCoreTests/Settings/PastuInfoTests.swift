import Foundation
import Testing
@testable import PastuCore

@Test func appNameIsPastu() {
    #expect(PastuInfo.name == "Pastu")
}

/// The identity lives in two places (the app's Info.plist and `PastuInfo`); they must never drift apart.
@Suite struct BundleIdentityTests {
    private func infoPlist() throws -> [String: Any] {
        // Walk up from this file to the repository root (the folder with Package.swift), however deep it sits.
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path), root.path != "/" {
            root = root.deletingLastPathComponent()
        }
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func infoPlistAndPastuInfoAgreeOnTheBundleIdentifier() throws {
        #expect(try infoPlist()["CFBundleIdentifier"] as? String == PastuInfo.bundleIdentifier)
    }

    @Test func bundleIdentifierIsReverseDNSOfADomainTheProjectControls() {
        let id = PastuInfo.bundleIdentifier
        #expect(id.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$"#, options: .regularExpression) != nil)
        // pastu.dev is not owned by the project, so no identifier may pretend to be under it.
        #expect(!id.lowercased().hasPrefix("dev.pastu"))
    }
}
