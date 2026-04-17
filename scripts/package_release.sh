#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/dist"
ADDONS_DIR="${OUT_DIR}/addons/firebase_plugin"

rm -rf "$OUT_DIR"
mkdir -p "$ADDONS_DIR"

cp "$ROOT_DIR/godot/addons/firebase_plugin/plugin.cfg" "$ADDONS_DIR/"
cp "$ROOT_DIR/godot/addons/firebase_plugin/firebase_plugin.gd" "$ADDONS_DIR/"
cp "$ROOT_DIR/godot/addons/firebase_plugin/FirebasePlugin-debug.aar" "$ADDONS_DIR/" 2>/dev/null || true
cp "$ROOT_DIR/godot/addons/firebase_plugin/FirebasePlugin-release.aar" "$ADDONS_DIR/" 2>/dev/null || true
cp "$ROOT_DIR/godot/autoload/FirebaseManager.gd" "$OUT_DIR/"

mkdir -p "$OUT_DIR/ios/plugins/firebase_plugin"
cp -R "$ROOT_DIR/ios/plugins/firebase_plugin/." "$OUT_DIR/ios/plugins/firebase_plugin/"

echo "Packaged payload at: $OUT_DIR"
