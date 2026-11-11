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

public enum EQStyle {
    /// Classic EQ command (0xF010): Balanced / More Voice / More Treble / More Bass.
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
    public let ringStyle: RingStyle

    public enum RingStyle { case single, perBud, headphone }

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
    static let headphoneRingBases: Set<String> = ["B170", "B164", "B175", "B186", "B192"]

    static let diracPresets: [(name: String, wire: UInt8)] =
        [("Dirac OPTEO", 0), ("Pop", 3), ("Rock", 1), ("Classical", 5), ("Custom", 6), ("Electronic", 2), ("Enhance Vocals", 4)]
    static let genrePresets: [(name: String, wire: UInt8)] =
        [("Pop", 3), ("Rock", 1), ("Electronic", 2), ("Classical", 5), ("Custom", 6), ("Enhance Vocals", 4)]
    static let diracBases: Set<String> = ["B172", "B195"]

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
        return DeviceModel(
            base: base, displayName: name, ancLevel: anc, eqStyle: style,
            supportsBassEnhance: bassBases.contains(base),
            threeStageBass: threeStageBassBases.contains(base),
            supportsInEar: !noInEarBases.contains(base),
            ringStyle: base == "B181" ? .single : (headphoneRingBases.contains(base) ? .headphone : .perBud))
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
