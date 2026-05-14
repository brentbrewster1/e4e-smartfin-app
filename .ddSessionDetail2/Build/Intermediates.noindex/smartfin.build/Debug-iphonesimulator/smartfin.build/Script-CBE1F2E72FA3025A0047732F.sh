#!/bin/sh
#!/usr/bin/env bash
# Remove bluetooth-required device capability keys from the built Info.plist
# when building for the iOS Simulator. Paste this into a Run Script build
# phase in your app target (only for the app target).

set -e

# Only operate for simulator builds
if [ "${PLATFORM_NAME}" != "iphonesimulator" ] && [ "${EFFECTIVE_PLATFORM_NAME}" != "-iphonesimulator" ]; then
  # Not a simulator build — do nothing
  exit 0
fi

PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
if [ ! -f "${PLIST_PATH}" ]; then
  echo "Built Info.plist not found at ${PLIST_PATH}. Nothing to do."
  exit 0
fi

# Helper to safely run PlistBuddy commands (ignore failures)
pb() {
  /usr/libexec/PlistBuddy -c "$1" "${PLIST_PATH}" 2>/dev/null || true
}

# Remove known bluetooth-related required device capability keys
pb "Delete :UIRequiredDeviceCapabilities:bluetooth-le"
pb "Delete :UIRequiredDeviceCapabilities:bluetooth-central"
pb "Delete :UIRequiredDeviceCapabilities:bluetooth-peripheral"

# If UIRequiredDeviceCapabilities exists but became empty, delete the whole key
EXISTS=$(/usr/libexec/PlistBuddy -c "Print :UIRequiredDeviceCapabilities" "${PLIST_PATH}" 2>/dev/null || echo "NOPE")
if [ "${EXISTS}" != "NOPE" ]; then
  COUNT=$(/usr/libexec/PlistBuddy -c "Print :UIRequiredDeviceCapabilities" "${PLIST_PATH}" 2>/dev/null | wc -l || echo 0)
  if [ "${COUNT}" -le 1 ]; then
    pb "Delete :UIRequiredDeviceCapabilities"
  fi
fi

echo "Simulator Info.plist: removed bluetooth required-device-capabilities if present"

