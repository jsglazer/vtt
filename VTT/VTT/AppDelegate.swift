import Cocoa
import ApplicationServices
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: VTTController?
    private static let firstRunKey = "vtt.firstRunComplete"

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")
        print("VTT: applicationDidFinishLaunching")

        controller = VTTController()
        Task { await controller?.loadModel() }

        let isFirstRun = !UserDefaults.standard.bool(forKey: Self.firstRunKey)
        DispatchQueue.main.async {
            if isFirstRun {
                self.showWelcome()
            } else if !AXIsProcessTrusted() {
                print("VTT: accessibility trusted = false — showing prompt")
                self.showAccessibilityAlert()
            } else {
                print("VTT: accessibility trusted = true")
            }
        }
    }

    private func showWelcome() {
        UserDefaults.standard.set(true, forKey: Self.firstRunKey)

        let isCached = FileManager.default.fileExists(
            atPath: (FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v2/config.json")).path
        )

        let downloadNote = isCached
            ? ""
            : "\n\nThe speech recognition model is downloading now (~300 MB, one-time). VTT will be ready when the menu shows \"Status: Idle\"."

        let alert = NSAlert()
        alert.messageText = "Welcome to VTT"
        alert.informativeText = """
            VTT transcribes your voice and types it directly into any app.

            • Hotkey: ⌘⇧Space — tap once to start recording, tap again to stop
            • Works in Sublime Text, Drafts, Notes, and any text field
            • All speech recognition runs fully on-device\(downloadNote)

            Accessibility permission is required to type into other apps — you'll be prompted next if it isn't granted yet.
            """
        alert.addButton(withTitle: "Get Started")
        alert.alertStyle = .informational
        alert.runModal()

        if !AXIsProcessTrusted() {
            print("VTT: accessibility trusted = false — showing prompt")
            showAccessibilityAlert()
        } else {
            print("VTT: accessibility trusted = true")
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            VTT needs Accessibility permission to type into other apps (Sublime Text, Drafts, etc.).

            Click "Open Settings", enable VTT under Privacy & Security → Accessibility, then restart VTT.

            Note: after every Clean Build you must re-grant this permission.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
