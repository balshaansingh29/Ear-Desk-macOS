import Foundation
import IOBluetooth
import SwiftUI
import NothingXCore

struct PairedDevice: Identifiable, Hashable {
    let id: String          // Bluetooth address
    let name: String
    let isConnected: Bool
}

enum LinkState: Equatable {
    case idle
    case connecting
    case connected
    case failed(String)
}

struct MenuBarBatteryIconView: View {
    let batteryLevel: Double
    var iconName: String = "earbuds"

    var body: some View {
        ZStack {
            // Background ring track
            Circle()
                .stroke(Color.black.opacity(0.25), lineWidth: 1.8)
                .frame(width: 17, height: 17)

            // Battery progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(max(0.04, min(1.0, batteryLevel))))
                .stroke(Color.black, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 17, height: 17)

            Image(systemName: iconName)
                .font(.system(size: iconName == "headphones" ? 7.5 : 8, weight: .medium))
                .foregroundColor(.black)
        }
        .frame(width: 20, height: 20)
    }
}

@MainActor
final class EarbudsController: ObservableObject {
    // Discovery
    @Published var pairedDevices: [PairedDevice] = []
    @Published var selectedAddress: String?
    @Published var manualModelBase: String = "auto"

    // Link
    @Published var link: LinkState = .idle
    @Published private(set) var model: DeviceModel?
    @Published private(set) var deviceName: String = ""

    // Device state
    @Published var battery = BatteryInfo()
    @Published var anc: ANCMode?
    @Published var eqWire: UInt8?
    @Published var firmware: String = ""
    @Published var inEarDetection: Bool = false
    @Published var lowLatency: Bool = false
    @Published var bassEnabled: Bool = false
    @Published var bassLevel: Int = 0
    @Published var ringing: (left: Bool, right: Bool) = (false, false)
    @Published var menuBarIcon: NSImage?

    private var lastMenuBarBatteryUpdate: Date?
    private var batteryTimer: Timer?
    private let menuBarUpdateInterval: TimeInterval = 300 // 5 minutes

    private let transport = RFCOMMTransport()
    private var parser = PacketParser()
    private var frames = FrameBuilder()

    init() {
        transport.onOpen = { [weak self] in self?.didOpen() }
        transport.onData = { [weak self] bytes in self?.didReceive(bytes) }
        transport.onClose = { [weak self] message in self?.didClose(message) }
        refreshDevices()
    }

    // MARK: Discovery
    func refreshDevices() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        pairedDevices = paired
            .filter { DeviceCatalog.looksLikeSupportedDevice(name: $0.name ?? "") }
            .map { PairedDevice(id: $0.addressString ?? "", name: $0.name ?? "Unknown", isConnected: $0.isConnected()) }
            .sorted { ($0.isConnected ? 0 : 1, $0.name) < ($1.isConnected ? 0 : 1, $1.name) }
        if selectedAddress == nil || !pairedDevices.contains(where: { $0.id == selectedAddress }) {
            selectedAddress = pairedDevices.first?.id
        }
    }

    // MARK: Connect
    func connect() {
        guard let address = selectedAddress,
              let device = IOBluetoothDevice(addressString: address) else { return }
        deviceName = device.name ?? "Earbuds"
        if manualModelBase != "auto" {
            model = DeviceCatalog.all.first { $0.base == manualModelBase }
        } else {
            model = DeviceCatalog.match(name: deviceName)
        }
        parser = PacketParser()
        frames = FrameBuilder()
        link = .connecting
        transport.open(device)
    }

    func disconnect() {
        stopBatteryTimer()
        transport.close()
        link = .idle
    }

    private func didOpen() {
        link = .connected
        startBatteryTimer()
        Task { await initDevice() }
    }

    private func didClose(_ message: String?) {
        stopBatteryTimer()
        if let message { link = .failed(message) }
        else if link == .connected { link = .failed("The earbuds disconnected.") }
        else { link = .idle }
    }

    /// Mirrors initDevice() in bluetooth_socket.js: request each state with ~100 ms spacing.
    private func initDevice() async {
        let useListening = isListeningMode
        var steps: [(UInt16, [UInt8])] = [(Command.getBattery, [])]
        steps.append(useListening ? (Command.getListeningMode, []) : (Command.getEQ, []))
        steps.append((Command.getFirmware, []))
        if model?.base != "B181" { steps.append(Messages.setTime()) }
        if model?.supportsInEar ?? true { steps.append((Command.getInEar, [])) }
        steps.append((Command.getLatency, []))
        if model?.hasANC ?? true { steps.append((Command.getANC, [])) }
        if model?.supportsBassEnhance ?? false { steps.append((Command.getBass, [])) }
        for (cmd, payload) in steps {
            send(cmd, payload)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Menu Bar Battery Ring

    private func startBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: menuBarUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.link == .connected else { return }
                self.send(Command.getBattery, [])
                self.updateMenuBarIcon(force: true)
            }
        }
    }

    private func stopBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = nil
        lastMenuBarBatteryUpdate = nil
        menuBarIcon = nil
    }

    private func checkMenuBarBatteryUpdate() {
        guard let last = lastMenuBarBatteryUpdate else {
            updateMenuBarIcon(force: true)
            return
        }
        if Date().timeIntervalSince(last) >= menuBarUpdateInterval {
            updateMenuBarIcon(force: true)
        }
    }

    func updateMenuBarIcon(force: Bool = false) {
        guard link == .connected else {
            menuBarIcon = nil
            return
        }

        if !force, let last = lastMenuBarBatteryUpdate, Date().timeIntervalSince(last) < menuBarUpdateInterval {
            return
        }

        let level: Double? = {
            if let s = battery.stereo { return Double(s.level) / 100.0 }
            if let l = battery.left, let r = battery.right { return Double(min(l.level, r.level)) / 100.0 }
            if let l = battery.left { return Double(l.level) / 100.0 }
            if let r = battery.right { return Double(r.level) / 100.0 }
            return nil
        }()

        guard let level else { return }
        lastMenuBarBatteryUpdate = Date()

        let iconName = model?.systemIconName ?? "earbuds"
        let iconView = MenuBarBatteryIconView(batteryLevel: level, iconName: iconName)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        if let img = renderer.nsImage {
            img.isTemplate = true
            img.size = NSSize(width: 20, height: 20)
            self.menuBarIcon = img
        }
    }

    // MARK: Send
    private func send(_ command: UInt16, _ payload: [UInt8] = []) {
        transport.write(frames.build(command, payload: payload))
    }
    private func send(_ message: (UInt16, [UInt8])) { send(message.0, message.1) }

    var isListeningMode: Bool {
        if case .listeningMode? = model?.eqStyle { return true }
        return false
    }

    func setANC(_ mode: ANCMode) {
        anc = mode
        send(Messages.setANC(mode))
    }

    func setEQ(wire: UInt8) {
        eqWire = wire
        send(isListeningMode ? Messages.setListeningMode(wire) : Messages.setEQ(wire))
    }

    func setInEar(_ on: Bool) { inEarDetection = on; send(Messages.setInEar(on)) }
    func setLowLatency(_ on: Bool) { lowLatency = on; send(Messages.setLowLatency(on)) }

    func setBass(enabled: Bool, level: Int) {
        bassEnabled = enabled
        bassLevel = level
        send(Messages.setBass(enabled: enabled, level: level, threeStage: model?.threeStageBass ?? false))
    }

    func ring(left: Bool, on: Bool) {
        if left { ringing.left = on } else { ringing.right = on }
        send(Messages.ring(on: on, left: left, style: model?.ringStyle ?? .perBud))
    }

    // MARK: Receive
    private func didReceive(_ bytes: [UInt8]) {
        for packet in parser.feed(bytes) { handle(packet) }
    }

    private func handle(_ p: Packet) {
        switch p.command {
        case let c where Command.batteryResponses.contains(c):
            battery = Messages.parseBattery(p)
            checkMenuBarBatteryUpdate()
        case let c where Command.ancResponses.contains(c):
            if let m = Messages.parseANC(p) { anc = m }
        case let c where Command.eqResponses.contains(c):
            if let v = Messages.parseEQ(p) { eqWire = v }
        case Command.firmwareResponse:
            firmware = Messages.parseFirmware(p)
        case Command.inEarResponse:
            if let v = Messages.parseInEar(p) { inEarDetection = v }
        case Command.latencyResponse:
            if let v = Messages.parseLowLatency(p) { lowLatency = v }
        case Command.bassResponse:
            if let v = Messages.parseBass(p, threeStage: model?.threeStageBass ?? false) {
                bassEnabled = v.enabled; bassLevel = v.level
            }
        default:
            break
        }
    }
}
