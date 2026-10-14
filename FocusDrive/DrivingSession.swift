import Foundation

@MainActor
protocol SessionAuthorizing: AnyObject {
    var isApproved: Bool { get }
    func requestIndividualAuthorization() async throws
}

@MainActor
protocol SessionPersisting: AnyObject {
    func load() throws -> Data?
    func save(_ data: Data) throws
    func remove()
}

struct SessionSnapshot<Selection: Codable>: Codable {
    let selection: Selection?
    let requested: Bool
}

enum SessionPhase: Equatable {
    case inactive, requested, cleanupRequired
}

enum SessionIssue: Equatable {
    case authorizationRequired, authorizationFailed, invalidSelection
    case persistenceFailed, restorationFailed, restrictionRequestFailed, cleanupFailed
}

/// Shared production coordination. A successful request is not proof of OS enforcement.
@MainActor
final class DrivingSession<Selection: Codable> {
    private(set) var selection: Selection?
    private(set) var phase: SessionPhase = .inactive
    private(set) var issue: SessionIssue?
    private(set) var isRequestingAuthorization = false

    private let authorization: any SessionAuthorizing
    private let persistence: any SessionPersisting
    private let isValid: (Selection) -> Bool
    private let applyShield: (Selection) throws -> Void
    private let clearShield: () throws -> Void

    init(authorization: any SessionAuthorizing, persistence: any SessionPersisting,
         isValid: @escaping (Selection) -> Bool,
         applyShield: @escaping (Selection) throws -> Void,
         clearShield: @escaping () throws -> Void) {
        self.authorization = authorization
        self.persistence = persistence
        self.isValid = isValid
        self.applyShield = applyShield
        self.clearShield = clearShield
        do {
            if let data = try persistence.load() {
                let snapshot = try JSONDecoder().decode(SessionSnapshot<Selection>.self, from: data)
                selection = snapshot.selection
                phase = snapshot.requested ? .requested : .inactive
            }
        } catch {
            persistence.remove()
            issue = .restorationFailed
        }
        reconcile()
    }

    var hasValidSelection: Bool { selection.map(isValid) ?? false }

    func authorize() async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        do {
            try await authorization.requestIndividualAuthorization()
            issue = nil
        } catch {
            issue = .authorizationFailed
        }
        reconcile()
    }

    func select(_ proposed: Selection) {
        guard phase == .inactive else { return }
        guard authorization.isApproved else {
            authorizationWasLost()
            return
        }
        do {
            try persist(selection: proposed, requested: false)
            selection = proposed
            issue = isValid(proposed) ? nil : .invalidSelection
        } catch {
            // Never leave the UI using a selection that was not encoded successfully.
            selection = nil
            persistence.remove()
            issue = .persistenceFailed
        }
    }

    func start() {
        guard phase == .inactive else { return }
        guard authorization.isApproved else {
            authorizationWasLost()
            return
        }
        guard let selected = selection, isValid(selected) else {
            issue = .invalidSelection
            return
        }
        do {
            // Save one complete restart intent before submitting the shield request.
            try persist(selection: selected, requested: true)
        } catch {
            issue = .persistenceFailed
            return
        }
        do {
            try applyShield(selected)
            phase = .requested
            issue = nil
        } catch {
            stop(discardSelection: false, issueAfter: .restrictionRequestFailed)
        }
    }

    func end() {
        stop(discardSelection: false)
    }

    /// Process revocation itself, even if the current authorization is approved again.
    func authorizationWasLost() {
        stop(discardSelection: true, issueAfter: .authorizationRequired)
    }

    func reconcile() {
        guard authorization.isApproved else {
            let reason = (selection != nil || phase != .inactive) ? SessionIssue.authorizationRequired : issue
            stop(discardSelection: true, issueAfter: reason)
            return
        }
        if phase == .requested {
            guard let selected = selection, isValid(selected) else {
                stop(discardSelection: true, issueAfter: .invalidSelection)
                return
            }
            do {
                try applyShield(selected)
            } catch {
                stop(discardSelection: false, issueAfter: .restrictionRequestFailed)
            }
        } else {
            let retainedIssue = phase == .cleanupRequired ? nil : issue
            // An inactive launch clears stale app-owned settings; never resume cleanup as driving.
            stop(discardSelection: false, issueAfter: retainedIssue)
        }
    }

    private func persist(selection: Selection?, requested: Bool) throws {
        try persistence.save(JSONEncoder().encode(SessionSnapshot(selection: selection, requested: requested)))
    }

    private func stop(discardSelection: Bool, issueAfter: SessionIssue? = nil) {
        if discardSelection { selection = nil }
        // Remove resume intent before cleanup. A failed save must not resume an ended journey.
        persistence.remove()
        var resultIssue = issueAfter
        if selection != nil {
            do {
                try persist(selection: selection, requested: false)
            } catch {
                persistence.remove()
                resultIssue = .persistenceFailed
            }
        }
        do {
            try clearShield()
            phase = .inactive
            issue = resultIssue
        } catch {
            // Keep End reachable so cleanup can be retried while safely parked.
            phase = .cleanupRequired
            issue = .cleanupFailed
        }
    }
}
