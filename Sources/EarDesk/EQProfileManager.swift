import Foundation

struct EQProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var bass: Int
    var mid: Int
    var treble: Int
}

@MainActor
final class EQProfileManager: ObservableObject {
    static let shared = EQProfileManager()

    @Published var profiles: [EQProfile] = []

    private let userDefaultsKey = "custom_eq_profiles"

    init() {
        loadProfiles()
        if profiles.isEmpty {
            profiles = [
                EQProfile(name: "Vocal Clarity", bass: -1, mid: 3, treble: 2),
                EQProfile(name: "Bass Punch", bass: 5, mid: 0, treble: -1),
                EQProfile(name: "Warm Acoustic", bass: 2, mid: 1, treble: -2),
                EQProfile(name: "Bright & Crisp", bass: -2, mid: 1, treble: 4)
            ]
            saveProfiles()
        }
    }

    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([EQProfile].self, from: data) {
            profiles = decoded
        }
    }

    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addProfile(name: String, bass: Int, mid: Int, treble: Int) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        profiles.append(EQProfile(name: cleanName, bass: bass, mid: mid, treble: treble))
        saveProfiles()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
    }
}
