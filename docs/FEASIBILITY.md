# Feasibility and platform boundaries

## Supported design

Use iOS 16+ `AuthorizationCenter.shared.requestAuthorization(for: .individual)`, `FamilyActivityPicker`, and `ManagedSettingsStore(named:)`. Apply only `store.shield.applications = selection.applicationTokens`. End Driving calls `clearAllSettings()` on **FocusDrive.driving**, never a different store. Apple's system provides the default shield; no shield extensions, App Group, or DeviceActivity scheduling are required for this manual session.

The picker supplies privacy-preserving opaque tokens. The app cannot reliably identify WhatsApp by name or bundle ID, preselect it programmatically, or assert that the user selected it. Users select WhatsApp themselves. Apple limits `shield.applications` to 50 application tokens; larger selections are rejected before activation. The picker may expose categories and websites; this MVP rejects these selections rather than applying them. It does not implement a public-API Waze-only system mode. Waze is intended to remain usable because it is unselected, but users must avoid selecting it. Existing system/parental restrictions are independent.

No Phone restrictions, call interception, GPS, background polling or driving detection are applied. Hands-free calling is supplied by iOS/CarPlay/Bluetooth and must be tested with the actual setup. This app does not guarantee call routing or override other restrictions. Never place a real emergency call as a test.

## Lifecycle and reliability limits

Managed Settings are OS-managed rather than dependent on a foreground loop. The coordinator persists requested intent and tokens together, migrates prior v1 keys, and is exercised using mock clients under macOS XCTest. The app reapplies its own settings on launch/foreground while authorization is approved. This is a design for session continuity, not proof that shielding survives force quit or reboot on every iOS release. Verify these cases on the target device. No DeviceActivity extension or background entitlement is used.

Individual authorization is voluntary: the user can revoke access or remove the app. It is not anti-tamper parental control. If authorization is lost, enforcement cannot be promised. The publisher and foreground checks update the UI while the process runs; a terminated process cannot immediately react. Apple explicitly states that authorization revocation voids previously issued selection tokens. This app clears the selection when it observes authorization loss, including a nonapproved publisher event followed rapidly by approval, and requires reselection. If revocation and reapproval both occur while the process is terminated, that transition may be unobservable. Tokens may also become stale after selected-app removal/reinstallation. A nonempty token set does not prove current shielding; reselect when appropriate and test.

The user may dismiss or deny authorization; Start remains disabled. No repeated requests or automatic prompts occur. App selection and authorization happen only through explicit actions. Requested sessions and detected cleanup failures retain End Driving; a short parked-safely reminder is always visible, without a modal confirmation or notification.

UserDefaults and Managed Settings are not a single atomic transaction. A crash between updates can leave temporary disagreement, reconciled on the next launch. There is no public enforcement-success acknowledgement used here. Backup restore, reboot, OS updates, revocation, and deletion behavior must be validated; this app is not a safety-critical lock and should not be relied on as the sole distraction prevention measure.

## Official references to review on the Mac

- [Family Controls](https://developer.apple.com/documentation/familycontrols)
- [Request individual authorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))
- [FamilyActivityPicker](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
- [Managed Settings](https://developer.apple.com/documentation/managedsettings)
- [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore)
- [Family Controls entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls)
- [Configure Family Controls](https://developer.apple.com/help/account/capabilities/configure-family-controls/)

Apple documentation was initially blocked during preparation, then successfully retrieved during the follow-up static review. The authorization publisher, individual authorization availability (iOS 16), token invalidation on revocation, named-store scope, and distribution approval requirements were checked against Apple documentation. This is documentation verification, not SDK compilation or proof of entitlement approval for this app. Confirm account-specific provisioning on the Mac.

UserDefaults use is declared with reason `CA92.1` in the bundled privacy manifest. See [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).


The visible driving status now reports request submission explicitly. Coordinator failure tests cover throwing storage/encoding or injected store clients; Apple's native Managed Settings methods themselves are nonthrowing and provide no guarantee that specified settings govern effective device behavior. No polling, timing heuristic or readback is treated as evidence of enforcement. A physical test is necessary for notifications, previously running apps, calls/navigation coexistence and actual shielding.
