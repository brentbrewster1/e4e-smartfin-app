# SmartFin (iOS + watchOS)

## Requirements

- Xcode 16+ (iOS / watchOS 11 deployment targets)
- iPhone with Bluetooth for fin sessions (simulator can build/run UI but not real BLE)

## Open and build

1. Clone with submodules and open `smartfin.xcodeproj`:
   ```bash
   git clone --recurse-submodules <repo-url>
   cd e4e-smartfin-app-2
   ```
   If you already cloned without submodules: `git submodule update --init --recursive`.
2. Prebuilt C++ decode libraries live in `Vendor/SmartfinBridge-*.xcframework` (linked by both iOS and watch targets). To rebuild after changing `external/`:
   ```bash
   ./scripts/build_smartfin_xcframework.sh
   ```
3. Scheme **smartfin** → iPhone simulator or device → Build (⌘B) or Run (⌘R).
4. Scheme **smartfinwatchos Watch App** for watch-only UI.

Session flow (start → connect SmartFin → record → save → history) is shared between iPhone and watch. Saved sample JSON lives in each app’s Application Support (`SmartFinSessionReadings/`).

## Testing

- Unit tests: **smartfin** scheme → `SmartFinTelemetryDecoderTests` in `smartfinTests` (exercises the native C++ bridge via `SmartfinNativeDecoder`).
- Device: use a real iPhone to scan/connect to a fin named with `smartfin`.

## Notes

- iOS simulator builds strip Bluetooth capability requirements via a Run Script phase so the app installs; use a device for BLE.
- `smartfin_data.txt` describes the full data pipeline spec.
