import Foundation
import IOBluetooth
import AppKit
import ServiceManagement
import UserNotifications
import SwiftUI
import EarDeskCore

enum LinkState: Equatable {
    case idle
    case connecting
    case connected
    case failed(String)
}

struct MenuBarBatteryIconView: View {
    let batteryLevel: Double
    let iconName: String

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
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.black)
        }
        .frame(width: 20, height: 20)
    }
}

struct PairedDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isConnected: Bool
}

@MainActor
final class EarbudsController: ObservableObject {
    // Discovery
    @Published var pairedDevices: [PairedDevice] = []
    @Published var selectedAddress: String?
    @Published var manualModelBase: String = "auto"

    // Link
    @Published var link: LinkState = .idle {
        didSet {
            syncStateToWidget()
        }
    }
    @Published private(set) var model: DeviceModel?
    @Published private(set) var deviceName: String = ""

    // Device state
    @Published var battery = BatteryInfo()
    @Published var anc: ANCMode?
    @Published var eqWire: UInt8?
    @Published var customEQ = CustomEQ()
    @Published var firmware: String = ""
    @Published var inEarDetection: Bool = false
    @Published var lowLatency: Bool = false
    @Published var bassEnabled: Bool = false
    @Published var bassLevel: Int = 0
    @Published var dualConnectionEnabled: Bool = false
    @Published var dualDevices: [DualDeviceItem] = []
    @Published var ringing: (left: Bool, right: Bool) = (false, false)
    @Published var spatialAudio: SpatialAudioMode = .off
    @Published var menuBarIcon: NSImage?

    private var lastMenuBarBatteryUpdate: Date?
    private var batteryTimer: Timer?

    // Auto-Connect & Notifications
    @Published var autoConnect: Bool = UserDefaults.standard.object(forKey: "autoConnectEnabled") != nil ? UserDefaults.standard.bool(forKey: "autoConnectEnabled") : true

    // Menu Bar Only (Hide from Dock)
    @Published var menuBarOnly: Bool = UserDefaults.standard.bool(forKey: "menuBarOnlyEnabled") {
        didSet {
            UserDefaults.standard.set(menuBarOnly, forKey: "menuBarOnlyEnabled")
            applyActivationPolicy()
        }
    }

    // Menu Bar Battery Percentage Text Display
    @Published var showMenuBarBatteryPercentage: Bool = UserDefaults.standard.bool(forKey: "showMenuBarBatteryPercentage") {
        didSet {
            UserDefaults.standard.set(showMenuBarBatteryPercentage, forKey: "showMenuBarBatteryPercentage")
        }
    }



    @Published var notifyConnection: Bool = UserDefaults.standard.object(forKey: "notifyConnectionEnabled") != nil ? UserDefaults.standard.bool(forKey: "notifyConnectionEnabled") : true {
        didSet {
            UserDefaults.standard.set(notifyConnection, forKey: "notifyConnectionEnabled")
        }
    }

    @Published var notifyLowBattery: Bool = UserDefaults.standard.object(forKey: "notifyLowBatteryEnabled") != nil ? UserDefaults.standard.bool(forKey: "notifyLowBatteryEnabled") : true {
        didSet {
            UserDefaults.standard.set(notifyLowBattery, forKey: "notifyLowBatteryEnabled")
        }
    }

    @Published var lowBatteryThreshold: Int = UserDefaults.standard.object(forKey: "lowBatteryThreshold") != nil ? UserDefaults.standard.integer(forKey: "lowBatteryThreshold") : 15 {
        didSet {
            UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold")
        }
    }

    private var connectNotificationRef: IOBluetoothUserNotification?
    private var hasNotifiedLowBattery = false

    private let menuBarUpdateInterval: TimeInterval = 300 // 5 minutes

    private let transport = RFCOMMTransport()
    private var parser = PacketParser()
    private var frames = FrameBuilder()

    private func sendConnectionNotification() {
        guard notifyConnection else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(deviceName.isEmpty ? "Earbuds" : deviceName) Connected"
        content.body = "Ear-Desk is active. Ready to stream audio."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func sendDisconnectionNotification() {
        guard notifyConnection else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(deviceName.isEmpty ? "Earbuds" : deviceName) Disconnected"
        content.body = "Audio device was disconnected."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    init() {
        transport.onOpen = { [weak self] in self?.didOpen() }
        transport.onData = { [weak self] bytes in self?.didReceive(bytes) }
        transport.onClose = { [weak self] message in self?.didClose(message) }
        loadPersistedCustomEQ()
        refreshDevices()
        setupAutoConnectObserver()
        requestNotificationPermission()
        applyActivationPolicy()

        GlobalHotkeyManager.shared.onCycleANC = { [weak self] in
            self?.cycleANC()
        }
        GlobalHotkeyManager.shared.onToggleLowLatency = { [weak self] in
            guard let self = self else { return }
            self.setLowLatency(!self.lowLatency)
        }
    }

    func applyActivationPolicy() {
        DispatchQueue.main.async {
            if self.menuBarOnly {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    func setMenuBarBatteryPercentage(_ enabled: Bool) {
        showMenuBarBatteryPercentage = enabled
    }



    func setMenuBarOnly(_ enabled: Bool) {
        menuBarOnly = enabled
    }

    // MARK: - Persistence for Custom EQ
    private func loadPersistedCustomEQ() {
        let b = UserDefaults.standard.object(forKey: "customEQ_bass") as? Int ?? 0
        let m = UserDefaults.standard.object(forKey: "customEQ_mid") as? Int ?? 0
        let t = UserDefaults.standard.object(forKey: "customEQ_treble") as? Int ?? 0
        customEQ = CustomEQ(bass: b, mid: m, treble: t)
    }

    private func savePersistedCustomEQ() {
        UserDefaults.standard.set(customEQ.bass, forKey: "customEQ_bass")
        UserDefaults.standard.set(customEQ.mid, forKey: "customEQ_mid")
        UserDefaults.standard.set(customEQ.treble, forKey: "customEQ_treble")
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
        let wasConnected = (link == .connected)
        stopBatteryTimer()
        transport.close()
        link = .idle
        if wasConnected { sendDisconnectionNotification() }
        // Clean up session state so reconnection has a clean slate
        battery = BatteryInfo()
        dualDevices = []
        hasNotifiedLowBattery = false
        ringing = (false, false)
        refreshDevices()
    }

    private func didOpen() {
        link = .connected
        startBatteryTimer()
        sendConnectionNotification()
        Task {
            await initDevice()
            // Second pass for dual connection to ensure list populates after initial query stabilizes
            try? await Task.sleep(nanoseconds: 800_000_000)
            if self.model?.supportsDualConnection ?? true {
                self.refreshDualConnectionList()
            }
        }
    }

    private func didClose(_ message: String?) {
        if link == .connected { sendDisconnectionNotification() }
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
        if !(model?.supportedSpatialModes.isEmpty ?? true) { steps.append((Command.getSpatialAudio, [])) }
        if model?.supportsDualConnection ?? true {
            steps.append((Command.getDualConnection, []))
            steps.append(Messages.getDualConnectionList(start: 0))
        }
        steps.append((Command.getCustomEQ, []))
        for (cmd, payload) in steps {
            send(cmd, payload)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Launch at Login
    @Published var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            } catch {
                NSLog("Failed to update launch at login: \(error)")
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }

    // MARK: - Auto-Connect & Notifications

    func setAutoConnect(_ enabled: Bool) {
        autoConnect = enabled
        UserDefaults.standard.set(enabled, forKey: "autoConnectEnabled")
        if enabled {
            setupAutoConnectObserver()
        } else {
            connectNotificationRef?.unregister()
            connectNotificationRef = nil
        }
    }

    func setNotifyConnection(_ enabled: Bool) {
        notifyConnection = enabled
    }

    func setNotifyLowBattery(_ enabled: Bool) {
        notifyLowBattery = enabled
        UserDefaults.standard.set(enabled, forKey: "notifyLowBatteryEnabled")
        if enabled {
            requestNotificationPermission()
        }
    }

    func setLowBatteryThreshold(_ threshold: Int) {
        lowBatteryThreshold = threshold
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func setupAutoConnectObserver() {
        guard autoConnect else { return }
        connectNotificationRef?.unregister()
        connectNotificationRef = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(bluetoothDeviceConnected(_:device:)))
    }

    @objc nonisolated private func bluetoothDeviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        Task { @MainActor in
            guard self.autoConnect, self.link == .idle else { return }
            guard let name = device.name, DeviceCatalog.looksLikeSupportedDevice(name: name) else { return }
            if let addr = device.addressString {
                self.selectedAddress = addr
                // Small delay to allow macOS to finish audio handshaking
                try? await Task.sleep(nanoseconds: 800_000_000)
                if self.link == .idle && device.isConnected() {
                    self.connect()
                }
            }
        }
    }

    private func checkLowBatteryNotifications(_ info: BatteryInfo) {
        guard notifyLowBattery else { return }
        let limit = lowBatteryThreshold
        var lowCells: [String] = []

        if let s = info.stereo, s.level <= limit && !s.charging {
            lowCells.append("Headphones (\(s.level)%)")
        } else {
            if let l = info.left, l.level <= limit && !l.charging {
                lowCells.append("Left Earbud (\(l.level)%)")
            }
            if let r = info.right, r.level <= limit && !r.charging {
                lowCells.append("Right Earbud (\(r.level)%)")
            }
            if let c = info.caseCell, c.level <= limit && !c.charging {
                lowCells.append("Charging Case (\(c.level)%)")
            }
        }

        if !lowCells.isEmpty && !hasNotifiedLowBattery {
            hasNotifiedLowBattery = true
            let content = UNMutableNotificationContent()
            content.title = "Low Battery Alert"
            content.body = "\(lowCells.joined(separator: ", ")) is running low on battery (\(limit)% or lower). Please charge your device."
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    NSLog("Failed to deliver notification: \(error)")
                }
            }
        } else if lowCells.isEmpty {
            // Reset state if all levels are above threshold (e.g. charged)
            hasNotifiedLowBattery = false
        }
    }

    // MARK: Periodic Battery Polling (every 60s)
    private func startBatteryTimer() {
        stopBatteryTimer()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.link == .connected else { return }
                self.send(Command.getBattery, [])
            }
        }
    }

    private func stopBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = nil
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

        // Round battery level to 5% increments to avoid needless redrawing
        let quantizedLevel = (level * 20.0).rounded() / 20.0
        let iconName = model?.systemIconName ?? "earbuds"
        
        let iconView = MenuBarBatteryIconView(batteryLevel: quantizedLevel, iconName: iconName)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        if let img = renderer.nsImage {
            img.isTemplate = true
            img.size = NSSize(width: 20, height: 20)
            self.menuBarIcon = img
        }
    }


    // MARK: - Widget State Persistence
    func syncStateToWidget() {
        let isConn = (link == .connected)
        let name = deviceName.isEmpty ? (model?.displayName ?? "Nothing Ear") : deviceName
        let mBase = model?.base ?? "B155"
        let ancStr: String? = isConn ? (anc?.title) : nil

        let shared = SharedDeviceBatteryState(
            isConnected: isConn,
            deviceName: name,
            modelBase: mBase,
            leftLevel: battery.left?.level,
            leftCharging: battery.left?.charging ?? false,
            rightLevel: battery.right?.level,
            rightCharging: battery.right?.charging ?? false,
            caseLevel: battery.caseCell?.level,
            caseCharging: battery.caseCell?.charging ?? false,
            stereoLevel: battery.stereo?.level,
            stereoCharging: battery.stereo?.charging ?? false,
            ancMode: ancStr,
            lastUpdated: Date()
        )
        shared.save()
    }

    // MARK: Send
    private func send(_ command: UInt16, _ payload: [UInt8] = []) {
        transport.write(frames.build(command, payload: payload))
    }
    private func send(_ message: (UInt16, [UInt8])) { send(message.0, message.1) }

    var primaryBatteryPercentageString: String? {
        guard link == .connected else { return nil }
        if let s = battery.stereo { return "\(s.level)%" }
        if let l = battery.left, let r = battery.right { return "\(min(l.level, r.level))%" }
        if let l = battery.left { return "\(l.level)%" }
        if let r = battery.right { return "\(r.level)%" }
        return nil
    }

    var isListeningMode: Bool {
        if case .listeningMode? = model?.eqStyle { return true }
        return false
    }

    func cycleANC() {
        guard link == .connected else { return }
        let next: ANCMode
        switch anc {
        case .high?, .mid?, .low?, .adaptive?:
            next = (model?.anc?.contains(.transparency) ?? true) ? .transparency : .off
        case .transparency?:
            next = .off
        case .off?, .none:
            let hasAdaptive = model?.anc?.contains(.strengthAdaptive) == true
            next = hasAdaptive ? .adaptive : .high
        }
        setANC(next)
    }

    func setANC(_ mode: ANCMode) {
        anc = mode
        send(Messages.setANC(mode))
    }

    func setEQ(wire: UInt8) {
        eqWire = wire
        send(isListeningMode ? Messages.setListeningMode(wire) : Messages.setEQ(wire))
        if wire == 6 {
            send(Command.getCustomEQ, [])
        }
    }

    func setCustomEQBands(bass: Int, mid: Int, treble: Int) {
        customEQ = CustomEQ(bass: bass, mid: mid, treble: treble)
        savePersistedCustomEQ()
        let freq = model?.customEQHighShelfFreq ?? 3500.0
        send(Messages.setCustomEQ(bass: bass, mid: mid, treble: treble, highShelfFreq: freq))
    }

    func setSpatialAudio(_ mode: SpatialAudioMode) {
        spatialAudio = mode
        send(Messages.setSpatialAudio(mode))
    }

    func setInEar(_ on: Bool) { inEarDetection = on; send(Messages.setInEar(on)) }
    func setLowLatency(_ on: Bool) { lowLatency = on; send(Messages.setLowLatency(on)) }

    func setBass(enabled: Bool, level: Int) {
        bassEnabled = enabled
        bassLevel = level
        send(Messages.setBass(enabled: enabled, level: level, threeStage: model?.threeStageBass ?? false))
    }

    func setDualConnection(_ enabled: Bool) {
        dualConnectionEnabled = enabled
        send(Messages.setDualConnection(enabled))
        // Re-read dual device list after toggling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshDualConnectionList()
        }
    }

    func refreshDualConnectionList() {
        send(Messages.getDualConnectionList(start: 0))
    }

    func setDualDeviceConnected(mac: String, connect: Bool) {
        // Optimistically update device list state for instant UI response
        if let idx = dualDevices.firstIndex(where: { $0.mac == mac }) {
            let cur = dualDevices[idx]
            dualDevices[idx] = DualDeviceItem(mac: cur.mac, name: cur.name, isCurrentHost: cur.isCurrentHost, isConnected: connect)
        }
        guard let msg = Messages.setDualDeviceConnect(mac: mac, connect: connect) else { return }
        send(msg)
        // Refresh from firmware after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.refreshDualConnectionList()
        }
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
            checkLowBatteryNotifications(battery)
            syncStateToWidget()
        case let c where Command.ancResponses.contains(c):
            if let m = Messages.parseANC(p) { anc = m }
        case let c where Command.eqResponses.contains(c):
            if let v = Messages.parseEQ(p) { eqWire = v }
        case Command.firmwareResponse:
            firmware = Messages.parseFirmware(p)
        case Command.customEQResponse:
            if let parsed = Messages.parseCustomEQ(p) {
                customEQ = parsed
                savePersistedCustomEQ()
            }
        case Command.inEarResponse:
            if let v = Messages.parseInEar(p) { inEarDetection = v }
        case Command.latencyResponse:
            if let v = Messages.parseLowLatency(p) { lowLatency = v }
        case Command.bassResponse:
            if let v = Messages.parseBass(p, threeStage: model?.threeStageBass ?? false) {
                bassEnabled = v.enabled; bassLevel = v.level
            }
        case let c where Command.spatialAudioResponses.contains(c):
            if let mode = Messages.parseSpatialAudio(p) {
                spatialAudio = mode
            }
        case Command.dualConnectionResponse:
            if let enabled = Messages.parseDualConnection(p) {
                dualConnectionEnabled = enabled
            }
        case Command.dualConnectionListResponse:
            let list = Messages.parseDualConnectionList(p)
            dualDevices = list
        case Command.dualConnectionPush:
            // Device connected / disconnected push notification
            refreshDualConnectionList()
        default:
            break
        }
    }
}
