# Blocking implementation review

## Findings before changes

Reviewed baseline `8df0b80889adf61e0553131983fe84f0b26e496a` before changing implementation.

| Area | Baseline finding |
| --- | --- |
| Authorization | Correct public individual authorization request. Publisher and foreground reconciliation handle observed revocation. |
| Selection | System picker edits a draft; encoded opaque application tokens are saved in UserDefaults. Empty, category, website and >50-app selections are rejected for Start. |
| Shield assignment | Correct `selection.applicationTokens` assigned synchronously to `shield.applications` of `FocusDrive.driving`. Apple does not acknowledge effective enforcement. |
| End | Clears only the app-owned named store. No other store or system Screen Time policy is modified. |
| Feedback issue | Active-screen Hebrew text says restrictions are applied, although the only known fact is that settings were requested. This is misleading without device evidence. |
| Persistence issue | Selection and active intent are separate keys with no single encoded snapshot; interruption or future persistence failure can leave mismatched restoration state. UserDefaults and Managed Settings cannot be made one atomic transaction. |
| Testability gap | Concrete singleton services and all coordination are inside the view model. No state-transition, restoration, or failure-path tests exist. |
| Lifecycle limitation | OS-managed settings do not require a live foreground app, but continued enforcement through backgrounding, termination and reboot has not been observed on a physical iPhone. |
| Revocation limitation | Tokens are voided on revocation; an entire revoke/reapprove cycle while the app is terminated can be unobservable. |
| Entitlement | Entitlement file, capability metadata and signing setting are present. Unsigned simulator success does not establish a device provisioning profile or Apple approval. |

## Intended corrections

Keep the existing app and picker. Extract only the state/store coordination into shared production code that can run under XCTest with injected authorization, persistence and store clients. Persist selection and intent in one encoded snapshot, preserve a migration path for existing keys, and make cleanup/recovery explicit. Describe successful settings submission as a **restriction request**, never proof of effective blocking. Retain the named store and parked-safely reminder. Do not introduce DeviceActivity, extensions, or unrelated features.

## Implemented corrections (verified coordinator and simulator build)

- Extracted `DrivingSession` into production code with injectable authorization, encoded snapshot persistence and apply/clear clients. The existing SwiftUI app uses that same coordinator.
- Added a single v2 snapshot and v1 migration; End deletes restart intent before cleanup, retains only inactive selection when possible, and handles collaborator failures with cleanup/retry state.
- Added requested/inactive/cleanup-required UI states; no state claims verified enforcement.
- Added a macOS SwiftPM XCTest suite exercising state transitions, restoration and failure recovery, plus the existing real iOS Simulator build in CI. No Apple API enforcement is mocked as a device PASS.
- Left the entitlement and named-store identity unchanged. No default store, unrelated store, DeviceActivity schedule or system Screen Time configuration is modified.


## Final verification

- **PASS:** [Actions run 38646708147](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38646708147), commit `9cecdf5b8049fe78b20dab702065e065145ac98d`, Xcode 16.4. Real simulator compilation, output/resource inspection and 25 mock-service coordinator tests passed with 0 failures and 0 skipped.
- **PASS:** application-owned store coordination. Production applies exactly `selection.applicationTokens` and clears only `FocusDrive.driving`; this identity and the entitlement declaration were retained.
- **NOT TESTED:** actual WhatsApp shielding/removal, picker/authorization UI, native adapter runtime behavior, v1 migration with real tokens on-device, force quit/reboot behavior, and other-policy coexistence on a physical iPhone.
- **PASS:** entitlement/capability and privacy manifest declarations. **BLOCKED:** account-specific device signing/provisioning and installation until an eligible developer team, Mac/Xcode and iPhone are available. Distribution entitlement approval is a separate future requirement.
- **PASS:** findings documented before implementation changes, no private APIs, DeviceActivity, new product features, merges, publication, deployments or purchases.

## Exact changed/new files relative to the supplied baseline

- `.github/workflows/ios-build.yml`
- `.gitignore`
- `FocusDrive.xcodeproj/project.pbxproj`
- `FocusDrive/DrivingSession.swift`
- `FocusDrive/DrivingViewModel.swift`
- `FocusDrive/HomeView.swift`
- `FocusDrive/ScreenTimeServices.swift`
- `Package.swift`
- `README.md`
- `Tests/FocusDriveCoreTests/DrivingSessionTests.swift`
- `docs/BLOCKING_REVIEW.md`
- `docs/FEASIBILITY.md`
- `docs/MANUAL_QA.md`
- `docs/VALIDATION.md`
- `docs/WHATSAPP_DEVICE_TEST.md`

`FocusDrive.entitlements`, `PrivacyInfo.xcprivacy`, `FocusDriveApp.swift` and the shared Xcode scheme are unchanged. The SwiftPM tests do not require a new iOS test target, device entitlements or signing credentials.
