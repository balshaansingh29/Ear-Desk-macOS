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
            Button(ctl.deviceName) {
                bringAppToFront()
            }
            if let s = ctl.battery.stereo {
                Button("Battery \(s.level)%") {
                    bringAppToFront()
                }
            } else {
                let label: String = {
                    var items: [String] = []
                    if let l = ctl.battery.left { items.append("L \(l.level)%") }
                    if let r = ctl.battery.right { items.append("R \(r.level)%") }
                    if let c = ctl.battery.caseCell { items.append("Case \(c.level)%") }
                    return items.joined(separator: "  ")
                }()
                if !label.isEmpty {
                    Button(label) {
                        bringAppToFront()
                    }
                }
            }
            Divider()
            if ctl.model?.hasANC ?? true {
                Button("Noise Cancellation") { ctl.setANC(ctl.model?.anc?.contains(.strengthAdaptive) == true ? .adaptive : .high) }
                if ctl.model?.anc?.contains(.transparency) ?? true {
                    Button("Transparency") { ctl.setANC(.transparency) }
                }
                Button("ANC Off") { ctl.setANC(.off) }
                Divider()
            }
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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "5"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // General Settings Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 5, height: 5)
                    Text("GENERAL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(NothingTheme.textSecondary)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("LAUNCH AT LOGIN")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.white)
                            Text("Automatically start Ear-Desk in the menu bar on login")
                                .font(.system(size: 10))
                                .foregroundStyle(NothingTheme.textTertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(get: { ctl.launchAtLogin }, set: ctl.setLaunchAtLogin))
                            .toggleStyle(NothingToggleStyle())
                            .labelsHidden()
                    }

                    Divider().background(NothingTheme.borderSubtle)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 32, height: 32)
                            Image(systemName: "bolt.badge.automatic")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AUTO-CONNECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.white)
                            Text("Automatically link when earbuds connect to macOS")
                                .font(.system(size: 10))
                                .foregroundStyle(NothingTheme.textTertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(get: { ctl.autoConnect }, set: ctl.setAutoConnect))
                            .toggleStyle(NothingToggleStyle())
                            .labelsHidden()
                    }

                    Divider().background(NothingTheme.borderSubtle)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 32, height: 32)
                            Image(systemName: "bell.badge")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("LOW BATTERY ALERTS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.white)
                            Text("Notify when earbuds battery drops to 15% or below")
                                .font(.system(size: 10))
                                .foregroundStyle(NothingTheme.textTertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(get: { ctl.notifyLowBattery }, set: ctl.setNotifyLowBattery))
                            .toggleStyle(NothingToggleStyle())
                            .labelsHidden()
                    }
                }
                .padding(16)
                .background(NothingTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(NothingTheme.border, lineWidth: 1))
            }

            // About Details Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 5, height: 5)
                    Text("ABOUT EAR-DESK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(NothingTheme.textSecondary)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        if let appIcon = NSImage(named: "AppIcon") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "earbuds")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("EAR-DESK")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(.white)
                            Text("Version \(appVersion) (Build \(buildNumber))")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(NothingTheme.textSecondary)
                            Text("Native macOS controller for Nothing & CMF audio devices")
                                .font(.system(size: 10))
                                .foregroundStyle(NothingTheme.textTertiary)
                        }
                        Spacer()
                    }

                    Divider().background(NothingTheme.borderSubtle)

                    HStack {
                        Link(destination: URL(string: "https://github.com/balshaansingh29/Ear-Desk-macOS")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.right.circle")
                                    .font(.system(size: 11))
                                Text("GITHUB REPOSITORY")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(NothingTheme.textSecondary)
                        }

                        Spacer()

                        Link(destination: URL(string: "https://github.com/balshaansingh29/Ear-Desk-macOS/releases")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11))
                                Text("CHECK FOR UPDATES")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(NothingTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(NothingTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(NothingTheme.border, lineWidth: 1))
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(NothingTheme.bg)
        .preferredColorScheme(.dark)
    }
}
