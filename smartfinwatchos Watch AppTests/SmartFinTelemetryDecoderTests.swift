//
//  SmartFinTelemetryDecoderTests.swift
//  smartfinwatchos Watch AppTests
//

import Foundation
import Testing
@testable import smartfinwatchos_Watch_App

struct SmartFinTelemetryDecoderTests {

    @Test func nativeDecoderAcceptsMinimalPacket() {
        let decoder = SmartfinNativeDecoder()
        let bytes: [UInt8] = [0x01, 0, 0, 0, 0, 0]
        let result = decoder.pushPacket(Data(bytes))
        #expect(result == 0)
        #expect(decoder.drainNewSamples().isEmpty)
    }
}
