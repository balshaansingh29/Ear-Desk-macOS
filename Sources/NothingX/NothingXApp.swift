import SwiftUI
import AppKit
import NothingXCore

@main
struct NothingXApp: App {
    @StateObject private var controller = EarbudsController()

    var body: some Scene {
        WindowGroup("Nothing X") {
            ContentView().environmentObject(controller)
        }
        .windowResizability(.contentMinSize)
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
        Button("Open Nothing X") {
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
        Button("Quit Nothing X") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
