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
                Image(systemName: "earbuds")
            }
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var ctl: EarbudsController

    private func bringAppToFront() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    var body: some View {
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
            Button("Not Connected - Open App") {
                bringAppToFront()
            }
        }
        Divider()
        Button("Quit Nothing X") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
