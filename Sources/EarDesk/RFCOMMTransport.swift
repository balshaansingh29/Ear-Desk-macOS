import Foundation
import IOBluetooth
import EarDeskCore

/// Bluetooth Classic RFCOMM link to the earbuds' SPP service (the same service the
/// web client opens through Web Serial). Replaces `navigator.serial` in ear-web.
final class RFCOMMTransport: NSObject, IOBluetoothRFCOMMChannelDelegate {
    /// Vendor SPP UUID used by Nothing/CMF earbuds: aeac4a03-dff5-498f-843a-34487cf133eb
    static let sppUUIDBytes: [UInt8] = [0xAE, 0xAC, 0x4A, 0x03, 0xDF, 0xF5, 0x49, 0x8F,
                                        0x84, 0x3A, 0x34, 0x48, 0x7C, 0xF1, 0x33, 0xEB]

    var onData: (([UInt8]) -> Void)?
    var onOpen: (() -> Void)?
    var onClose: ((String?) -> Void)?

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?

    var isOpen: Bool { channel?.isOpen() ?? false }

    func open(_ device: IOBluetoothDevice) {
        close()
        self.device = device

        // If the device already has the SDP record cached, try to connect directly
        // to avoid unnecessary or failing redundant SDP queries.
        let uuid = IOBluetoothSDPUUID(bytes: RFCOMMTransport.sppUUIDBytes, length: 16)
        if let record = device.getServiceRecord(for: uuid) {
            var channelID: BluetoothRFCOMMChannelID = 0
            if record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
                var ch: IOBluetoothRFCOMMChannel?
                let r = device.openRFCOMMChannelAsync(&ch, withChannelID: channelID, delegate: self)
                if r == kIOReturnSuccess {
                    channel = ch
                    return
                }
            }
        }

        // Otherwise query SDP records
        device.performSDPQuery(self)
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard status == kIOReturnSuccess else {
            DispatchQueue.main.async {
                self.onClose?("Service lookup failed (\(status)). Is the device connected to this Mac?")
            }
            return
        }
        let uuid = IOBluetoothSDPUUID(bytes: RFCOMMTransport.sppUUIDBytes, length: 16)
        guard let record = device.getServiceRecord(for: uuid) else {
            DispatchQueue.main.async {
                self.onClose?("This device does not expose the Nothing control service.")
            }
            return
        }
        var channelID: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else {
            DispatchQueue.main.async {
                self.onClose?("Could not read the RFCOMM channel for the control service.")
            }
            return
        }
        var ch: IOBluetoothRFCOMMChannel?
        let r = device.openRFCOMMChannelAsync(&ch, withChannelID: channelID, delegate: self)
        if r != kIOReturnSuccess {
            DispatchQueue.main.async {
                self.onClose?("Could not open the connection (\(r)).")
            }
            return
        }
        channel = ch
    }

    func write(_ bytes: [UInt8]) {
        guard let channel = channel, channel.isOpen() else { return }
        var copy = bytes
        let status = copy.withUnsafeMutableBytes { raw -> IOReturn in
            channel.writeSync(raw.baseAddress, length: UInt16(bytes.count))
        }
        if status != kIOReturnSuccess { NSLog("RFCOMM write failed: \(status)") }
    }

    func close() {
        if let ch = channel {
            ch.setDelegate(nil)
            ch.close()
            channel = nil
        }
        // NOTE: Do NOT call device.closeConnection() here!
        // Calling closeConnection() tears down the host baseband / audio ACL connection,
        // leaving IOBluetooth and the earbuds in an inconsistent disconnected state
        // where subsequent RFCOMM opens fail until the app or Bluetooth daemon restarts.
        device = nil
    }

    // MARK: IOBluetoothRFCOMMChannelDelegate
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        DispatchQueue.main.async {
            if error == kIOReturnSuccess { self.onOpen?() }
            else { self.onClose?("Connection failed (\(error)).") }
        }
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let bytes = Array(UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength))
        DispatchQueue.main.async { self.onData?(bytes) }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        DispatchQueue.main.async { self.onClose?(nil) }
    }
}
