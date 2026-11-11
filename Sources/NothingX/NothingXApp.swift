import SwiftUI
import NothingXCore

@main
struct NothingXApp: App {
    @StateObject private var controller = EarbudsController()

    var body: some Scene {
        WindowGroup("Nothing X") {
            ContentView().environmentObject(controller)
        }
        .windowResizability(.contentMinSize)

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

    var body: some View {
        if ctl.link == .connected {
            Button(ctl.deviceName) {}
            if let s = ctl.battery.stereo {
                Button("Battery \(s.level)%") {}
            } else {
                let parts = [("L", ctl.battery.left), ("R", ctl.battery.right), ("Case", ctl.battery.caseCell)]
                    .compactMap { label, cell in cell.map { "\(label) \($0.level)%" } }
                if !parts.isEmpty {
                    Button(parts.joined(separator: "  ")) {}
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
            Text("Not connected")
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
