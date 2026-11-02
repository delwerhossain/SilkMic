// SilkMic/Voice/DriverInstaller.swift
import AppKit
import Foundation
import os

/// Installs the SilkMic virtual mic (a Core Audio HAL plug-in shipped inside the app) into
/// /Library/Audio/Plug-Ins/HAL. Runs once on first launch and again after an update that ships a
/// newer driver. macOS asks for the admin password; all audio drops for a second while
/// Core Audio restarts.
@MainActor
enum DriverInstaller {
    private static let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Driver")
    private static let skippedVersionKey = "silkmic.driver.skippedVersion"

    static let installedURL = URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL/SilkMicDriver.driver")

    /// The driver inside the app bundle. Missing in plain Xcode builds (developers install it with
    /// `Driver/install-driver.sh`), so nothing is offered there.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: "SilkMicDriver", withExtension: "driver")
    }

    static func version(at url: URL) -> String? {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: installedURL.path) }

    /// True when the app carries a driver and the installed one is missing or different.
    static var needsInstall: Bool {
        guard let bundled = bundledURL, let bundledVersion = version(at: bundled) else { return false }
        return version(at: installedURL) != bundledVersion
    }

    /// Asks once per driver version; "Later" is remembered until the next driver update.
    static func offerInstallIfNeeded() {
        guard needsInstall, let bundled = bundledURL else { return }
        let bundledVersion = version(at: bundled) ?? ""
        guard UserDefaults.standard.string(forKey: skippedVersionKey) != bundledVersion else { return }

        let alert = NSAlert()
        alert.messageText = isInstalled ? "Update the SilkMic microphone" : "Install the SilkMic microphone"
        alert.informativeText = """
            Clean Mic works through a small virtual microphone called "SilkMic". \
            macOS will ask for your password to install it. Sound stops for a second while it installs.
            """
        alert.addButton(withTitle: isInstalled ? "Update" : "Install")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(bundledVersion, forKey: skippedVersionKey)
            return
        }
        Task { await install(from: bundled) }
    }

    /// Copies the driver with admin rights and restarts Core Audio. Returns whether it worked.
    @discardableResult
    static func install(from source: URL) async -> Bool {
        let command = [
            "rm -rf \(shellQuoted(installedURL.path))",
            "cp -R \(shellQuoted(source.path)) \(shellQuoted(installedURL.deletingLastPathComponent().path))/",
            "xattr -dr com.apple.quarantine \(shellQuoted(installedURL.path)) 2>/dev/null || true",
            "killall coreaudiod 2>/dev/null || true",
        ].joined(separator: " && ")
        let script = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        let error: String? = await Task.detached {
            var info: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&info)
            return info?[NSAppleScript.errorMessage] as? String
        }.value

        if let error {
            logger.error("Driver install failed: \(error, privacy: .public)")
            return false
        }
        logger.info("Driver installed (\(version(at: installedURL) ?? "?", privacy: .public))")
        return true
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
