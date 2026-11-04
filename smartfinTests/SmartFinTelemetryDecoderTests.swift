//
//  SmartFinTelemetryDecoderTests.swift
//  smartfinTests
//

import Foundation
import Testing
@testable import smartfin

struct SmartFinTelemetryDecoderTests {

    // Vectors below follow smartfin-fw3's packed structs: 6-byte transport header,
    // then ensembles with a 4-byte header (type in low 4 bits, elapsed ms above).

    @Test func decodeGoldenTemperaturePacket() throws {
        // Transport: v1, telemetry, seq 0, len 7 | Ens 0x01 @ 5000 ms | 18.5 C (2368) | wet
        let hex = "010100000700" + "81380100" + "4009" + "01"
        let data = dataFromHex(hex)
        let ensembles = SmartFinTelemetryDecoder.decodePacket(data)

        #expect(ensembles.count == 1)

        guard case .temperatureWater(let finElapsedDs, let celsius, let waterRaw) = ensembles[0] else {
            Issue.record("Expected temperatureWater ensemble")
            return
        }

        #expect(finElapsedDs == 50) // 5000 ms -> 50 ds
        #expect(celsius == 18.5)
        #expect(waterRaw == 1)
        #expect(SmartFinTelemetryDecoder.waterStatusString(from: waterRaw) == "in-water")
        #expect(SmartFinTelemetryDecoder.fahrenheit(fromCelsius: celsius) == 65.3)
    }

    @Test func decodeEmptyWhenTooShort() {
        let ensembles = SmartFinTelemetryDecoder.decodePacket(Data([0x01, 0x00]))
        #expect(ensembles.isEmpty)
    }

    @Test func imuOnlyPacketYieldsNoTemperature() {
        // One 36-byte 0x0D (IMU+quat) record. Must not be misread as a temperature.
        let hex = "010100002400" + "0d000000" + String(repeating: "00", count: 32)
        let ensembles = SmartFinTelemetryDecoder.decodePacket(dataFromHex(hex))
        #expect(ensembles.isEmpty)
    }

    @Test func temperatureAfterImuRecordIsDecoded() {
        // 0x0D record @ 4950 ms (skipped), then 0x01 @ 5000 ms, 18.5 C, wet. len 43.
        let hex = "010100002b00" + "6d350100" + String(repeating: "00", count: 32)
            + "81380100" + "4009" + "01"
        let ensembles = SmartFinTelemetryDecoder.decodePacket(dataFromHex(hex))

        #expect(ensembles.count == 1)
        guard case .temperatureWater(let finElapsedDs, let celsius, let waterRaw) = ensembles[0] else {
            Issue.record("Expected temperatureWater ensemble")
            return
        }
        #expect(finElapsedDs == 50)
        #expect(celsius == 18.5)
        #expect(waterRaw == 1)
    }

    @Test func truncatedPacketDropsPartialEnsemble() {
        // Same packet as above but cut off right after the temperature ensemble's 4-byte
        // header (as an MTU-limited notification would be). No crash, no partial reading.
        let hex = "010100002b00" + "6d350100" + String(repeating: "00", count: 32) + "81380100"
        let ensembles = SmartFinTelemetryDecoder.decodePacket(dataFromHex(hex))
        #expect(ensembles.isEmpty)
    }

    @Test func decodeDemoPacketBuilder() {
        let data = SmartFinTelemetryDecoder.makeDemoTemperaturePacket(celsius: 22.0, waterRaw: 0)
        let ensembles = SmartFinTelemetryDecoder.decodePacket(data)
        #expect(ensembles.count == 1)

        guard case .temperatureWater(_, let celsius, let waterRaw) = ensembles[0] else {
            Issue.record("Expected temperatureWater ensemble")
            return
        }

        #expect(abs(celsius - 22.0) < 0.01)
        #expect(waterRaw == 0)
    }
}

private func dataFromHex(_ hexString: String) -> Data {
    var data = Data()
    var index = hexString.startIndex
    while index < hexString.endIndex {
        let next = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
        let byte = hexString[index..<next]
        if let value = UInt8(byte, radix: 16) {
            data.append(value)
        }
        index = next
    }
    return data
}
