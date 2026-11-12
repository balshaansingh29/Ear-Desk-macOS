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
}
