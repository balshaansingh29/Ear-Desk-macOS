// MARK: - Product Hero View

struct ProductHeroView: View {
    let image: NSImage
    @State private var isHovered = false
    @State private var isFloating = false

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                // Subtle ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(isHovered ? 0.08 : 0.03), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 220, height: 220)

                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .scaleEffect(isHovered ? 1.03 : 1.0)
                    .offset(y: isFloating ? -4 : 4)
                    .shadow(color: Color.black.opacity(isHovered ? 0.65 : 0.45), radius: isHovered ? 24 : 14, x: 0, y: isHovered ? 12 : 8)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: isFloating)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovered)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .onHover { isHovered = $0 }
        .onAppear {
            isFloating = true
        }
    }
}

// MARK: - Pulsing Status Dot

struct PulsingStatusDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.35))
                .frame(width: 12, height: 12)
                .scaleEffect(pulse ? 1.4 : 0.9)
                .opacity(pulse ? 0.0 : 0.8)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                .frame(width: 6, height: 6)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Product Asset Helper

enum ProductAssets {
    static func image(for base: String?) -> NSImage? {
        guard let base = base else { return nil }
        if let bundlePath = Bundle.main.path(forResource: base, ofType: "png", inDirectory: "Products"),
           let img = NSImage(contentsOfFile: bundlePath) {
            return img
        }
        // Fallback for development / unbundled builds
        let devPath = "Resources/Products/\(base).png"
        if FileManager.default.fileExists(atPath: devPath),
           let img = NSImage(contentsOfFile: devPath) {
            return img
        }
        return nil
    }
}

import SwiftUI
import EarDeskCore

// MARK: - Nothing Design System

enum NothingTheme {
    static let red = Color(red: 0.88, green: 0.12, blue: 0.12)
    static let bg = Color(red: 0.06, green: 0.06, blue: 0.07)
    static let surface = Color.white.opacity(0.04)
    static let surfaceHover = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.10)
    static let borderSubtle = Color.white.opacity(0.06)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
}

struct NothingToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? NothingTheme.red : Color.white.opacity(0.12))
                    .frame(width: 38, height: 20)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .padding(3)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
            .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var ctl: EarbudsController
    @EnvironmentObject var updater: AppUpdater
    @AppStorage("hasPromptedLaunchAtLogin") private var hasPromptedLaunchAtLogin: Bool = false
    @State private var showPromptSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Update Banner (shows when newer release is available)
            if case .updateAvailable(let version, _, let dlUrl) = updater.status {
                HStack(spacing: 10) {
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 6, height: 6)

                    Text("UPDATE AVAILABLE: v\(version)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        Task {
                            await updater.downloadAndInstall(url: dlUrl)
                        }
                    } label: {
                        Text("UPDATE & RESTART")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 22/255, green: 22/255, blue: 24/255))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if ctl.link == .connected {
                    ControlsView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            )
                        )
                } else {
                    ConnectView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                                removal: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: -8))
                            )
                        )
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: ctl.link == .connected)
        .frame(minWidth: 460, idealWidth: 480, minHeight: 600)
        .background(NothingTheme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPromptSheet) {
            LaunchAtLoginPromptView(onDismiss: {
                showPromptSheet = false
                hasPromptedLaunchAtLogin = true
            })
            .environmentObject(ctl)
        }
        .sheet(isPresented: Binding(
            get: {
                if case .downloading = updater.status { return true }
                if case .installing = updater.status { return true }
                if case .readyToRestart = updater.status { return true }
                return false
            },
            set: { _ in }
        )) {
            UpdateProgressModal()
                .environmentObject(updater)
        }
        .onAppear {
            if !hasPromptedLaunchAtLogin {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if !hasPromptedLaunchAtLogin {
                        showPromptSheet = true
                    }
                }
            }
            // Background check for updates on startup
            Task {
                await updater.checkForUpdates()
            }
        }
    }
}

// MARK: - Launch At Login First-Time Popup

struct LaunchAtLoginPromptView: View {
    @EnvironmentObject var ctl: EarbudsController
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Nothing Glyph aesthetic header icon
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 68, height: 68)
                Circle()
                    .strokeBorder(NothingTheme.red.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: 54, height: 54)
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text("START EAR-DESK AT LOGIN?")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                Text("Ear-Desk can live in your macOS menu bar and automatically monitor your Nothing & CMF audio gear whenever you start your Mac.")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .foregroundStyle(NothingTheme.textSecondary)
                    .frame(maxWidth: 320)
            }

            HStack(spacing: 12) {
                Button("NOT NOW") {
                    onDismiss()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(NothingTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04), in: Capsule())
                .overlay(Capsule().strokeBorder(NothingTheme.border, lineWidth: 1))
                .buttonStyle(.plain)

                Button("ENABLE AT LOGIN") {
                    ctl.setLaunchAtLogin(true)
                    onDismiss()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.white, in: Capsule())
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)
        }
        .padding(24)
        .frame(width: 380)
        .background(NothingTheme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(NothingTheme.border, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Connect View

struct ConnectView: View {
    @EnvironmentObject var ctl: EarbudsController

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 16)

                // Glyph-inspired hero illustration
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 140, height: 140)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 80, height: 80)
                        .overlay(Circle().strokeBorder(NothingTheme.border, lineWidth: 1))

                    Image(systemName: "earbuds")
                        .font(.system(size: 34, weight: .ultraLight))
                        .foregroundStyle(.white)

                    // Nothing red accent dot
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 6, height: 6)
                        .offset(x: 44, y: -44)
                }

                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        Text("EAR")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(.white)
                        Text("(DESK)")
                            .font(.system(size: 22, weight: .light, design: .monospaced))
                            .foregroundStyle(NothingTheme.red)
                    }

                    Text("// AUDIO CONTROL HUB FOR MAC")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(NothingTheme.textTertiary)
                }

                Text("Pair your earbuds in System Settings › Bluetooth, connect to this Mac, then select them below.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NothingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Select Device card
                Card(title: "Select Device", icon: "antenna.radiowaves.left.and.right") {
                    if ctl.pairedDevices.isEmpty {
                        Text("[ NO PAIRED DEVICES DETECTED ]")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(NothingTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        Picker("Device", selection: $ctl.selectedAddress) {
                            ForEach(ctl.pairedDevices) { d in
                                Text(d.isConnected ? "\(d.name)  ●" : d.name).tag(Optional(d.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }

                // Model override
                DisclosureGroup {
                    Picker("Model", selection: $ctl.manualModelBase) {
                        Text("Detect from name (Auto)").tag("auto")
                        ForEach(DeviceCatalog.all, id: \.base) { Text("\($0.displayName) (\($0.base))").tag($0.base) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(NothingTheme.red)
                            .frame(width: 4, height: 4)
                        Text("MODEL OVERRIDE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(NothingTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NothingTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NothingTheme.border, lineWidth: 1)
                )

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        ctl.refreshDevices()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("REFRESH")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(NothingTheme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(NothingTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        ctl.connect()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .bold))
                            Text("CONNECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .background(
                            (ctl.selectedAddress == nil || ctl.link == .connecting) ? Color.white.opacity(0.3) : Color.white,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(ctl.selectedAddress == nil || ctl.link == .connecting)
                }

                switch ctl.link {
                case .connecting:
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("CONNECTING...")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(NothingTheme.textSecondary)
                    }
                    .padding(.top, 4)
                case .failed(let msg):
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(msg)
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .foregroundStyle(NothingTheme.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NothingTheme.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(NothingTheme.red.opacity(0.2), lineWidth: 1))
                default:
                    EmptyView()
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .onAppear { ctl.refreshDevices() }
    }
}

// MARK: - Controls View

struct ControlsView: View {
    @EnvironmentObject var ctl: EarbudsController

    private var productImage: NSImage? {
        ProductAssets.image(for: ctl.model?.base)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let img = productImage {
                    ProductHeroView(image: img)
                }
                BatteryView(info: ctl.battery)
                if ctl.model?.hasANC ?? true { ANCSection() }
                EQSection()
                if !(ctl.model?.supportedSpatialModes.isEmpty ?? true) { SpatialAudioSection() }
                if ctl.model?.supportsBassEnhance ?? false { BassSection() }
                if ctl.model?.supportsDualConnection ?? true { DualConnectionSection() }
                QuickSettings()
                FindSection()
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    PulsingStatusDot()
                    Text(ctl.deviceName.uppercased())
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                }
                Text(ctl.firmware.isEmpty ? (ctl.model?.displayName ?? "Unknown model") : "FW \(ctl.firmware) · \(ctl.model?.displayName ?? "")")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NothingTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                // Settings button
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NothingTheme.textSecondary)
                        .padding(7.5)
                        .background(Color.white.opacity(0.04), in: Circle())
                        .overlay(Circle().strokeBorder(NothingTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")

                // Disconnect button
                Button {
                    ctl.disconnect()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .bold))
                        Text("DISCONNECT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                    }
                    .foregroundStyle(NothingTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.04), in: Capsule())
                    .overlay(Capsule().strokeBorder(NothingTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Card Component

struct Card<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var content: Content

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(NothingTheme.red)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isHovered ? 1.25 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(isHovered ? Color.white : NothingTheme.textSecondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(isHovered ? NothingTheme.surfaceHover : NothingTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isHovered ? Color.white.opacity(0.18) : NothingTheme.border, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Battery View

struct BatteryRingView: View {
    let label: String
    let cell: BatteryInfo.Cell
    let iconName: String

    private var progress: Double {
        Double(max(0, min(100, cell.level))) / 100.0
    }

    private var ringColor: Color {
        if cell.charging {
            return Color(red: 0.2, green: 0.85, blue: 0.4)
        } else if cell.level <= 15 {
            return NothingTheme.red
        } else {
            return Color.white
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4.5)
                    .frame(width: 58, height: 58)

                if cell.charging {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.35), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 58, height: 58)
                        .blur(radius: 3)
                }

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                VStack(spacing: 1) {
                    if cell.charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(NothingTheme.red)
                    }
                    Text("\(cell.level)%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 9))
                    .foregroundStyle(NothingTheme.textTertiary)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(NothingTheme.textSecondary)
            }
        }
        .frame(minWidth: 80)
    }
}

struct BatteryView: View {
    @EnvironmentObject var ctl: EarbudsController
    let info: BatteryInfo

    private var deviceIcon: String {
        ctl.model?.systemIconName ?? "earbuds"
    }

    var body: some View {
        Card(title: "Battery", icon: "bolt.badge.clock") {
            HStack(spacing: 24) {
                if let s = info.stereo {
                    let label = ctl.model?.displayName.uppercased().contains("HEADPHONE") == true ? "HEADPHONES" : "EARBUDS"
                    BatteryRingView(label: label, cell: s, iconName: deviceIcon)
                } else {
                    if let l = info.left {
                        BatteryRingView(label: "LEFT", cell: l, iconName: "earbuds")
                    }
                    if let r = info.right {
                        BatteryRingView(label: "RIGHT", cell: r, iconName: "earbuds")
                    }
                    if let c = info.caseCell {
                        BatteryRingView(label: "CASE", cell: c, iconName: "earbuds.case")
                    }
                }
                if info.stereo == nil && info.left == nil && info.right == nil && info.caseCell == nil {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("READING BATTERY LEVELS...")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(NothingTheme.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - ANC Section

struct ANCSection: View {
    @EnvironmentObject var ctl: EarbudsController

    private var available: [ANCMode] {
        guard let caps = ctl.model?.anc else { return ANCMode.allCases }
        var modes: [ANCMode] = [.off]
        if caps.contains(.transparency) { modes.append(.transparency) }
        if caps.contains(.strengthBase) { modes += [.high] }
        if caps.contains(.strengthMid) { modes.append(.mid) }
        if caps.contains(.strengthBase) { modes.append(.low) }
        if caps.contains(.strengthAdaptive) { modes.append(.adaptive) }
        if !caps.contains(.strengthBase) { modes.append(.high) }
        return modes
    }

    private var availableStrengths: [ANCMode] {
        available.filter { $0 == .high || $0 == .mid || $0 == .low || $0 == .adaptive }
    }

    private var isNCActive: Bool {
        ctl.anc == .high || ctl.anc == .mid || ctl.anc == .low || ctl.anc == .adaptive
    }

    var body: some View {
        Card(title: "Noise Control", icon: "waveform") {
            VStack(spacing: 12) {
                // Primary mode selector
                HStack(spacing: 8) {
                    if available.contains(.off) {
                        modeButton(title: "OFF", icon: "circle.slash", isSelected: ctl.anc == .off) {
                            ctl.setANC(.off)
                        }
                    }

                    if !availableStrengths.isEmpty {
                        modeButton(title: "NOISE CANCELLATION", icon: "shield.fill", isSelected: isNCActive) {
                            if !isNCActive {
                                let preferred = availableStrengths.contains(.adaptive) ? .adaptive : (availableStrengths.contains(.high) ? .high : availableStrengths[0])
                                ctl.setANC(preferred)
                            }
                        }
                    }

                    if available.contains(.transparency) {
                        modeButton(title: "TRANSPARENCY", icon: "waveform", isSelected: ctl.anc == .transparency) {
                            ctl.setANC(.transparency)
                        }
                    }
                }

                // Sub-strength selector if Noise Cancellation is selected and multiple strengths are supported
                if isNCActive && availableStrengths.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(availableStrengths, id: \.self) { mode in
                            strengthButton(mode: mode)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func modeButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .black : .white)
            .background(isSelected ? Color.white : NothingTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : NothingTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func strengthButton(mode: ANCMode) -> some View {
        let isSelected = ctl.anc == mode
        let label: String = {
            switch mode {
            case .high: return "HIGH"
            case .mid: return "MID"
            case .low: return "LOW"
            case .adaptive: return "ADAPTIVE"
            default: return mode.title.uppercased()
            }
        }()

        return Button {
            ctl.setANC(mode)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 4, height: 4)
                }
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : NothingTheme.textSecondary)
            .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.02), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : NothingTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EQ Section

struct EQVisualizerView: View {
    let presetName: String
    var customEQ: CustomEQ? = nil

    // 16-band spectrum waveform
    private var barHeights: [CGFloat] {
        if presetName.lowercased() == "custom", let c = customEQ {
            // Modulate 16 bands based on Bass (bands 0..4), Mid (bands 5..10), Treble (bands 11..15)
            // Values are between -6 and +6 dB -> mapped into offset factors
            let bFactor = CGFloat(c.bass) / 12.0      // -0.5 ... +0.5
            let mFactor = CGFloat(c.mid) / 12.0       // -0.5 ... +0.5
            let tFactor = CGFloat(c.treble) / 12.0    // -0.5 ... +0.5

            let base: [CGFloat] = [
                0.50, 0.48, 0.46, 0.45, 0.46,
                0.48, 0.50, 0.52, 0.52, 0.50, 0.48,
                0.46, 0.47, 0.49, 0.51, 0.52
            ]

            return base.enumerated().map { i, val in
                var adjusted = val
                if i <= 4 {
                    let weight = 1.0 - (CGFloat(i) * 0.15)
                    adjusted += bFactor * weight
                } else if i >= 11 {
                    let weight = 0.4 + (CGFloat(i - 11) * 0.15)
                    adjusted += tFactor * weight
                } else {
                    let weight = 1.0 - abs(CGFloat(i) - 7.5) * 0.2
                    adjusted += mFactor * weight
                }
                return max(0.08, min(1.0, adjusted))
            }
        }

        switch presetName.lowercased() {
        case "more bass":
            return [1.0, 0.94, 0.84, 0.72, 0.58, 0.46, 0.36, 0.28, 0.24, 0.20, 0.18, 0.16, 0.15, 0.14, 0.13, 0.12]
        case "more treble":
            return [0.12, 0.15, 0.18, 0.24, 0.32, 0.42, 0.54, 0.68, 0.78, 0.88, 0.94, 0.98, 0.94, 0.88, 0.82, 0.76]
        case "more voice":
            return [0.18, 0.24, 0.38, 0.60, 0.84, 0.98, 0.96, 0.82, 0.62, 0.44, 0.32, 0.24, 0.20, 0.18, 0.15, 0.14]
        case "balanced":
            return [0.50, 0.52, 0.50, 0.53, 0.51, 0.50, 0.52, 0.50, 0.53, 0.51, 0.50, 0.52, 0.50, 0.52, 0.50, 0.50]
        case "rock":
            return [0.92, 0.84, 0.70, 0.52, 0.40, 0.44, 0.56, 0.70, 0.82, 0.92, 0.90, 0.84, 0.80, 0.76, 0.72, 0.68]
        case "pop":
            return [0.62, 0.72, 0.80, 0.85, 0.82, 0.74, 0.68, 0.72, 0.78, 0.74, 0.66, 0.56, 0.48, 0.42, 0.38, 0.35]
        case "electronic":
            return [0.96, 0.88, 0.76, 0.62, 0.48, 0.42, 0.54, 0.72, 0.86, 0.96, 0.92, 0.84, 0.78, 0.70, 0.64, 0.58]
        case "classical":
            return [0.44, 0.50, 0.54, 0.58, 0.64, 0.70, 0.76, 0.82, 0.84, 0.80, 0.72, 0.64, 0.56, 0.48, 0.42, 0.38]
        case "custom":
            return [0.72, 0.65, 0.58, 0.52, 0.48, 0.55, 0.68, 0.75, 0.82, 0.85, 0.78, 0.70, 0.65, 0.60, 0.58, 0.55]
        case "enhance vocals":
            return [0.16, 0.22, 0.36, 0.62, 0.88, 1.0, 0.92, 0.76, 0.58, 0.38, 0.26, 0.20, 0.18, 0.15, 0.13, 0.12]
        case "dirac opteo":
            return [0.65, 0.68, 0.70, 0.68, 0.70, 0.72, 0.70, 0.68, 0.72, 0.70, 0.68, 0.66, 0.64, 0.62, 0.60, 0.58]
        default:
            return [0.50, 0.51, 0.50, 0.52, 0.50, 0.51, 0.50, 0.52, 0.50, 0.51, 0.50, 0.52, 0.50, 0.51, 0.50, 0.50]
        }
    }

    @State private var animPhase = false

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let count = barHeights.count
            let spacing: CGFloat = 2.5
            let barW = max(2.5, (totalWidth - (CGFloat(count - 1) * spacing)) / CGFloat(count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let harmonicFactor = CGFloat(sin(Double(i) * 0.5 + (animPhase ? 1.5 : 0.0)))
                    let jitter: CGFloat = harmonicFactor * 0.07
                    let barHeight = max(4.0, (barHeights[i] + jitter) * (geo.size.height - 4))

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    NothingTheme.red,
                                    NothingTheme.red.opacity(0.8),
                                    Color.white.opacity(0.4)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barW, height: barHeight)
                        .animation(
                            .easeInOut(duration: 0.65 + Double(i % 4) * 0.12).repeatForever(autoreverses: true),
                            value: animPhase
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .onAppear { animPhase = true }
    }
}

// MARK: - Custom EQ Modal Sheet

struct CustomEQSheet: View {
    @EnvironmentObject var ctl: EarbudsController
    @Binding var isPresented: Bool

    @State private var bass: Double = 0
    @State private var mid: Double = 0
    @State private var treble: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(NothingTheme.red)
                        .frame(width: 6, height: 6)
                    Text("CUSTOM EQUALIZER")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(NothingTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text("Fine-tune acoustic frequency responses from -6 dB to +6 dB.")
                .font(.system(size: 11))
                .foregroundStyle(NothingTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Waveform live preview with current custom sliders
            EQVisualizerView(presetName: "custom", customEQ: CustomEQ(bass: Int(bass), mid: Int(mid), treble: Int(treble)))
                .frame(height: 70)

            // 3 Vertical/Horizontal Band Tuning Sliders
            HStack(spacing: 16) {
                BandSlider(title: "BASS", subtitle: "140 Hz", value: $bass) {
                    applyBands()
                }
                BandSlider(title: "MID", subtitle: "980 Hz", value: $mid) {
                    applyBands()
                }
                BandSlider(title: "TREBLE", subtitle: "\(Int(ctl.model?.customEQHighShelfFreq ?? 3500)) Hz", value: $treble) {
                    applyBands()
                }
            }
            .padding(.vertical, 8)

            // Footer controls
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        bass = 0
                        mid = 0
                        treble = 0
                    }
                    applyBands()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("RESET FLAT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(NothingTheme.textSecondary)
                    .background(Color.white.opacity(0.04), in: Capsule())
                    .overlay(Capsule().strokeBorder(NothingTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    applyBands()
                    ctl.setEQ(wire: 6)
                    isPresented = false
                } label: {
                    Text("APPLY & SAVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(NothingTheme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NothingTheme.border, lineWidth: 1)
        )
        .onAppear {
            bass = Double(ctl.customEQ.bass)
            mid = Double(ctl.customEQ.mid)
            treble = Double(ctl.customEQ.treble)
        }
        .preferredColorScheme(.dark)
    }

    private func applyBands() {
        ctl.setCustomEQBands(bass: Int(bass), mid: Int(mid), treble: Int(treble))
    }
}

struct BandSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Title & frequency
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(NothingTheme.textTertiary)
            }

            // dB value badge
            Text(value > 0 ? "+\(Int(value)) dB" : "\(Int(value)) dB")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(value == 0 ? NothingTheme.textSecondary : (value > 0 ? NothingTheme.red : Color.white))
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))

            // Custom styled slider
            Slider(value: $value, in: -6...6, step: 1) {
                Text(title)
            }
            .labelsHidden()
            .tint(NothingTheme.red)
            .onChange(of: value) { _ in
                onChange()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NothingTheme.borderSubtle, lineWidth: 1)
                )
        )
    }
}

struct EQSection: View {
    @EnvironmentObject var ctl: EarbudsController
    @State private var showCustomModal = false

    private var presets: [(name: String, wire: UInt8)] {
        switch ctl.model?.eqStyle {
        case .listeningMode(let p)?: return p
        default: return [("Balanced", 0), ("More Voice", 1), ("More Treble", 2), ("More Bass", 3), ("Custom", 6)]
        }
    }

    private var activePresetName: String {
        presets.first(where: { $0.wire == ctl.eqWire })?.name ?? "Balanced"
    }

    var body: some View {
        Card(title: "Equalizer") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    // Presets on the left
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(presets, id: \.wire) { preset in
                            let isSelected = ctl.eqWire == preset.wire
                            let isCustom = preset.name.lowercased() == "custom"
                            Button {
                                ctl.setEQ(wire: preset.wire)
                                if isCustom {
                                    showCustomModal = true
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    if isSelected {
                                        Circle()
                                            .fill(NothingTheme.red)
                                            .frame(width: 4, height: 4)
                                    }
                                    Text(preset.name.uppercased())
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(0.8)
                                        .lineLimit(1)

                                    if isCustom {
                                        Image(systemName: "slider.vertical.3")
                                            .font(.system(size: 8))
                                            .foregroundStyle(isSelected ? .black.opacity(0.7) : NothingTheme.textTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 6)
                                .foregroundStyle(isSelected ? .black : .white)
                                .background(
                                    isSelected ? Color.white : NothingTheme.surface,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? Color.clear : NothingTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: isSelected)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Waveform on the right of buttons
                    EQVisualizerView(presetName: activePresetName, customEQ: ctl.customEQ)
                        .frame(width: 130)
                }

                if ctl.eqWire == 6 {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10))
                            .foregroundStyle(NothingTheme.red)
                        Text("B: \(ctl.customEQ.bass >= 0 ? "+" : "")\(ctl.customEQ.bass)dB  ·  M: \(ctl.customEQ.mid >= 0 ? "+" : "")\(ctl.customEQ.mid)dB  ·  T: \(ctl.customEQ.treble >= 0 ? "+" : "")\(ctl.customEQ.treble)dB")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NothingTheme.textSecondary)
                        Spacer()
                        Button {
                            showCustomModal = true
                        } label: {
                            Text("TUNE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else if ctl.eqWire == 5 {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text("Classical acoustic preset profile is active.")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(NothingTheme.textTertiary)
                    .padding(.top, 2)
                }
            }
        }
        .sheet(isPresented: $showCustomModal) {
            CustomEQSheet(isPresented: $showCustomModal)
                .environmentObject(ctl)
        }
    }
}


// MARK: - Spatial Audio Section

struct SpatialAudioSection: View {
    @EnvironmentObject var ctl: EarbudsController

    private var modes: [SpatialAudioMode] {
        ctl.model?.supportedSpatialModes ?? [.off, .fixed]
    }

    private func iconForMode(_ mode: SpatialAudioMode) -> String {
        switch mode {
        case .off: return "speaker.slash"
        case .fixed: return "speaker.wave.2"
        case .headTracked: return "person.crop.circle"
        case .concert: return "music.note.house"
        case .theatre: return "film"
        }
    }

    private func subtitleForMode(_ mode: SpatialAudioMode) -> String {
        switch mode {
        case .off: return "Standard stereo audio without spatialization"
        case .fixed: return "3D spatial immersion anchored to soundstage"
        case .headTracked: return "Dynamic soundstage matching head rotation"
        case .concert: return "Simulated wide acoustic concert hall acoustics"
        case .theatre: return "Surround cinematic immersion with enhanced width"
        }
    }

    var body: some View {
        Card(title: "Spatial Audio", icon: "waveform.and.person.filled") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(modes) { mode in
                        let isSelected = ctl.spatialAudio == mode
                        Button {
                            ctl.setSpatialAudio(mode)
                        } label: {
                            HStack(spacing: 6) {
                                if isSelected {
                                    Circle()
                                        .fill(NothingTheme.red)
                                        .frame(width: 4, height: 4)
                                }
                                Image(systemName: iconForMode(mode))
                                    .font(.system(size: 9))
                                Text(mode.title.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(isSelected ? .black : .white)
                            .background(
                                isSelected ? Color.white : NothingTheme.surface,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isSelected ? Color.clear : NothingTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.16), value: isSelected)
                    }
                }

                // Subtitle description of active mode
                HStack(spacing: 6) {
                    Image(systemName: iconForMode(ctl.spatialAudio))
                        .font(.system(size: 10))
                        .foregroundStyle(ctl.spatialAudio == .off ? NothingTheme.textTertiary : NothingTheme.red)
                    Text(subtitleForMode(ctl.spatialAudio))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NothingTheme.textTertiary)
                }
                .padding(.top, 2)
            }
        }
    }
}

struct BassSection: View {
    @EnvironmentObject var ctl: EarbudsController

    var body: some View {
        Card(title: "Bass Enhance", icon: "waveform.path") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BASS BOOST")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                        Text("Intelligent low-frequency amplification")
                            .font(.system(size: 10))
                            .foregroundStyle(NothingTheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { ctl.bassEnabled },
                        set: { ctl.setBass(enabled: $0, level: ctl.bassLevel) }
                    ))
                    .toggleStyle(NothingToggleStyle())
                    .labelsHidden()
                }

                let maxLevel = (ctl.model?.threeStageBass ?? false) ? 2 : 5

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("INTENSITY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(NothingTheme.textSecondary)
                        Spacer()
                        Text("LVL \(ctl.bassLevel)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(ctl.bassEnabled ? .white : NothingTheme.textTertiary)
                    }

                    // Segmented LED-style bar
                    HStack(spacing: 5) {
                        ForEach(0...maxLevel, id: \.self) { lvl in
                            Button {
                                if ctl.bassEnabled {
                                    ctl.setBass(enabled: true, level: lvl)
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        !ctl.bassEnabled ? Color.white.opacity(0.06) :
                                        lvl <= ctl.bassLevel ? (lvl == ctl.bassLevel ? NothingTheme.red : Color.white) :
                                        Color.white.opacity(0.12)
                                    )
                                    .frame(height: 14)
                            }
                            .buttonStyle(.plain)
                            .disabled(!ctl.bassEnabled)
                        }
                    }
                }
                .opacity(ctl.bassEnabled ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.18), value: ctl.bassEnabled)
            }
        }
    }
}

// MARK: - Quick Settings

struct QuickSettings: View {
    @EnvironmentObject var ctl: EarbudsController

    var body: some View {
        Card(title: "Quick Settings", icon: "gearshape") {
            VStack(spacing: 12) {
                if ctl.model?.supportsInEar ?? true {
                    settingRow(
                        title: "IN-EAR DETECTION",
                        subtitle: "Auto-pause when earbuds are removed",
                        icon: "ear",
                        isOn: Binding(get: { ctl.inEarDetection }, set: ctl.setInEar)
                    )
                }

                settingRow(
                    title: "LOW LATENCY MODE",
                    subtitle: "Minimizes audio lag for video and gaming",
                    icon: "bolt.horizontal",
                    isOn: Binding(get: { ctl.lowLatency }, set: ctl.setLowLatency)
                )


            }
        }
    }

    private func settingRow(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(NothingTheme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(NothingToggleStyle())
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Find Section

struct FindSection: View {
    @EnvironmentObject var ctl: EarbudsController

    private var isRinging: Bool {
        ctl.ringing.left || ctl.ringing.right
    }

    var body: some View {
        Card(title: "Find My Earbuds", icon: "speaker.wave.3") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plays a loud acoustic tone. Remove the earbuds from your ears first.")
                    .font(.system(size: 11))
                    .foregroundStyle(NothingTheme.textTertiary)

                Button {
                    let next = !isRinging
                    ctl.ring(left: true, on: next)
                    if ctl.model?.ringStyle == .perBud || ctl.model == nil {
                        ctl.ring(left: false, on: next)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRinging ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isRinging ? "STOP" : "RING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(isRinging ? NothingTheme.red : NothingTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isRinging ? Color.clear : NothingTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isRinging)
            }
        }
    }
}


// MARK: - Dual Connection Section

struct DualConnectionSection: View {
    @EnvironmentObject var ctl: EarbudsController

    var body: some View {
        Card(title: "Dual Connection", icon: "link") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MULTIPOINT AUDIO")                            .font(.system(size: 12, weight: .bold, design: .monospaced))                            .tracking(1.2)                            .foregroundStyle(.white)
                        Text("Connect simultaneously to two Bluetooth audio sources")                            .font(.system(size: 10))                            .foregroundStyle(NothingTheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { ctl.dualConnectionEnabled },
                        set: { ctl.setDualConnection($0) }
                    ))
                    .toggleStyle(NothingToggleStyle())
                    .labelsHidden()
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("PAIRED MULTIPOINT HOSTS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(NothingTheme.textSecondary)
                        Spacer()
                        Button {
                            ctl.refreshDualConnectionList()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                                Text("REFRESH")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(NothingTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if !ctl.dualConnectionEnabled {
                        HStack {
                            Spacer()
                            Text("Enable Multipoint Audio above to connect two devices simultaneously.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(NothingTheme.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if ctl.dualDevices.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("No secondary hosts connected or paired.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(NothingTheme.textTertiary)
                                Text("Pair your other device (phone, iPad, laptop) to these earbuds.")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(NothingTheme.textTertiary.opacity(0.8))
                            }
                            .padding(.vertical, 8)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(ctl.dualDevices) { dev in
                                deviceRow(dev)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func deviceRow(_ dev: DualDeviceItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                Image(systemName: dev.isCurrentHost ? "laptopcomputer" : (dev.name.lowercased().contains("phone") || dev.name.lowercased().contains("iphone") ? "iphone" : "headphones"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(dev.isConnected ? .white : NothingTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dev.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    if dev.isCurrentHost {
                        Text("THIS MAC")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(NothingTheme.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(NothingTheme.red.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(dev.mac)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(NothingTheme.textTertiary)
                    if dev.isConnected {
                        Text("· ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                }
            }

            Spacer()

            if dev.isCurrentHost {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                        .frame(width: 6, height: 6)
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.4))
                }
            } else {
                Toggle("", isOn: Binding(
                    get: { dev.isConnected },
                    set: { shouldConnect in
                        ctl.setDualDeviceConnected(mac: dev.mac, connect: shouldConnect)
                    }
                ))
                .toggleStyle(NothingToggleStyle())
                .labelsHidden()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NothingTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(NothingTheme.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Reactive Animated Installer Modal for Self-Updating

struct UpdateProgressModal: View {
    @EnvironmentObject var updater: AppUpdater
    @State private var rotatePhase: Double = 0
    @State private var pulse: Bool = false

    private var progressValue: Double {
        updater.downloadProgress
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            // Animated Glyph-Style Installer Graphic with Reactive Progress Ring
            ZStack {
                // Background Track
                Circle()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 96, height: 96)

                // Reactive Progress Arc (Reacts directly to real download progress)
                if progressValue > 0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(max(progressValue, 0.02), 1.0)))
                        .stroke(
                            NothingTheme.red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                        .animation(.easeOut(duration: 0.25), value: progressValue)
                }

                // Rotating ambient dotted ring
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 8]))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotatePhase))

                // Reactive Inner Center
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 62, height: 62)
                    .scaleEffect(pulse ? 1.04 : 0.96)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if case .readyToRestart = updater.status {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.green)
                        .transition(.scale.combined(with: .opacity))
                } else if case .installing = updater.status {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(NothingTheme.red)
                        .rotationEffect(.degrees(rotatePhase * 1.5))
                } else {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    rotatePhase = 360
                }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            // Status Text Reactive Switcher
            VStack(spacing: 6) {
                switch updater.status {
                case .downloading:
                    HStack(spacing: 6) {
                        Text("DOWNLOADING")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(2.0)
                            .foregroundStyle(.white)
                        if progressValue > 0 {
                            Text("\(Int(progressValue * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(NothingTheme.red)
                        }
                    }
                    Text("Streaming latest release package from GitHub…")
                        .font(.system(size: 11))
                        .foregroundStyle(NothingTheme.textSecondary)

                case .installing(let step):
                    Text("INSTALLING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(.white)
                    Text(step)
                        .font(.system(size: 11))
                        .foregroundStyle(NothingTheme.textSecondary)

                case .readyToRestart:
                    Text("RESTARTING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.green)
                    Text("Ear-Desk is relaunching with the latest version.")
                        .font(.system(size: 11))
                        .foregroundStyle(NothingTheme.textSecondary)

                default:
                    EmptyView()
                }
            }

            // Reactive Horizontal Progress Bar
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 260, height: 4)

                    if case .downloading = updater.status {
                        Capsule()
                            .fill(NothingTheme.red)
                            .frame(width: max(4, 260 * CGFloat(min(progressValue, 1.0))), height: 4)
                            .animation(.easeOut(duration: 0.2), value: progressValue)
                    } else if case .installing = updater.status {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 260, height: 4)
                            .overlay(
                                Capsule()
                                    .fill(NothingTheme.red)
                                    .scaleEffect(x: pulse ? 1.0 : 0.6, y: 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                            )
                    } else {
                        Capsule()
                            .fill(Color.green)
                            .frame(width: 260, height: 4)
                    }
                }

                // Dot matrix indicator lights
                HStack(spacing: 8) {
                    ForEach(0..<9) { idx in
                        let active = (Double(idx) / 8.0) <= progressValue
                        Circle()
                            .fill(active ? NothingTheme.red : Color.white.opacity(0.12))
                            .frame(width: 4, height: 4)
                            .animation(.easeOut(duration: 0.2), value: progressValue)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 4)
        }
        .padding(24)
        .frame(width: 380, height: 280)
        .background(NothingTheme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(NothingTheme.border, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
}
