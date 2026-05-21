//
//  SmartFinTelemetryDecoderTests.swift
//  smartfinTests
//

import Foundation
import Testing
@testable import smartfin

struct SmartFinTelemetryDecoderTests {

    @Test func decodesSingleTemperatureEnsemble() {
        let bytes: [UInt8] = [0x01, 0, 0, 0, 0x06, 0, 0x01, 0, 0, 0, 0x05, 0x01]
        let decoded = SmartFinTelemetryDecoder.decodePacket(Data(bytes))
        #expect(decoded.count == 1)
        guard case .temperatureWater(_, let celsius, let water, let tempRaw) = decoded[0] else {
            #expect(false, "Expected temperatureWater ensemble")
            return
        }
        #expect(abs(celsius - 10.0) < 0.001)
        #expect(water == 1)
        #expect(tempRaw == 1280)
    }

    @Test func emptyWhenTooShort() {
        #expect(SmartFinTelemetryDecoder.decodePacket(Data([1, 2, 3])).isEmpty)
    }
}
