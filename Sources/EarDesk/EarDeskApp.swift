import SwiftUI
import AppKit
import EarDeskCore

@MainActor
func openSettingsWindow() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        for window in NSApp.windows {
            let title = window.title.lowercased()
            let className = window.className
            if title.contains("settings") || title.contains("preferences") || className.contains("Preferences") {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.setIsVisible(true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    }
}

@main
struct EarDeskApp: App {
    @StateObject private var controller = EarbudsController()
    @StateObject private var updater = AppUpdater.shared
    @StateObject private var iconManager = AppIconManager.shared

    var body: some Scene {
        WindowGroup("Ear-Desk") {
            ContentView()
                .background(WindowAccessor())
                .environmentObject(controller)
                .environmentObject(updater)
                .environmentObject(iconManager)
        }
        .windowResizability(.contentMinSize)
        Settings {
            SettingsView()
                .environmentObject(controller)
                .environmentObject(updater)
                .environmentObject(iconManager)
        }
        .commands {
            // Remove the macOS system "Services" menu
            CommandGroup(replacing: .systemServices) {}

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task {
                        await updater.checkForUpdates(manual: true)
                    }
                    openSettingsWindow()
                }
            }
        }

        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(controller)
                .environmentObject(updater)
        } label: {
            HStack(spacing: 4) {
                if let image = controller.menuBarIcon {
                    Image(nsImage: image)
                } else {
                    Image(systemName: controller.model?.systemIconName ?? "earbuds")
                }
                if controller.showMenuBarBatteryPercentage, let pct = controller.primaryBatteryPercentageString {
                    Text(pct)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}




struct MenuContent: View {
    @EnvironmentObject var ctl: EarbudsController
    @EnvironmentObject var updater: AppUpdater
    @ObservedObject var iconManager = AppIconManager.shared
    @ObservedObject var hotkeyManager = GlobalHotkeyManager.shared
    @ObservedObject var typoManager = TypographyManager.shared

    private func bringAppToFront() {
        // If dock icon is hidden, keep accessory or switch to regular temporarily to activate window
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            // Find existing main window without spawning a new one
            for window in NSApp.windows {
                let className = window.className
                if className.contains("StatusBarWindow") || className.contains("MenuBarExtra") || className.contains("NSStatusBar") {
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
        Toggle("Hide Dock Icon (Menu Bar Only)", isOn: Binding(get: { ctl.menuBarOnly }, set: ctl.setMenuBarOnly))
        Toggle("Show Battery Percentage in Menu Bar", isOn: Binding(get: { ctl.showMenuBarBatteryPercentage }, set: ctl.setMenuBarBatteryPercentage))

        if case .updateAvailable(let ver, _, _) = updater.status {
            Divider()
            Button("✨ Update Available (v\(ver))") {
                bringAppToFront()
            }
        }

        Divider()
        Button("Quit Ear-Desk") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}


// MARK: - Interactive Menu Bar Popover View (Option 6)

struct MenuBarPopoverView: View {
    @EnvironmentObject var ctl: EarbudsController
    @EnvironmentObject var updater: AppUpdater
    @ObservedObject var iconManager = AppIconManager.shared
    @ObservedObject var hotkeyManager = GlobalHotkeyManager.shared

    private func bringAppToFront() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows {
                let className = window.className
                if className.contains("StatusBarWindow") || className.contains("MenuBarExtra") || className.contains("NSStatusBar") {
                    continue
                }
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
        VStack(alignment: .leading, spacing: 14) {
            // Header: Status dot, Device Name & Quick Action Icons
            HStack(spacing: 8) {
                Circle()
                    .fill(ctl.link == .connected ? Color.green : NothingTheme.red)
                    .frame(width: 7, height: 7)

                Text(ctl.link == .connected ? ctl.deviceName.uppercased() : "EAR-DESK")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        bringAppToFront()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NothingTheme.textSecondary)
                            .padding(5)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Full App Window")

                    Button {
                        openSettingsWindow()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NothingTheme.textSecondary)
                            .padding(5)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                }
            }

            if ctl.link == .connected {
                // Interactive Battery Mini Cards
                HStack(spacing: 6) {
                    if let s = ctl.battery.stereo {
                        batteryPill(label: "HEADPHONES", level: s.level, charging: s.charging, icon: ctl.model?.systemIconName ?? "headphones")
                    } else {
                        if let l = ctl.battery.left {
                            batteryPill(label: "L", level: l.level, charging: l.charging, icon: "earbuds")
                        }
                        if let r = ctl.battery.right {
                            batteryPill(label: "R", level: r.level, charging: r.charging, icon: "earbuds")
                        }
                        if let c = ctl.battery.caseCell {
                            batteryPill(label: "CASE", level: c.level, charging: c.charging, icon: "earbuds.case")
                        }
                    }
                }

                // Interactive ANC Segmented Control Bar
                if ctl.model?.hasANC ?? true {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOISE CONTROL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(NothingTheme.textSecondary)

                        let hasAdaptive = ctl.model?.anc?.contains(.strengthAdaptive) == true
                        let activeANC = ctl.anc

                        HStack(spacing: 4) {
                            ancButton(
                                title: hasAdaptive ? "Adaptive" : "Noise Cancelling",
                                systemIcon: "earbuds.noise.cancelling",
                                isSelected: activeANC == .high || activeANC == .adaptive
                            ) {
                                ctl.setANC(hasAdaptive ? .adaptive : .high)
                            }

                            if ctl.model?.anc?.contains(.transparency) ?? true {
                                ancButton(
                                    title: "Transparency",
                                    systemIcon: "earbuds.noise.cancelling",
                                    isSelected: activeANC == .transparency
                                ) {
                                    ctl.setANC(.transparency)
                                }
                            }

                            ancButton(
                                title: "Off",
                                systemIcon: "slash.circle",
                                isSelected: activeANC == .off
                            ) {
                                ctl.setANC(.off)
                            }
                        }
                    }
                }

                // Bass & Spatial Audio Row
                HStack(spacing: 8) {
                    if ctl.model?.supportsBassEnhance ?? false {
                        Button {
                            ctl.setBass(enabled: !ctl.bassEnabled, level: ctl.bassLevel == 0 ? 3 : ctl.bassLevel)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 9, weight: .bold))
                                Text(ctl.bassEnabled ? "Bass L\(ctl.bassLevel)" : "Bass Off")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(ctl.bassEnabled ? Color.white : NothingTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ctl.bassEnabled ? NothingTheme.red : Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if let modes = ctl.model?.supportedSpatialModes, !modes.isEmpty {
                        Menu {
                            ForEach(modes) { mode in
                                Button(mode.title) {
                                    ctl.setSpatialAudio(mode)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "beats.headphones")
                                    .font(.system(size: 9, weight: .bold))
                                Text(ctl.spatialAudio.title.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(ctl.spatialAudio != .off ? Color.white : NothingTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ctl.spatialAudio != .off ? Color.white.opacity(0.18) : Color.white.opacity(0.06), in: Capsule())
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Equalizer Quick Preset Menu
                    let presets: [(name: String, wire: UInt8)] = {
                        switch ctl.model?.eqStyle {
                        case .listeningMode(let p)?: return p
                        default: return [("Balanced", 0), ("More Voice", 1), ("More Treble", 2), ("More Bass", 3), ("Custom", 6)]
                        }
                    }()
                    let currentEQName = presets.first(where: { $0.wire == ctl.eqWire })?.name ?? "EQ"

                    Menu {
                        ForEach(presets, id: \.wire) { p in
                            Button(p.name) {
                                ctl.setEQ(wire: p.wire)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.vertical.3")
                                .font(.system(size: 9, weight: .bold))
                            Text(currentEQName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(ctl.eqWire != 0 ? Color.white : NothingTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ctl.eqWire != 0 ? Color.white.opacity(0.18) : Color.white.opacity(0.06), in: Capsule())
                    }
                    .menuStyle(.borderlessButton)


                    Spacer()

                    Button {
                        ctl.disconnect()
                    } label: {
                        Text("DISCONNECT")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(NothingTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Not Connected State
                VStack(spacing: 10) {
                    Text("No Earbuds Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NothingTheme.textSecondary)
                        .padding(.vertical, 6)

                    Button {
                        bringAppToFront()
                    } label: {
                        Text("CONNECT IN FULL APP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Footer actions: Preferences, Menu Bar Only & Quit
            HStack {
                Toggle("Menu Bar Only", isOn: Binding(get: { ctl.menuBarOnly }, set: ctl.setMenuBarOnly))
                    .font(.system(size: 10, weight: .medium))
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(NothingTheme.textSecondary)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Color(red: 16/255, green: 16/255, blue: 18/255))
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func batteryPill(label: String, level: Int, charging: Bool, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(charging ? Color.green : NothingTheme.textSecondary)

            Text("\(label):")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(NothingTheme.textSecondary)

            Text("\(level)%\(charging ? "⚡" : "")")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func ancButton(title: String, systemIcon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemIcon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .monospaced))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Settings View (Cmd + ,)

struct SettingsView: View {
    @EnvironmentObject var ctl: EarbudsController
    @EnvironmentObject var updater: AppUpdater
    @ObservedObject var iconManager = AppIconManager.shared
    @ObservedObject var hotkeyManager = GlobalHotkeyManager.shared
    @ObservedObject var typoManager = TypographyManager.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "7"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ear-Desk")
                            .font(.system(size: 16, weight: .bold))
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.system(size: 11))
                            .foregroundStyle(NothingTheme.textSecondary)
                    }
                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: Notification.Name("ReopenWhatsNew"), object: nil)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "gift")
                                .font(.system(size: 11))
                            Text("WHAT'S NEW")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                        }
                        .foregroundStyle(NothingTheme.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(NothingTheme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(NothingTheme.red.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("View recent updates and new features")
                }

                // 1. General & Connection Section
                settingsSection(title: "GENERAL & CONNECTION") {
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
                        title: "Menu Bar Only (Hide Dock Icon)",
                        subtitle: "Hide the app from the macOS Dock and Cmd+Tab switcher; run exclusively from the menu bar",
                        isOn: Binding(
                            get: { ctl.menuBarOnly },
                            set: { ctl.setMenuBarOnly($0) }
                        )
                    )
                }

                // 2. Notifications & Alerts Section
                settingsSection(title: "NOTIFICATIONS & ALERTS") {
                    settingToggle(
                        title: "Connection & Disconnection Alerts",
                        subtitle: "Show desktop banner notification when earbuds pair or unpair",
                        isOn: Binding(
                            get: { ctl.notifyConnection },
                            set: { ctl.setNotifyConnection($0) }
                        )
                    )

                    settingToggle(
                        title: "Show Battery Percentage in Menu Bar",
                        subtitle: "Display exact numerical battery percentage alongside the menu bar icon",
                        isOn: Binding(
                            get: { ctl.showMenuBarBatteryPercentage },
                            set: { ctl.setMenuBarBatteryPercentage($0) }
                        )
                    )



                    VStack(alignment: .leading, spacing: 10) {
                        settingToggle(
                            title: "Low Battery Notifications",
                            subtitle: "Show desktop alert when earbud or case battery falls below threshold",
                            isOn: Binding(
                                get: { ctl.notifyLowBattery },
                                set: { ctl.setNotifyLowBattery($0) }
                            )
                        )

                        if ctl.notifyLowBattery {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Alert Threshold:")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(NothingTheme.textSecondary)
                                    Spacer()
                                    Text("\(ctl.lowBatteryThreshold)%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ctl.lowBatteryThreshold <= 15 ? NothingTheme.red : Color.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                                }

                                HStack(spacing: 10) {
                                    Text("5%")
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(NothingTheme.textTertiary)

                                    Slider(
                                        value: Binding(
                                            get: { Double(ctl.lowBatteryThreshold) },
                                            set: { ctl.setLowBatteryThreshold(Int($0)) }
                                        ),
                                        in: 5...40,
                                        step: 5
                                    )
                                    .tint(NothingTheme.red)

                                    Text("40%")
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(NothingTheme.textTertiary)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                        }
                    }
                }

                // 3. Global Shortcuts Section
                settingsSection(title: "GLOBAL SHORTCUTS") {
                    settingToggle(
                        title: "Cycle ANC Modes (⌃⌥A)",
                        subtitle: "Press Control + Option + A anywhere to cycle Noise Cancellation, Transparency & Off",
                        isOn: Binding(
                            get: { hotkeyManager.isANCShortcutEnabled },
                            set: { hotkeyManager.isANCShortcutEnabled = $0 }
                        )
                    )

                    settingToggle(
                        title: "Toggle Low Latency (⌃⌥L)",
                        subtitle: "Press Control + Option + L anywhere to toggle Low Latency Game Mode",
                        isOn: Binding(
                            get: { hotkeyManager.isGameModeShortcutEnabled },
                            set: { hotkeyManager.isGameModeShortcutEnabled = $0 }
                        )
                    )
                }

                // 4. Appearance & Icon Section
                settingsSection(title: "APPEARANCE & THEME") {
                    settingToggle(
                        title: "Nothing Dot Matrix Font (NDot)",
                        subtitle: "Render titles, cards, and branding in Nothing OS authentic dot-matrix typography",
                        isOn: Binding(
                            get: { typoManager.useDotMatrix },
                            set: { typoManager.useDotMatrix = $0 }
                        )
                    )

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Icon & Widget Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("Select an icon appearance or follow macOS System Settings")
                                    .font(.system(size: 10))
                                    .foregroundStyle(NothingTheme.textSecondary)
                            }
                            Spacer()
                            Picker("", selection: $iconManager.selectedTheme) {
                                ForEach(AppIconTheme.allCases) { theme in
                                    Text(theme.description).tag(theme)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        // 4 Swatches matching macOS System Settings: Default, Dark, Clear, Tinted
                        HStack(spacing: 8) {
                            ForEach([AppIconTheme.light, AppIconTheme.dark, AppIconTheme.clear, AppIconTheme.tinted], id: \.self) { theme in
                                let isDirectlySelected = iconManager.selectedTheme == theme
                                let isAutoMatching = iconManager.selectedTheme == .automatic && iconManager.iconName(for: .automatic).contains(theme.rawValue)
                                let isActive = isDirectlySelected || isAutoMatching

                                Button(action: {
                                    iconManager.selectedTheme = theme
                                }) {
                                    VStack(spacing: 6) {
                                        let assetName = iconManager.iconName(for: theme)
                                        if let img = iconManager.loadIconImage(named: assetName) {
                                            Image(nsImage: img)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 36, height: 36)
                                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                                        }
                                        Text(theme.rawValue)
                                            .font(.system(size: 9.5, weight: isActive ? .semibold : .regular))
                                            .foregroundStyle(isActive ? .white : NothingTheme.textSecondary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity)
                                    .background(isActive ? Color.white.opacity(0.10) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isActive ? NothingTheme.red : Color.white.opacity(0.08), lineWidth: isActive ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 5. Software Updates Section
                settingsSection(title: "SOFTWARE UPDATES") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check for Updates")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                if let lastChecked = updater.lastChecked {
                                    Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(NothingTheme.textSecondary)
                                } else {
                                    Text("Check GitHub releases for updates")
                                        .font(.system(size: 10))
                                        .foregroundStyle(NothingTheme.textSecondary)
                                }
                            }
                            Spacer()

                            switch updater.status {
                            case .checking, .downloading, .installing:
                                ProgressView().controlSize(.small)
                            default:
                                Button("Check Now") {
                                    Task {
                                        await updater.checkForUpdates(manual: true)
                                    }
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                        }

                        switch updater.status {
                        case .upToDate:
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.green)
                                    .font(.system(size: 11))
                                Text("Ear-Desk is up to date (v\(updater.currentVersion)).")
                                    .font(.system(size: 10))
                                    .foregroundStyle(NothingTheme.textSecondary)
                            }
                        case .updateAvailable(let version, _, let downloadUrl):
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(NothingTheme.red)
                                    .frame(width: 6, height: 6)
                                Text("Version \(version) is available!")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button("Update Now") {
                                    Task {
                                        await updater.downloadAndInstall(url: downloadUrl)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(NothingTheme.red)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                        case .downloading:
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Downloading update from GitHub…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(NothingTheme.textSecondary)
                            }
                        case .installing:
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Installing and relaunching…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(NothingTheme.textSecondary)
                            }
                        case .readyToRestart:
                            Text("Restarting Ear-Desk…")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.green)
                        case .failed(let err):
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(NothingTheme.red)
                                    .font(.system(size: 11))
                                Text(err)
                                    .font(.system(size: 10))
                                    .foregroundStyle(NothingTheme.red.opacity(0.9))
                            }
                        default:
                            EmptyView()
                        }
                    }
                }

                // Footer
                HStack {
                    Text("Designed for Nothing & CMF by Nothing Audio")
                        .font(.system(size: 10))
                        .foregroundStyle(NothingTheme.textTertiary)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(width: 440, height: 560)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(NothingTheme.textTertiary)

            VStack(spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
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

// MARK: - Dynamic App Icon Manager

public enum AppIconTheme: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case light = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .automatic: return "System Icon Style"
        case .light: return "Default (Light)"
        case .dark: return "Dark"
        case .clear: return "Clear"
        case .tinted: return "Tinted"
        }
    }
}

@MainActor
public final class AppIconManager: ObservableObject {
    public static let shared = AppIconManager()

    private let userDefaultsKey = "AppIconSelectedTheme"

    @Published public var selectedTheme: AppIconTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: userDefaultsKey)
            applyCurrentIcon()
        }
    }

    public init() {
        let savedRaw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? AppIconTheme.automatic.rawValue
        self.selectedTheme = AppIconTheme(rawValue: savedRaw) ?? .automatic
        applyCurrentIcon()

        // 1. Observe macOS Icon & Widget Style changes via NSWorkspaceIconAppearanceConfigurationDidChangeNotification
        let iconAppearanceChanged = NSNotification.Name("NSWorkspaceIconAppearanceConfigurationDidChangeNotification")
        DistributedNotificationCenter.default().addObserver(
            forName: iconAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.selectedTheme == .automatic else { return }
                self.applyCurrentIcon()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: iconAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.selectedTheme == .automatic else { return }
                self.applyCurrentIcon()
            }
        }

        // 2. Observe system appearance theme transitions (Light/Dark mode)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.selectedTheme == .automatic else { return }
                self.applyCurrentIcon()
            }
        }

        // 3. Re-verify when application becomes active
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.selectedTheme == .automatic else { return }
                self.applyCurrentIcon()
            }
        }
    }

    public var isSystemDark: Bool {
        if let appearance = NSApp?.effectiveAppearance,
           appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        }
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
        if let style = global["AppleInterfaceStyle"] as? String,
           style.caseInsensitiveCompare("Dark") == .orderedSame {
            return true
        }
        return false
    }

    /// Returns the asset name corresponding to a given theme, honoring system dark/light mode for glass styles
    public func iconName(for theme: AppIconTheme) -> String {
        switch theme {
        case .automatic:
            return determineSystemIconName()
        case .light:
            return "AppIcon-Light"
        case .dark:
            return "AppIcon-Dark"
        case .clear:
            return isSystemDark ? "AppIcon-Clear-Dark" : "AppIcon-Clear-Light"
        case .tinted:
            return isSystemDark ? "AppIcon-Tinted-Dark" : "AppIcon-Tinted-Light"
        }
    }

    /// Sets the dock icon in-memory without disk modifications or permission prompts
    public func applyCurrentIcon() {
        let name = iconName(for: selectedTheme)
        guard let image = loadIconImage(named: name) else { return }
        NSApplication.shared.applicationIconImage = image
        self.objectWillChange.send()
    }

    /// Queries the exact macOS System Settings -> Appearance -> "Icon & widget style" setting:
    /// [Default] -> AppIcon-Light
    /// [Dark]    -> AppIcon-Dark
    /// [Clear]   -> AppIcon-Clear
    /// [Tinted]  -> AppIcon-Clear
    /// Queries the exact macOS System Settings -> Appearance -> "Icon & widget style" setting:
    /// Uses the exact Apple SkyLight SLSIconAppearanceConfiguration lookup tables:
    /// Variant 0 (fullColor) -> AppIcon-Light / AppIcon-Dark
    /// Variant 1 (clear)     -> AppIcon-Clear
    /// Variant 2 (tinted)    -> AppIcon-Tinted
    /// Queries the exact macOS System Settings -> Appearance -> "Icon & widget style" setting
    /// and resolves Light/Dark sub-modes for Clear and Tinted flat liquid glass styles:
    /// - Default: Light (AppIcon-Light)
    /// - Dark: Dark (AppIcon-Dark)
    /// - Clear: Flat Liquid Glass (Light: AppIcon-Clear-Light, Dark: AppIcon-Clear-Dark)
    /// - Tinted: Flat Liquid Glass (Light: AppIcon-Tinted-Light, Dark: AppIcon-Tinted-Dark)
    private func determineSystemIconName() -> String {
        let isSystemDark: Bool = {
            if let appearance = NSApp?.effectiveAppearance,
               appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return true
            }
            let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
            if let style = global["AppleInterfaceStyle"] as? String,
               style.caseInsensitiveCompare("Dark") == .orderedSame {
                return true
            }
            return false
        }()

        let ws = NSWorkspace.shared
        let configSel = NSSelectorFromString("currentIconAppearanceConfiguration")

        if ws.responds(to: configSel),
           let config = ws.perform(configSel)?.takeUnretainedValue() as? NSObject {
            typealias IntGetter = @convention(c) (AnyObject, Selector) -> Int

            let themeSel = NSSelectorFromString("iconAppearanceTheme")
            if config.responds(to: themeSel) {
                let getTheme = unsafeBitCast(class_getMethodImplementation(object_getClass(config), themeSel), to: IntGetter.self)
                let rawTheme = getTheme(config, themeSel)

                // Exact lookup table from macOS Appearance framework
                // Table 1 (Theme):   0=Auto, 1=Light, 2=Dark
                // Table 2 (Variant): 0=FullColor, 1=Clear, 2=Tinted
                let themeTable: [UInt8]   = [0, 0, 0, 1, 1, 1, 2, 2, 2]
                let variantTable: [UInt8] = [2, 0, 1, 2, 0, 1, 2, 0, 1]

                if rawTheme >= 0 && rawTheme < 9 {
                    let themeIdx = themeTable[rawTheme]
                    let variantIdx = variantTable[rawTheme]

                    let isDarkStyle = (themeIdx == 2) || (themeIdx == 0 && isSystemDark)

                    switch variantIdx {
                    case 1:
                        // Clear Mode (Flat Liquid Glass)
                        return isDarkStyle ? "AppIcon-Clear-Dark" : "AppIcon-Clear-Light"
                    case 2:
                        // Tinted Mode (Flat Liquid Glass Tinted)
                        return isDarkStyle ? "AppIcon-Tinted-Dark" : "AppIcon-Tinted-Light"
                    default:
                        // FullColor (Default or Dark)
                        return (themeIdx == 2 || (themeIdx == 0 && isSystemDark)) ? "AppIcon-Dark" : "AppIcon-Light"
                    }
                }
            }
        }

        // Fallback
        return isSystemDark ? "AppIcon-Dark" : "AppIcon-Light"
    }

    public func loadIconImage(named name: String) -> NSImage? {
        // 1. Bundle AppIcons directory
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "AppIcons"),
           let img = NSImage(contentsOf: url) { return img }
        // 2. Main bundle image resource
        if let img = Bundle.main.image(forResource: name) { return img }
        // 3. Fallback: check standard app icon
        return NSImage(named: NSImage.applicationIconName)
    }
}


// MARK: - Window Delegate to Hide on Close Instead of Quitting or Destroying
final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If user closes window, order it out to hide it into menu bar cleanly
        sender.orderOut(nil)
        return false
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = MainWindowDelegate.shared
                window.isReleasedWhenClosed = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
