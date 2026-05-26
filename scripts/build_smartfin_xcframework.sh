#!/usr/bin/env bash
# Build merged SmartFin C++ bridge static libraries and package Vendor/*.xcframework.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT="${ROOT}/external"
VENDOR="${ROOT}/Vendor"
HEADER_SRC="${EXT}/src/bridge/smartfin_c_api.h"

LIBS=(
  smartfin_bridge
  smartfin_proc_core
  smartfin_filter
  smartfin_ahrs
  smartfin_math
  smartfin_pipeline
  smartfin_protocol
  smartfin_welch
)

merge_libs() {
  local build_dir="$1"
  local out="$2"
  local args=()
  for lib in "${LIBS[@]}"; do
    args+=("${build_dir}/lib${lib}.a")
  done
  libtool -static -o "$out" "${args[@]}"
}

cmake_build() {
  local build_dir="$1"
  local system_name="$2"
  local sysroot="$3"
  local arch="$4"

  cmake -B "${build_dir}" \
    -DCMAKE_SYSTEM_NAME="${system_name}" \
    -DCMAKE_OSX_SYSROOT="${sysroot}" \
    -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DSMARTFIN_ENABLE_BRIDGE=ON \
    -DSMARTFIN_ENABLE_SIMPLEBLE=OFF

  cmake --build "${build_dir}" --target smartfin_bridge -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
}

stage_slice() {
  local slice_dir="$1"
  local build_dir="$2"
  local lib_name="$3"
  rm -rf "${slice_dir}"
  mkdir -p "${slice_dir}/Headers"
  cp "${HEADER_SRC}" "${slice_dir}/Headers/"
  merge_libs "${build_dir}" "${slice_dir}/${lib_name}"
}

TMP="${EXT}/.xcframework-staging"
rm -rf "${TMP}"
mkdir -p "${TMP}"

echo "== iOS Simulator (arm64 + x86_64) =="
cmake_build "${EXT}/build-ios-simulator" "iOS" "iphonesimulator" "arm64;x86_64"
stage_slice "${TMP}/ios-arm64-simulator" "${EXT}/build-ios-simulator" "libsmartfin-iphonesimulator.a"

echo "== iOS Device (arm64) =="
cmake_build "${EXT}/build-ios-device" "iOS" "iphoneos" "arm64"
stage_slice "${TMP}/ios-arm64" "${EXT}/build-ios-device" "libsmartfin-iphoneos.a"

echo "== watchOS Device (arm64) =="
cmake_build "${EXT}/build-watchos-device" "watchOS" "watchos" "arm64"
stage_slice "${TMP}/watchos-arm64" "${EXT}/build-watchos-device" "libsmartfin-watchos.a"

echo "== watchOS Simulator (arm64 + x86_64) =="
cmake_build "${EXT}/build-watchos-simulator" "watchOS" "watchsimulator" "arm64;x86_64"
stage_slice "${TMP}/watchos-arm64-simulator" "${EXT}/build-watchos-simulator" "libsmartfin-watchsimulator.a"

mkdir -p "${VENDOR}"
rm -rf "${VENDOR}/SmartfinBridge-iOS.xcframework" "${VENDOR}/SmartfinBridge-watchOS.xcframework"

xcodebuild -create-xcframework \
  -library "${TMP}/ios-arm64-simulator/libsmartfin-iphonesimulator.a" -headers "${TMP}/ios-arm64-simulator/Headers" \
  -library "${TMP}/ios-arm64/libsmartfin-iphoneos.a" -headers "${TMP}/ios-arm64/Headers" \
  -output "${VENDOR}/SmartfinBridge-iOS.xcframework"

xcodebuild -create-xcframework \
  -library "${TMP}/watchos-arm64/libsmartfin-watchos.a" -headers "${TMP}/watchos-arm64/Headers" \
  -library "${TMP}/watchos-arm64-simulator/libsmartfin-watchsimulator.a" -headers "${TMP}/watchos-arm64-simulator/Headers" \
  -output "${VENDOR}/SmartfinBridge-watchOS.xcframework"

echo "Wrote ${VENDOR}/SmartfinBridge-iOS.xcframework"
echo "Wrote ${VENDOR}/SmartfinBridge-watchOS.xcframework"
