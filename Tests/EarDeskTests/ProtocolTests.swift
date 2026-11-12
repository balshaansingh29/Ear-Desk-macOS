import XCTest
@testable import EarDeskCore

/// Golden vectors were produced by running the original ear-web `send()` / `crc16()` JavaScript.
final class ProtocolTests: XCTestCase {
    private func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }

    func testBatteryRequestMatchesWebClient() {
        let f = FrameBuilder.frame(command: Command.getBattery, payload: [], operationID: 1)
        XCTAssertEqual(hex(f), "55600107c0000001acdf")
    }

    func testSetANCOffMatchesWebClient() {
        let (c, p) = Messages.setANC(.off)
        XCTAssertEqual(hex(FrameBuilder.frame(command: c, payload: p, operationID: 2)), "5560010ff0030002010500fb53")
    }

    func testSetEQBassMatchesWebClient() {
        let (c, p) = Messages.setEQ(3)
        XCTAssertEqual(hex(FrameBuilder.frame(command: c, payload: p, operationID: 3)), "55600110f002000303008699")
    }

    func testSetTimeMatchesWebClient() {
        let f = FrameBuilder.frame(command: Command.setTime, payload: [0x67, 0x4a, 0xbc, 0x10], operationID: 4)
        XCTAssertEqual(hex(f), "5560010af0040004674abc108d40")
    }

    func testParserHandlesSplitAndCoalescedFrames() {
        let a = FrameBuilder.frame(command: 0xE001, payload: [2, 0x02, 80, 0x03, 0x80 | 77], operationID: 7)
        let b = FrameBuilder.frame(command: 0x401F, payload: [3, 0], operationID: 8)
        var parser = PacketParser()
        var got: [Packet] = []
        let stream = a + b
        for chunk in stride(from: 0, to: stream.count, by: 5) {
            got += parser.feed(Array(stream[chunk..<min(chunk + 5, stream.count)]))
        }
        XCTAssertEqual(got.count, 2)
        let battery = Messages.parseBattery(got[0])
        XCTAssertEqual(battery.left, .init(level: 80, charging: false))
        XCTAssertEqual(battery.right, .init(level: 77, charging: true))
        XCTAssertEqual(Messages.parseEQ(got[1]), 3)
    }

    func testParserResyncsAfterGarbage() {
        var parser = PacketParser()
        let good = FrameBuilder.frame(command: 0x401E, payload: [1, 0x05, 0], operationID: 1)
        let got = parser.feed([0x00, 0x12, 0x55, 0x01] + good)
        XCTAssertTrue(got.contains { $0.command == 0x401E })
    }

    func testANCRoundTrip() {
        for m in ANCMode.allCases { XCTAssertEqual(ANCMode(wire: m.wire), m) }
    }

    func testDeviceMatching() {
        XCTAssertEqual(DeviceCatalog.match(name: "Nothing Ear (2)")?.base, "B155")
        XCTAssertEqual(DeviceCatalog.match(name: "CMF Buds Pro 2")?.base, "B172")
    }
    func testCustomEQBuildPayload() {
        let (cmd, payload) = Messages.setCustomEQ(bass: 3, mid: 0, treble: -3, highShelfFreq: 3500)
        XCTAssertEqual(cmd, Command.setCustomEQ)
        XCTAssertEqual(payload.count, 53)
        XCTAssertEqual(payload[0], 0x03) // 3 bands

        // totalGain should be -3.0
        let totalGainData = Data(payload[1...4])
        let totalGain = totalGainData.withUnsafeBytes { $0.load(as: Float.self) }
        XCTAssertEqual(totalGain, -3.0)

        // Mid band (index 5)
        XCTAssertEqual(payload[5], 0x01)
        let midGain = Data(payload[6...9]).withUnsafeBytes { $0.load(as: Float.self) }
        XCTAssertEqual(midGain, 0.0)

        // Treble band (index 18)
        XCTAssertEqual(payload[18], 0x02)
        let trebleGain = Data(payload[19...22]).withUnsafeBytes { $0.load(as: Float.self) }
        XCTAssertEqual(trebleGain, -3.0)

        // Bass band (index 31)
        XCTAssertEqual(payload[31], 0x00)
        let bassGain = Data(payload[32...35]).withUnsafeBytes { $0.load(as: Float.self) }
        XCTAssertEqual(bassGain, 3.0)
    }

    func testCustomEQParseResponse() {
        // Build mock response packet for 0x4044
        // Payload has 10 bytes header/prefix, then band 1 (Mid) at offset 10 (type at 10, gain float32 at 11..14)
        // Band 2 (Treble) at offset 23 (type at 23, gain float32 at 24..27)
        // Band 3 (Bass) at offset 36 (type at 36, gain float32 at 37..40)
        var payload = [UInt8](repeating: 0, count: 50)
        func writeFloat(_ val: Float, at offset: Int) {
            var v = val
            withUnsafeBytes(of: &v) {
                for (idx, b) in $0.enumerated() {
                    payload[offset + idx] = b
                }
            }
        }
        writeFloat(2.0, at: 14)   // Mid = +2
        writeFloat(-1.0, at: 27)  // Treble = -1
        writeFloat(4.0, at: 40)   // Bass = +4

        let packet = Packet(command: Command.customEQResponse, operationID: 0, payload: payload, raw: payload)
        let parsed = Messages.parseCustomEQ(packet)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.bass, 4)
        XCTAssertEqual(parsed?.mid, 2)
        XCTAssertEqual(parsed?.treble, -1)
    }
    func testSpatialAudioSetMatchesWebClient() {
        // From nothingctl golden frames:
        // Off: 55 60 01 52 f0 02 00 01 00 00 45 ad
        let (cmdOff, payloadOff) = Messages.setSpatialAudio(.off)
        XCTAssertEqual(cmdOff, Command.setSpatialAudio)
        XCTAssertEqual(payloadOff, [0x00, 0x00])

        // Concert: 55 60 01 52 f0 02 00 01 02 00 44 cd
        let (cmdConcert, payloadConcert) = Messages.setSpatialAudio(.concert)
        XCTAssertEqual(cmdConcert, Command.setSpatialAudio)
        XCTAssertEqual(payloadConcert, [0x02, 0x00])

        // Theatre: 55 60 01 52 f0 02 00 01 03 00 45 5d
        let (cmdTheatre, payloadTheatre) = Messages.setSpatialAudio(.theatre)
        XCTAssertEqual(cmdTheatre, Command.setSpatialAudio)
        XCTAssertEqual(payloadTheatre, [0x03, 0x00])

        // Head-Tracked: 55 60 01 52 f0 02 00 01 01 01 85 fd
        let (cmdHead, payloadHead) = Messages.setSpatialAudio(.headTracked)
        XCTAssertEqual(cmdHead, Command.setSpatialAudio)
        XCTAssertEqual(payloadHead, [0x01, 0x01])

        // Fixed: 55 60 01 52 f0 02 00 01 01 00 44 3d
        let (cmdFixed, payloadFixed) = Messages.setSpatialAudio(.fixed)
        XCTAssertEqual(cmdFixed, Command.setSpatialAudio)
        XCTAssertEqual(payloadFixed, [0x01, 0x00])
    }

    func testSpatialAudioParse() {
        var raw = [UInt8](repeating: 0, count: 12)
        raw[8] = 0x01
        raw[9] = 0x01
        let packetHead = Packet(command: 0x404F, operationID: 1, payload: [0x01, 0x01], raw: raw)
        XCTAssertEqual(Messages.parseSpatialAudio(packetHead), .headTracked)

        raw[8] = 0x01
        raw[9] = 0x00
        let packetFixed = Packet(command: 0x404F, operationID: 1, payload: [0x01, 0x00], raw: raw)
        XCTAssertEqual(Messages.parseSpatialAudio(packetFixed), .fixed)

        raw[8] = 0x02
        raw[9] = 0x00
        let packetConcert = Packet(command: 0x404F, operationID: 1, payload: [0x02, 0x00], raw: raw)
        XCTAssertEqual(Messages.parseSpatialAudio(packetConcert), .concert)
    }

    func testDualConnectionPayloads() {
        // Toggle on: 0xF01A payload [0x01] -> 5560011af0010001015cc8
        let (cmdOn, payloadOn) = Messages.setDualConnection(true)
        XCTAssertEqual(cmdOn, Command.setDualConnection)
        XCTAssertEqual(payloadOn, [0x01])
        let frameOn = FrameBuilder.frame(command: cmdOn, payload: payloadOn, operationID: 1)
        XCTAssertEqual(hex(frameOn), "5560011af0010001015cc8")

        // Toggle off: 0xF01A payload [0x00] -> 5560011af0010001009d08
        let (cmdOff, payloadOff) = Messages.setDualConnection(false)
        XCTAssertEqual(cmdOff, Command.setDualConnection)
        XCTAssertEqual(payloadOff, [0x00])
        let frameOff = FrameBuilder.frame(command: cmdOff, payload: payloadOff, operationID: 1)
        XCTAssertEqual(hex(frameOff), "5560011af0010001009d08")

        // Connect host AA:BB:CC:DD:EE:FF -> 5560011bf007000101aabbccddeeffae0b
        guard let (cmdConn, payloadConn) = Messages.setDualDeviceConnect(mac: "AA:BB:CC:DD:EE:FF", connect: true) else {
            XCTFail("Failed to build connect message")
            return
        }
        XCTAssertEqual(cmdConn, Command.setDualDeviceConnect)
        let frameConn = FrameBuilder.frame(command: cmdConn, payload: payloadConn, operationID: 1)
        XCTAssertEqual(hex(frameConn), "5560011bf007000101aabbccddeeffae0b")
    }

    func testDualConnectionListParse() {
        // Mock response packet for 0x4028 with 2 devices:
        // Byte 8..9: padding
        // Byte 10: count = 2
        // Device 1: flags = 0x11 (current host + connected), MAC: 11:22:33:44:55:66, nameLen: 7, name: "MacBook"
        // Device 2: flags = 0x01 (not current host + connected), MAC: AA:BB:CC:DD:EE:FF, nameLen: 6, name: "iPhone"
        var raw: [UInt8] = [0x55, 0x60, 0x01, 0x28, 0x40, 0x00, 0x00, 0x01, 0x00, 0x00, 0x02]
        
        // Dev 1
        raw.append(0x11) // flags
        raw.append(contentsOf: [0x11, 0x22, 0x33, 0x44, 0x55, 0x66]) // MAC
        raw.append(0x07) // nameLen
        raw.append(contentsOf: Array("MacBook".utf8))

        // Dev 2
        raw.append(0x01) // flags
        raw.append(contentsOf: [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]) // MAC
        raw.append(0x06) // nameLen
        raw.append(contentsOf: Array("iPhone".utf8))

        let packet = Packet(command: Command.dualConnectionListResponse, operationID: 1, payload: [], raw: raw)
        let devices = Messages.parseDualConnectionList(packet)
        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].name, "MacBook")
        XCTAssertEqual(devices[0].mac, "11:22:33:44:55:66")
        XCTAssertTrue(devices[0].isCurrentHost)
        XCTAssertTrue(devices[0].isConnected)

        XCTAssertEqual(devices[1].name, "iPhone")
        XCTAssertEqual(devices[1].mac, "AA:BB:CC:DD:EE:FF")
        XCTAssertFalse(devices[1].isCurrentHost)
        XCTAssertTrue(devices[1].isConnected)
    }
}
