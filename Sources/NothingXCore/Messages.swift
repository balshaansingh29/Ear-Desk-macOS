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
    public struct Cell: Equatable { public var level: Int; public var charging: Bool }
    public var left: Cell?
    public var right: Cell?
    public var caseCell: Cell?
    public var stereo: Cell?
    public init(left: Cell? = nil, right: Cell? = nil, caseCell: Cell? = nil, stereo: Cell? = nil) {
        self.left = left; self.right = right; self.caseCell = caseCell; self.stereo = stereo
    }
}

public enum Messages {
    // MARK: Requests
    public static func setANC(_ mode: ANCMode) -> (UInt16, [UInt8]) {
        (Command.setANC, [0x01, mode.wire, 0x00])
    }
    public static func setEQ(_ wire: UInt8) -> (UInt16, [UInt8]) { (Command.setEQ, [wire, 0x00]) }
    public static func setListeningMode(_ wire: UInt8) -> (UInt16, [UInt8]) { (Command.setListeningMode, [wire, 0x00]) }
    public static func setInEar(_ on: Bool) -> (UInt16, [UInt8]) { (Command.setInEar, [0x01, 0x01, on ? 1 : 0]) }
    /// Web client: on -> 0x01, off -> 0x02.
    public static func setLowLatency(_ on: Bool) -> (UInt16, [UInt8]) { (Command.setLatency, [on ? 0x01 : 0x02, 0x00]) }

    /// `level` is the UI position. Three-stage models map {0,1,2} -> {0,5,10}; others use level*2.
    public static func setBass(enabled: Bool, level: Int, threeStage: Bool) -> (UInt16, [UInt8]) {
        let wireLevel: Int = threeStage ? ([0, 5, 10][max(0, min(2, level))]) : level * 2
        return (Command.setBass, [enabled ? 1 : 0, UInt8(truncatingIfNeeded: wireLevel)])
    }

    public static func ring(on: Bool, left: Bool, style: DeviceModel.RingStyle) -> (UInt16, [UInt8]) {
        switch style {
        case .single: return (Command.ring, [on ? 1 : 0])
        case .headphone: return (Command.ring, [0x06, on ? 1 : 0])
        case .perBud: return (Command.ring, [left ? 0x02 : 0x03, on ? 1 : 0])
        }
    }

    public static func setTime(_ date: Date = Date()) -> (UInt16, [UInt8]) {
        let s = UInt32(truncatingIfNeeded: Int(date.timeIntervalSince1970))
        return (Command.setTime, [UInt8(s >> 24 & 0xFF), UInt8(s >> 16 & 0xFF), UInt8(s >> 8 & 0xFF), UInt8(s & 0xFF)])
    }

    // MARK: Responses (offsets match the web client: payload starts at raw[8])
    public static func parseBattery(_ p: Packet) -> BatteryInfo {
        let r = p.raw
        var info = BatteryInfo()
        guard r.count > 8 else { return info }
        let count = Int(r[8])
        for i in 0..<count {
            guard r.count > 10 + i * 2 else { break }
            let id = r[9 + i * 2]
            let v = r[10 + i * 2]
            let cell = BatteryInfo.Cell(level: Int(v & 0x7F), charging: (v & 0x80) != 0)
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
}
