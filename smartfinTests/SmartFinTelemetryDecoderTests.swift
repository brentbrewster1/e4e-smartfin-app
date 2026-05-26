//
//  SmartFinTelemetryDecoderTests.swift
//  smartfinTests
//

import Foundation
import Testing
@testable import smartfin

struct SmartFinTelemetryDecoderTests {

    @Test func nativeDecoderAcceptsMinimalPacket() {
        let decoder = SmartfinNativeDecoder()
        // Transport v=1, type=0, seq=0, payloadLen=0 — valid header, no ensembles.
        let bytes: [UInt8] = [0x01, 0, 0, 0, 0, 0]
        let result = decoder.pushPacket(Data(bytes))
        #expect(result == 0)
        #expect(decoder.drainNewSamples().isEmpty)
    }

    @Test func nativeDecoderRejectsTruncatedPacket() {
        let decoder = SmartfinNativeDecoder()
        let result = decoder.pushPacket(Data([0x01, 0, 0]))
        #expect(result != 0)
    }
}
