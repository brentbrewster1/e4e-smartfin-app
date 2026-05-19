# SmartFin

SmartFin is an iPhone + watchOS app that captures SmartFin sensor data, stores it locally, and uploads it to a backend server.

## What This Project Does

1. Connects to a SmartFin device over Bluetooth.
2. Collects sensor readings during watch sessions.
3. Stores sessions and ensembles locally.
4. Transfers watch data to the paired iPhone using WatchConnectivity.
5. Uploads data from iPhone to the backend API.

## Main App Targets

- `smartfin/` - iPhone app and phone-side sync/upload logic.
- `smartfinwatchos Watch App/` - watch app session flow and watch-side transfer logic.

## Core File Guide

### Shared Data + Session Logic

- `smartfin/SessionManager.swift`
: Central session state, local persistence, merge helpers, and server upload orchestration.

- `smartfin/TransferModels.swift`
: Codable payload models used for watch-to-phone transfer batches.

- `smartfin/SessionData.swift`
: iOS session model used by server and sync paths.

### iPhone App

- `smartfin/smartfinApp.swift`
: iPhone entry point; creates and provides `SyncDataManager`.

- `smartfin/SyncDataManager.swift`
: Phone-side WatchConnectivity receiver; merges incoming watch batches and triggers uploads.

- `smartfin/ServerManager.swift`
: REST client for server endpoints (`/sessions`, `/ensembles`).

- `smartfin/ContentView.swift`
: Main iPhone UI for Bluetooth status/logs and debug test trigger in simulator.

- `smartfin/BluetoothManager.swift`
: Real Bluetooth implementation for iPhone/device builds.

- `smartfin/MockBluetoothManager.swift`
: Simulator-only mock Bluetooth data for iPhone UI testing.

### watchOS App

- `smartfinwatchos Watch App/smartfinwatchosApp.swift`
: Watch entry point; wires shared session manager + watch sync manager.

- `smartfinwatchos Watch App/SessionFlowView.swift`
: Main watch session state flow (ready, connecting, active, complete, history).

- `smartfinwatchos Watch App/WatchSyncDataManager.swift`
: Watch-side WatchConnectivity sender; flushes pending local data to paired phone.

- `smartfinwatchos Watch App/MockBluetoothManager.swift`
: Mock data source for watch simulator testing.

## Local Development Notes

- Use an up-to-date Xcode version that supports the project iOS/watchOS SDKs.
- For simulator testing with a local backend, default server base URL is:
	- `http://127.0.0.1:8000/api`
	- https://github.com/UCSD-E4E/smartfin-data-endpoint-v2

