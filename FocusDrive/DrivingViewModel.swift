import SwiftUI
import FamilyControls
import Combine

@MainActor
final class DrivingViewModel: ObservableObject {
    @Published private(set) var isDriving = false
    @Published private(set) var authorization: AuthorizationStatus = .notDetermined
    @Published private(set) var isRequesting = false
    @Published private(set) var message: String?
    @Published private(set) var selection = FamilyActivitySelection()
    @Published private(set) var phase: SessionPhase = .inactive

    private let session: DrivingSession<FamilyActivitySelection>
    private var authorizationObserver: AnyCancellable?

    init() {
        let shield = DrivingShieldStore()
        session = DrivingSession(
            authorization: ScreenTimeAuthorization(),
            persistence: UserDefaultsSessionPersistence(),
            isValid: Self.isValid,
            applyShield: { shield.apply($0) },
            clearShield: { shield.clear() }
        )
        refresh()
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if status != .approved { self.session.authorizationWasLost() }
                    self.reconcile()
                }
            }
    }

    private static func isValid(_ selection: FamilyActivitySelection) -> Bool {
        !selection.applicationTokens.isEmpty && selection.applicationTokens.count <= 50
            && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    var hasValidSelection: Bool { session.hasValidSelection }

    var statusTitle: String {
        switch phase {
        case .inactive: return "מצב נהיגה לא פעיל"
        case .requested: return "מצב נהיגה: בקשת הגבלה נשלחה"
        case .cleanupRequired: return "נדרשת הסרת הגבלה מחדש"
        }
    }

    var statusDetail: String {
        switch phase {
        case .inactive: return "הפעילו את מצב הנהיגה לפני תחילת הנסיעה."
        case .requested: return "נשלחה בקשה להגבלת היישומים שנבחרו. אין אישור מהמערכת שהחסימה נאכפת."
        case .cleanupRequired: return "לא ניתן לאשר את הסרת הבקשה. נסו לסיים שוב רק כשחונים בבטחה."
        }
    }

    func requestAuthorization() async {
        guard !isRequesting else { return }
        isRequesting = true
        await session.authorize()
        isRequesting = false
        refresh()
    }

    func saveSelection(_ proposedSelection: FamilyActivitySelection) {
        session.select(proposedSelection)
        refresh()
    }

    func startDriving() { session.start(); refresh() }
    func endDriving() { session.end(); refresh() }
    func reconcile() { session.reconcile(); refresh() }

    private func refresh() {
        authorization = AuthorizationCenter.shared.authorizationStatus
        phase = session.phase
        isDriving = phase != .inactive
        selection = session.selection ?? FamilyActivitySelection()
        switch session.issue {
        case nil: message = nil
        case .authorizationRequired: message = "נדרשת הרשאת זמן מסך ובחירה חדשה של יישומים כשחונים בבטחה."
        case .authorizationFailed: message = "ההרשאה לא ניתנה. לא ניתן לבקש הגבלות ללא הרשאת זמן מסך. בדקו את ההרשאה בהגדרות כשחונים בבטחה."
        case .invalidSelection: message = "יש לבחור בין יישום אחד ל־50 יישומים בלבד, ללא קטגוריות או אתרים."
        case .persistenceFailed: message = "שמירת מצב הנהיגה נכשלה. יש לבדוק את הבחירה מחדש כשחונים בבטחה."
        case .restorationFailed: message = "לא ניתן לשחזר את המצב. שחזור הנהיגה בוטל ונשלחה בקשת הסרה. יש לבחור יישומים מחדש."
        case .restrictionRequestFailed: message = "בקשת ההגבלה נכשלה. מצב הנהיגה לא הופעל."
        case .cleanupFailed: message = "הסרת בקשת ההגבלה נכשלה. נסו לסיים שוב כשחונים בבטחה."
        }
    }
}
