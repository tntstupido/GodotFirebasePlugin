#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/../../plugins/firebase_plugin"

: "${GODOT_HEADERS_DIR:?Set GODOT_HEADERS_DIR to the local Godot iOS headers directory}"
FIREBASE_SDK_DIR="${FIREBASE_SDK_DIR:-${ROOT_DIR}/../../../third_party/firebase/Firebase}"

IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

COMMON_GODOT_INCLUDES=(
	-I"${GODOT_HEADERS_DIR}"
	-I"${GODOT_HEADERS_DIR}/platform/ios"
	-I"${GODOT_HEADERS_DIR}/drivers/apple_embedded"
)

FIREBASE_FRAMEWORKS=(
	"FirebaseCore"
	"FirebaseAnalytics"
	"FirebaseCrashlytics"
)

VENDOR_XCFRAMEWORKS=(
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/FBLPromises.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseAnalytics.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseCore.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseCoreInternal.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseInstallations.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/GoogleAdsOnDeviceConversion.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/GoogleAppMeasurement.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/GoogleAppMeasurementIdentitySupport.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/GoogleUtilities.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseAnalytics/nanopb.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseCoreExtension.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseCrashlytics.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseRemoteConfigInterop.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseSessions.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/GoogleDataTransport.xcframework"
	"${FIREBASE_SDK_DIR}/FirebaseCrashlytics/Promises.xcframework"
)

sanitize_vendor_xcframework() {
	local xcframework_path="$1"
	find "${xcframework_path}" -type d -name "_CodeSignature" -prune -exec rm -rf {} +
	xattr -cr "${xcframework_path}" 2>/dev/null || true

	local framework_dir
	while IFS= read -r framework_dir; do
		local parent_dir
		parent_dir="$(basename "$(dirname "${framework_dir}")")"
		case "${parent_dir}" in
			ios-arm64|ios-arm64_x86_64-simulator)
				codesign --force --sign - "${framework_dir}"
				;;
		esac
	done < <(find "${xcframework_path}" -type d -name "*.framework")
}

rm -rf "${BUILD_DIR}"
mkdir -p \
	"${BUILD_DIR}/debug/iphoneos" \
	"${BUILD_DIR}/debug/iphonesimulator" \
	"${BUILD_DIR}/release/iphoneos" \
	"${BUILD_DIR}/release/iphonesimulator" \
	"${OUTPUT_DIR}/crashlytics_tools"
rm -rf \
	"${OUTPUT_DIR}/GodotFirebase.debug.xcframework" \
	"${OUTPUT_DIR}/GodotFirebase.release.xcframework" \
	"${OUTPUT_DIR}/GodotFirebase.xcframework"

framework_dir_for_sdk() {
	local sdk_name="$1"
	local framework_name="$2"
	if [[ "$sdk_name" == "iphoneos" ]]; then
		case "${framework_name}" in
			FirebaseCore)
				echo "${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseCore.xcframework/ios-arm64"
				;;
			FirebaseAnalytics)
				echo "${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseAnalytics.xcframework/ios-arm64"
				;;
			FirebaseCrashlytics)
				echo "${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseCrashlytics.xcframework/ios-arm64"
				;;
		esac
	else
		case "${framework_name}" in
			FirebaseCore)
				echo "${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseCore.xcframework/ios-arm64_x86_64-simulator"
				;;
			FirebaseAnalytics)
				echo "${FIREBASE_SDK_DIR}/FirebaseAnalytics/FirebaseAnalytics.xcframework/ios-arm64_x86_64-simulator"
				;;
			FirebaseCrashlytics)
				echo "${FIREBASE_SDK_DIR}/FirebaseCrashlytics/FirebaseCrashlytics.xcframework/ios-arm64_x86_64-simulator"
				;;
		esac
	fi
}

build_static_lib() {
	local sdk_name="$1"
	local sdk_path="$2"
	local arch="$3"
	local slice_dir="$4"
	local min_flag="$5"
	local debug_define="$6"
	local -a framework_flags=()

	for framework_name in "${FIREBASE_FRAMEWORKS[@]}"; do
		local framework_dir
		framework_dir="$(framework_dir_for_sdk "${sdk_name}" "${framework_name}")"
		framework_flags+=("-F${framework_dir}")
	done

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		${debug_define:+${debug_define}} \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		"${framework_flags[@]}" \
		-c "${SRC_DIR}/firebase_plugin.mm" \
		-o "${slice_dir}/firebase_plugin.o"

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		${debug_define:+${debug_define}} \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		"${framework_flags[@]}" \
		-c "${SRC_DIR}/firebase_plugin_bootstrap.mm" \
		-o "${slice_dir}/firebase_plugin_bootstrap.o"

	libtool -static \
		-o "${slice_dir}/libGodotFirebase.a" \
		"${slice_dir}/firebase_plugin.o" \
		"${slice_dir}/firebase_plugin_bootstrap.o"
}

build_static_lib "iphoneos" "${IOS_SDK_PATH}" "arm64" "${BUILD_DIR}/debug/iphoneos" "-miphoneos-version-min=15.0" "-DDEBUG_ENABLED"
build_static_lib "iphonesimulator" "${SIM_SDK_PATH}" "arm64" "${BUILD_DIR}/debug/iphonesimulator" "-mios-simulator-version-min=15.0" "-DDEBUG_ENABLED"
build_static_lib "iphoneos" "${IOS_SDK_PATH}" "arm64" "${BUILD_DIR}/release/iphoneos" "-miphoneos-version-min=15.0" ""
build_static_lib "iphonesimulator" "${SIM_SDK_PATH}" "arm64" "${BUILD_DIR}/release/iphonesimulator" "-mios-simulator-version-min=15.0" ""

xcodebuild -create-xcframework \
	-library "${BUILD_DIR}/debug/iphoneos/libGodotFirebase.a" \
	-headers "${SRC_DIR}" \
	-library "${BUILD_DIR}/debug/iphonesimulator/libGodotFirebase.a" \
	-headers "${SRC_DIR}" \
	-output "${OUTPUT_DIR}/GodotFirebase.debug.xcframework"

xcodebuild -create-xcframework \
	-library "${BUILD_DIR}/release/iphoneos/libGodotFirebase.a" \
	-headers "${SRC_DIR}" \
	-library "${BUILD_DIR}/release/iphonesimulator/libGodotFirebase.a" \
	-headers "${SRC_DIR}" \
	-output "${OUTPUT_DIR}/GodotFirebase.release.xcframework"

# Keep a stable base-name artifact expected by `firebase_plugin.gdip`.
cp -R "${OUTPUT_DIR}/GodotFirebase.release.xcframework" "${OUTPUT_DIR}/GodotFirebase.xcframework"

for framework_path in "${VENDOR_XCFRAMEWORKS[@]}"; do
	rsync -a "${framework_path}/" "${OUTPUT_DIR}/$(basename "${framework_path}")/"
	sanitize_vendor_xcframework "${OUTPUT_DIR}/$(basename "${framework_path}")"
done

cp "${FIREBASE_SDK_DIR}/FirebaseCrashlytics/run" "${OUTPUT_DIR}/crashlytics_tools/run"
cp "${FIREBASE_SDK_DIR}/FirebaseCrashlytics/upload-symbols" "${OUTPUT_DIR}/crashlytics_tools/upload-symbols"
chmod +x "${OUTPUT_DIR}/crashlytics_tools/run" "${OUTPUT_DIR}/crashlytics_tools/upload-symbols"

echo "Built xcframeworks in ${OUTPUT_DIR}"
