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

    var body: some View {
        Group {
            if ctl.link == .connected {
                ControlsView()
            } else {
                ConnectView()
            }
        }
        .frame(minWidth: 460, idealWidth: 480, minHeight: 600)
        .background(NothingTheme.bg.ignoresSafeArea())
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
                if ctl.model?.supportsBassEnhance ?? false { BassSection() }
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
                if let icon {
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.6) : NothingTheme.textTertiary)
                }
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

    private var barHeights: [CGFloat] {
        switch presetName.lowercased() {
        case "more bass": return [0.95, 0.75, 0.40, 0.20]
        case "more treble": return [0.20, 0.40, 0.75, 0.95]
        case "more voice": return [0.30, 0.85, 0.70, 0.30]
        case "balanced": return [0.55, 0.55, 0.55, 0.55]
        case "rock": return [0.85, 0.45, 0.60, 0.85]
        case "pop": return [0.65, 0.80, 0.75, 0.55]
        case "electronic": return [0.90, 0.60, 0.50, 0.85]
        case "classical": return [0.55, 0.50, 0.70, 0.80]
        case "enhance vocals": return [0.30, 0.90, 0.75, 0.35]
        case "dirac opteo": return [0.70, 0.70, 0.70, 0.70]
        default: return [0.50, 0.50, 0.50, 0.50]
        }
    }

    @State private var animPhase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 3.5) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                let jitter: CGFloat = animPhase ? CGFloat(sin(Double(i) * 1.3)) * 0.12 : -CGFloat(cos(Double(i) * 0.9)) * 0.10
                let h = max(4, (barHeights[i] + jitter) * 24)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(NothingTheme.red)
                    .frame(width: 3.5, height: h)
                    .animation(.easeInOut(duration: 0.7 + Double(i) * 0.15).repeatForever(autoreverses: true), value: animPhase)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 6)
        .onAppear { animPhase = true }
    }
}

struct EQSection: View {
    @EnvironmentObject var ctl: EarbudsController

    private var presets: [(name: String, wire: UInt8)] {
        switch ctl.model?.eqStyle {
        case .listeningMode(let p)?: return p
        default: return [("Balanced", 0), ("More Voice", 1), ("More Treble", 2), ("More Bass", 3)]
        }
    }

    private var activePresetName: String {
        presets.first(where: { $0.wire == ctl.eqWire })?.name ?? "Balanced"
    }

    var body: some View {
        Card(title: "Equalizer", icon: "slider.vertical.3") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("PROFILE: \(activePresetName.uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(NothingTheme.textSecondary)
                    Spacer()
                    EQVisualizerView(presetName: activePresetName)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(presets, id: \.wire) { preset in
                        let isSelected = ctl.eqWire == preset.wire
                        Button {
                            ctl.setEQ(wire: preset.wire)
                        } label: {
                            HStack(spacing: 5) {
                                if isSelected {
                                    Circle()
                                        .fill(NothingTheme.red)
                                        .frame(width: 4, height: 4)
                                }
                                Text(preset.name.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1.0)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
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

                if ctl.eqWire == 5 || ctl.eqWire == 6 {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text("A custom or advanced EQ profile is active on the earbuds.")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(NothingTheme.textTertiary)
                    .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Bass Section

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
