# Focus & Drive

Minimal, Hebrew/RTL SwiftUI iPhone MVP. The driver grants individual Screen Time authorization, selects WhatsApp in Apple's picker, then manually starts and ends Driving Mode while safely parked. No backend, accounts, analytics, subscriptions, location, motion tracking, notifications, or third-party dependencies.

**Status:** the current implementation passed real Xcode 16.4 iOS Simulator compilation and **25 macOS coordinator XCTest cases (0 failures, 0 skipped)** in [Actions run 38646708147](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38646708147), testing commit `9cecdf5b8049fe78b20dab702065e065145ac98d`. Output/resource checks also passed. No iPhone app launch, device signing, installation, or runtime enforcement was tested. Actual WhatsApp blocking and removal remain **NOT TESTED**, not PASS. See [build/test evidence](docs/VALIDATION.md), [implementation review](docs/BLOCKING_REVIEW.md) and [stationary WhatsApp test](docs/WHATSAPP_DEVICE_TEST.md).

## Open and install on a friend's Mac

1. Transfer this repository, including `FocusDrive.xcodeproj`, `FocusDrive/`, and `docs/`. No package installation or project generation is needed.
2. Install Xcode 16 or newer with an iOS SDK supporting the iPhone's installed OS. Launch Xcode once and install requested components. The app's deployment target is iOS 16.0, which supports individual authorization and named Managed Settings stores.
3. Open `FocusDrive.xcodeproj`. Select the **FocusDrive** scheme and app target.
4. In Xcode Settings → Accounts, add your Apple Developer account. Under Signing & Capabilities, choose your Team, keep automatic signing, and replace `com.example.FocusDrive` with a unique bundle identifier associated with your team. Do not share credentials with the repository.
5. Confirm **Family Controls** is enabled and `FocusDrive/FocusDrive.entitlements` is the code signing entitlements file. The signed provisioning profile must include `com.apple.developer.family-controls`. The file alone does not grant this entitlement.
6. Connect the physical iPhone by cable, unlock it, trust the Mac, and enable Developer Mode in Settings → Privacy & Security when required. Select that iPhone as the run destination.
7. Build and Run (⌘R). Resolve signing/profile errors before testing. If iOS requests developer trust, follow the device's Settings prompts.
8. While safely parked, tap **מתן הרשאת זמן מסך**, approve individual authorization, then **בחירת יישומים להגבלה**. Select **WhatsApp only**, not a category or website. Leave Waze and Phone unselected. Tap **התחלת נהיגה** to start and **סיום נהיגה** to end.
9. Execute every required case in [MANUAL_QA.md](docs/MANUAL_QA.md), recording iOS/Xcode versions and observed results. Simulator UI is not evidence of working Screen Time enforcement.

## Signing and entitlement limitations

For the intended physical-device development and distribution path, use an Apple Developer Program team with Family Controls development provisioning. Distribution requires Program enrollment. Unsigned CI simulator compilation and mock macOS tests require no signing account or entitlement approval. Do not assume a free Personal Team supports this capability. Xcode automatic signing must create an eligible development profile; if it fails, verify the team's capability and App ID in the developer portal. Check current Apple requirements, as account policies can change.

Family Controls is a managed capability. Distribution through TestFlight or the App Store requires Apple's Family Controls **distribution entitlement approval**, followed by an eligible distribution provisioning profile. Development capability does not guarantee distribution approval or App Review approval. This MVP has a single app target and no extensions; if extensions are added later, their identifiers and profiles need their own appropriate entitlements. No approval, certificate, or profile is included here. Codex Cloud can prepare code, entitlement declarations and CI, but this Linux environment cannot pair your iPhone, configure your account-specific signing in Xcode, install a signed app on it, or observe its Screen Time behavior. Those steps require an eligible developer account and Mac/iPhone access. No enrollment, paid upgrade or distribution request has been made.

## Mac validation commands

From the checkout root, first verify `xcode-select -p` points to the full Xcode installation (not only Command Line Tools). If needed, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` on the Mac, then:

```sh
xcodebuild -list -project FocusDrive.xcodeproj
xcodebuild -project FocusDrive.xcodeproj -scheme FocusDrive \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FocusDriveDerivedData CODE_SIGNING_ALLOWED=NO build
```

The second command checks Apple SDK compilation only; it does not authorize, sign, install, or verify restrictions. For installation use Xcode Run with your team and physical device. Run `xcrun swift test --jobs 2` on the Mac for the shared production coordinator XCTest suite. SwiftPM tests use mock services on macOS, not the iOS app or actual Screen Time restrictions. Use the device checklist for Apple framework integration and lifecycle behavior.

## Architecture and privacy

- `FocusDriveApp`: SwiftUI lifecycle, Hebrew locale, RTL, dark appearance.
- `HomeView`: one accessible, scrollable screen with authorization, system picker, status and driving controls. Hebrew labels correspond to Start Driving and End Driving.
- `DrivingViewModel`: bridges published Hebrew UI state and authorization events to the coordinator.
- `DrivingSession`: shared production state/store coordination, tested by the local Swift package.
- `ScreenTimeServices`: Apple individual authorization, the single named settings store, and snapshot persistence/migration adapters.

Only opaque system selection tokens and requested-session intent are stored in one encoded local UserDefaults snapshot (`FocusDrive.session.v2`); existing v1 selection/active keys are migrated. No bundle IDs are inferred, transmitted, or logged. Normal device backup policies may apply. This is not an atomic transaction with Apple's settings, and UserDefaults does not acknowledge durable disk writes.

The picker edits a temporary selection. The coordinator accepts it only while authorized and inactive, after encoding. Empty selections, >50 applications, categories and websites cannot start a session. Start persists intent before submitting the settings request. On a detected collaborator failure, it attempts to roll back the request. End removes restart intent before clearing the app-owned store; if a save fails, it still attempts cleanup and does not retain an active snapshot. A detected cleanup failure keeps End available for retry. The native Managed Settings setter/clear methods do not throw or provide enforcement acknowledgement; mock failure tests exercise coordinator recovery, not detection of an OS enforcement failure.

Observed authorization loss clears saved tokens and ends the requested session; tokens must be selected again after revocation. A revoke/reapprove cycle entirely while terminated may be unobservable. An authorized restart reapplies the saved request. Background, force-quit and reboot enforcement still requires device testing.

`PrivacyInfo.xcprivacy` is included in Copy Bundle Resources and declares UserDefaults use for this app's own preferences (`CA92.1`), with no tracking or collected data. The placeholder bundle ID must be changed on the Mac. A custom app icon is not included; it is optional for development-device testing and required before App Store submission.

The driving UI explicitly says a **restriction request was sent**, not that blocking was verified: Managed Settings setters do not acknowledge shielding success. Other Screen Time controls may continue blocking an app after Focus & Drive clears its own store. See the limitations and recovery cases before relying on the MVP.

## Cloud workflow

Use the existing isolated checkout; do not create a worktree unless explicitly requested. Linux supports editing and `python3 scripts/validate_project.py` for project consistency. It cannot run Xcode, Apple's iOS SDK, or meaningful Family Controls integration tests. No cloud server, service, secrets or dependency installation are required. Apple signing credentials stay on the Mac. Do not interpret the cloud structural validator as an iOS build or functional test.

### GitHub Actions simulator build

[iOS Simulator Build](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/workflows/ios-build.yml) uses GitHub's `macos-15` runner with installed Xcode 16.4, its bundled Swift compiler in Swift 5 language mode, and a generic iOS Simulator destination. Relevant project/workflow/package/test pushes to `feature/focus-drive-static-qa` trigger a build. It also declares `workflow_dispatch`; GitHub's manual-run UI requires the workflow to be present on the default branch. Do not merge merely to obtain that button.

The workflow disables code signing, preserves the `xcodebuild` exit status while logging, and inspects the built simulator executable, generated Info.plist and bundled privacy manifest. It uploads toolchain/build logs and the Xcode result bundle as artifacts for seven days, including on failure. It uses read-only repository permission, pinned actions and no signing secrets. It also runs the shared coordinator XCTest suite using `xcrun swift test --jobs 2 --parallel --num-workers 2 --xunit-output ...`, captures JUnit results, and rejects zero-test, skipped or failing runs. There is no iOS XCTest target; the Swift package tests production coordination with mock clients on macOS.

Only a completed successful Actions run proves simulator compilation for its recorded commit and toolchain. It does not prove app launch, physical-device compilation/signing, Family Controls entitlement approval, authorization, or WhatsApp shielding. Those remain subject to the physical-iPhone checklist.


For the stationary WhatsApp acceptance scenario, use [WHATSAPP_DEVICE_TEST.md](docs/WHATSAPP_DEVICE_TEST.md). For findings before implementation changes, see [BLOCKING_REVIEW.md](docs/BLOCKING_REVIEW.md).
