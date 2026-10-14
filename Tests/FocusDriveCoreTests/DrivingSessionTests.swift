import XCTest
@testable import FocusDriveCore

@MainActor
private final class AuthorizationStub: SessionAuthorizing {
    var isApproved = true
    var requestError: Error?
    var requests = 0
    func requestIndividualAuthorization() async throws {
        requests += 1
        if let requestError { throw requestError }
        isApproved = true
    }
}

private enum Failure: Error { case injected }

@MainActor
private final class MemoryPersistence: SessionPersisting {
    var data: Data?
    var failLoad = false
    var failSave = false
    func load() throws -> Data? {
        if failLoad { throw Failure.injected }
        return data
    }
    func save(_ data: Data) throws {
        if failSave { throw Failure.injected }
        self.data = data
    }
    func remove() { data = nil }
}

@MainActor
private final class ShieldSpy {
    var ownApplications: Set<String> = []
    var applicationsSubmitted: [Set<String>] = []
    var clears = 0
    var failApply = false
    var failClear = false
    func apply(_ selected: Set<String>) throws {
        // Simulate even a partially completed request before an error.
        ownApplications = selected
        applicationsSubmitted.append(selected)
        if failApply { throw Failure.injected }
    }
    func clear() throws {
        clears += 1
        if failClear { throw Failure.injected }
        ownApplications = []
    }
}

@MainActor
final class DrivingSessionTests: XCTestCase {
    private let selected: Set<String> = ["opaque-test-token"]

    private func make(_ auth: AuthorizationStub? = nil,
                      _ disk: MemoryPersistence? = nil,
                      _ shield: ShieldSpy? = nil) -> DrivingSession<Set<String>> {
        let auth = auth ?? AuthorizationStub()
        let disk = disk ?? MemoryPersistence()
        let shield = shield ?? ShieldSpy()
        return DrivingSession(authorization: auth, persistence: disk,
                       isValid: { !$0.isEmpty && $0.count <= 50 },
                       applyShield: { try shield.apply($0) },
                       clearShield: { try shield.clear() })
    }

    private func snapshot(_ disk: MemoryPersistence) throws -> SessionSnapshot<Set<String>> {
        try JSONDecoder().decode(SessionSnapshot<Set<String>>.self, from: XCTUnwrap(disk.data))
    }

    func testAuthorizedStartSubmitsExactSelectionAndPersistsRestartIntent() async throws {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        session.start()
        XCTAssertEqual(session.phase, .requested)
        XCTAssertEqual(shield.applicationsSubmitted, [selected])
        XCTAssertEqual(try snapshot(disk).selection, selected)
        XCTAssertTrue(try snapshot(disk).requested)
        XCTAssertNil(session.issue)
    }

    func testStartWithoutAuthorizationNeverSubmitsShield() async {
        let auth = AuthorizationStub(), disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(auth, disk, shield)
        session.select(selected)
        auth.isApproved = false
        session.start()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .authorizationRequired)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
        XCTAssertNil(session.selection)
        XCTAssertNil(disk.data)
    }

    func testStartWithoutSelectionNeverSubmitsShield() async {
        let shield = ShieldSpy(), session = make(AuthorizationStub(), MemoryPersistence(), shield)
        session.start()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .invalidSelection)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
    }

    func testEmptySelectionCannotStart() async {
        let session = make()
        session.select([])
        session.start()
        XCTAssertFalse(session.hasValidSelection)
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .invalidSelection)
    }

    func testOversizedSelectionCannotStart() async {
        let session = make()
        session.select(Set((0..<51).map(String.init)))
        session.start()
        XCTAssertFalse(session.hasValidSelection)
        XCTAssertEqual(session.phase, .inactive)
    }

    func testEndClearsInjectedStoreAndPersistsInactiveSelection() async throws {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        session.start()
        let clears = shield.clears
        session.end()
        XCTAssertEqual(shield.clears, clears + 1)
        XCTAssertTrue(shield.ownApplications.isEmpty)
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertFalse(try snapshot(disk).requested)
        XCTAssertEqual(try snapshot(disk).selection, selected)
    }

    func testRepeatedStartDoesNotResubmitOrChangeSelection() async {
        let shield = ShieldSpy(), session = make(AuthorizationStub(), MemoryPersistence(), shield)
        session.select(selected)
        session.start()
        session.select(["different-token"])
        session.start()
        XCTAssertEqual(session.selection, selected)
        XCTAssertEqual(shield.applicationsSubmitted, [selected])
    }

    func testAuthorizationLossClearsShieldSelectionAndRestartIntent() async {
        let auth = AuthorizationStub(), disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(auth, disk, shield)
        session.select(selected)
        session.start()
        auth.isApproved = false
        session.reconcile()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .authorizationRequired)
        XCTAssertNil(session.selection)
        XCTAssertNil(disk.data)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

    func testRevocationEventInvalidatesTokensEvenAfterRapidReapproval() async {
        let session = make()
        session.select(selected)
        session.start()
        // The current provider is approved, but the queued event reports revocation.
        session.authorizationWasLost()
        session.reconcile()
        XCTAssertNil(session.selection)
        XCTAssertEqual(session.phase, .inactive)
        session.start()
        XCTAssertEqual(session.issue, .invalidSelection)
    }

    func testActiveRestartReappliesPersistedSelection() async {
        let disk = MemoryPersistence()
        let first = make(AuthorizationStub(), disk, ShieldSpy())
        first.select(selected)
        first.start()
        let shield = ShieldSpy(), restored = make(AuthorizationStub(), disk, shield)
        XCTAssertEqual(restored.phase, .requested)
        XCTAssertEqual(restored.selection, selected)
        XCTAssertEqual(shield.applicationsSubmitted, [selected])
    }

    func testInactiveRestartClearsStaleOwnShieldWithoutSubmitting() async {
        let disk = MemoryPersistence()
        make(AuthorizationStub(), disk, ShieldSpy()).select(selected)
        let shield = ShieldSpy()
        shield.ownApplications = ["stale"]
        let restored = make(AuthorizationStub(), disk, shield)
        XCTAssertEqual(restored.phase, .inactive)
        XCTAssertEqual(restored.selection, selected)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

    func testRestartWithoutAuthorizationDiscardsSavedActiveSession() async {
        let disk = MemoryPersistence()
        let first = make(AuthorizationStub(), disk, ShieldSpy())
        first.select(selected)
        first.start()
        let auth = AuthorizationStub()
        auth.isApproved = false
        let shield = ShieldSpy(), restored = make(auth, disk, shield)
        XCTAssertEqual(restored.phase, .inactive)
        XCTAssertNil(restored.selection)
        XCTAssertNil(disk.data)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
    }

    func testForegroundReconciliationResubmitsActiveRequest() async {
        let shield = ShieldSpy(), session = make(AuthorizationStub(), MemoryPersistence(), shield)
        session.select(selected)
        session.start()
        shield.ownApplications = []
        session.reconcile()
        XCTAssertEqual(shield.ownApplications, selected)
        XCTAssertEqual(shield.applicationsSubmitted.count, 2)
    }

    func testCorruptSnapshotClearsStaleShieldAndReportsRestorationFailure() async {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        disk.data = Data("broken snapshot".utf8)
        shield.ownApplications = selected
        let restored = make(AuthorizationStub(), disk, shield)
        XCTAssertEqual(restored.phase, .inactive)
        XCTAssertEqual(restored.issue, .restorationFailed)
        XCTAssertNil(disk.data)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

    func testLoadFailureClearsStaleShield() async {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        disk.failLoad = true
        shield.ownApplications = selected
        let session = make(AuthorizationStub(), disk, shield)
        XCTAssertEqual(session.issue, .restorationFailed)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

    func testSelectionSaveFailureDoesNotCommitUnsavedSelection() async {
        let disk = MemoryPersistence(), session = make(AuthorizationStub(), disk, ShieldSpy())
        session.select(selected)
        disk.failSave = true
        session.select(["replacement"])
        XCTAssertNil(session.selection)
        XCTAssertNil(disk.data)
        XCTAssertEqual(session.issue, .persistenceFailed)
    }

    func testStartPersistenceFailureNeverSubmitsShield() async {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        disk.failSave = true
        session.start()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .persistenceFailed)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
    }

    func testApplyFailureRollsBackPartialShieldAndRestartIntent() async throws {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        shield.failApply = true
        session.start()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .restrictionRequestFailed)
        XCTAssertTrue(shield.ownApplications.isEmpty)
        XCTAssertFalse(try snapshot(disk).requested)
    }

    func testEndSaveFailureStillClearsShieldAndCannotResumeOnRestart() async {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        session.start()
        disk.failSave = true
        session.end()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .persistenceFailed)
        XCTAssertTrue(shield.ownApplications.isEmpty)
        XCTAssertNil(disk.data)
        XCTAssertEqual(make(AuthorizationStub(), disk, ShieldSpy()).phase, .inactive)
    }

    func testCleanupFailureRetainsRetryStateButNotResumeIntent() async throws {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        let session = make(AuthorizationStub(), disk, shield)
        session.select(selected)
        session.start()
        shield.failClear = true
        session.end()
        XCTAssertEqual(session.phase, .cleanupRequired)
        XCTAssertEqual(session.issue, .cleanupFailed)
        XCTAssertFalse(try snapshot(disk).requested)
        let submitted = shield.applicationsSubmitted.count
        session.start()
        XCTAssertEqual(shield.applicationsSubmitted.count, submitted)
        shield.failClear = false
        session.end()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertNil(session.issue)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

    func testAuthorizationRequestFailureReportsErrorAndNeverApplies() async {
        let auth = AuthorizationStub(), shield = ShieldSpy()
        auth.isApproved = false
        auth.requestError = Failure.injected
        let session = make(auth, MemoryPersistence(), shield)
        await session.authorize()
        XCTAssertEqual(auth.requests, 1)
        XCTAssertFalse(session.isRequestingAuthorization)
        XCTAssertEqual(session.issue, .authorizationFailed)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
    }

    func testAuthorizationApprovalRequiresExplicitSelectionAndStart() async {
        let auth = AuthorizationStub(), shield = ShieldSpy()
        auth.isApproved = false
        let session = make(auth, MemoryPersistence(), shield)
        await session.authorize()
        XCTAssertTrue(auth.isApproved)
        XCTAssertNil(session.issue)
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
        session.select(selected)
        session.start()
        XCTAssertEqual(shield.ownApplications, selected)
    }
    func testRequestedSnapshotWithoutSelectionCannotResume() async throws {
        let disk = MemoryPersistence(), shield = ShieldSpy()
        disk.data = try JSONEncoder().encode(SessionSnapshot<Set<String>>(selection: nil, requested: true))
        let session = make(AuthorizationStub(), disk, shield)
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .invalidSelection)
        XCTAssertTrue(shield.applicationsSubmitted.isEmpty)
        XCTAssertNil(disk.data)
    }

    func testEncodingFailureIsReportedWithoutCommittingSelection() async {
        let session = DrivingSession<UnencodableSelection>(
            authorization: AuthorizationStub(), persistence: MemoryPersistence(),
            isValid: { _ in true }, applyShield: { _ in XCTFail("Must not apply") },
            clearShield: {}
        )
        session.select(UnencodableSelection())
        XCTAssertNil(session.selection)
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertEqual(session.issue, .persistenceFailed)
    }

    func testForegroundCanRetryFailedCleanupWithoutReapplying() async {
        let shield = ShieldSpy(), session = make(AuthorizationStub(), MemoryPersistence(), shield)
        session.select(selected)
        session.start()
        shield.failClear = true
        session.end()
        shield.failClear = false
        session.reconcile()
        XCTAssertEqual(session.phase, .inactive)
        XCTAssertNil(session.issue)
        XCTAssertEqual(shield.applicationsSubmitted.count, 1)
        XCTAssertTrue(shield.ownApplications.isEmpty)
    }

}

private struct UnencodableSelection: Codable {
    init() {}
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws { throw Failure.injected }
}
