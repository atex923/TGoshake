# Changelog

## V0.0.3 — 2026-09-24

- Moved pause/resume and stop controls to the first row of the recording screen.
- Kept the elapsed timer on one line and placed the perceived-shake marker below the recording status.
- Removed app-generated haptic feedback from manual marker creation to avoid contaminating motion samples.
- Added a simultaneous three-card X/Y/Z waveform view while retaining overlaid and individual-axis modes.
- Limited the live marker card to one latest-record summary so new markers do not continuously expand the screen.
- Added trailing swipe-to-delete for stored sessions with destructive confirmation and error handling.
- Added the supplied artwork as an opaque 1024 × 1024 AppIcon.
- Advanced the app to version 0.0.3, build 3.
- Moved `V0.0.3(20260925)` below the home-screen start button and reused the same value in Settings and recording metadata.
- Removed the analysis-version row from Settings, shortened the privacy explanation, and added developer and feedback-email information.

## V0.0.2 — 2026-09-24

- Changed the live chart to a moving ten-second time window with dynamic amplitude scaling.
- Added all-axis, lateral, longitudinal and vertical chart selection.
- Moved the manual perceived-shake marker beside the elapsed timer and added tappable recent marker details.
- Made stored trip rows navigable to trip metadata, record counts and export details.
- Changed travel direction presets to northbound, southbound and other.
- Added route and train-type presets, train-specific carriage ranges and manual fallback fields.
- Kept seat entry manual and added locomotive-front and locomotive-rear placement choices.
- Advanced the app to version 0.0.2, build 2.
- Added a unit test covering train-specific carriage limits and manual fallback behavior.

## V0.0.1 — 2026-09-08

- Created the SwiftUI iPhone app project under the English name `TGoshake` and Chinese display name `火車搖起來`.
- Added trip setup, five-second mounting check, foreground recording, pause/resume, results, history and settings flows.
- Added 100 Hz-class `CMDeviceMotion` collection and Core Location collection with source timestamps and accuracy fields.
- Added streaming CSV/JSON session packages and incomplete-session manifest state.
- Added live three-axis charts and post-trip 0.5–30 Hz analysis.
- Added RMS, P95, peak, jerk, rotation-rate and relative-percentile hotspot scoring.
- Added MapKit colored routes, GPS uncertainty circles and event details.
- Added on-screen perceived-shake markers and Apple Game Controller A-button point/interval markers.
- Added precise-GPS warning and acknowledgement before sharing a session package.
- Added automated analyzer and signal-filter tests.
