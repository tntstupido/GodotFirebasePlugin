#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${ROOT_DIR}/ios/plugins/firebase_plugin"
OUTPUT_ZIP="${ROOT_DIR}/GodotFirebasePlugin-ios.zip"

rm -f "${OUTPUT_ZIP}"
cd "${ROOT_DIR}/ios/plugins"
zip -qry "${OUTPUT_ZIP}" firebase_plugin

echo "Packaged ${OUTPUT_ZIP}"
