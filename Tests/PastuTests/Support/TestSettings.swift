import PastuCore
@testable import Pastu

/// Stands in for `SMAppService`: tests must never register the real app as a login item.
@MainActor
final class StubLoginItem: LoginItemService {
    var status: LoginItemStatus
    init(status: LoginItemStatus = .disabled) { self.status = status }
    func register() throws { status = .enabled }
    func unregister() throws { status = .disabled }
}

extension AppSettings {
    /// Settings that live in memory only: no UserDefaults, no login item, no system-wide hotkey.
    static func inMemory(
        loginStatus: LoginItemStatus = .disabled,
        registerHotKey: @escaping @MainActor (HotKeyCombo) -> Bool = { _ in true }
    ) -> AppSettings {
        AppSettings(store: InMemorySettings(), loginItem: StubLoginItem(status: loginStatus), registerHotKey: registerHotKey)
    }
}
