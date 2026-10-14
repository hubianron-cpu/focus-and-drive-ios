# Focus & Drive

Minimal, Hebrew/RTL SwiftUI iPhone MVP. The driver grants individual Screen Time authorization, selects WhatsApp in Apple's picker, then manually starts and ends Driving Mode while safely parked. No backend, accounts, analytics, subscriptions, location, motion tracking, notifications, or third-party dependencies.

**Status:** the existing app compiled successfully for iOS Simulator using Xcode 16.4 on GitHub Actions at commit `afc48ea8bb229df86c48c35d22f157922d117e87` ([successful run 38645026287](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/runs/38645026287)). The simulator executable and bundled privacy manifest checks passed. No app launch, tests, device signing, installation, or iPhone runtime validation was performed. Actual WhatsApp blocking is **UNVERIFIED**, not PASS. See [build evidence](docs/VALIDATION.md), [feasibility](docs/FEASIBILITY.md) and [manual QA](docs/MANUAL_QA.md).

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

Plan to use an Apple Developer Program team with Family Controls development provisioning. Do not assume a free Personal Team supports this capability. Xcode automatic signing must create an eligible development profile; if it fails, verify the team's capability and App ID in the developer portal. Check current Apple requirements, as account policies can change.

Family Controls is a managed capability. Distribution through TestFlight or the App Store requires Apple's Family Controls **distribution entitlement approval**, followed by an eligible distribution provisioning profile. Development capability does not guarantee distribution approval or App Review approval. This MVP has a single app target and no extensions; if extensions are added later, their identifiers and profiles need their own appropriate entitlements. No approval, certificate, or profile is included here.

## Mac validation commands

From the checkout root, first verify `xcode-select -p` points to the full Xcode installation (not only Command Line Tools). If needed, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` on the Mac, then:

```sh
xcodebuild -list -project FocusDrive.xcodeproj
xcodebuild -project FocusDrive.xcodeproj -scheme FocusDrive \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FocusDriveDerivedData CODE_SIGNING_ALLOWED=NO build
```

The second command checks Apple SDK compilation only; it does not authorize, sign, install, or verify restrictions. For installation use Xcode Run with your team and physical device. This project has no automated XCTest suite; use the device checklist for the framework integration and lifecycle behavior.

## Architecture and privacy

- `FocusDriveApp`: SwiftUI lifecycle, Hebrew locale, RTL, dark appearance.
- `HomeView`: one accessible, scrollable screen with authorization, system picker, status and driving controls. Hebrew labels correspond to Start Driving and End Driving.
- `DrivingViewModel`: main-actor state, individual authorization, token persistence, foreground/authorization reconciliation, and named-store shielding.

Only opaque system selection tokens and a session boolean are stored in local UserDefaults. No bundle IDs are inferred, transmitted, or logged. These values use the app sandbox, not a database or secret vault; normal device backup policies may apply. Selection edits are disabled during Driving Mode. Empty selections, selections above Apple's 50-app shielding limit, categories and websites cannot start a session. The picker edits a temporary selection; the model accepts it only after encoding and while authorized and inactive. Encoding failure removes the saved selection and prevents activation. Authorization loss clears the app's store, active state, and saved selection when observed; Apple voids selection tokens on revocation, so select WhatsApp again after reauthorization. A revocation/reapproval occurring entirely while the process is terminated may be unobservable; reselect if shielding fails. End Driving remains available while active.

`PrivacyInfo.xcprivacy` is included in Copy Bundle Resources and declares UserDefaults use for this app's own preferences (`CA92.1`), with no tracking or collected data. The placeholder bundle ID must be changed on the Mac. A custom app icon is not included; it is optional for development-device testing and required before App Store submission.

The active UI reflects the app's settings request, **not an independently verified enforcement result**: Managed Settings setters do not acknowledge shielding success. Other Screen Time controls may continue blocking an app after Focus & Drive clears its own store. See the limitations and recovery cases before relying on the MVP.

## Cloud workflow

Use the existing isolated checkout; do not create a worktree unless explicitly requested. Linux supports editing and `python3 scripts/validate_project.py` for project consistency. It cannot run Xcode, Apple's iOS SDK, or meaningful Family Controls integration tests. No cloud server, service, secrets or dependency installation are required. Apple signing credentials stay on the Mac. Do not interpret the cloud structural validator as an iOS build or functional test.

### GitHub Actions simulator build

[iOS Simulator Build](https://github.com/hubianron-cpu/focus-and-drive-ios/actions/workflows/ios-build.yml) uses GitHub's `macos-15` runner with installed Xcode 16.4, its bundled Swift compiler in Swift 5 language mode, and a generic iOS Simulator destination. Relevant project/workflow pushes to `feature/focus-drive-static-qa` trigger a build. It also declares `workflow_dispatch`; GitHub's manual-run UI requires the workflow to be present on the default branch. Do not merge merely to obtain that button.

The workflow disables code signing, preserves the `xcodebuild` exit status while logging, and inspects the built simulator executable, generated Info.plist and bundled privacy manifest. It uploads toolchain/build logs and the Xcode result bundle as artifacts for seven days, including on failure. It uses read-only repository permission, pinned actions and no signing secrets. No compatible automated test targets exist, so tests are explicitly **NOT RUN**.

Only a completed successful Actions run proves simulator compilation for its recorded commit and toolchain. It does not prove app launch, physical-device compilation/signing, Family Controls entitlement approval, authorization, or WhatsApp shielding. Those remain subject to the physical-iPhone checklist.
