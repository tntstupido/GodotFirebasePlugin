# iOS Implementation Notes

## Architecture

`GodotFirebase` is a Godot iOS singleton backed by a native Objective-C++ bridge.

It configures Firebase from `GoogleService-Info.plist` at runtime using:

- `FirebaseCore`
- `FirebaseAnalytics`
- `FirebaseCrashlytics`

## Runtime Behavior

- The bridge attempts `FIROptions.defaultOptions`.
- If `GoogleService-Info.plist` is missing from the app bundle, the plugin emits `firebase_error`.
- `FirebaseApp.configureWithOptions(...)` is only attempted once a valid options object exists.
- `Crashlytics` is activated through the default app configure path.

## Event and Key Hygiene

The bridge sanitizes:

- event names
- analytics parameter keys
- user-property names
- Crashlytics custom-key names

This keeps the Godot side simple and avoids coupling the game project to Firebase naming edge cases.

## Crashlytics / dSYM Handling

### Automatic path

The packaged payload includes:

- `crashlytics_tools/run`
- `crashlytics_tools/upload-symbols`

The consuming project should patch the exported Xcode project to:

- add `GoogleService-Info.plist` to target resources
- add a Crashlytics run-script build phase that points at `crashlytics_tools/run`

### Manual fallback

If automatic symbol upload is incomplete, run:

```bash
/path/to/crashlytics_tools/upload-symbols \
  -gsp /path/to/GoogleService-Info.plist \
  -p ios \
  /path/to/App.dSYM
```

Important distinction:

- app binary + statically linked plugin code: symbolicated through the app dSYM
- vendor Firebase framework symbolication: may still depend on vendor symbol availability

## Packaging Notes

The build script copies the exact Analytics + Crashlytics xcframework set required by the plugin payload. It does not ship other Firebase products.
