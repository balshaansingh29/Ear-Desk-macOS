import Foundation

public struct SharedDeviceBatteryState: Codable, Equatable {
    public var isConnected: Bool
    public var deviceName: String
    public var modelBase: String
    public var leftLevel: Int?
    public var leftCharging: Bool
    public var rightLevel: Int?
    public var rightCharging: Bool
    public var caseLevel: Int?
    public var caseCharging: Bool
    public var stereoLevel: Int?
    public var stereoCharging: Bool
    public var ancMode: String?
    public var lastUpdated: Date

    public init(
        isConnected: Bool = false,
        deviceName: String = "Nothing Ear",
        modelBase: String = "B155",
        leftLevel: Int? = nil,
        leftCharging: Bool = false,
        rightLevel: Int? = nil,
        rightCharging: Bool = false,
        caseLevel: Int? = nil,
        caseCharging: Bool = false,
        stereoLevel: Int? = nil,
        stereoCharging: Bool = false,
        ancMode: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.isConnected = isConnected
        self.deviceName = deviceName
        self.modelBase = modelBase
        self.leftLevel = leftLevel
        self.leftCharging = leftCharging
        self.rightLevel = rightLevel
        self.rightCharging = rightCharging
        self.caseLevel = caseLevel
        self.caseCharging = caseCharging
        self.stereoLevel = stereoLevel
        self.stereoCharging = stereoCharging
        self.ancMode = ancMode
        self.lastUpdated = lastUpdated
    }

    public static let sharedFilePath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let earDeskDir = appSupport.appendingPathComponent("Ear-Desk", isDirectory: true)
        try? FileManager.default.createDirectory(at: earDeskDir, withIntermediateDirectories: true)
        return earDeskDir.appendingPathComponent("widget_state.json")
    }()

    public static func load() -> SharedDeviceBatteryState {
        if let data = try? Data(contentsOf: sharedFilePath),
           let state = try? JSONDecoder().decode(SharedDeviceBatteryState.self, from: data) {
            return state
        }
        return SharedDeviceBatteryState()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.sharedFilePath, options: .atomic)
        }
    }
}
