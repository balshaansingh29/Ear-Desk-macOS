import Foundation

public enum ANCMode: Equatable, CaseIterable {
    case off, transparency, high, mid, low, adaptive

    /// Wire byte, from setANC_BT / readANC in bluetooth_socket.js.
    public var wire: UInt8 {
        switch self {
        case .off: return 0x05
        case .transparency: return 0x07
        case .low: return 0x03
        case .high: return 0x01
        case .mid: return 0x02
        case .adaptive: return 0x04
        }
    }
    public init?(wire: UInt8) {
        guard let m = ANCMode.allCases.first(where: { $0.wire == wire }) else { return nil }
        self = m
    }
    public var title: String {
        switch self {
        case .off: return "Off"
        case .transparency: return "Transparency"
        case .high: return "Noise Cancellation: High"
        case .mid: return "Noise Cancellation: Mid"
        case .low: return "Noise Cancellation: Low"
        case .adaptive: return "Noise Cancellation: Adaptive"
        }
    }
}

public struct BatteryInfo: Equatable {
    public struct Cell: Equatable { public var level: Int; public var charging: Bool; public init(level: Int, charging: Bool = false) { self.level = level; self.charging = charging } }
    public var left: Cell?
    public var right: Cell?
    public var caseCell: Cell?
    public var stereo: Cell?
    public init(left: Cell? = nil, right: Cell? = nil, caseCell: Cell? = nil, stereo: Cell? = nil) {
        self.left = left; self.right = right; self.caseCell = caseCell; self.stereo = stereo
    }
}

public struct CustomEQ: Equatable {
    public var bass: Int    // -6 ... +6
    public var mid: Int     // -6 ... +6
    public var treble: Int  // -6 ... +6

    public init(bass: Int = 0, mid: Int = 0, treble: Int = 0) {
        self.bass = max(-6, min(6, bass))
        self.mid = max(-6, min(6, mid))
        self.treble = max(-6, min(6, treble))
    }
}

/// Dual connection paired device record.
public struct DualDeviceItem: Equatable, Identifiable {
    public var id: String { mac }
    public let mac: String
    public let name: String
    public let isCurrentHost: Bool
    public let isConnected: Bool

    public init(mac: String, name: String, isCurrentHost: Bool, isConnected: Bool) {
        self.mac = mac
        self.name = name
        self.isCurrentHost = isCurrentHost
        self.isConnected = isConnected
    }
}

public enum Messages {
    // MARK: Requests
    public static func setANC(_ mode: ANCMode) -> (UInt16, [UInt8]) {
        (Command.setANC, [0x01, mode.wire, 0x00])
    }
    public static func setEQ(_ index: UInt8) -> (UInt16, [UInt8]) {
        (Command.setEQ, [index, 0x00])
    }
    public static func setListeningMode(_ index: UInt8) -> (UInt16, [UInt8]) {
        (Command.setListeningMode, [index, 0x00])
    }
    public static func setInEar(_ on: Bool) -> (UInt16, [UInt8]) {
        (Command.setInEar, [on ? 0x01 : 0x00])
    }
    public static func setLowLatency(_ on: Bool) -> (UInt16, [UInt8]) {
        (Command.setLatency, [on ? 0x01 : 0x02, 0x00])
    }

    /// UTC time payload is 4 bytes big-endian seconds since 1970.
    public static func setTime(_ date: Date = Date()) -> (UInt16, [UInt8]) {
        let secs = UInt32(max(0, date.timeIntervalSince1970))
        let payload = [
            UInt8((secs >> 24) & 0xFF),
            UInt8((secs >> 16) & 0xFF),
            UInt8((secs >> 8) & 0xFF),
            UInt8(secs & 0xFF),
        ]
        return (Command.setTime, payload)
    }

    /// Bass enhance level: 0..5 (or 0..2 for 3-stage models).
    public static func setBass(enabled: Bool, level: Int, threeStage: Bool) -> (UInt16, [UInt8]) {
        let wireLevel: UInt8 = threeStage
            ? [0x00, 0x05, 0x0A][max(0, min(2, level))]
            : UInt8(max(0, min(5, level)) * 2)
        return (Command.setBass, [enabled ? 0x01 : 0x00, wireLevel])
    }

    /// Dual connection enable / disable: 0xF01A payload [0x01] or [0x00].
    public static func setDualConnection(_ enabled: Bool) -> (UInt16, [UInt8]) {
        (Command.setDualConnection, [enabled ? 0x01 : 0x00])
    }

    /// Dual connection device list request: 0xC028 payload [startIndex] (usually 0x00).
    public static func getDualConnectionList(start: UInt8 = 0) -> (UInt16, [UInt8]) {
        (Command.getDualConnectionList, [start])
    }

    /// Dual device connect or disconnect: 0xF01B payload [0x01 or 0x00, macByte0...macByte5].
    public static func setDualDeviceConnect(mac: String, connect: Bool) -> (UInt16, [UInt8])? {
        let clean = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        guard clean.count == 12 else { return nil }
        var bytes: [UInt8] = [connect ? 0x01 : 0x00]
        for i in stride(from: 0, to: 12, by: 2) {
            let start = clean.index(clean.startIndex, offsetBy: i)
            let end = clean.index(start, offsetBy: 2)
            guard let b = UInt8(clean[start..<end], radix: 16) else { return nil }
            bytes.append(b)
        }
        return (Command.setDualDeviceConnect, bytes)
    }

    /// Spatial Audio payload: [mode, headTracking]
    public static func setSpatialAudio(_ mode: SpatialAudioMode) -> (UInt16, [UInt8]) {
        let (m, h) = mode.wirePayload
        return (Command.setSpatialAudio, [m, h])
    }

    /// Constructs the 53-byte payload for 0xF041:
    /// byte 0: 0x03 (3 bands)
    /// bytes 1..4: total gain float32 LE
    /// bytes 5..17: Mid band (type 0x01, gain float32 LE, freq 980.0 float32 LE, Q 0.7 float32 LE)
    /// bytes 18..30: Treble band (type 0x02, gain float32 LE, freq float32 LE, Q 1.0 float32 LE)
    /// bytes 31..43: Bass band (type 0x00, gain float32 LE, freq 140.0 float32 LE, Q 0.8 float32 LE)
    /// bytes 44..52: padding / terminator (zeros)
    public static func setCustomEQ(bass: Int, mid: Int, treble: Int, highShelfFreq: Float = 3500.0) -> (UInt16, [UInt8]) {
        let b = max(-6, min(6, bass))
        let m = max(-6, min(6, mid))
        let t = max(-6, min(6, treble))

        // Total gain is -max(b, m, t) if positive, else 0.0
        let maxPos = max(0, max(b, max(m, t)))
        let totalGain: Float = maxPos > 0 ? -Float(maxPos) : 0.0

        var payload = [UInt8](repeating: 0, count: 53)
        payload[0] = 0x03

        func writeFloat(_ value: Float, at offset: Int) {
            var val = value
            withUnsafeBytes(of: &val) {
                for (i, byte) in $0.enumerated() {
                    payload[offset + i] = byte
                }
            }
        }

        writeFloat(totalGain, at: 1)

        // Mid band
        payload[5] = 0x01
        writeFloat(Float(m), at: 6)
        writeFloat(980.0, at: 10)
        writeFloat(0.7, at: 14)

        // Treble band
        payload[18] = 0x02
        writeFloat(Float(t), at: 19)
        writeFloat(highShelfFreq, at: 23)
        writeFloat(1.0, at: 27)

        // Bass band
        payload[31] = 0x00
        writeFloat(Float(b), at: 32)
        writeFloat(140.0, at: 36)
        writeFloat(0.8, at: 40)

        return (Command.setCustomEQ, payload)
    }

    /// Ring command:
    /// - perBud (default): 0xF002 [0x02 or 0x03, 0x01 or 0x00]
    /// - single (ear 1):   0xF002 [0x06, 0x01 or 0x00]
    /// - headphone:        0xF002 [0x06, 0x01 or 0x00]
    public static func ring(on: Bool, left: Bool = true, style: DeviceModel.RingStyle = .perBud) -> (UInt16, [UInt8]) {
        let deviceID: UInt8
        switch style {
        case .single, .headphone: deviceID = 0x06
        case .perBud:             deviceID = left ? 0x02 : 0x03
        }
        return (Command.ring, [deviceID, on ? 0x01 : 0x00])
    }

    // MARK: Parsing responses
    public static func parseBattery(_ p: Packet) -> BatteryInfo {
        var info = BatteryInfo()
        let count = Int(p.raw.count > 8 ? p.raw[8] : 0)
        for i in 0..<count {
            let offset = 9 + i * 2
            guard p.raw.count >= offset + 2 else { break }
            let id = p.raw[offset]
            let levelByte = p.raw[offset + 1]
            let cell = BatteryInfo.Cell(
                level: Int(levelByte & 0x7F),
                charging: (levelByte & 0x80) != 0
            )
            switch id {
            case 0x02: info.left = cell
            case 0x03: info.right = cell
            case 0x04: info.caseCell = cell
            case 0x06: info.stereo = cell
            default: break
            }
        }
        return info
    }

    public static func parseANC(_ p: Packet) -> ANCMode? {
        p.raw.count > 9 ? ANCMode(wire: p.raw[9]) : nil
    }
    public static func parseEQ(_ p: Packet) -> UInt8? { p.raw.count > 8 ? p.raw[8] : nil }

    public static func parseFirmware(_ p: Packet) -> String {
        let size = Int(p.raw.count > 5 ? p.raw[5] : 0)
        let end = min(p.raw.count, 8 + size)
        guard end > 8 else { return "" }
        return String(decoding: p.raw[8..<end], as: UTF8.self)
    }

    /// In-ear detection flag lives at raw[10] (quirk of the protocol, per readInEar).
    public static func parseInEar(_ p: Packet) -> Bool? { p.raw.count > 10 ? p.raw[10] == 1 : nil }
    public static func parseLowLatency(_ p: Packet) -> Bool? { p.raw.count > 8 ? p.raw[8] == 1 : nil }

    public static func parseBass(_ p: Packet, threeStage: Bool) -> (enabled: Bool, level: Int)? {
        guard p.raw.count > 9 else { return nil }
        let wireLevel = Int(p.raw[9])
        let level = threeStage ? ([0, 5, 10].firstIndex(of: wireLevel) ?? 0) : wireLevel / 2
        return (p.raw[8] == 1, level)
    }

    /// Parses 0x4027 Dual Connection enabled response. Byte 8 == 1 enabled.
    public static func parseDualConnection(_ p: Packet) -> Bool? {
        p.raw.count > 8 ? p.raw[8] == 1 : nil
    }

    /// Parses 0x4028 Dual Connection list response.
    /// Byte 10: count
    /// From byte 11:
    ///   byte 0: flags (high nibble nonzero = this host, low nibble nonzero = connected)
    ///   bytes 1..6: 6-byte MAC address
    ///   byte 7: name length (bits 0..6)
    ///   bytes 8..<8+len: UTF-8 name
    public static func parseDualConnectionList(_ p: Packet) -> [DualDeviceItem] {
        let r = p.raw
        guard r.count > 10 else { return [] }
        let count = Int(r[10])
        var items: [DualDeviceItem] = []
        var cursor = 11

        for _ in 0..<count {
            guard r.count >= cursor + 8 else { break }
            let flags = r[cursor]
            let isCurrentHost = (flags & 0xF0) != 0
            let isConnected = (flags & 0x0F) != 0
            let macBytes = Array(r[(cursor + 1)..<(cursor + 7)])
            let mac = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
            let nameLen = Int(r[cursor + 7] & 0x7F)
            cursor += 8

            let nameEnd = min(r.count, cursor + nameLen)
            let name: String
            if nameEnd > cursor {
                name = String(decoding: r[cursor..<nameEnd], as: UTF8.self)
            } else {
                name = "Unknown Device"
            }
            cursor = nameEnd
            items.append(DualDeviceItem(mac: mac, name: name, isCurrentHost: isCurrentHost, isConnected: isConnected))
        }
        return items
    }

    /// Parses 0x4044 Custom EQ response. Band gains are float32 LE at bytes 14..17, 27..30, 40..43.
    public static func parseCustomEQ(_ p: Packet) -> CustomEQ? {
        let r = p.raw
        guard r.count >= 44 else { return nil }
        func readFloat(at offset: Int) -> Float {
            let slice = Array(r[offset..<offset+4])
            return slice.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
        }
        let m = Int(round(readFloat(at: 14)))
        let t = Int(round(readFloat(at: 27)))
        let b = Int(round(readFloat(at: 40)))
        return CustomEQ(bass: b, mid: m, treble: t)
    }

    /// Parses 0x404F / 0xE029 Spatial Audio reply. Byte 8 is mode, byte 9 is head tracking.
    public static func parseSpatialAudio(_ p: Packet) -> SpatialAudioMode? {
        guard p.raw.count > 8 else { return nil }
        let modeByte = p.raw[8]
        let headByte = p.raw.count > 9 ? p.raw[9] : 0
        return SpatialAudioMode.from(modeByte: modeByte, headByte: headByte)
    }
}
