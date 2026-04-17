# GodotFirebasePlugin

Firebase Core plugin for Godot 4:
- Analytics
- Crashlytics
- Remote Config
- Firebase Messaging (Android v1)

## Repo layout
- `android/` Android Godot plugin source (`FirebasePlugin.kt`)
- `godot/addons/firebase_plugin/` Godot EditorExportPlugin script
- `godot/autoload/FirebaseManager.gd` runtime wrapper
- `ios/` iOS plugin scaffold + `.gdip` payload descriptor

## Build notes (Android)
1. Copy Godot template AARs into `android/firebaseplugin/libs/`:
   - `godot-lib.template_debug.aar`
   - `godot-lib.template_release.aar`
2. Build:
   ```bash
   cd android
   ./gradlew :firebaseplugin:assembleDebug :firebaseplugin:assembleRelease
   ```
3. Copy output AARs from `android/firebaseplugin/build/outputs/aar/` into:
   - `godot/addons/firebase_plugin/FirebasePlugin-debug.aar`
   - `godot/addons/firebase_plugin/FirebasePlugin-release.aar`
