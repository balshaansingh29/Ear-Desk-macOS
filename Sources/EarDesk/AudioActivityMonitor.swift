import Foundation
import CoreAudio

/// Observes macOS system audio activity to detect whether audio is currently streaming through output devices
@MainActor
final class AudioActivityMonitor: ObservableObject {
    static let shared = AudioActivityMonitor()

    @Published private(set) var isAudioPlaying: Bool = false

    private var pollTimer: Timer?

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        checkAudioStatus()
        pollTimer?.invalidate()
        // Poll every 0.6 seconds - lightweight CoreAudio property read
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAudioStatus()
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        isAudioPlaying = false
    }

    private func checkAudioStatus() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultOutputDeviceID
        )

        guard status == noErr, defaultOutputDeviceID != kAudioDeviceUnknown else {
            if isAudioPlaying { isAudioPlaying = false }
            return
        }

        var isRunning: UInt32 = 0
        var runAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var runSize = UInt32(MemoryLayout<UInt32>.size)
        let runStatus = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &runAddress,
            0,
            nil,
            &runSize,
            &isRunning
        )

        let playing = (runStatus == noErr && isRunning != 0)
        if playing != isAudioPlaying {
            isAudioPlaying = playing
        }
    }
}
