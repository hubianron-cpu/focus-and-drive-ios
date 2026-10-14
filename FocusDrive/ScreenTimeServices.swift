import FamilyControls
import ManagedSettings
import Foundation

@MainActor
final class ScreenTimeAuthorization: SessionAuthorizing {
    var isApproved: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }

    func requestIndividualAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}

@MainActor
final class DrivingShieldStore {
    // Never use the default store or clear another named store.
    private let store = ManagedSettingsStore(named: .init("FocusDrive.driving"))

    func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens
        // Apple's setter neither throws nor acknowledges effective enforcement.
    }

    func clear() {
        store.clearAllSettings()
    }
}

@MainActor
final class UserDefaultsSessionPersistence: SessionPersisting {
    private let defaults: UserDefaults
    private let key = "FocusDrive.session.v2"
    private let legacySelectionKey = "FocusDrive.selection.v1"
    private let legacyActiveKey = "FocusDrive.active.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> Data? {
        if let data = defaults.data(forKey: key) { return data }
        // Preserve existing users' selection and intent; the coordinator validates both.
        guard defaults.object(forKey: legacySelectionKey) != nil
                || defaults.object(forKey: legacyActiveKey) != nil else { return nil }
        let selection = try defaults.data(forKey: legacySelectionKey).map {
            try JSONDecoder().decode(FamilyActivitySelection.self, from: $0)
        }
        let snapshot = SessionSnapshot(selection: selection, requested: defaults.bool(forKey: legacyActiveKey))
        let data = try JSONEncoder().encode(snapshot)
        try save(data)
        return data
    }

    func save(_ data: Data) throws {
        defaults.set(data, forKey: key)
        defaults.removeObject(forKey: legacySelectionKey)
        defaults.removeObject(forKey: legacyActiveKey)
        // UserDefaults provides no durable-disk acknowledgement; do not call synchronize().
    }

    func remove() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: legacySelectionKey)
        defaults.removeObject(forKey: legacyActiveKey)
    }
}
