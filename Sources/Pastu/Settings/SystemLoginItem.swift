import PastuCore
import ServiceManagement

/// The real login item: this app, registered through `SMAppService`. Not used in tests.
@MainActor
final class SystemLoginItem: LoginItemService {
    private var service: SMAppService { .mainApp }

    var status: LoginItemStatus {
        switch service.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
