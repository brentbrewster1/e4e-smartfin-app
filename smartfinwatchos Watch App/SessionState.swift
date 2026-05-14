//
//  SessionState.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

enum SessionState {
    case ready
    /// Scanning / listing real SmartFin peripherals (CoreBluetooth).
    case selectFin
    case active
    case complete
    case history
}
