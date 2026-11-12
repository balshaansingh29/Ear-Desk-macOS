import Foundation

/// Wire protocol for Nothing / CMF earbuds over Bluetooth Classic SPP (RFCOMM).
/// Ported from radiance-project/ear-web `bluetooth_socket.js`.
///
/// Frame: 55 60 01 <cmdLo> <cmdHi> <payloadLen> 00 <opId> <payload...> <crcLo> <crcHi>
/// CRC is CRC-16/MODBUS (poly 0xA001 reflected, init 0xFFFF) over everything before it.
public enum Command {
    // Requests (host -> buds)
    public static let getBattery: UInt16 = 0xC007
    public static let getInEar: UInt16 = 0xC00E
    public static let getANC: UInt16 = 0xC01E
    public static let getEQ: UInt16 = 0xC01F
    public static let getDualConnection: UInt16 = 0xC027
    public static let getDualConnectionList: UInt16 = 0xC028
    public static let getLatency: UInt16 = 0xC041
    public static let getFirmware: UInt16 = 0xC042
    public static let getCustomEQ: UInt16 = 0xC044
    public static let getBass: UInt16 = 0xC04E
    public static let getSpatialAudio: UInt16 = 0xC04F
    public static let getListeningMode: UInt16 = 0xC050

    public static let ring: UInt16 = 0xF002
    public static let setInEar: UInt16 = 0xF004
    public static let setTime: UInt16 = 0xF00A
    public static let setANC: UInt16 = 0xF00F
    public static let setEQ: UInt16 = 0xF010
    public static let setDualConnection: UInt16 = 0xF01A
    public static let setDualDeviceConnect: UInt16 = 0xF01B
    public static let setListeningMode: UInt16 = 0xF01D
    public static let setLatency: UInt16 = 0xF040
    public static let setCustomEQ: UInt16 = 0xF041
    public static let setBass: UInt16 = 0xF051
    public static let setSpatialAudio: UInt16 = 0xF052

    // Responses / notifications (buds -> host)
    public static let batteryResponses: Set<UInt16> = [0xE001, 0x4007]
    public static let ancResponses: Set<UInt16> = [0xE003, 0x6003, 0x401E]
    public static let eqResponses: Set<UInt16> = [0x401F, 0x4050]
    public static let dualConnectionResponse: UInt16 = 0x4027
    public static let dualConnectionListResponse: UInt16 = 0x4028
    public static let dualConnectionPush: UInt16 = 0xE00E
    public static let firmwareResponse: UInt16 = 0x4042
    public static let inEarResponse: UInt16 = 0x400E
    public static let latencyResponse: UInt16 = 0x4041
    public static let customEQResponse: UInt16 = 0x4044
    public static let bassResponse: UInt16 = 0x404E
    public static let spatialAudioResponses: Set<UInt16> = [0x404F, 0xE029, 0x6029]
}

public enum CRC16 {
    public static func compute(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? ((crc >> 1) ^ 0xA001) : (crc >> 1)
            }
        }
        return crc
    }
}

public struct Packet: Equatable {
    public let command: UInt16
    public let operationID: UInt8
    public let payload: [UInt8]
    /// Full frame bytes including header and CRC, useful for commands whose payload
    /// fields are specified relative to the start of the frame (e.g. byte 8, 9).
    public let raw: [UInt8]

    public init(command: UInt16, operationID: UInt8, payload: [UInt8], raw: [UInt8] = []) {
        self.command = command
        self.operationID = operationID
        self.payload = payload
        self.raw = raw
    }
}

public struct FrameBuilder {
    private var nextOpID: UInt8 = 1

    public init() {}

    public mutating func build(_ command: UInt16, payload: [UInt8] = []) -> [UInt8] {
        defer { nextOpID = nextOpID &+ 1 }
        return Self.frame(command: command, payload: payload, operationID: nextOpID)
    }

    public static func frame(command: UInt16, payload: [UInt8], operationID: UInt8) -> [UInt8] {
        let cmdLo = UInt8(command & 0xFF)
        let cmdHi = UInt8((command >> 8) & 0xFF)
        let len = UInt8(payload.count)
        var body: [UInt8] = [0x55, 0x60, 0x01, cmdLo, cmdHi, len, 0x00, operationID]
        body.append(contentsOf: payload)
        let crc = CRC16.compute(body)
        let crcLo = UInt8(crc & 0xFF)
        let crcHi = UInt8((crc >> 8) & 0xFF)
        body.append(contentsOf: [crcLo, crcHi])
        return body
    }
}

public struct PacketParser {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func feed(_ chunk: [UInt8]) -> [Packet] {
        buffer.append(contentsOf: chunk)
        var packets: [Packet] = []

        while true {
            guard let sync = findSync() else {
                buffer.removeAll()
                break
            }
            if sync > 0 { buffer.removeFirst(sync) }

            // Need at least header (8 bytes) + CRC (2 bytes) = 10 bytes.
            guard buffer.count >= 10 else { break }

            let payloadLen = Int(buffer[5])
            let totalLen = 8 + payloadLen + 2
            guard buffer.count >= totalLen else { break }

            let frame = Array(buffer[0..<totalLen])
            let expectedCRC = CRC16.compute(Array(frame[0..<8 + payloadLen]))
            let actualCRC = UInt16(frame[8 + payloadLen]) | (UInt16(frame[8 + payloadLen + 1]) << 8)

            if expectedCRC == actualCRC {
                let cmd = UInt16(frame[3]) | (UInt16(frame[4]) << 8)
                let op = frame[7]
                let payload = Array(frame[8..<8 + payloadLen])
                packets.append(Packet(command: cmd, operationID: op, payload: payload, raw: frame))
                buffer.removeFirst(totalLen)
            } else {
                // False sync or corrupted frame: advance by 1 byte and re-scan.
                buffer.removeFirst()
            }
        }
        return packets
    }

    private func findSync() -> Int? {
        guard buffer.count >= 3 else { return nil }
        for i in 0...(buffer.count - 3) {
            if buffer[i] == 0x55 && buffer[i + 1] == 0x60 && buffer[i + 2] == 0x01 {
                return i
            }
        }
        return nil
    }
}
