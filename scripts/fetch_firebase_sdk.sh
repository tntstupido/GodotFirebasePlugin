#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${ROOT_DIR}/third_party/firebase"
VERSION="${1:-12.10.0}"

mkdir -p "${DEST_DIR}"
cd "${DEST_DIR}"

gh release download "${VERSION}" --repo firebase/firebase-ios-sdk --pattern Firebase.zip --clobber
unzip -q -o Firebase.zip

echo "Fetched Firebase Apple SDK ${VERSION} into ${DEST_DIR}"
