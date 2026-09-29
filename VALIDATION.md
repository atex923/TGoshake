# TGoshake V0.0.4 Validation

Validation date: 2026-09-28

| Check | Environment | Result |
|---|---|---|
| Simulator build | Xcode 26.6, iPhone 16 simulator, iOS 26.5 | Passed |
| Static analysis | Xcode 26.6, generic iOS Simulator | Passed |
| XCTest | SnapshotBuyCheck iPhone 16, iOS 26.5 | Passed; 4 tests, 0 failures |
| Simulator install and launch | SnapshotBuyCheck iPhone 16, iOS 26.5 | Passed |
| Home visual inspection | 945 × 2048 screenshot | Passed; `V0.0.4(20260928)` visible with no obvious clipping |
| Settings About source check | `SettingsView.swift` | Passed; section title is exactly `關於` and required fields remain present |
| Built metadata | App `Info.plist` | Passed; `com.atex1.TGoshake`, version `0.0.4`, build `4`, iOS 17.0 minimum |
| Asset catalog JSON | `jq empty` | Passed |
| AppIcon source | PNG inspection | Passed; 1024 × 1024, no alpha channel |
| Shared About skill | `quick_validate.py` and iOS Simulator Swift type-check | Passed |
| Settings About visual interaction | macOS Simulator UI | Not completed; Mac was locked and UI automation could not open the Settings tab |
| Signed physical-device build | Xcode 26.6, iPhoneOS 26.5 SDK | Passed with existing Apple Development provisioning |
| Physical-device installation | Atex-iPhone16, iPhone 16, iOS 27.2, USB | Passed as an in-place update from 0.0.3 build 3 |
| Installed metadata | `devicectl device info apps` | Passed; `火車搖起來`, version `0.0.4`, build `4` |
| Physical-device launch | `devicectl device process launch` | Passed |

Test result bundle:

```text
work/v004-test/Logs/Test/Test-TGoshake-2026.09.28_22-57-51-+0800.xcresult
```

Visual evidence:

```text
work/TGoshake_V0.0.4_home.png
TGoshake_V0.0.4/TGoshake/Assets.xcassets/AppIcon.appiconset/TGoshake-AppIcon-1024.png
```

## Source acceptance checks

- The visible release string is assembled as `V#.#.#(YYYYMMDD)`.
- `#.#.#` is read from the built bundle's `CFBundleShortVersionString` rather than duplicated as a normal UI constant.
- The release date has one project-owned value: `20260928`.
- Home, Settings and recording metadata reuse `AppInfo`.
- The Settings section is titled `關於` and contains English name, Chinese name, version, developer and a tappable feedback email.
- Analysis version and build number are not shown in the normal About section.
- The existing bundle identifier and on-device data model were not changed.

## Evidence boundary

- Compilation establishes that the revised SwiftUI source is valid; it does not establish Settings layout behavior at every Dynamic Type size.
- The home screenshot verifies only the visible Home state. The Settings About screen still needs an unlocked interactive simulator or physical iPhone for direct visual inspection.
- Simulator launch does not validate Device Motion, real GPS, Bluetooth controller input, requested sample delivery rate, battery behavior or long-duration recording.
- V0.0.4 was signed, installed over V0.0.3 without uninstalling, and launched successfully. This preserves the existing app container by installation method, but does not by itself prove every prior record is readable.
- Google Drive and GitHub delivery are separate from app runtime validation and are reported independently.
