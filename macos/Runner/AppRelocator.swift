import Cocoa

/// Copy a translocated / DMG / /var/folders launch into Applications and
/// relaunch. macOS force-unmounts those volumes (SIGBUS: “backing vnode was
/// force unmounted”) — mining just keeps the doomed mapping alive long enough
/// to hit it.
enum AppRelocator {
    static let installedBundleName = "GNFP Wallet.app"
    static let productBundleName = "gnfp_wallet.app"

    static func isInstalledInApplications(_ path: String) -> Bool {
        let lower = path.replacingOccurrences(of: "\\", with: "/").lowercased()
        return lower.contains("/applications/")
    }

    static func isMacosAppPath(_ path: String) -> Bool {
        let lower = path.replacingOccurrences(of: "\\", with: "/").lowercased()
        return lower.contains(".app/") || lower.hasSuffix(".app")
    }

    static func isDevBuildPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.contains("/build/macos/build/products/")
            || lower.contains("/deriveddata/")
    }

    /// True for App Translocation, temp folders, and disk-image volumes.
    static func isEphemeralLaunchPath(_ path: String) -> Bool {
        guard isMacosAppPath(path) else { return false }
        if isInstalledInApplications(path) { return false }
        let lower = path.replacingOccurrences(of: "\\", with: "/").lowercased()
        if lower.contains("/apptranslocation/") { return true }
        if lower.contains("/var/folders/") { return true }
        if lower.contains("/temporaryitems/") { return true }
        if lower.contains("/volumes/") { return true }
        return false
    }

    static func shouldRelocate(_ path: String) -> Bool {
        isEphemeralLaunchPath(path) && !isDevBuildPath(path)
    }

    /// Returns true when a new copy was opened and this process must exit.
    @discardableResult
    static func relocateAndRelaunchIfNeeded(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        let path = bundleURL.path
        guard shouldRelocate(path) else { return false }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let destinations = [
            URL(fileURLWithPath: "/Applications/\(installedBundleName)"),
            home.appendingPathComponent("Applications/\(installedBundleName)"),
            URL(fileURLWithPath: "/Applications/\(productBundleName)"),
            home.appendingPathComponent("Applications/\(productBundleName)"),
        ]
        for dest in destinations {
            if copyBundle(from: bundleURL, to: dest) {
                stripQuarantine(dest)
                NSWorkspace.shared.open(dest)
                return true
            }
        }
        return false
    }

    static func copyBundle(from source: URL, to dest: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: source, to: dest)
            return fm.fileExists(atPath: dest.path)
        } catch {
            return false
        }
    }

    static func stripQuarantine(_ dest: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        proc.arguments = ["-dr", "com.apple.quarantine", dest.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }
}
