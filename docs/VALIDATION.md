# Static review results

## Completed in cloud

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

Linux has neither Xcode nor the Apple SDK. Swift parsing/type checking against Apple SDKs, compilation, signing, simulator launch, physical-iPhone launch, authorization, WhatsApp shielding, shield removal, and all functional lifecycle QA remain **NOT RUN / UNVERIFIED**. Project parsing and source review are not substitutes for compilation or device tests. There is no automated XCTest suite.

## Remaining limitations and next gate

- Follow README.md on a Mac with full Xcode and an SDK compatible with the phone. Select a unique bundle ID and an eligible Apple Developer team; verify Family Controls provisioning before installation.
- Complete MANUAL_QA.md on a physical iPhone. Do not mark actual blocking PASS until WhatsApp shows a system shield and End Driving successfully clears this app's restriction.
- Individual authorization is revocable. Tokens may be stale after selected-app reinstall, and a revoke/reapprove transition entirely while the process is terminated can be unobservable. Reselect WhatsApp if needed. OS-managed settings and UserDefaults are not an atomic transaction.
- The app uses the system shield, without extensions. It does not enforce a system-wide Waze-only mode or guarantee navigation/call routing.
- No custom app icon is included. It does not block a development-device test, but must be supplied before App Store submission. Distribution separately requires Apple Family Controls approval.
- This follow-up was authorized to commit and push a feature branch only. No merge, environment publication or deployment was performed. Consult the reported Git SHA/branch for the exact reviewed snapshot.
