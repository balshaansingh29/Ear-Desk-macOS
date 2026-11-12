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
    public static let setListeningMode: UInt16 = 0xF01D
    public static let setLatency: UInt16 = 0xF040
    public static let setCustomEQ: UInt16 = 0xF041
    public static let setBass: UInt16 = 0xF051
    public static let setSpatialAudio: UInt16 = 0xF052

    // Responses / notifications (buds -> host)
    public static let batteryResponses: Set<UInt16> = [0xE001, 0x4007]
    public static let ancResponses: Set<UInt16> = [0xE003, 0x6003, 0x401E]
    public static let eqResponses: Set<UInt16> = [0x401F, 0x4050]
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
    /// Raw frame bytes (header + payload [+ crc]). `raw[8...]` is the payload,
    /// matching the byte offsets used by the web client.
    public let raw: [UInt8]
}

public struct FrameBuilder {
    private var operationID: UInt8 = 0
    public init() {}

    /// Builds a frame. Operation ID increments per call and wraps like the web client (resets at 250).
    public mutating func build(_ command: UInt16, payload: [UInt8] = []) -> [UInt8] {
        operationID &+= 1
        if operationID >= 250 { operationID = 1 }
        return FrameBuilder.frame(command: command, payload: payload, operationID: operationID)
    }

    public static func frame(command: UInt16, payload: [UInt8], operationID: UInt8) -> [UInt8] {
        var f: [UInt8] = [0x55, 0x60, 0x01,
                          UInt8(command & 0xFF), UInt8(command >> 8),
                          UInt8(truncatingIfNeeded: payload.count), 0x00, operationID]
        f.append(contentsOf: payload)
        let crc = CRC16.compute(f)
        f.append(UInt8(crc & 0xFF))
        f.append(UInt8(crc >> 8))
        return f
    }
}

/// Reassembles packets from an arbitrary byte stream (RFCOMM may split or coalesce frames).
public struct PacketParser {
    private var buffer: [UInt8] = []
    public init() {}

    public mutating func feed(_ data: [UInt8]) -> [Packet] {
        buffer.append(contentsOf: data)
        var out: [Packet] = []
        while true {
            // Resync to start byte.
            guard let start = buffer.firstIndex(of: 0x55) else { buffer.removeAll(); break }
            if start > 0 { buffer.removeFirst(start) }
            guard buffer.count >= 3 else { break }
            // Header magic is 55 60 01; anything else is a false start byte.
            if buffer[1] != 0x60 || buffer[2] != 0x01 { buffer.removeFirst(); continue }
            guard buffer.count >= 8 else { break }
            let len = Int(buffer[5])
            let withCRC = 8 + len + 2

            // Preferred: frame with a valid trailing CRC.
            if buffer.count >= withCRC {
                let body = Array(buffer[0..<(withCRC - 2)])
                let crc = UInt16(buffer[withCRC - 2]) | (UInt16(buffer[withCRC - 1]) << 8)
                if CRC16.compute(body) == crc {
                    out.append(make(Array(buffer[0..<withCRC]), payloadLen: len))
                    buffer.removeFirst(withCRC)
                    continue
                }
            }
            if buffer.count < withCRC { break }   // wait for more bytes
            // CRC mismatch. Tolerate a frame that carries no CRC but is followed by another frame.
            let noCRC = 8 + len
            if buffer.count >= noCRC + 3, buffer[noCRC] == 0x55, buffer[noCRC + 1] == 0x60, buffer[noCRC + 2] == 0x01 {
                out.append(make(Array(buffer[0..<noCRC]), payloadLen: len))
                buffer.removeFirst(noCRC)
                continue
            }
            buffer.removeFirst()                  // corrupt: drop the start byte and resync
        }
        return out
    }

    private func make(_ raw: [UInt8], payloadLen: Int) -> Packet {
        let cmd = UInt16(raw[3]) | (UInt16(raw[4]) << 8)
        let op = raw[7]
        let end = min(raw.count, 8 + payloadLen)
        let payload = (end > 8) ? Array(raw[8..<end]) : []
        return Packet(command: cmd, operationID: op, payload: payload, raw: raw)
    }
}
