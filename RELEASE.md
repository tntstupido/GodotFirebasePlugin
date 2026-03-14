# Release Workflow

## 1. Fetch or update the Firebase Apple SDK

```bash
./scripts/fetch_firebase_sdk.sh
```

## 2. Build the native plugin xcframeworks

```bash
GODOT_HEADERS_DIR=/path/to/godot-4.5.1-stable \
FIREBASE_SDK_DIR=/Users/mladen/Documents/Plugins/GodotFirebasePlugin/third_party/firebase/Firebase \
./ios/native/FirebasePlugin/scripts/build_xcframework.sh
```

## 3. Package the Godot iOS payload

```bash
./scripts/package_release.sh
```

## 4. Sync into the consuming Godot project

Copy `ios/plugins/firebase_plugin/` into the game project and re-export iOS.

## 5. Validate in the exported Xcode project

- confirm `GoogleService-Info.plist` is present in the target resources
- confirm the Crashlytics run script exists in the target build phases
- confirm archive dSYM generation is enabled
- confirm Crashlytics can symbolicate app crashes after upload
