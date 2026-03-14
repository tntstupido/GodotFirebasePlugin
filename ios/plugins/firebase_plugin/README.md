# firebase_plugin

Packaged Godot iOS Firebase plugin payload.

Contents:

- `GodotFirebase.debug.xcframework`
- `GodotFirebase.release.xcframework`
- required Firebase Analytics + Crashlytics dependency xcframeworks
- `crashlytics_tools/run`
- `crashlytics_tools/upload-symbols`
- `firebase_plugin.gdip`

The consuming project must still provide a real `GoogleService-Info.plist`.
