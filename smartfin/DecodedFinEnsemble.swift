//
//  DecodedFinEnsemble.swift
//  smartfin
//

import Foundation

enum DecodedFinEnsemble: Equatable {
    case temperatureWater(finElapsedMs: UInt32, celsius: Double, inWater: Bool)
    case highRateIMU(finElapsedMs: UInt32, imu9: [Double])
    case quatImu(finElapsedMs: UInt32, imu9: [Double], quaternion: [Double])
}

enum FinEnsembleMapper {
    static func ensembles(from samples: [NativeDecodedSample]) -> [DecodedFinEnsemble] {
        samples.map { sample in
            switch sample.kind {
            case .temperature(let ms, let celsius, let inWater):
                return .temperatureWater(finElapsedMs: ms, celsius: celsius, inWater: inWater)
            case .imu(let ms, let accel, let gyro, let mag):
                return .highRateIMU(finElapsedMs: ms, imu9: accel + gyro + mag)
            case .quatImu(let ms, let accel, let gyro, let mag, let q):
                return .quatImu(finElapsedMs: ms, imu9: accel + gyro + mag, quaternion: q)
            }
        }
    }
}
