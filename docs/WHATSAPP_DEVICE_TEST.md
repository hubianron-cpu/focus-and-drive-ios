# Stationary WhatsApp blocking acceptance test

**Status: NOT TESTED on a physical iPhone.** No simulator or mock-test result may change this status.

Record tester/date, device model, iOS/Xcode versions, source commit, bundle identifier, signing team/profile and Family Controls capability status. Do not record opaque tokens or account credentials. Perform every step stationary, safely parked. Never test while driving.

Preconditions: physical iPhone running iOS 16+, WhatsApp installed, full Xcode on a Mac compatible with the phone, eligible development signing/profile with `com.apple.developer.family-controls`. Verify WhatsApp opens normally beforehand. Document other Screen Time policies; remove them only using their own authorized controls if isolation is needed. Install the app following README.md. A simulator build does not supply device entitlements.

1. **Install and open Focus & Drive.** Expected: Hebrew RTL screen, inactive status; no automatic permission prompt.
2. **Grant individual authorization.** Tap `מתן הרשאת זמן מסך` and approve Apple's system prompt. Expected: picker action available. On denial/cancellation, Start stays disabled; do not mark the scenario PASS.
3. **Select WhatsApp.** Tap `בחירת יישומים להגבלה`; use FamilyActivityPicker to select WhatsApp only, not its entire category or any website. Leave Waze and Phone unselected. Dismiss the picker. Expected: one selected app and Start enabled. The app cannot identify WhatsApp from opaque tokens itself.
4. **Request Driving Mode.** Tap `התחלת נהיגה`. Expected: `מצב נהיגה: בקשת הגבלה נשלחה` and `סיום נהיגה`. The screen explicitly states iOS enforcement is not acknowledged. This proves only local request submission; it is not a blocking PASS.
5. **Attempt to open WhatsApp.** Leave Focus & Drive and launch WhatsApp from the Home Screen. Record exactly what happens. Do not infer shielding from Focus & Drive's status label.
6. **Observe the system shield.** Expected for blocking PASS: Apple's Screen Time restriction shield prevents normal access to WhatsApp. Record screenshot/observation and iOS version, omitting private content. If WhatsApp opens normally, mark blocking FAIL, return while parked, verify authorization and selection, reselect WhatsApp if necessary, and retest with recorded steps. Do not substitute unsupported APIs or claim system-wide Waze-only enforcement.
7. **End Driving.** Return to Focus & Drive, tap `סיום נהיגה`. Expected: inactive state; only the `FocusDrive.driving` store receives a clear request. If an error is detected, End stays reachable for a parked-safely retry.
8. **Verify WhatsApp access.** Relaunch WhatsApp. Expected for removal PASS: normal access restored when no independent restriction applies. If another app/system Screen Time policy still blocks it, document that policy and retest in isolation. Focus & Drive must not clear the other policy.

| Result | Classification | Evidence |
| --- | --- | --- |
| Individual authorization | NOT TESTED | Physical-device observation required |
| Picker/selection persistence | NOT TESTED | Physical-device observation required |
| Actual WhatsApp system shield | NOT TESTED | Must observe step 6 |
| Actual removal after End | NOT TESTED | Must observe step 8 |
| Waze/hands-free calls coexistence | NOT TESTED | Separate stationary device setup needed; never call emergency services as a test |

Then run background/lock, force quit, restart, reboot, authorization revocation, reauthorization/reselection, v1 migration, stale tokens after WhatsApp reinstall, repeated Start/End and other-policy coexistence cases in MANUAL_QA.md. Individual authorization can be revoked and the app can be removed; no anti-tamper guarantee exists. Selection/shielding does not guarantee suppression of notifications, notification actions or every already-running app surface; record observed iOS limitations instead of claiming coverage.
