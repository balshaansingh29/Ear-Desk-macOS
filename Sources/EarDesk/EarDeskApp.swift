import SwiftUI
import AppKit
import EarDeskCore

@main
struct EarDeskApp: App {
    @StateObject private var controller = EarbudsController()

    var body: some Scene {
        WindowGroup("Ear-Desk") {
            ContentView().environmentObject(controller)
        }
        .windowResizability(.contentMinSize)
        Settings {
            SettingsView().environmentObject(controller)
        }
        .commands {
            // Remove the macOS system "Services" menu
            CommandGroup(replacing: .systemServices) {}
        }

        MenuBarExtra {
            MenuContent().environmentObject(controller)
        } label: {
            if let image = controller.menuBarIcon {
                Image(nsImage: image)
            } else {
                Image(systemName: controller.model?.systemIconName ?? "earbuds")
            }
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var ctl: EarbudsController

    private func bringAppToFront() {
        // Bring macOS app process to the front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            // Find existing main window without spawning a new one
            for window in NSApp.windows {
                let className = window.className
                if className.contains("StatusBarWindow") || className.contains("MenuBarExtra") {
                    continue
                }
                // Unminimize if minimized and bring to front
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.setIsVisible(true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
        }
    }

    var body: some View {
        Button("Open Ear-Desk") {
            bringAppToFront()
        }
        Divider()

        if ctl.link == .connected {
            // Device header & Battery
            Button(ctl.deviceName) {
                bringAppToFront()
            }
            if let s = ctl.battery.stereo {
                Text("Headphones: \(s.level)%\(s.charging ? " ⚡" : "")")
            } else {
                let label: String = {
                    var items: [String] = []
                    if let l = ctl.battery.left { items.append("L: \(l.level)%\(l.charging ? "⚡" : "")") }
                    if let r = ctl.battery.right { items.append("R: \(r.level)%\(r.charging ? "⚡" : "")") }
                    if let c = ctl.battery.caseCell { items.append("Case: \(c.level)%\(c.charging ? "⚡" : "")") }
                    return items.joined(separator: "  ·  ")
                }()
                if !label.isEmpty {
                    Text(label)
                }
            }

            Divider()

            // MARK: Noise Control Menu Switcher
            if ctl.model?.hasANC ?? true {
                Menu("Noise Control") {
                    let hasAdaptive = ctl.model?.anc?.contains(.strengthAdaptive) == true
                    Button {
                        ctl.setANC(hasAdaptive ? .adaptive : .high)
                    } label: {
                        HStack {
                            Text(hasAdaptive ? "Adaptive Noise Cancellation" : "High Noise Cancellation")
                            if ctl.anc == .high || ctl.anc == .adaptive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if ctl.model?.anc?.contains(.transparency) ?? true {
                        Button {
                            ctl.setANC(.transparency)
                        } label: {
                            HStack {
                                Text("Transparency")
                                if ctl.anc == .transparency {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Button {
                        ctl.setANC(.off)
                    } label: {
                        HStack {
                            Text("Off")
                            if ctl.anc == .off {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // MARK: Equalizer Menu Switcher
            Menu("Equalizer") {
                if case .listeningMode(let presets)? = ctl.model?.eqStyle {
                    ForEach(presets, id: \.wire) { p in
                        Button {
                            ctl.setEQ(wire: p.wire)
                        } label: {
                            HStack {
                                Text(p.name)
                                if ctl.eqWire == p.wire {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    let classic: [(String, UInt8)] = [
                        ("Balanced", 0), ("More Voice", 1), ("More Treble", 2), ("More Bass", 3), ("Custom", 6)
                    ]
                    ForEach(classic, id: \.1) { item in
                        Button {
                            ctl.setEQ(wire: item.1)
                        } label: {
                            HStack {
                                Text(item.0)
                                if ctl.eqWire == item.1 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Spatial Audio Menu Switcher (if supported)
            if let modes = ctl.model?.supportedSpatialModes, !modes.isEmpty {
                Menu("Spatial Audio") {
                    ForEach(modes) { mode in
                        Button {
                            ctl.setSpatialAudio(mode)
                        } label: {
                            HStack {
                                Text(mode.title)
                                if ctl.spatialAudio == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Bass Enhance Menu Switcher (if supported)
            if ctl.model?.supportsBassEnhance ?? false {
                Menu("Bass Enhance") {
                    Button {
                        ctl.setBass(enabled: !ctl.bassEnabled, level: ctl.bassLevel)
                    } label: {
                        HStack {
                            Text(ctl.bassEnabled ? "Enabled" : "Disabled")
                            if ctl.bassEnabled { Image(systemName: "checkmark") }
                        }
                    }
                    Divider()
                    let maxLvl = (ctl.model?.threeStageBass ?? false) ? 2 : 5
                    ForEach(0...maxLvl, id: \.self) { lvl in
                        Button {
                            ctl.setBass(enabled: true, level: lvl)
                        } label: {
                            HStack {
                                Text("Level \(lvl)")
                                if ctl.bassEnabled && ctl.bassLevel == lvl {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Dual Connection Menu Switcher (if supported)
            if ctl.model?.supportsDualConnection ?? true {
                Menu("Dual Connection") {
                    Button {
                        ctl.setDualConnection(!ctl.dualConnectionEnabled)
                    } label: {
                        HStack {
                            Text(ctl.dualConnectionEnabled ? "Multipoint: Enabled" : "Multipoint: Disabled")
                            if ctl.dualConnectionEnabled { Image(systemName: "checkmark") }
                        }
                    }

                    if !ctl.dualDevices.isEmpty {
                        Divider()
                        ForEach(ctl.dualDevices) { dev in
                            Button {
                                if !dev.isCurrentHost {
                                    ctl.setDualDeviceConnected(mac: dev.mac, connect: !dev.isConnected)
                                }
                            } label: {
                                HStack {
                                    Text("\(dev.name)\(dev.isCurrentHost ? " (This Mac)" : "")")
                                    if dev.isConnected {
                                        Image(systemName: "link")
                                    }
                                }
                            }
                            .disabled(dev.isCurrentHost)
                        }
                    }
                }
            }

            Divider()
            Button("Disconnect") { ctl.disconnect() }
        } else {
            Text("Not Connected")
        }

        Divider()
        Toggle("Launch at Login", isOn: Binding(get: { ctl.launchAtLogin }, set: ctl.setLaunchAtLogin))
        Divider()
        Button("Quit Ear-Desk") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

// MARK: - App Settings View (Cmd + ,)

struct SettingsView: View {
    @EnvironmentObject var ctl: EarbudsController

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ear-Desk")
                        .font(.system(size: 16, weight: .bold))
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.system(size: 11))
                        .foregroundStyle(NothingTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)

            Divider()

            // Settings Options
            VStack(spacing: 12) {
                settingToggle(
                    title: "Launch at Login",
                    subtitle: "Automatically start Ear-Desk when you log in to your Mac",
                    isOn: Binding(
                        get: { ctl.launchAtLogin },
                        set: { ctl.setLaunchAtLogin($0) }
                    )
                )

                settingToggle(
                    title: "Auto-Connect to Paired Earbuds",
                    subtitle: "Automatically connect when earbuds become reachable via Bluetooth",
                    isOn: Binding(
                        get: { ctl.autoConnect },
                        set: { ctl.setAutoConnect($0) }
                    )
                )

                settingToggle(
                    title: "Low Battery Notifications",
                    subtitle: "Show desktop alert when earbud or case battery falls below 15%",
                    isOn: Binding(
                        get: { ctl.notifyLowBattery },
                        set: { ctl.setNotifyLowBattery($0) }
                    )
                )
            }

            Divider()

            // Footer
            HStack {
                Text("Designed for Nothing & CMF by Nothing Audio")
                    .font(.system(size: 10))
                    .foregroundStyle(NothingTheme.textTertiary)
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .preferredColorScheme(.dark)
    }

    private func settingToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(NothingTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(NothingToggleStyle())
                .labelsHidden()
        }
    }
}
