//
//  SmartFinTelemetryDecoder.swift
//  smartfin
//

import Foundation

enum DecodedFinEnsemble: Equatable {
    case temperatureWater(finElapsedDs: UInt32, celsius: Double, waterRaw: UInt8)
    case highRateIMU(finElapsedDs: UInt32, imu9: [Double])
}

enum SmartFinTelemetryDecoder {
    static let telemetryCharacteristicUUID = "DEEDDB00-166E-407C-8158-7B9693AD2685"

    static func fahrenheit(fromCelsius celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    static func waterStatusString(from waterRaw: UInt8) -> String {
        switch waterRaw {
        case 0: return "dry"
        case 1: return "in-water"
        default: return "raw_\(waterRaw)"
        }
    }

    static func decodePacket(_ data: Data) -> [DecodedFinEnsemble] {
        guard data.count >= 6 else { return [] }

        let payloadLength = Int(readUInt16LE(data, offset: 4))
        let payloadStart = 6
        let payloadEnd = min(data.count, payloadStart + max(0, payloadLength))
        guard payloadEnd > payloadStart else { return [] }

        return parsePayload(data.subdata(in: payloadStart..<payloadEnd))
    }

    private static func parsePayload(_ payload: Data) -> [DecodedFinEnsemble] {
        var ensembles: [DecodedFinEnsemble] = []
        var offset = 0

        while offset + 3 <= payload.count {
            let headerWord = readUInt24LE(payload, offset: offset)
            let ensembleType = UInt8(headerWord & 0x0F)
            let finElapsedDs = (headerWord >> 4) & 0xFFFFF

            switch ensembleType {
            case 0x01:
                guard offset + 6 <= payload.count else { return ensembles }
                let tempRaw = readInt16LE(payload, offset: offset + 3)
                let waterRaw = payload[offset + 5]
                let celsius = Double(tempRaw) / 128.0
                ensembles.append(
                    .temperatureWater(
                        finElapsedDs: finElapsedDs,
                        celsius: celsius,
                        waterRaw: waterRaw
                    )
                )
                offset += 6

            case 0x0C:
                guard offset + 21 <= payload.count else { return ensembles }
                let imu9 = parseIMU9(payload.subdata(in: (offset + 3)..<(offset + 21)))
                ensembles.append(.highRateIMU(finElapsedDs: finElapsedDs, imu9: imu9))
                offset += 21

            default:
                return ensembles
            }
        }

        return ensembles
    }

    private static func parseIMU9(_ body: Data) -> [Double] {
        let scales: [Double] = [16384, 16384, 16384, 128, 128, 128, 8, 8, 8]
        var values: [Double] = []
        values.reserveCapacity(9)

        for index in 0..<9 {
            let raw = readInt16LE(body, offset: index * 2)
            values.append(Double(raw) / scales[index])
        }

        return values
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt16.self)
        }.littleEndian
    }

    private static func readInt16LE(_ data: Data, offset: Int) -> Int16 {
        data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: Int16.self)
        }.littleEndian
    }

    private static func readUInt24LE(_ data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        return b0 | b1 | b2
    }
}

#if DEBUG
extension SmartFinTelemetryDecoder {
    /// Synthetic transport + type `0x01` packet from `smartfin-decode-reference.md`.
    static func makeDemoTemperaturePacket(
        celsius: Double = 10.0,
        waterRaw: UInt8 = 1
    ) -> Data {
        let tempRaw = Int16(celsius * 128.0)
        var payload = Data([0x01, 0x00, 0x00])
        var tempBytes = tempRaw.littleEndian
        withUnsafeBytes(of: &tempBytes) { payload.append(contentsOf: $0) }
        payload.append(waterRaw)

        var packet = Data([0x01, 0x00, 0x00, 0x00])
        var payloadLen = UInt16(payload.count).littleEndian
        withUnsafeBytes(of: &payloadLen) { packet.append(contentsOf: $0) }
        packet.append(payload)
        return packet
    }
}
#endif
