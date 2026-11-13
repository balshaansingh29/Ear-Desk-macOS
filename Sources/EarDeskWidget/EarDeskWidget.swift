import WidgetKit
import SwiftUI

struct EarDeskWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EarDeskEntry {
        EarDeskEntry(date: Date(), state: SharedDeviceBatteryState(
            isConnected: true,
            deviceName: "Ear (a)",
            modelBase: "B164",
            leftLevel: 85,
            leftCharging: false,
            rightLevel: 90,
            rightCharging: false,
            caseLevel: 65,
            caseCharging: true,
            ancMode: "high"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (EarDeskEntry) -> Void) {
        let state = SharedDeviceBatteryState.load()
        completion(EarDeskEntry(date: Date(), state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EarDeskEntry>) -> Void) {
        let state = SharedDeviceBatteryState.load()
        let entry = EarDeskEntry(date: Date(), state: state)
        // Refresh every 15 minutes or when system refreshes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct EarDeskEntry: TimelineEntry {
    let date: Date
    let state: SharedDeviceBatteryState
}

struct EarDeskWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: EarDeskEntry

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.07)

            if entry.state.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color.white.opacity(0.3))

            Text("NO EARBUDS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Connect in menu bar")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .padding()
    }

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.85, green: 0.1, blue: 0.15))
                    .frame(width: 6, height: 6)

                Text(entry.state.deviceName.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if let anc = entry.state.ancMode {
                    Text(anc.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(3)
                        .foregroundColor(Color.white.opacity(0.8))
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Battery Rows
            HStack(spacing: 12) {
                if let stereo = entry.state.stereoLevel {
                    batteryRing(label: "STEREO", level: stereo, charging: entry.state.stereoCharging)
                } else {
                    if let left = entry.state.leftLevel {
                        batteryRing(label: "LEFT", level: left, charging: entry.state.leftCharging)
                    }
                    if let right = entry.state.rightLevel {
                        batteryRing(label: "RIGHT", level: right, charging: entry.state.rightCharging)
                    }
                }

                if let caseLvl = entry.state.caseLevel {
                    batteryRing(label: "CASE", level: caseLvl, charging: entry.state.caseCharging)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
    }

    private func batteryRing(label: String, level: Int, charging: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3.5)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0.0, to: CGFloat(max(0.05, min(1.0, Double(level) / 100.0))))
                    .stroke(
                        level <= 20 ? Color(red: 0.85, green: 0.1, blue: 0.15) : Color.white,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)

                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                } else {
                    Text("\(level)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
        }
    }
}

struct EarDeskWidget: Widget {
    let kind: String = "EarDeskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EarDeskWidgetProvider()) { entry in
            EarDeskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ear-Desk Status")
        .description("View live battery percentages for your Nothing earbuds directly on macOS.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct EarDeskWidgetBundle: WidgetBundle {
    var body: some Widget {
        EarDeskWidget()
    }
}
