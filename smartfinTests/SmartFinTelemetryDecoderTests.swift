//
//  SmartFinTelemetryDecoderTests.swift
//  smartfinTests
//

import Foundation
import Testing
@testable import smartfin

struct SmartFinTelemetryDecoderTests {

    @Test func decodeGoldenTemperaturePacket() throws {
        let hex = "010000000600010000000501"
        let data = dataFromHex(hex)
        let ensembles = SmartFinTelemetryDecoder.decodePacket(data)

        #expect(ensembles.count == 1)

        guard case .temperatureWater(let finElapsedDs, let celsius, let waterRaw) = ensembles[0] else {
            Issue.record("Expected temperatureWater ensemble")
            return
        }

        #expect(finElapsedDs == 0)
        #expect(celsius == 10.0)
        #expect(waterRaw == 1)
        #expect(SmartFinTelemetryDecoder.waterStatusString(from: waterRaw) == "in-water")
        #expect(SmartFinTelemetryDecoder.fahrenheit(fromCelsius: celsius) == 50.0)
    }

    @Test func decodeEmptyWhenTooShort() {
        let ensembles = SmartFinTelemetryDecoder.decodePacket(Data([0x01, 0x00]))
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
