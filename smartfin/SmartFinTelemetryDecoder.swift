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

    // Packet layout from smartfin-fw3 (src/ble/ble_transport.hpp, src/deploy/ensembleTypes.hpp):
    //   [6-byte transport header: version u8, type u8, seq u16, payloadLen u16]
    //   followed by ensembles packed back to back, each starting with a 4-byte
    //   EnsembleHeader_t (low 4 bits = type, upper 28 bits = elapsed ms). All little-endian.
    private static let transportHeaderSize = 6
    private static let ensembleHeaderSize = 4

    /// Total on-wire size (4-byte header + data) of each fw3 ensemble type.
    /// Ensembles carry no length field, so the size is needed to find the next one.
    private static let ensembleSizes: [UInt8: Int] = [
        0x01: 7,   // Ensemble01: int16 temp*128, u8 water
        0x07: 6,   // Ensemble07: u16 battery mV
        0x08: 11,  // Ensemble08: int16 temp*128, u8 water, u32 unix time
        0x0C: 22,  // Ensemble12: 9 x int16 IMU
        0x0D: 36,  // Ensemble13: 9 x int16 IMU, 3 x int32 quat, int16 accuracy
        0x0F: 37,  // Text (FW version): u8 nChars, 32 chars
    ]

    /// Decodes one fw3 BLE telemetry notification (transport header + ensembles).
    static func decodePacket(_ data: Data) -> [DecodedFinEnsemble] {
        guard data.count >= transportHeaderSize else { return [] }

        let payloadLength = Int(readUInt16LE(data, offset: 4))
        // min(): a notification cut short by the BLE MTU still decodes its complete ensembles.
        let payloadEnd = min(data.count, transportHeaderSize + payloadLength)
        guard payloadEnd > transportHeaderSize else { return [] }

        return parsePayload(data.subdata(in: transportHeaderSize..<payloadEnd))
    }

    static func parsePayload(_ payload: Data) -> [DecodedFinEnsemble] {
        var ensembles: [DecodedFinEnsemble] = []
        var offset = 0

        while offset + ensembleHeaderSize <= payload.count {
            let headerWord = readUInt32LE(payload, offset: offset)
            let ensembleType = UInt8(headerWord & 0x0F)
            // fw3 sends milliseconds; downstream records store deciseconds.
            let finElapsedDs = (headerWord >> 4) / 100

            // Unknown type: the next ensemble's position can't be known, so stop.
            guard let size = ensembleSizes[ensembleType] else { return ensembles }
            // Partial ensemble (e.g. notification truncated): stop.
            guard offset + size <= payload.count else { return ensembles }

            let body = offset + ensembleHeaderSize
            switch ensembleType {
            case 0x01, 0x08:
                let tempRaw = readInt16LE(payload, offset: body)
                let waterRaw = payload[body + 2]
                ensembles.append(
                    .temperatureWater(
                        finElapsedDs: finElapsedDs,
                        celsius: Double(tempRaw) / 128.0,
                        waterRaw: waterRaw
                    )
                )

            case 0x0C:
                let imu9 = parseIMU9(payload.subdata(in: body..<(body + 18)))
                ensembles.append(.highRateIMU(finElapsedDs: finElapsedDs, imu9: imu9))

            default:
                break // Known size but not used by the app (e.g. 0x0D IMU+quat): skip it.
            }

            offset += size
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
        // Avoid using `load(as:)` on potentially misaligned pointers (can crash on some architectures).
        // Assemble from bytes to be safe on any alignment.
        guard offset + 1 < data.count else { return 0 }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1]) << 8
        return b0 | b1
    }

    private static func readInt16LE(_ data: Data, offset: Int) -> Int16 {
        let u = readUInt16LE(data, offset: offset)
        return Int16(bitPattern: u)
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}

#if DEBUG
extension SmartFinTelemetryDecoder {
    /// Synthetic fw3 transport + type `0x01` packet (4-byte ensemble header, elapsed 0 ms).
    static func makeDemoTemperaturePacket(
        celsius: Double = 10.0,
        waterRaw: UInt8 = 1
    ) -> Data {
        let tempRaw = Int16(celsius * 128.0)
        var payload = Data([0x01, 0x00, 0x00, 0x00])
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
