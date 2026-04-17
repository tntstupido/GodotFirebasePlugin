#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_ROOT="${GAME_ROOT:-$(cd "${PLUGIN_ROOT}/../../GodotProjects/rule-rings" && pwd)}"

mkdir -p "$GAME_ROOT/addons/firebase_plugin"
mkdir -p "$GAME_ROOT/ios/plugins/firebase_plugin"

cp "$PLUGIN_ROOT/godot/addons/firebase_plugin/plugin.cfg" "$GAME_ROOT/addons/firebase_plugin/"
cp "$PLUGIN_ROOT/godot/addons/firebase_plugin/firebase_plugin.gd" "$GAME_ROOT/addons/firebase_plugin/"
cp "$PLUGIN_ROOT/godot/autoload/FirebaseManager.gd" "$GAME_ROOT/addons/firebase_plugin/"
cp "$PLUGIN_ROOT/godot/addons/firebase_plugin/FirebasePlugin-debug.aar" "$GAME_ROOT/addons/firebase_plugin/" 2>/dev/null || true
cp "$PLUGIN_ROOT/godot/addons/firebase_plugin/FirebasePlugin-release.aar" "$GAME_ROOT/addons/firebase_plugin/" 2>/dev/null || true

rm -rf "$GAME_ROOT/ios/plugins/firebase_plugin"
mkdir -p "$GAME_ROOT/ios/plugins/firebase_plugin"
cp -R "$PLUGIN_ROOT/ios/plugins/firebase_plugin/." "$GAME_ROOT/ios/plugins/firebase_plugin/"

echo "Copied Firebase addon payload to $GAME_ROOT"
