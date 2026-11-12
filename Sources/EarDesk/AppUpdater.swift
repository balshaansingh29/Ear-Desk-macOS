import Foundation
import AppKit

/// Manages checking for GitHub releases, downloading updates with live progress, and in-place application replacement.
@MainActor
public final class AppUpdater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = AppUpdater()

    public enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, releaseNotes: String, downloadUrl: URL)
        case downloading(progress: Double)
        case installing(step: String)
        case readyToRestart(appPath: String)
        case failed(error: String)
    }

    @Published public private(set) var status: UpdateStatus = .idle
    @Published public private(set) var lastChecked: Date? = nil
    @Published public private(set) var downloadProgress: Double = 0.0

    private let repo = "balshaansingh29/Ear-Desk-macOS"
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var tempDownloadDir: URL?

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.0"
    }

    public override init() {
        super.init()
    }

    /// Checks GitHub for the latest release tag
    public func checkForUpdates(manual: Bool = false) async {
        status = .checking
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            status = .failed(error: "Invalid repository URL")
            return
        }

        var req = URLRequest(url: url)
        req.setValue("EarDeskApp", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                status = .failed(error: "Unable to reach update server (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return
            }

            struct Asset: Decodable {
                let name: String
                let browser_download_url: String
            }
            struct Release: Decodable {
                let tag_name: String
                let body: String?
                let assets: [Asset]
            }

            let release = try JSONDecoder().decode(Release.self, from: data)
            lastChecked = Date()

            let latestVer = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let currentVer = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            if isVersion(latestVer, newerThan: currentVer) {
                if let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
                   let dlUrl = URL(string: zipAsset.browser_download_url) {
                    status = .updateAvailable(version: latestVer, releaseNotes: release.body ?? "", downloadUrl: dlUrl)
                } else if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
                          let dlUrl = URL(string: dmgAsset.browser_download_url) {
                    status = .updateAvailable(version: latestVer, releaseNotes: release.body ?? "", downloadUrl: dlUrl)
                } else {
                    status = .failed(error: "No downloadable binaries found in release v\(latestVer)")
                }
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed(error: error.localizedDescription)
        }
    }

    /// Downloads and installs the update with live reactive download progress
    public func downloadAndInstall(url: URL) async {
        downloadProgress = 0.0
        status = .downloading(progress: 0.0)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.tempDownloadDir = tempDir

        let destArchive = tempDir.appendingPathComponent(url.lastPathComponent)

        do {
            let downloadedTempUrl: URL = try await withCheckedThrowingContinuation { continuation in
                self.downloadContinuation = continuation
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
                let task = session.downloadTask(with: url)
                task.resume()
            }

            try FileManager.default.moveItem(at: downloadedTempUrl, to: destArchive)

            status = .installing(step: "Extracting package…")

            let currentAppBundle = Bundle.main.bundleURL
            let isAppBundle = currentAppBundle.pathExtension == "app"
            let targetInstallPath = isAppBundle ? currentAppBundle.path : "/Applications/Ear-Desk.app"

            if destArchive.pathExtension == "zip" {
                let unzipDir = tempDir.appendingPathComponent("extracted")
                try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-q", destArchive.path, "-d", unzipDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()

                let extractedItems = try FileManager.default.contentsOfDirectory(atPath: unzipDir.path)
                guard let appFolder = extractedItems.first(where: { $0.hasSuffix(".app") }) else {
                    status = .failed(error: "Update archive does not contain Ear-Desk.app")
                    return
                }

                status = .installing(step: "Verifying binary…")
                let newAppPath = unzipDir.appendingPathComponent(appFolder).path
                performSelfReplacement(from: newAppPath, to: targetInstallPath)
            } else if destArchive.pathExtension == "dmg" {
                let mountPoint = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

                let hdiProcess = Process()
                hdiProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                hdiProcess.arguments = ["attach", destArchive.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
                try hdiProcess.run()
                hdiProcess.waitUntilExit()

                defer {
                    let detach = Process()
                    detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detach.arguments = ["detach", mountPoint.path, "-quiet", "-force"]
                    try? detach.run()
                    detach.waitUntilExit()
                }

                let mountedItems = (try? FileManager.default.contentsOfDirectory(atPath: mountPoint.path)) ?? []
                guard let appFolder = mountedItems.first(where: { $0.hasSuffix(".app") }) else {
                    status = .failed(error: "DMG does not contain Ear-Desk.app")
                    return
                }

                status = .installing(step: "Verifying binary…")
                let newAppPath = mountPoint.appendingPathComponent(appFolder).path
                performSelfReplacement(from: newAppPath, to: targetInstallPath)
            }
        } catch {
            status = .failed(error: "Update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - URLSessionDownloadDelegate
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let prog = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        Task { @MainActor in
            self.downloadProgress = prog
            self.status = .downloading(progress: prog)
        }
    }

    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempTarget = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.copyItem(at: location, to: tempTarget)
        Task { @MainActor in
            self.downloadContinuation?.resume(returning: tempTarget)
            self.downloadContinuation = nil
        }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }

    /// Writes helper script to swap old app with new app and relaunch
    private func performSelfReplacement(from sourceAppPath: String, to targetAppPath: String) {
        let scriptPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("eardesk_update_\(UUID().uuidString).sh")

        let scriptContent = """
        #!/bin/bash
        sleep 1.2
        rm -rf "\(targetAppPath)"
        cp -R "\(sourceAppPath)" "\(targetAppPath)"
        xattr -rd com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
        open -a "\(targetAppPath)"
        rm -- "$0"
        """

        do {
            try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", scriptPath.path]
            try chmod.run()
            chmod.waitUntilExit()

            status = .readyToRestart(appPath: targetAppPath)

            let launchTask = Process()
            launchTask.executableURL = scriptPath
            try launchTask.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            status = .failed(error: "Failed to schedule restart: \(error.localizedDescription)")
        }
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1Parts.count, v2Parts.count) {
            let p1 = i < v1Parts.count ? v1Parts[i] : 0
            let p2 = i < v2Parts.count ? v2Parts[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}
