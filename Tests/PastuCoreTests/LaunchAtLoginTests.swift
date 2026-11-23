import Foundation
import Observation
import Testing
@testable import PastuCore

/// Stands in for `SMAppService`: tests must never register the real app as a login item.
@MainActor
final class FakeLoginItem: LoginItemService {
    struct Failure: Error {}
    var status: LoginItemStatus
    var failNext = false
    var registerCalls = 0
    var unregisterCalls = 0
    /// What the system reports after a successful `register()`; macOS may ask for approval instead.
    var statusAfterRegister: LoginItemStatus = .enabled

    init(status: LoginItemStatus = .disabled) { self.status = status }

    func register() throws {
        registerCalls += 1
        if failNext { failNext = false; throw Failure() }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        if failNext { failNext = false; throw Failure() }
        status = .disabled
    }
}

@MainActor
@Suite struct LaunchAtLoginTests {
    @Test func startsWithTheSystemStatus() {
        #expect(LaunchAtLogin(service: FakeLoginItem(status: .disabled)).isOn == false)
        #expect(LaunchAtLogin(service: FakeLoginItem(status: .enabled)).isOn == true)
    }

    @Test func turningItOnRegistersTheApp() {
        let service = FakeLoginItem()
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(true)
        #expect(service.registerCalls == 1)
        #expect(setting.isOn)
        #expect(setting.errorMessage == nil)
    }

    @Test func turningItOffUnregistersTheApp() {
        let service = FakeLoginItem(status: .enabled)
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(false)
        #expect(service.unregisterCalls == 1)
        #expect(!setting.isOn)
    }

    @Test func doesNothingWhenAlreadyInTheWantedState() {
        let service = FakeLoginItem(status: .enabled)
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(true)
        #expect(service.registerCalls == 0)
        let off = FakeLoginItem(status: .disabled)
        LaunchAtLogin(service: off).setEnabled(false)
        #expect(off.unregisterCalls == 0)
    }

    /// macOS can hold a new login item until the user approves it in System Settings.
    @Test func approvalPendingCountsAsOnAndSaysSo() {
        let service = FakeLoginItem()
        service.statusAfterRegister = .requiresApproval
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(true)
        #expect(setting.isOn)
        #expect(setting.needsApproval)
        #expect(setting.errorMessage == nil)
    }

    @Test func aFailedRegisterLeavesItOffAndExplainsWhy() {
        let service = FakeLoginItem()
        service.failNext = true
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(true)
        #expect(!setting.isOn)
        #expect(setting.errorMessage == "Pastu couldn't be added to your login items.")
    }

    @Test func aFailedUnregisterKeepsItOnAndExplainsWhy() {
        let service = FakeLoginItem(status: .enabled)
        service.failNext = true
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(false)
        #expect(setting.isOn)
        #expect(setting.errorMessage == "Pastu couldn't be removed from your login items.")
    }

    @Test func theMessageGoesAwayAfterTheNextSuccess() {
        let service = FakeLoginItem()
        service.failNext = true
        let setting = LaunchAtLogin(service: service)
        setting.setEnabled(true)
        setting.setEnabled(true)
        #expect(setting.errorMessage == nil)
        #expect(setting.isOn)
    }

    /// The user can flip the switch in System Settings while the window is open.
    @Test func refreshPicksUpChangesMadeElsewhere() {
        let service = FakeLoginItem()
        let setting = LaunchAtLogin(service: service)
        service.status = .enabled
        setting.refresh()
        #expect(setting.isOn)
    }

    @Test func anUnavailableServiceCannotBeSwitched() {
        let service = FakeLoginItem(status: .unavailable)
        let setting = LaunchAtLogin(service: service)
        #expect(!setting.isAvailable)
        setting.setEnabled(true)
        #expect(service.registerCalls == 0)
    }

    @Test func statusIsObservable() {
        let setting = LaunchAtLogin(service: FakeLoginItem())
        let changes = ChangeCounter()
        withObservationTracking { _ = setting.status } onChange: { changes.count += 1 }
        setting.setEnabled(true)
        #expect(changes.count == 1)
    }
}
