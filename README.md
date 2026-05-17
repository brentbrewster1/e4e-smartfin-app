# SmartFin (iOS + watchOS)

## Requirements

- Xcode 16+ (project targets iOS / watchOS 11)
- Apple Watch simulator or paired watch for the watch app

## Open and build

1. Clone the repo and open `smartfin.xcodeproj`.
2. Select the **smartfin** scheme (iOS app; embeds the watch app).
3. Choose an **iPhone** simulator or device, then **Product → Build** (⌘B) or **Run** (⌘R).

To run only the watch UI, use the **smartfinwatchos Watch App** scheme with a watch simulator.

## Notes

- BLE requires a real device for meaningful SmartFin connectivity; the iOS target includes a Run Script phase that strips Bluetooth capability requirements for **simulator** builds only.
- Session sample JSON is written on the watch under Application Support when you save a session; see `smartfin_data.txt` for the data pipeline spec.
