//
//  SmartfinNativeDecoder.swift
//  smartfin
//

import Foundation

private func vec3(_ v: (Float, Float, Float)) -> [Double] {
    [Double(v.0), Double(v.1), Double(v.2)]
}

private func vec4(_ v: (Float, Float, Float, Float)) -> [Double] {
    [Double(v.0), Double(v.1), Double(v.2), Double(v.3)]
}

struct NativeDecodedSample: Equatable {
    enum Kind: Equatable {
        case temperature(elapsedMs: UInt32, celsius: Double, inWater: Bool)
        case imu(elapsedMs: UInt32, accel: [Double], gyro: [Double], mag: [Double])
        case quatImu(elapsedMs: UInt32, accel: [Double], gyro: [Double], mag: [Double], quaternion: [Double])
    }

    let kind: Kind
}

final class SmartfinNativeDecoder {
    private var sink: OpaquePointer?
    private var lastTempIndex: Int = 0
    private var lastImuIndex: Int = 0
    private var lastQuatImuIndex: Int = 0

    init() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            sink = sf_sink_create()
        }
    }

    deinit {
        if let sink {
            sf_sink_destroy(sink)
        }
    }

    func reset() {
        lastTempIndex = 0
        lastImuIndex = 0
        lastQuatImuIndex = 0
        if let sink {
            sf_sink_clear(sink)
        }
    }

    @discardableResult
    func pushPacket(_ data: Data) -> Int {
        guard let sink else { return -1 }
        return data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return Int(sf_sink_push_packet(sink, base, raw.count))
        }
    }

    func drainNewSamples() -> [NativeDecodedSample] {
        guard let sink else { return [] }
        var out: [NativeDecodedSample] = []

        let tempCount = Int(sf_sink_temp_count(sink))
        while lastTempIndex < tempCount {
            var t = SF_Temp()
            sf_sink_get_temp(sink, size_t(lastTempIndex), &t)
            lastTempIndex += 1
            out.append(NativeDecodedSample(kind: .temperature(
                elapsedMs: t.elapsed_ms,
                celsius: Double(t.temp_c),
                inWater: t.in_water != 0
            )))
        }

        let imuCount = Int(sf_sink_imu_count(sink))
        while lastImuIndex < imuCount {
            var imu = SF_Imu()
            sf_sink_get_imu(sink, size_t(lastImuIndex), &imu)
            lastImuIndex += 1
            out.append(NativeDecodedSample(kind: .imu(
                elapsedMs: imu.elapsed_ms,
                accel: vec3(imu.accel),
                gyro: vec3(imu.gyro),
                mag: vec3(imu.mag)
            )))
        }

        let quatCount = Int(sf_sink_quat_imu_count(sink))
        while lastQuatImuIndex < quatCount {
            var q = SF_QuatImu()
            sf_sink_get_quat_imu(sink, size_t(lastQuatImuIndex), &q)
            lastQuatImuIndex += 1
            out.append(NativeDecodedSample(kind: .quatImu(
                elapsedMs: q.elapsed_ms,
                accel: vec3(q.accel),
                gyro: vec3(q.gyro),
                mag: vec3(q.mag),
                quaternion: vec4(q.q)
            )))
        }

        return out
    }

    static func liveLogLines(for data: Data, pushResult: Int, samples: [NativeDecodedSample]) -> [String] {
        var lines: [String] = []
        let shown = data.prefix(40)
        let hex = shown.map { String(format: "%02x", $0) }.joined(separator: " ")
        let suffix = data.count > 40 ? " +\(data.count - 40)b" : ""
        lines.append("rx \(data.count)b: \(hex)\(suffix)")
        if pushResult != 0 {
            lines.append("  decode: malformed packet")
            return lines
        }
        if samples.isEmpty {
            lines.append("  decoded: (none)")
            return lines
        }
        for sample in samples {
            switch sample.kind {
            case .temperature(let ms, let c, let water):
                let f = c * 9.0 / 5.0 + 32.0
                var line = String(format: "  01 temp %.2fC %.1fF %@ fin %ums", c, f, water ? "in-water" : "dry", ms)
                if f < -50 || f > 150 { line += " (!)" }
                lines.append(line)
            case .imu(let ms, let accel, _, _):
                let preview = accel.prefix(3).map { String(format: "%.3f", $0) }.joined(separator: ",")
                lines.append("  0C imu [\(preview),…] fin \(ms)ms")
            case .quatImu(let ms, let accel, _, _, _):
                let preview = accel.prefix(3).map { String(format: "%.3f", $0) }.joined(separator: ",")
                lines.append("  0D quat [\(preview),…] fin \(ms)ms")
            }
        }
        return lines
    }
}
