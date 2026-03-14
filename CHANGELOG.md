# Changelog

## 2026-03-14

- Added initial `GodotFirebase` iOS source plugin.
- Added Firebase Analytics + Crashlytics bridge methods and signals.
- Added xcframework build script with true debug/release outputs.
- Added Firebase Apple SDK fetch helper and packaged payload release helper.
- Added Crashlytics helper-script packaging and dSYM workflow documentation.
- Raised the Firebase iOS minimum target to `15.0`.
- Added native early-start bootstrap so iOS runtime starts without the previous FirebaseCore default-app startup warning.
- Clarified that Xcode-project Crashlytics build-phase wiring belongs in the consuming-project export patch, not the source plugin payload.
- Added a native `trigger_test_crash()` API so the consuming project can trigger a real Crashlytics fatal test from its debug UI.
