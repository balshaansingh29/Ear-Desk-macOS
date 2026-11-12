import Foundation

/// ANC capability bits from `ancLevel` in ear_config_file.json (see device_common.js).
public struct ANCCapabilities: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let strengthBase = ANCCapabilities(rawValue: 0x04)      // High + Low
    public static let strengthMid = ANCCapabilities(rawValue: 0x02)       // + Mid
    public static let strengthAdaptive = ANCCapabilities(rawValue: 0x08)  // + Adaptive
    public static let transparency = ANCCapabilities(rawValue: 0x10)
}

public enum SpatialAudioMode: String, CaseIterable, Identifiable {
    case off
    case fixed
    case headTracked
    case concert
    case theatre

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: return "Off"
        case .fixed: return "Fixed"
        case .headTracked: return "Head Tracked"
        case .concert: return "Concert"
        case .theatre: return "Theatre"
        }
    }

    public var wirePayload: (mode: UInt8, head: UInt8) {
        switch self {
        case .off: return (0x00, 0x00)
        case .fixed: return (0x01, 0x00)
        case .headTracked: return (0x01, 0x01)
        case .concert: return (0x02, 0x00)
        case .theatre: return (0x03, 0x00)
        }
    }

    public static func from(modeByte: UInt8, headByte: UInt8) -> SpatialAudioMode {
        if modeByte == 0 { return .off }
        if modeByte == 1 {
            return headByte == 1 ? .headTracked : .fixed
        }
        if modeByte == 2 { return .concert }
        if modeByte == 3 { return .theatre }
        return .off
    }
}

public enum EQStyle {
    /// Classic EQ command (0xF010): Balanced / More Voice / More Treble / More Bass / Custom.
    case classic
    /// "Listening mode" command (0xF01D) with genre presets (CMF Buds line, Pro 2, headphones).
    case listeningMode(presets: [(name: String, wire: UInt8)])
}

public struct DeviceModel {
    public let base: String
    public let displayName: String
    public let ancLevel: Int            // -1 = no ANC
    public let eqStyle: EQStyle
    public let supportsBassEnhance: Bool
    public let threeStageBass: Bool
    public let supportsInEar: Bool
    public let supportsDualConnection: Bool
    public let ringStyle: RingStyle
    public let customEQHighShelfFreq: Float
    public let supportedSpatialModes: [SpatialAudioMode]

    public enum RingStyle { case single, perBud, headphone }

    public init(base: String,
                displayName: String,
                ancLevel: Int,
                eqStyle: EQStyle,
                supportsBassEnhance: Bool,
                threeStageBass: Bool,
                supportsInEar: Bool,
                supportsDualConnection: Bool = true,
                ringStyle: RingStyle,
                customEQHighShelfFreq: Float = 3500.0,
                supportedSpatialModes: [SpatialAudioMode] = []) {
        self.base = base
        self.displayName = displayName
        self.ancLevel = ancLevel
        self.eqStyle = eqStyle
        self.supportsBassEnhance = supportsBassEnhance
        self.threeStageBass = threeStageBass
        self.supportsInEar = supportsInEar
        self.supportsDualConnection = supportsDualConnection
        self.ringStyle = ringStyle
        self.customEQHighShelfFreq = customEQHighShelfFreq
        self.supportedSpatialModes = supportedSpatialModes
    }

    public var anc: ANCCapabilities? { ancLevel < 0 ? nil : ANCCapabilities(rawValue: ancLevel) }
    public var hasANC: Bool { ancLevel >= 0 }

    /// SF Symbol name representing this device type
    public var systemIconName: String {
        let name = displayName.lowercased()
        if ringStyle == .headphone || name.contains("headphone") {
            return "headphones"
        } else if name.contains("neckband") {
            return "beats.earphones"
        } else if name.contains("ear (open)") || name.contains("clip") {
            return "earbuds.case"
        } else {
            return "earbuds"
        }
    }
}

public enum DeviceCatalog {
    // Sets taken from bluetooth_socket.js.
    static let listeningModeBases: Set<String> = ["B172", "B195", "B168", "B179", "B197", "B184", "B185", "B175", "B189"]
    static let bassBases: Set<String> = ["B171", "B172", "B195", "B168", "B162", "B184", "B179", "B197", "B170", "B185", "B164", "B173", "B189", "B186"]
    static let threeStageBassBases: Set<String> = ["B189", "B186", "B195", "B197"]
    static let noInEarBases: Set<String> = ["B174", "B185", "B175", "B189", "B186"]
    static let noDualConnectionBases: Set<String> = ["B181", "B157"] // ear (1) and ear (stick) lack multipoint
    static let headphoneRingBases: Set<String> = ["B170", "B164", "B175", "B186", "B192"]

    static let diracPresets: [(name: String, wire: UInt8)] =
        [("Dirac OPTEO", 0), ("Pop", 3), ("Rock", 1), ("Classical", 5), ("Custom", 6), ("Electronic", 2), ("Enhance Vocals", 4)]
    static let genrePresets: [(name: String, wire: UInt8)] =
        [("Pop", 3), ("Rock", 1), ("Electronic", 2), ("Classical", 5), ("Custom", 6), ("Enhance Vocals", 4)]
    static let diracBases: Set<String> = ["B172", "B195"]

    static let highShelf6900Bases: Set<String> = ["B163", "B179", "B184", "B197", "B190"]
    static let highShelf3400Bases: Set<String> = ["B155", "B162", "B168", "B171", "B174", "B185", "B189", "B192"]
    static let concertTheatreSpatialBases: Set<String> = ["B175", "B186"]
    static let headTrackedSpatialBases: Set<String> = ["B170", "B173"]
    static let fixedSpatialBases: Set<String> = ["B179", "B181", "B184", "B185", "B189", "B190", "B197", "B172", "B195"]


    // (base, marketing name, ancLevel from ear_config_file.json)
    static let rows: [(String, String, Int)] = [
        ("B181", "Nothing ear (1)", 53), ("B157", "Ear (Stick)", 33), ("B155", "Nothing Ear (2)", 63),
        ("B171", "Nothing Ear", 63), ("B162", "Nothing Ear (a)", 63), ("B174", "Nothing Ear (open)", -1),
        ("B163", "Buds Pro", 55), ("B164", "Neckband Pro", 63), ("B168", "CMF Buds", 49),
        ("B172", "CMF Buds Pro 2", 63), ("B179", "CMF Buds 2", 63), ("B197", "CMF Buds 2", 63),
        ("B184", "CMF Buds 2 Plus", 63), ("B185", "CMF Buds 2a", 49), ("B195", "CMF Buds Pro 2", 63),
        ("B170", "Nothing Headphone (1)", 63), ("B173", "Nothing Ear (3)", 63),
        ("B175", "CMF Headphone Pro", 63), ("B186", "Nothing Headphone (a)", 63),
        ("B190", "Nothing Ear (3a)", 63), ("B189", "CMF Clip Pro", -1),
        ("B192", "Nothing Headphone (1) Pro", 63),
    ]

    public static let all: [DeviceModel] = rows.map { base, name, anc in
        let style: EQStyle
        if listeningModeBases.contains(base) {
            style = .listeningMode(presets: diracBases.contains(base) ? diracPresets : genrePresets)
        } else {
            style = .classic
        }
        let highShelfFreq: Float = {
            if highShelf6900Bases.contains(base) { return 6900.0 }
            if highShelf3400Bases.contains(base) { return 3400.0 }
            return 3500.0
        }()
        let spatialModes: [SpatialAudioMode] = {
            if concertTheatreSpatialBases.contains(base) {
                return [.off, .concert, .theatre]
            } else if headTrackedSpatialBases.contains(base) {
                return [.off, .fixed, .headTracked]
            } else if fixedSpatialBases.contains(base) {
                return [.off, .fixed]
            }
            return []
        }()
        return DeviceModel(
            base: base, displayName: name, ancLevel: anc, eqStyle: style,
            supportsBassEnhance: bassBases.contains(base),
            threeStageBass: threeStageBassBases.contains(base),
            supportsInEar: !noInEarBases.contains(base),
            supportsDualConnection: !noDualConnectionBases.contains(base),
            ringStyle: base == "B181" ? .single : (headphoneRingBases.contains(base) ? .headphone : .perBud),
            customEQHighShelfFreq: highShelfFreq,
            supportedSpatialModes: spatialModes
        )
    }

    /// Best-effort match from the Bluetooth device name (macOS does not expose Fast Pair model IDs).
    public static func match(name: String) -> DeviceModel? {
        let n = name.lowercased()
        // Longest marketing name that is contained in the BT name wins.
        return all
            .filter { n.contains($0.displayName.lowercased()) }
            .max { $0.displayName.count < $1.displayName.count }
    }

    public static func looksLikeSupportedDevice(name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("nothing") || n.contains("cmf") || n.hasPrefix("ear")
    }
}
