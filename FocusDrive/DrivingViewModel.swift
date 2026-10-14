import SwiftUI
import FamilyControls
import ManagedSettings
import Combine

@MainActor
final class DrivingViewModel: ObservableObject {
    @Published private(set) var isDriving = false
    @Published private(set) var authorization: AuthorizationStatus = .notDetermined
    @Published private(set) var isRequesting = false
    @Published var message: String?
    @Published private(set) var selection = FamilyActivitySelection()

    private let store = ManagedSettingsStore(named: .init("FocusDrive.driving"))
    private let defaults = UserDefaults.standard
    private let selectionKey = "FocusDrive.selection.v1"
    private let activeKey = "FocusDrive.active.v1"
    private var authorizationObserver: AnyCancellable?

    init() {
        if let data = defaults.data(forKey: selectionKey) {
            do {
                selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                message = "לא ניתן לשחזר את הבחירה. יש לבחור יישומים מחדש כשחונים בבטחה."
                defaults.removeObject(forKey: selectionKey)
                defaults.set(false, forKey: activeKey)
            }
        }
        isDriving = defaults.bool(forKey: activeKey)
        reconcile()
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    // Revocation voids existing tokens. Process the emitted status even if
                    // another authorization change occurs before this task executes.
                    if status != .approved { self?.invalidateSelection() }
                    self?.reconcile()
                }
            }
    }

    var hasValidSelection: Bool {
        !selection.applicationTokens.isEmpty && selection.applicationTokens.count <= 50
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    func requestAuthorization() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            message = nil
        } catch {
            message = "ההרשאה לא ניתנה. לא ניתן להפעיל הגבלות ללא הרשאת זמן מסך. ניתן לבדוק את ההרשאה בהגדרות."
        }
        reconcile()
    }

    func saveSelection(_ proposedSelection: FamilyActivitySelection) {
        guard !isDriving, AuthorizationCenter.shared.authorizationStatus == .approved else {
            reconcile()
            return
        }
        do {
            let data = try JSONEncoder().encode(proposedSelection)
            defaults.set(data, forKey: selectionKey)
            selection = proposedSelection
            message = hasValidSelection ? nil : "יש לבחור בין יישום אחד ל־50 יישומים בלבד, למשל WhatsApp. אין לבחור קטגוריות, אתרים, Waze או טלפון."
        } catch {
            invalidateSelection()
            message = "שמירת הבחירה נכשלה. יש לבחור שוב לפני תחילת הנסיעה."
        }
    }

    func startDriving() {
        reconcile()
        guard authorization == .approved, hasValidSelection else {
            message = "נדרשים אישור זמן מסך ובחירת יישומים לפני תחילת הנסיעה."
            return
        }
        // Settings setters have no enforcement acknowledgement. Device QA is required.
        store.shield.applications = selection.applicationTokens
        defaults.set(true, forKey: activeKey)
        isDriving = true
        message = nil
    }

    func endDriving() {
        // Clear this app's named store only; other Screen Time stores remain untouched.
        store.clearAllSettings()
        defaults.set(false, forKey: activeKey)
        isDriving = false
        message = nil
    }

    private func invalidateSelection() {
        selection = FamilyActivitySelection()
        defaults.removeObject(forKey: selectionKey)
    }

    func reconcile() {
        authorization = AuthorizationCenter.shared.authorizationStatus
        guard authorization == .approved else {
            let wasDriving = isDriving
            invalidateSelection()
            store.clearAllSettings()
            defaults.set(false, forKey: activeKey)
            isDriving = false
            if wasDriving { message = "הרשאת זמן המסך אינה זמינה. מצב הנהיגה הופסק. יש לבדוק הרשאות כשחונים בבטחה." }
            return
        }
        if isDriving {
            guard hasValidSelection else {
                endDriving()
                message = "הבחירה אינה זמינה. יש לבחור יישומים מחדש כשחונים בבטחה."
                return
            }
            store.shield.applications = selection.applicationTokens
        } else {
            store.clearAllSettings()
        }
    }
}
