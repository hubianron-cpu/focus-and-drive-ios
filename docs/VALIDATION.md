# Static review and Xcode build results

## Baseline GitHub Actions simulator build (before coordinator changes)

- Workflow: [iOS Simulator Build](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/workflows/ios-build.yml).
- Actual run: [38645026287, attempt 1](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38645026287), triggered by the feature-branch push. Final status: **SUCCESS**; total duration reported by GitHub: 57 seconds.
- Built commit: `afc48ea8bb229df86c48c35d22f157922d117e87` on `feature/focus-drive-static-qa`. The next documentation-only commit `8df0b80889adf61e0553131983fe84f0b26e496a` did not change that compiled app or workflow. The later implementation follow-up is recorded below.
- GitHub-hosted `macos-15` runner; installed **Xcode 16.4** selected with `DEVELOPER_DIR`. The toolchain step explicitly checks this version and records Xcode, Swift compiler and SDK versions in `toolchain.log`. The project uses Swift 5 language mode and iOS 16 deployment target.
- `xcodebuild` compiled the existing FocusDrive scheme in Debug for `generic/platform=iOS Simulator`, using `-sdk iphonesimulator`, `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`. Its exit status is preserved through `tee` using `pipefail`.
- **PASS:** project/scheme inspection, Swift compilation and linking (including SwiftUI, FamilyControls and ManagedSettings references), simulator executable existence, generated Info.plist with the `iPhoneSimulator` supported platform, and the bundled privacy manifest with UserDefaults reason `CA92.1`.
- **Tests: NOT RUN.** No XCTest target or scheme TestAction exists; no substitute tests were created.
- Artifact upload: **SUCCESS**. `ios-simulator-build-38645026287-1` contains toolchain, project, static validation, build and output logs, an Xcode result bundle and a summary. Retention is seven days. GitHub reported 22.3 KB and SHA-256 `4b2787fe8df85c752a5874820b4b1e2ff24a497babdb92097a0d766b3be2288c` for the uploaded artifact.
- Run completion and all job-step conclusions were checked on GitHub's public run/job pages. The cloud proxy blocked the REST API and GitHub requires sign-in for full log viewing/downloads; raw runner logs were not independently downloaded into this cloud machine. The successful workflow and output-check conclusions are the compilation evidence.
- No Swift source, application behavior, entitlement or Xcode project changes were needed for this build. Added the workflow and documentation only. Workflow YAML, embedded Bash syntax and actionlint validation passed before the push. Action references are pinned to full commit SHAs, permissions are `contents: read`, checkout credentials are not retained, and no signing credentials are used.
- GitHub emitted an action-runtime deprecation warning for the pinned v4 actions (automatically run with Node 24) and a macOS runner-capacity notice. Neither prevented this run; no billing or runner-setting changes were made.

## Initial static review completed in cloud

- Continued the existing MVP in place; no application rebuild from scratch.
- Reviewed the SwiftUI view, individual authorization, picker, named-store shielding, state persistence, entitlement and both Xcode build configurations.
- Confirmed from source that every settings mutation targets the single `ManagedSettingsStore(named: .init("FocusDrive.driving"))`. End Driving calls `clearAllSettings()` on that instance. No default store, other named store, system Screen Time policy or authorization grant is cleared. Runtime coexistence with other restrictions remains a required device check.
- Fixed retention of voided tokens: observed nonapproved authorization clears the saved selection, and a nonapproved publisher event is processed even if approval follows before the handler runs.
- Isolated picker edits from the committed model selection; changes are accepted only while authorized and inactive, after encoding. Failed encoding clears the selection and prevents activation.
- Enforced Apple's documented maximum of 50 shielded application tokens. Empty, category, website and oversized selections cannot activate Driving Mode.
- Moved the primary button's frame, background and hit shape into its label so its full visible area is interactive. Device touch and accessibility checks remain unverified.
- Added `PrivacyInfo.xcprivacy` to Copy Bundle Resources, declaring app-only UserDefaults access (`CA92.1`), no tracking and no collected data.
- Updated README and manual QA for Xcode selection, privacy resources, fresh selection after revocation, selection persistence, maximum selection count, large-button touch area, and the missing optional development app icon.

## Static checks

- `python3 scripts/validate_project.py`: PASS — 24 project objects, 3 Swift source build inputs, shared-scheme references, privacy resource and entitlement XML. The validator follows build-phase references rather than comparing the total number of build files with Swift files.
- Independent `openstep-plist==0.5.1` parser, installed outside the checkout: PASS — project syntax, app target, Debug/Release configurations, generated Info.plist and signing settings.
- Negative validation checks on disposable copies: PASS — rejected missing Swift source, missing privacy manifest, invalid entitlement and unresolved scheme target (4 checks).
- Markdown local file-link existence and staged whitespace checks: PASS.
- Apple documentation retrieval: PASS during follow-up review. Checked individual authorization and iOS 16 availability, the authorization publisher, token invalidation on revocation, named-store scope, the 50-application limit and distribution approval requirements. Earlier preparation attempts had returned proxy HTTP 403. No trust or verification bypass was used.

## Not completed

The Linux cloud machine has neither Xcode nor the Apple SDK. Actual simulator compilation was completed on GitHub's macOS runner as recorded above. Physical-device compilation/signing, simulator launch, physical-iPhone launch, authorization, WhatsApp shielding, shield removal, and all functional lifecycle QA remain **NOT RUN / UNVERIFIED**. Simulator compilation does not validate runtime behavior or entitlement approval. The updated app now shares its coordinator with a macOS SwiftPM XCTest suite; see the follow-up CI result when recorded below.

## Remaining limitations and next gate

- Follow README.md on a Mac with full Xcode and an SDK compatible with the phone. Select a unique bundle ID and an eligible Apple Developer team; verify Family Controls provisioning before installation.
- Complete MANUAL_QA.md on a physical iPhone. Do not mark actual blocking PASS until WhatsApp shows a system shield and End Driving successfully clears this app's restriction.
- Individual authorization is revocable. Tokens may be stale after selected-app reinstall, and a revoke/reapprove transition entirely while the process is terminated can be unobservable. Reselect WhatsApp if needed. OS-managed settings and UserDefaults are not an atomic transaction.
- The app uses the system shield, without extensions. It does not enforce a system-wide Waze-only mode or guarantee navigation/call routing.
- No custom app icon is included. It does not block a development-device test, but must be supplied before App Store submission. Distribution separately requires Apple Family Controls approval.
- This follow-up was authorized to commit and push a feature branch only. No merge, environment publication or deployment was performed. Consult the reported Git SHA/branch for the exact reviewed snapshot.


## Blocking coordination follow-up

Implementation findings before edits are in BLOCKING_REVIEW.md. The updated coordinator has 25 XCTest cases covering valid/invalid Start, End, revocation/rapid reapproval, selection persistence, restart/reconciliation, authorization errors, encoding/load/save failures, partial-apply rollback and cleanup retries. These tests use mock services with the same production coordinator; they are not evidence of Apple shielding. The workflow retains real simulator compilation and output checks and now runs XCTest on macOS, preserves test exit status, uploads JUnit/logs, and rejects missing, skipped, failing or zero-test execution. Follow-up compilation/tests completed successfully in the rerun recorded below. Entitlement declarations remain unchanged; physical-device provisioning and enforcement remain NOT TESTED.


The first follow-up run [38646360776](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38646360776) passed the actual Xcode simulator build and output inspection but failed the XCTest reporting step. SwiftPM 6.1's sequential XCTest path does not generate `--xunit-output`; its parallel path does. This was confirmed in the official SwiftPM source, and CI now uses two parallel test workers to generate a real report without relaxing test-count/failure checks. The diagnostic matcher was also corrected so a passing test named `testForegroundCanRetryFailedCleanupWithoutReapplying` is not misclassified as a failure solely because of its name. The completed rerun remains required before reporting tests PASS.


## Verified blocking coordination rerun — PASS

- [Run 38646708147, attempt 1](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38646708147): **SUCCESS**, GitHub-reported total duration 1 minute 16 seconds. Tested commit `9cecdf5b8049fe78b20dab702065e065145ac98d`, branch `feature/focus-drive-static-qa`.
- **PASS — Xcode build:** Xcode 16.4 on GitHub-hosted macos-15; Swift 5 language mode, iOS 16 minimum; generic iOS Simulator app built with signing disabled. All five app Swift files, including the new coordinator and native adapters, compiled and linked. Simulator executable, generated Info.plist and bundled privacy manifest checks passed.
- **PASS — Automated tests:** macOS XCTest using the actual production `DrivingSession` with mocked services, run by `xcrun swift test --jobs 2 --parallel --num-workers 2 --xunit-output ...`. Actual report: **25 executed, 0 failures/errors, 0 skipped**. CI parsed the XML and checked the executed count against all declared test methods. This is not an Apple framework integration or device enforcement test.
- **PASS — Artifact:** `ios-simulator-build-38646708147-1` (25.5 KB) uploaded; includes build/toolchain/test logs, Xcode result bundle, JUnit XML, test-report output and summary. Seven-day retention. GitHub-reported SHA-256: `91d9e4d279859a9720fbf0dbb7fba8b3a274978054fe1f62b312880049e1f65d`.
- **PASS — Review:** checked actual workflow success, each step conclusion and the public test-count notice on GitHub. Full raw artifacts require GitHub sign-in; they were not downloaded to this Linux cloud machine.
- **PASS — Local checks:** 28 project objects, 5 Swift source build inputs, unchanged entitlement and privacy XML/resource membership; independent OpenStep parse, actionlint, embedded shell syntax, documentation file links and whitespace checks.
- The first run's test-reporting failure was corrected without disabling tests, weakening assertions or changing application behavior. The final successful run contains that correction.
- **NOT TESTED:** iPhone app launch, native FamilyControls authorization/picker, actual WhatsApp shield/removal, OS lifecycle enforcement and real-token migration. **BLOCKED:** device provisioning/installation until account-specific signing, Mac/Xcode and physical iPhone access are supplied.
- Subsequent result-documentation-only commits do not alter the compiled/tested code and do not trigger another run under the workflow's path filter. No merge, deployment, publication or purchase occurred.
