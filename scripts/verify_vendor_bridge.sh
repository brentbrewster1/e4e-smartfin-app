#!/usr/bin/env bash
# Fail fast when Vendor xcframework slices are missing (common after incomplete git pull).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_SIM="${ROOT}/Vendor/SmartfinBridge-iOS.xcframework/ios-arm64_x86_64-simulator/libsmartfin-iphonesimulator.a"
IOS_DEV="${ROOT}/Vendor/SmartfinBridge-iOS.xcframework/ios-arm64/libsmartfin-iphoneos.a"
# Legacy slice name from older xcframework builds
IOS_SIM_LEGACY="${ROOT}/Vendor/SmartfinBridge-iOS.xcframework/ios-arm64-simulator/libsmartfin-iphonesimulator.a"

if [[ ! -f "$IOS_SIM" && -f "$IOS_SIM_LEGACY" ]]; then
  echo "warning: using legacy Vendor simulator slice (ios-arm64-simulator). Rebuild with ./scripts/build_smartfin_xcframework.sh" >&2
  IOS_SIM="$IOS_SIM_LEGACY"
fi

missing=0
for path in "$IOS_SIM" "$IOS_DEV"; do
  if [[ ! -f "$path" ]]; then
    echo "error: missing $path" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Run: ./scripts/build_smartfin_xcframework.sh" >&2
  echo "Then commit Vendor/ or pull the latest branch." >&2
  exit 1
fi

if ! nm "$IOS_SIM" 2>/dev/null | grep -q '_sf_sink_create'; then
  echo "error: $IOS_SIM does not contain sf_sink symbols (wrong or stale library)" >&2
  exit 1
fi

echo "Vendor SmartfinBridge iOS libraries OK"
