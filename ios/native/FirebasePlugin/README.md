# Native iOS Firebase Plugin

Native Objective-C++ bridge for the Godot iOS `GodotFirebase` singleton.

## Build

```bash
GODOT_HEADERS_DIR=/path/to/godot-4.5.1-stable \
FIREBASE_SDK_DIR=/Users/mladen/Documents/Plugins/GodotFirebasePlugin/third_party/firebase/Firebase \
./scripts/build_xcframework.sh
```

## Output

The build script writes:

- `../../plugins/firebase_plugin/GodotFirebase.debug.xcframework`
- `../../plugins/firebase_plugin/GodotFirebase.release.xcframework`

and refreshes the packaged Firebase dependency xcframeworks used by the Godot exporter.
