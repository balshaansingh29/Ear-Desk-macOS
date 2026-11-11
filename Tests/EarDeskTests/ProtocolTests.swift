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
}
