# Physical-iPhone QA

All functional cases below are **NOT RUN**. Record tester/date, hardware, iOS version, Xcode version, team/profile, commit or source snapshot, expected result, observed result, and PASS/FAIL per case. Test stationary and safely parked. Do not drive while testing. Any failed required case blocks acceptance of the corresponding behavior.

| Case | Steps and expected result |
| --- | --- |
| Build/sign/install | Open shared scheme, build with Apple SDK, sign with Family Controls profile, install on iOS 16+ physical iPhone. App launches without crash. Confirm `PrivacyInfo.xcprivacy` is present in the built app bundle. A generic app icon is expected for this development MVP. |
| First launch | Fresh install has Hebrew RTL, inactive status, disabled Start, explicit authorization action. No unsolicited permission prompt. |
| Authorization denial/cancel | Deny or cancel the system prompt. Show helpful message, remain inactive, no restrictions; explicit retry possible. |
| Authorization approval | Approve individual access. Picker action appears; no parent/child flow required. |
| Selection | Install WhatsApp and Waze. Pick WhatsApp only. Selected count is correct; Start enables. No bundle-ID lookup is assumed. |
| Empty/invalid selection | Deselect all, or select category/website. Start stays disabled and explanation appears. Picker can be reopened to correct selection. |
| Selection persistence | Select WhatsApp, dismiss the picker, terminate/relaunch while inactive. Authorized selection is restored and Start enables. |
| Selection limit | If enough apps are available, select more than 50 applications: Start stays disabled. Reduce to 50 or fewer to enable it. Record NOT RUN with reason if the device has too few apps. |
| Picker dismissal | Dismiss/reopen, verify final system selection persists. Cancel semantics should match the system picker. |
| Start and actual blocking | Start. Status becomes active. Leave app and open WhatsApp: system shield is shown. **Do not mark PASS from the status label alone.** |
| Waze/Phone available | With only WhatsApp selected, open Waze and start a stationary navigation preview. Use a normal test contact to check supported Bluetooth/CarPlay hands-free calls. Never test by calling emergency services. |
| End and restoration | End. Status inactive. Open WhatsApp and verify access restored when no other control blocks it. Waze/Phone remain available. |
| Multiple cycles | Repeat Start/End several times. No stuck shields, stale state, or extra prompts. Selection cannot be changed while active. |
| Background/lock | Start, background app and lock/unlock phone. WhatsApp remains shielded, return to app shows active. |
| Force quit/relaunch | Start, force quit, test WhatsApp, relaunch. Record both enforcement and restored state. End removes own shield. |
| Reboot | Start, reboot, test WhatsApp before reopening app, reopen and End. Record OS-specific enforcement, persistence and recovery. |
| Revocation inactive | Revoke authorization in iOS Settings. Return to app: inactive, Start disabled; explicit authorization retry works if allowed. |
| Revocation active | Start, revoke while app backgrounded, return. Active state is cleared and missing authorization explained. Check actual OS removal behavior. |
| Reauthorization | After revocation, grant authorization again; after observed revocation verify the old selection is empty and Start stays disabled until WhatsApp is selected again. Start and End then work. |
| Rapid revoke/reapprove | Revoke and reapprove while the app is running. Previously issued tokens are discarded; do not resume the old session. Select WhatsApp again. Also test the terminated-process variant and record limitations. |
| Other restrictions | Apply another legitimate Screen Time restriction. End clears only FocusDrive's named store; other restriction stays. Remove the other restriction separately and retest. |
| Removed/reinstalled selected app | Select WhatsApp, then remove/reinstall it while parked. Check stale token behavior, reselect and verify blocking again. |
| App removal | While parked, remove Focus & Drive during active mode. Record OS restriction cleanup. Reinstall: no false active state. |
| Accessibility/RTL | Largest Dynamic Type, VoiceOver, portrait/landscape, small iPhone: all actions reachable, the entire primary button (including its edges) responds to taps, Hebrew reading order sensible, status understandable without color. |
| Safety/privacy | No notifications, location/motion prompts, accounts, network calls or repeated prompts. Safety reminder present; End remains immediately reachable. |

If shielding remains unexpectedly, reopen Focus & Drive and End Driving. Inspect other Screen Time restrictions separately. If access was revoked, use iOS Settings to manage that permission. Do not claim Focus & Drive can remove settings belonging to other apps or system policies.

Acceptance requires successful device shielding and removal plus the required authorization, lifecycle and safety cases. The current cloud result validates none of these functional cases. File defects with exact steps, OS version and screenshots that omit private app selections where possible.
