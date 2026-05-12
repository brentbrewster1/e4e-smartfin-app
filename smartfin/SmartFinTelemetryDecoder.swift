//
//  SmartFinTelemetryDecoder.swift
//  smartfin
//

import Foundation

enum SmartFinDecodeError: Error, Equatable {
    case packetTooShort
    case incompleteEnsembleHeader
    case incompleteTemperatureRecord
    case incompleteIMURecord
    case outOfBounds
}

enum DecodedFinEnsemble: Equatable {
    case temperatureWater(finElapsedDs: UInt32, celsius: Double, waterRaw: UInt8)
    case highRateIMU(finElapsedDs: UInt32, imu9: [Double])
}

enum SmartFinTelemetryDecoder {
    private static let transportHeaderSize = 6
    private static let ensembleHeaderSize = 3
    private static let ensTemp: UInt8 = 0x01
    private static let ensHighRateIMU: UInt8 = 0x0C

    static func decodePacket(_ data: Data) -> [DecodedFinEnsemble] {
        guard data.count >= transportHeaderSize else { return [] }

        let payloadLen = readUInt16LE(data, offset: 4)
        let payloadEnd = min(data.count, transportHeaderSize + Int(payloadLen))
        let payload = data.subdata(in: transportHeaderSize..<payloadEnd)

        var results: [DecodedFinEnsemble] = []
        var offset = 0

        while offset + ensembleHeaderSize <= payload.count {
            guard let header = try? decodeEnsembleHeader(payload, offset: offset) else { break }

            let recordSize: Int?
            switch header.ensembleType {
            case ensTemp:
                recordSize = ensembleHeaderSize + 3
            case ensHighRateIMU:
                recordSize = ensembleHeaderSize + 18
            default:
                recordSize = nil
            }

            guard let rs = recordSize else { break }
            if offset + rs > payload.count { break }

            switch header.ensembleType {
            case ensTemp:
                if let reading = try? decodeTemperatureWater(payload, offset: offset) {
                    results.append(.temperatureWater(
                        finElapsedDs: header.elapsedTimeDeciseconds,
                        celsius: reading.temperatureCelsius,
                        waterRaw: reading.waterStatusRaw
                    ))
                }
            case ensHighRateIMU:
                if let reading = try? decodeHighRateIMU(payload, offset: offset) {
                    results.append(.highRateIMU(finElapsedDs: header.elapsedTimeDeciseconds, imu9: reading.imu9))
                }
            default:
                break
            }

            offset += rs
        }

        return results
    }

    private struct EnsembleHeader {
        let ensembleType: UInt8
        let elapsedTimeDeciseconds: UInt32
    }

    private static func decodeEnsembleHeader(_ data: Data, offset: Int) throws -> EnsembleHeader {
        guard offset + ensembleHeaderSize <= data.count else {
            throw SmartFinDecodeError.incompleteEnsembleHeader
        }

        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let headerWord = b0 | (b1 << 8) | (b2 << 16)

        let ensembleType = UInt8(headerWord & 0x0F)
        let elapsedTimeDs = (headerWord >> 4) & 0xFFFFF

        return EnsembleHeader(ensembleType: ensembleType, elapsedTimeDeciseconds: elapsedTimeDs)
    }

    private struct TemperatureWaterReading {
        let temperatureCelsius: Double
        let waterStatusRaw: UInt8
    }

    private static func decodeTemperatureWater(_ data: Data, offset: Int) throws -> TemperatureWaterReading {
        let valueOffset = offset + ensembleHeaderSize
        guard valueOffset + 3 <= data.count else {
            throw SmartFinDecodeError.incompleteTemperatureRecord
        }

        let raw = try readInt16LE(data, offset: valueOffset)
        let water = data[valueOffset + 2]
        let tempC = Double(raw) / 128.0

        return TemperatureWaterReading(temperatureCelsius: tempC, waterStatusRaw: water)
    }

    private struct HighRateIMUReading {
        let imu9: [Double]
    }

    private static func decodeHighRateIMU(_ data: Data, offset: Int) throws -> HighRateIMUReading {
        let valueOffset = offset + ensembleHeaderSize
        guard valueOffset + 18 <= data.count else {
            throw SmartFinDecodeError.incompleteIMURecord
        }

        let ax = try readInt16LE(data, offset: valueOffset + 0)
        let ay = try readInt16LE(data, offset: valueOffset + 2)
        let az = try readInt16LE(data, offset: valueOffset + 4)
        let gx = try readInt16LE(data, offset: valueOffset + 6)
        let gy = try readInt16LE(data, offset: valueOffset + 8)
        let gz = try readInt16LE(data, offset: valueOffset + 10)
        let mx = try readInt16LE(data, offset: valueOffset + 12)
        let my = try readInt16LE(data, offset: valueOffset + 14)
        let mz = try readInt16LE(data, offset: valueOffset + 16)

        let imu9: [Double] = [
            Double(ax) / 16384.0, Double(ay) / 16384.0, Double(az) / 16384.0,
            Double(gx) / 128.0, Double(gy) / 128.0, Double(gz) / 128.0,
            Double(mx) / 8.0, Double(my) / 8.0, Double(mz) / 8.0
        ]

        return HighRateIMUReading(imu9: imu9)
    }

    private static func readInt16LE(_ data: Data, offset: Int) throws -> Int16 {
        guard offset + 2 <= data.count else { throw SmartFinDecodeError.outOfBounds }
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return Int16(bitPattern: lo | (hi << 8))
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return lo | (hi << 8)
    }
}
