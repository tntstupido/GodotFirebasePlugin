# GodotFirebasePlugin

iOS Firebase plugin for Godot 4.5.1 that exposes Firebase Analytics and Crashlytics through a single `GodotFirebase` singleton.

## Scope

- Firebase Analytics event logging
- Firebase Crashlytics logs, custom keys, user ID, and non-fatal errors
- iOS only
- Built as a Godot iOS plugin payload plus a native source-plugin repo

## Public API

- `is_ready() -> bool`
- `log_event(event_name: String, params: Dictionary = {})`
- `set_user_id(user_id: String)`
- `set_user_property(name: String, value: String)`
- `set_crashlytics_custom_key(name: String, value: Variant)`
- `log_crashlytics_message(message: String)`
- `record_nonfatal(message: String, details: Dictionary = {})`

Signals:

- `firebase_ready`
- `firebase_error(code: int, message: String)`

## Repo Layout

- `ios/native/FirebasePlugin/`
  - native Objective-C++ bridge
  - xcframework build script
- `ios/plugins/firebase_plugin/`
  - packaged Godot iOS plugin payload
- `scripts/fetch_firebase_sdk.sh`
  - downloads the official Firebase Apple SDK zip
- `scripts/package_release.sh`
  - zips the packaged iOS plugin payload

## Build

Prerequisites:

- local Godot 4.5.1 iOS headers
- official Firebase Apple SDK extracted under `third_party/firebase/Firebase`
- Xcode command-line tools
- `gh` authenticated if you want to use the fetch script

Fetch SDK:

```bash
./scripts/fetch_firebase_sdk.sh
```

Build xcframeworks and refresh the packaged payload:

```bash
GODOT_HEADERS_DIR=/path/to/godot-4.5.1-stable \
FIREBASE_SDK_DIR=/Users/mladen/Documents/Plugins/GodotFirebasePlugin/third_party/firebase/Firebase \
./ios/native/FirebasePlugin/scripts/build_xcframework.sh
```

The build script creates:

- `ios/plugins/firebase_plugin/GodotFirebase.debug.xcframework`
- `ios/plugins/firebase_plugin/GodotFirebase.release.xcframework`

and copies the required Firebase xcframework dependencies plus Crashlytics helper scripts into the packaged payload directory.

## Consuming Project

Sync `ios/plugins/firebase_plugin/` into the Godot game project under the same path and enable the plugin in the iOS export preset.

The consuming project must also provide a real `GoogleService-Info.plist`. This plugin intentionally does not ship a placeholder config file.

## dSYM Notes

- App crashes and statically linked plugin code are symbolicated by the app archive dSYM.
- Firebase vendor-framework symbolication may still depend on vendor-provided symbols and can produce separate non-blocking warnings.
- Crashlytics helper scripts are copied into `ios/plugins/firebase_plugin/crashlytics_tools/` for archive-time or manual symbol upload workflows.
