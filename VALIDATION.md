# TGoshake V0.0.3 Validation

Validation dates: 2026-09-24 and 2026-09-25

| Check | Environment | Result |
|---|---|---|
| Simulator build | Xcode 26.6, iOS Simulator 26.5 SDK | Passed |
| Static analysis | Xcode 26.6, generic iOS Simulator | Passed |
| XCTest | SnapshotBuyCheck iPhone 16, iOS 26.5 | 4 tests passed, 0 failures |
| Simulator install and launch | SnapshotBuyCheck iPhone 16, iOS 26.5 | Passed |
| Home screen visual inspection | 1179 × 2556 screenshot | Passed; V0.0.3 visible and no obvious clipping |
| Built metadata | App `Info.plist` | `com.atex1.TGoshake`, version 0.0.3, build 3 |
| Asset catalog JSON | `jq empty` | Passed |
| AppIcon source | PNG inspection | 1024 × 1024, RGB, no alpha channel |
| Final XCTest rerun | SnapshotBuyCheck iPhone 16, iOS 26.5 | Passed, 4 tests and 0 failures |
| Signed physical-device build | Xcode 26.6, iPhoneOS 26.5 SDK | Passed with existing Apple Development provisioning |
| Physical-device installation | Atex-iPhone16, iPhone 16, iOS 27.0, USB | Passed as an in-place update |
| Installed metadata | `devicectl device info apps` | `火車搖起來`, version 0.0.3, build 3 |
| Physical-device launch | `devicectl device process launch` | Not verified; iPhone was locked and denied launch |

Test result bundle:

```text
work/v003-test/Logs/Test/Test-TGoshake-2026.09.24_21-28-02-+0800.xcresult
```

Visual evidence:

```text
work/TGoshake_V0.0.3_home.png
TGoshake_V0.0.3/TGoshake/Assets.xcassets/AppIcon.appiconset/TGoshake-AppIcon-1024.png
```

## Source acceptance checks

- Pause/resume and stop controls are the first card in the active recording scroll view.
- Elapsed time uses a one-line monospaced display; the marker button is in a separate row below status text.
- Default waveform selection is the simultaneous X/Y/Z three-card view; overlaid and single-axis views remain selectable.
- The live marker card remains bounded to the latest marker instead of adding one row per marker.
- No `UIFeedbackGenerator` or SwiftUI sensory-feedback call remains in marker creation.
- History rows provide a non-full-swipe destructive action, an explicit permanent-delete confirmation and a scoped `.tgoshake` folder guard.

## Evidence boundary

- iOS Simulator does not provide representative Device Motion, so the recording screen and actual waveform response were not runtime-validated in this cycle.
- Source inspection establishes that app-generated haptic feedback was removed; only a physical iPhone recording can show whether tapping the screen still produces a measurable mechanical disturbance from the user's finger.
- Permanent deletion was not performed against user records during validation. The confirmation text states that the session folder and its Motion, GPS, marker and analysis files cannot be recovered.
- Real GPS, Bluetooth controller input, requested 100 Hz delivery, battery behavior and long-duration screen layout remain physical-device checks.
- V0.0.3 was signed and update-installed without uninstalling the existing app. Launch verification remains blocked by the locked screen.
